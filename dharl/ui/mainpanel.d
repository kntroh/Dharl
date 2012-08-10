
/// This module includes MainPanel and members related to it. 
module dharl.ui.mainpanel;

private import dharl.common;
private import dharl.util.undomanager;
private import dharl.util.graphics;
private import dharl.util.utils;
private import dharl.ui.mlimage;
private import dharl.ui.paintarea;
private import dharl.ui.paletteview;
private import dharl.ui.colorslider;
private import dharl.ui.pimagelist;
private import dharl.ui.uicommon;
private import dharl.ui.dwtfactory;
private import dharl.ui.dwtutils;

private import std.algorithm;
private import std.exception;
private import std.path;
private import std.string;
private import std.traits;

private import org.eclipse.swt.all;

private import java.lang.all;

/// Parameter for PImage management.
private class PImageParams {
	/// Is saved?
	bool saved = false;
	/// File path.
	string path = "";
	/// Image name.
	string name = "";
	/// Bitmap depth.
	ubyte depth = 8;
	/// Counter of modify.
	uint modCount = 0;
	/// Counter of modify at  saved time.
	uint modCountS = 0;

	/// Does modified this?
	@property
	bool modify() { return modCount != modCountS; }
}

/// The main panel for dharl.
class MainPanel : Composite {
	/// Status changed receivers. TODO comment
	void delegate()[] statusChangedReceivers;
	/// Selected receivers. TODO comment
	void delegate()[] selectedReceivers;

	private DCommon _c = null;

	private PaintArea _paintArea = null;
	private PaintPreview _paintPreview = null;
	private LayerList _layerList = null;
	private PaletteView _paletteView = null;
	private ColorSlider _colorSlider = null;
	private PImageList _imageList = null;

	/// Tool bar for tones.
	private ToolBar _tones = null;

	private UndoManager _um = null;

	// Pushed image before draws.
	private Object _pushBase = null;

	/// The only constructor.
	this (Composite parent, int style) {
		super (parent, style);
	}
	/// Initialize instance.
	void init(DCommon c) {
		if (!c) {
			SWT.error(__FILE__, __LINE__, SWT.ERROR_NULL_ARGUMENT);
		}
		_c = c;

		this.p_layout = new FillLayout;

		_um = new UndoManager(_c.conf.undoMax);

		/// Splits PImageList and other controls.
		auto sash = basicSashForm(this, SWT.HORIZONTAL);
		constructPaintArea(sash, _um);
		constructImageList(sash, _um);
		setRefWeights(sash, _c.conf.weightsWork_List.value);

		_paletteView.listeners!(SWT.Selection) ~= {
			_um.resetRetryWord();
			_paintArea.pixel = _paletteView.pixel1;
			_paintArea.backgroundPixel = _paletteView.pixel2;
			_paintArea.mask = _paletteView.mask;
			_colorSlider.color = _paletteView.color(_paletteView.pixel1);
		};
		_paintArea.listeners!(SWT.Selection) ~= {
			_um.resetRetryWord();
			_paletteView.pixel1 = _paintArea.pixel;
			_colorSlider.color = _paletteView.color(_paletteView.pixel1);
		};
		_colorSlider.listeners!(SWT.Selection) ~= {
			auto pixel = _paletteView.pixel1;
			auto rgb = _colorSlider.color;
			if (rgb == _paletteView.color(pixel)) return;

			// TODO comment
			Undoable[] us = [_paletteView];
			int sel = _imageList.selectedIndex;
			if (-1 != sel) {
				us ~= _imageList.item(sel).image;
			}
			_um.store(us, null, "Slide color");

			_paletteView.color(pixel, rgb);
			_paintArea.color(pixel, rgb);
			if (-1 != sel) {
				auto item = _imageList.item(sel);
				item.color(pixel, rgb);
				modified(item);
			}
			_paintPreview.redraw();
		};

		_imageList.listeners!(SWT.Selection) ~= {
			selectImage(_imageList.selectedIndex);
		};
		_imageList.listeners!(SWT.MouseDown) ~= (Event e) {
			if (e.button != 1 && e.button != 3) return;
			int sel = _imageList.indexOf(e.x, e.y);
			if (-1 == sel) return;
			switch (e.button) {
			case 1:
				// Send on paintArea to imageList item.
				auto item = _imageList.item(sel);
				_um.store(item.image, {
					_paintArea.fixPaste();
					if (item.pushImage(_paintArea.image)) {
						_pushBase = _paintArea.image.storeData;
						modified(item);
						return true;
					}
					return false;
				});
				break;
			case 3:
				// Send on imageList item to paintArea.
				auto item = _imageList.item(sel);
				auto image = item.image;
				auto bounds = item.selectedPiece;
				_paintArea.pushImage(image, bounds.x, bounds.y);
				_paintPreview.redraw();
				_layerList.redraw();
				_pushBase = _paintArea.image.storeData;
				break;
			default: assert (0);
			}
		};
		_um.statusChangedReceivers ~= {
			statusChangedReceivers.raiseEvent();
		};
		_paintArea.statusChangedReceivers ~= {
			statusChangedReceivers.raiseEvent();
		};
		_paintArea.selectChangedReceivers ~= (int x, int y, int w, int h) {
			statusChangedReceivers.raiseEvent();
		};
		_paletteView.statusChangedReceivers ~= {
			statusChangedReceivers.raiseEvent();
		};
		_paletteView.colorChangeReceivers ~= (int pixel, in RGB afterRGB) {
			int sel = _imageList.selectedIndex;
			Undoable[] us = [_paletteView];
			if (-1 != sel) us ~= _imageList.item(sel).image;
			_um.store(us, {
				_paintArea.color(pixel, afterRGB);
				return true;
			});
		};
		_paletteView.colorSwapReceivers ~= (int pixel1, int pixel2) {
			int sel = _imageList.selectedIndex;
			Undoable[] us = [cast(Undoable) _paletteView, _paintArea];
			MLImage img = null;
			if (-1 != sel) {
				img = _imageList.item(sel).image;
				us ~= img;
			}
			_um.store(us, {
				_paintArea.swapColor(pixel1, pixel2);
				if (img) {
					img.swapColor(pixel1, pixel2);
				}
				return true;
			});
		};
		_imageList.removedReceivers ~= {
			if (0 == _imageList.imageCount) {
				_paintArea.setCanvasSize(0, 0);
			}
			statusChangedReceivers.raiseEvent();
		};
		_paletteView.restoreReceivers ~= {
			_paintArea.colors = _paletteView.colors;
			_colorSlider.color = _paletteView.color(_paletteView.pixel1);
			int sel = _imageList.selectedIndex;
			if (-1 != sel) {
				_imageList.item(sel).colors(_paletteView.colors);
			}
			_paintPreview.redraw();
		};
		_imageList.removeReceivers ~= &canCloseImage;
	}

	/// If doesn't initialized throws exception.
	const
	private void checkInit() {
		enforce(_c, new Exception("MainPanel is no initialized.", __FILE__, __LINE__));
	}

	/// Creates paint area and palette. TODO comment
	private void constructPaintArea(Composite parent, UndoManager um) {
		checkWidget();
		checkInit();

		// TODO comment
		auto ppSash = basicSashForm(parent, SWT.VERTICAL);
		scope (exit) setRefWeights(paintSash, _c.conf.weightsPaint_Preview.value);

		// TODO comment
		auto paintSash = basicSashForm(ppSash, SWT.HORIZONTAL);
		scope (exit) setRefWeights(ppSash, _c.conf.weightsPaint_Palette.value);

		// TODO comment
		auto ptSash = basicSashForm(paintSash, SWT.VERTICAL);
		scope (exit) setRefWeights(ptSash, _c.conf.weightsPreview_Tools.value);

		// TODO comment
		_paintPreview = new PaintPreview(ptSash, SWT.BORDER | SWT.DOUBLE_BUFFERED);
		_paintPreview.p_layoutData = GD(GridData.VERTICAL_ALIGN_BEGINNING);

		// TODO comment
		_paintArea = new PaintArea(paintSash, SWT.BORDER | SWT.DOUBLE_BUFFERED);
		_paintArea.p_layoutData = GD(GridData.FILL_BOTH).hSpan(2);
		_paintArea.undoManager = um;

		constructModeToolBar(ptSash);

		// TODO comment
		auto comp = basicComposite(ppSash, GL.window(3, false));

		// TODO comment
		_colorSlider = new ColorSlider(comp, SWT.VERTICAL);
		_colorSlider.p_layoutData = GD(GridData.VERTICAL_ALIGN_BEGINNING).vSpan(2);
		auto css = _colorSlider.computeSize(SWT.DEFAULT, SWT.DEFAULT);

		// TODO comment
		_paletteView = new PaletteView(comp, SWT.BORDER | SWT.NO_BACKGROUND | SWT.DOUBLE_BUFFERED);
		_paletteView.p_layoutData = GD(GridData.VERTICAL_ALIGN_BEGINNING).vSpan(3);

		// TODO comment
		auto lToolBar = basicToolBar(comp);
		lToolBar.p_layoutData = GD(GridData.FILL_HORIZONTAL);
		basicToolItem(lToolBar, _c.text.menu.addLayer, cimg(_c.image.addLayer), &addLayer);
		basicToolItem(lToolBar, _c.text.menu.removeLayer, cimg(_c.image.removeLayer), &removeLayer);

		// TODO comment
		_layerList = new LayerList(comp, SWT.BORDER | SWT.DOUBLE_BUFFERED);
		_layerList.p_layoutData = GD(GridData.FILL_BOTH).vSpan(2);
		_layerList.undoManager = um;

		// TODO comment
		auto pToolBar = basicToolBar(comp, SWT.WRAP | SWT.FLAT);
		pToolBar.p_layoutData = GD(GridData.VERTICAL_ALIGN_BEGINNING);
		basicToolItem(pToolBar, _c.text.menu.createGradation,
			cimg(_c.image.createGradation),
			&createGradation);
		ToolItem tMask;
		tMask = basicToolItem(pToolBar, _c.text.menu.maskMode, cimg(_c.image.maskMode), {
			maskMode = tMask.p_selection;
		}, SWT.CHECK);
		ToolItem tBack;
		tBack = basicToolItem(pToolBar, _c.text.menu.enabledBackColor, cimg(_c.image.enabledBackColor), {
			_paintArea.enabledBackColor = tBack.p_selection;
		}, SWT.CHECK);
		void refreshPaletteMenu() {
			tMask.p_selection = maskMode;
			tBack.p_selection = _paintArea.enabledBackColor;
		}
		statusChangedReceivers ~= &refreshPaletteMenu;
		refreshPaletteMenu();

		// Initializes widgets.
		auto cs = _c.conf.character;
		_paintArea.init(cs.width, cs.height, _paletteView.createPalette());
		_paintArea.zoom = 1;
		_paintArea.mode = PaintMode.FreePath;
		_paintArea.cursorSize = 1;
		_paintArea.pixel = _paletteView.pixel1;
		_paintArea.backgroundPixel = _paletteView.pixel2;
		_paintArea.addLayer(_c.text.newLayer);
		auto cursor = ccur(_c.image.cursorPen, 0, 0);
		foreach (mode; EnumMembers!PaintMode) {
			_paintArea.cursor(mode, cursor);
		}
		_paintArea.cursorDropper = ccur(_c.image.cursorDropper, 0, 0);
		_paintPreview.init(_paintArea);
		_layerList.init(_paintArea);
		_colorSlider.color = _paletteView.color(_paletteView.pixel1);

		// TODO comment
		_pushBase = _paintArea.image.storeData;
	}
	/// Creates paint mode tool bar. TODO comment
	private void constructModeToolBar(Composite parent) {
		auto comp = basicComposite(parent, GL.noMargin(2, false));
		void createSeparator() {
			auto sep = separator(comp);
			sep.p_layoutData = GD(GridData.FILL_HORIZONTAL).wHint(0).hSpan(2);
		}
		void createLabel(string text) {
			auto label = basicLabel(comp, text);
			label.p_layoutData = GD(GridData.FILL_HORIZONTAL);
		}

		// Creates paint mode tool bar. TODO comment
		ToolItem[PaintMode] modeItems;
		auto mToolBar = basicToolBar(comp, SWT.WRAP | SWT.FLAT);
		mToolBar.p_layoutData = GD(GridData.FILL_HORIZONTAL).wHint(0).hSpan(2);
		void createModeItem(string text, Image img, PaintMode mode) {
			auto mt = basicToolItem(mToolBar, text, img, {
				_paintArea.mode = mode;
			}, SWT.RADIO);
			modeItems[mode] = mt;
		}
		// Selection mode. TODO comment
		ToolItem tSel;
		tSel = basicToolItem(mToolBar, _c.text.menu.selection, cimg(_c.image.selection), {
			_paintArea.rangeSelection = tSel.p_selection;
		}, SWT.RADIO, _paintArea.rangeSelection);

		// Paint mode. TODO comment
		createModeItem(_c.text.menu.freePath, cimg(_c.image.freePath), PaintMode.FreePath);
		createModeItem(_c.text.menu.straight, cimg(_c.image.straight), PaintMode.Straight);
		createModeItem(_c.text.menu.ovalLine, cimg(_c.image.ovalLine), PaintMode.OvalLine);
		createModeItem(_c.text.menu.rectLine, cimg(_c.image.rectLine), PaintMode.RectLine);
		createModeItem(_c.text.menu.ovalFill, cimg(_c.image.ovalFill), PaintMode.OvalFill);
		createModeItem(_c.text.menu.rectFill, cimg(_c.image.rectFill), PaintMode.RectFill);
		createModeItem(_c.text.menu.fillArea, cimg(_c.image.fillArea), PaintMode.Fill);

		void refreshModeMenu() {
			bool range = _paintArea.rangeSelection;
			tSel.p_selection = range;
			foreach (mode, item; modeItems) {
				item.p_selection = !range && _paintArea.mode == mode;
			}
		}
		statusChangedReceivers ~= &refreshModeMenu;
		refreshModeMenu();

		createSeparator();

		// Tones tool bar. TODO comment
		_tones = basicToolBar(comp, SWT.WRAP | SWT.FLAT);
		_tones.p_layoutData = GD(GridData.FILL_HORIZONTAL).wHint(0).hSpan(2);

		auto noTone = basicToolItem(_tones, _c.text.noTone, cimg(_c.image.noTone), {
			_paintArea.tone = null;
		}, SWT.RADIO, true);
		_tones.listeners!(SWT.Dispose) ~= &clearTonesToolBar;

		refreshTonesToolBar();

		createSeparator();

		// Zoom and line width. TODO comment
		createLabel(_c.text.zoom);
		auto zoom = basicSpinner(comp, 1, PaintArea.ZOOM_MAX);
		zoom.listeners!(SWT.Selection) ~= {
			_paintArea.zoom = zoom.p_selection;
		};
		createLabel(_c.text.lineWidth);
		auto lineWidth = basicSpinner(comp, 1, 16);
		lineWidth.listeners!(SWT.Selection) ~= {
			_paintArea.cursorSize = lineWidth.p_selection;
		};
		void refreshZoomAndLineWidth() {
			zoom.p_selection = _paintArea.zoom;
			lineWidth.p_selection = _paintArea.cursorSize;
		}
		statusChangedReceivers ~= &refreshZoomAndLineWidth;
	}
	/// Refreshs tones tool bar. TODO comment
	private void refreshTonesToolBar() {
		enforce(_tones);
		checkWidget();
		auto d = this.p_display;

		clearTonesToolBar();

		foreach (tone; _c.conf.tones.array) {
			auto icon = toneIcon(tone.value, 16, 16);
			basicToolItem(_tones, tone.name, new Image(d, icon), {
				_paintArea.tone = tone.value;
			}, SWT.RADIO, tone.value == _paintArea.tone);
		}
	}
	/// Clears tones tool bar. TODO comment
	private void clearTonesToolBar() {
		enforce(_tones);
		checkWidget();
		foreach_reverse (i; 1 .. _tones.p_itemCount) {
			auto item = _tones.getItem(i);
			auto img = item.p_image;
			item.dispose();
			img.dispose();
		}
	}

	/// Creates image list. TODO comment
	private void constructImageList(Composite parent, UndoManager um) {
		checkWidget();
		checkInit();
		_imageList = new PImageList(parent, SWT.BORDER | SWT.DOUBLE_BUFFERED);
	}

	/// Paint area. TODO comment
	@property
	PaintArea paintArea() {
		checkWidget();
		checkInit();
		return _paintArea;
	}

	/// Undo manager. TODO comment
	@property
	UndoManager undoManager() {
		checkWidget();
		checkInit();
		return _um;
	}

	/// Gets selected index at image list. TODO comment
	@property
	const
	int selectedIndex() {
		checkInit();
		return _imageList.selectedIndex;
	}
	/// Gets image name. TODO comment
	string imageName(size_t index) {
		checkWidget();
		checkInit();
		auto params = _imageList.item(index).dataTo!PImageParams;
		assert (params);
		return params.name;
	}
	/// Gets base file path of image at index. TODO comment
	string imagePath(size_t index) {
		checkWidget();
		checkInit();
		auto params = _imageList.item(index).dataTo!PImageParams;
		assert (params);
		return params.path;
	}

	/// TODO comment
	private void modified(PImageItem item) {
		checkWidget();
		checkInit();
		auto params = item.dataTo!PImageParams;
		assert (params);
		params.modCount++;
		if (params.modCountS == params.modCount - 1) {
			string changed = _c.text.fChanged.value;
			item.p_text = changed.format(params.name);

			statusChangedReceivers.raiseEvent();
		}
	}

	/// Creates new image. TODO comment
	void createNewImage(int width, int height, bool copyPalette) {
		checkWidget();
		checkInit();
		auto img = new MLImage;
		if (copyPalette) {
			img.init(width, height, _paletteView.createPalette());
		} else {
			img.init(width, height, PaletteView.createDefaultPalette());
		}
		img.addLayer(_c.text.newLayer);
		loadImage(img, _c.text.noName, "", 8, false);
	}
	/// Loads image from a file. A loaded image adds image list. TODO comment
	bool loadImage() {
		checkWidget();
		checkInit();
		auto dlg = new FileDialog(this.p_shell, SWT.OPEN | SWT.MULTI);
		static FILTER = "*.bmp;*.png;*.jpg;*.jpeg;*.tif;*.tiff";
		string type = _c.text.fLoadImageType.value;
		dlg.p_filterNames = [type.format(FILTER)];
		dlg.p_filterExtensions = [FILTER];
		if (!dlg.open()) return false;
		auto fPath = dlg.p_filterPath;
		auto names = dlg.p_fileNames;
		foreach (file; names) {
			auto path = fPath.buildPath(file);
			loadImage(path);
		}
		return true;
	}
	/// ditto
	void loadImage(string file) {
		checkWidget();
		checkInit();
		auto data = new ImageData(file);
		auto img = new MLImage;
		img.init(data, _c.text.newLayer);
		assert (1 == img.layerCount);
		bool saved = !data.palette.isDirect && data.depth <= 8;
		if (saved) {
			string ext = file.extension();
			if (0 != ext.filenameCmp(".bmp") && 0 != ext.filenameCmp(".png")) {
				saved = false;
			}
		}
		loadImage(img, file.baseName(), file, cast(ubyte) min(data.depth, 8), saved);
	}
	private void loadImage(MLImage img, string name, string path, ubyte depth, bool saved) {
		checkWidget();
		checkInit();
		if (_paintArea.empty) {
			// Creates first layer. TODO comment
			_paintArea.addLayer(_c.text.newLayer);
		}
		auto pi = new PImageItem(_imageList, SWT.NONE);
		pi.p_text = name;
		pi.image = img;
		pi.toolTip = path;

		auto params = new PImageParams;
		params.saved = saved;
		params.path = path;
		params.name = name;
		params.depth = depth;
		params.modCount = 0;
		params.modCountS = 0;
		pi.p_data = params;

		pi.listeners!(SWT.Dispose) ~= {
			img.dispose();
		};
		size_t index = _imageList.imageCount - 1;

		// Sets tool tip hint (full-path). TODO comment
		// Selects load image now. TODO comment
		selectImage(index);
		_imageList.showSelection();

		pi.image.restoreReceivers ~= () {
			params.modCount--;
			auto item = _imageList.item(index);
			string fChanged = _c.text.fChanged;
			if (params.modify) {
				item.p_text = fChanged.format(params.name);
			} else {
				item.p_text = params.name;
			}
		};

		statusChangedReceivers.raiseEvent();
	}

	/// Saves image to a file.
	/// Switchs image type from the extention. TODO comment
	/// bmp, png.
	bool saveImageWithName() {
		checkWidget();
		checkInit();
		int sel = _imageList.selectedIndex;
		if (-1 == sel) return false;
		return saveImageWithName(sel);
	}
	/// ditto
	bool saveImageWithName(size_t index) {
		checkWidget();
		checkInit();
		auto item = _imageList.item(index);
		auto params = item.dataTo!PImageParams;
		auto dlg = new FileDialog(this.p_shell, SWT.SAVE | SWT.SINGLE);
		dlg.p_fileName = params.path;
		string bmp = _c.text.fSaveImageTypeBitmap;
		string png = _c.text.fSaveImageTypePNG;
		dlg.p_filterNames = [
			bmp.format(8, 256),
			bmp.format(4, 16),
			bmp.format(1, 2),
			png.format(8, 256),
			png.format(4, 16),
			png.format(1, 2),
		];
		dlg.p_filterExtensions = [
			"*.bmp",
			"*.bmp",
			"*.bmp",
			"*.png",
			"*.png",
			"*.png"
		];
		size_t fi = 0; // filter index
		if (0 == params.path.extension().filenameCmp(".bmp")) {
			switch (params.depth) {
			case 8: fi = 0; break;
			case 4: fi = 1; break;
			case 1: fi = 2; break;
			default: break;
			}
		} else if (0 == params.path.extension().filenameCmp(".png")) {
			switch (params.depth) {
			case 8: fi = 3; break;
			case 4: fi = 4; break;
			case 1: fi = 5; break;
			default: break;
			}
		}
		dlg.p_filterIndex = fi;
		dlg.p_overwrite = true;
		if (!dlg.open()) return false;
		if (!dlg.p_fileName || !dlg.p_fileName.length) return false;
		auto fPath = dlg.p_filterPath;
		auto file = fPath.buildPath(dlg.p_fileName);
		ubyte depth;
		switch (dlg.p_filterIndex) {
		case 0, 3: depth = 8; break;
		case 1, 4: depth = 4; break;
		case 2, 5: depth = 1; break;
		default: assert (0);
		}
		saveImageWithName(index, file, depth);
		return true;
	}
	/// ditto
	void saveImageWithName(string file, ubyte bitmapDepth = 8) {
		if (!file) {
			SWT.error(__FILE__, __LINE__, SWT.ERROR_NULL_ARGUMENT);
		}
		checkWidget();
		checkInit();
		int sel = _imageList.selectedIndex;
		if (-1 == sel) return;
		saveImageWithName(sel, file, bitmapDepth);
	}
	/// ditto
	void saveImageWithName(size_t index, string file, ubyte bitmapDepth = 8) {
		if (!file) {
			SWT.error(__FILE__, __LINE__, SWT.ERROR_NULL_ARGUMENT);
		}
		checkWidget();
		checkInit();
		saveCommon(index, file, bitmapDepth);
		_paletteView.depth = bitmapDepth;
	}

	/// Saves image to file overwrite.
	bool saveImageOverwrite() {
		checkWidget();
		checkInit();
		int sel = _imageList.selectedIndex;
		if (-1 == sel) return false;
		return saveImageOverwrite(sel);
	}
	/// ditto
	bool saveImageOverwrite(size_t index) {
		checkWidget();
		checkInit();
		auto item = _imageList.item(index);
		auto params = item.dataTo!PImageParams;
		assert (params);
		if (params.saved && params.path.length) {
			saveCommon(index, params.path, params.depth);
			return true;
		} else {
			return saveImageWithName(index);
		}
		return false;
	}

	/// Saves all image. TODO comment
	bool saveAll() {
		checkWidget();
		checkInit();
		bool saved = false;
		foreach (i; 0 .. _imageList.imageCount) {
			auto itm = _imageList.item(i);
			auto params = itm.dataTo!PImageParams;
			if (!params.modify) continue;
			if (!params.saved) continue;
			saved |= saveImageOverwrite(i);
		}
		return saved;
	}

	private void saveCommon(size_t index, string file, ubyte depth)
	in {
		assert (index < _imageList.imageCount);
	} body {
		checkWidget();
		checkInit();

		auto item = _imageList.item(index);
		auto params = item.dataTo!PImageParams;
		assert (params);

		auto loader = new ImageLoader;
		auto data = item.image.createImageData(params.depth);
		loader.data ~= data;
		switch (file.extension().toLower()) {
		case ".bmp":
			loader.save(file, SWT.IMAGE_BMP);
			break;
		case ".png":
			loader.save(file, SWT.IMAGE_PNG);
			break;
		default:
			SWT.error(__FILE__, __LINE__, SWT.ERROR_INVALID_ARGUMENT);
		}
		params.saved = true;
		params.path = file;
		params.name = file.baseName();
		params.depth = depth;
		params.modCountS = params.modCount;
		item.p_text = params.name;

		statusChangedReceivers.raiseEvent();
	}

	/// Selects image in image list from index. TODO comment
	void selectImage(int index) {
		checkWidget();
		checkInit();
		_imageList.selectedIndex = index;
		if (-1 == index) {
			selectedReceivers.raiseEvent();
			return;
		}
		auto item = _imageList.item(index);

		_paintArea.colors = item.palette.colors;
		_paletteView.colors = _paintArea.palette;
		_colorSlider.color = _paletteView.color(_paintArea.pixel);
		_paintPreview.redraw();

		auto params = item.dataTo!PImageParams;
		assert (params);
		_paletteView.depth = params.depth;

		_paintArea.setCanvasSize(item.image.width, item.image.height);

		selectedReceivers.raiseEvent();
	}

	/// Paint area can close is returns true. TODO comment
	@property
	bool canClosePaintArea() {
		checkWidget();
		checkInit();
		if (!isPaintAreaChanged) return true;
		static const DLG_STYLE = SWT.OK | SWT.CANCEL | SWT.ICON_QUESTION;
		int r = MessageBox.showMessageBox(_c.text.paintAreaChanged, _c.text.question, this.p_shell, DLG_STYLE);
		return SWT.CANCEL != r;
	}
	/// Image at index can close is returns true. TODO comment
	bool canCloseImage(size_t index) {
		checkWidget();
		checkInit();
		auto item = _imageList.item(index);
		auto params = item.dataTo!PImageParams;
		if (!params.modify) return true;

		static const DLG_STYLE = SWT.YES | SWT.NO | SWT.CANCEL | SWT.ICON_QUESTION;
		string cChanged = _c.text.fCanvasChanged;
		int r = MessageBox.showMessageBox(cChanged.format(params.name), _c.text.question, this.p_shell, DLG_STYLE);
		if (SWT.YES == r) {
			return saveImageOverwrite(index);
		} else if (SWT.CANCEL == r) {
			return false;
		}
		assert (SWT.NO == r);
		return true;
	}

	/// Resize canvas. TODO comment
	void resizeCanvas(uint w, uint h, bool rescale) {
		checkWidget();
		checkInit();
		int sel = _imageList.selectedIndex;
		if (-1 == sel) return;
		resizeCanvas(sel, w, h, rescale);
	}
	/// ditto
	void resizeCanvas(size_t index, uint w, uint h, bool rescale) {
		checkWidget();
		checkInit();

		auto item = _imageList.item(index);
		_um.store(item.image);
		if (rescale) {
			item.scaledTo(w, h);
		} else {
			item.resize(w, h, _paletteView.pixel2);
		}
		if (index == _imageList.selectedIndex) {
			_paintArea.setCanvasSize(w, h);
		}
	}

	/// Creates gradation colors from selected pixel 1 to pixel 2.
	void createGradation() {
		checkWidget();
		checkInit();
		int sel = _imageList.selectedIndex;

		// TODO comment
		Undoable[] us = [_paletteView];
		if (-1 != sel) {
			us ~= _imageList.item(sel).image;
		}
		_um.store(us, {
			size_t p1 = _paletteView.pixel1;
			size_t p2 = _paletteView.pixel2;
			if (p1 > p2) swap(p1, p2);
			_paletteView.createGradation();

			auto item = -1 != sel ? _imageList.item(sel) : null;
			bool mod = false;
			foreach (p; p1 .. p2 + 1) {
				auto rgb = _paletteView.color(p);
				if (rgb == _paintArea.color(p)) continue;
				_paintArea.color(p, rgb);
				if (item) {
					item.color(p, rgb);
				}
				mod = true;
			}
			if (mod) {
				_paintPreview.redraw();
				if (item) modified(item);
			}
			return mod;
		});
		// ColorSlider is no change. TODO comment
	}

	/// Edit mask mode. TODO comment
	@property
	const
	bool maskMode() {
		checkInit();
		return _paletteView.maskMode;
	}

	/// ditto
	@property
	void maskMode(bool v) {
		checkWidget();
		checkInit();
		_paletteView.maskMode = v;
	}

	/// Layer managament. TODO comment
	void addLayer() {
		checkWidget();
		checkInit();
		_paintArea.addLayer(_c.text.newLayer);
	}
	/// ditto
	void removeLayer() {
		checkWidget();
		checkInit();
		auto ls = _paintArea.selectedLayers;
		assert (0 != ls.length);
		_paintArea.removeLayers(ls[0], ls[$ - 1] + 1);
	}
	/// If paint area is changed (don't push), returns true. TODO comment
	@property
	const
	bool isPaintAreaChanged() {
		checkInit();
		return !_paintArea.image.equalsTo(_pushBase);
	}
	/// If have changed (don't save) image, returns true. TODO comment
	bool isChanged(bool includeNewImage) {
		checkWidget();
		checkInit();
		foreach (i; 0 .. _imageList.imageCount) {
			auto params = _imageList.item(i).dataTo!PImageParams;
			assert (params);
			if (!params.modify) continue;
			if (!includeNewImage && !params.saved) continue;
			return true;
		}
		return false;
	}
	/// If changed (don't save) image, returns true. TODO comment
	bool isChanged(size_t index) {
		checkWidget();
		checkInit();

		auto item = _imageList.item(index);
		auto params = item.dataTo!PImageParams;
		assert (params);
		return params.modify;
	}
	/// Gets changed (don't save) image indices. TODO comment
	@property
	size_t[] changedImages() {
		checkWidget();
		checkInit();
		size_t[] r;
		foreach (i; 0 .. _imageList.imageCount) {
			auto params = _imageList.item(i).dataTo!PImageParams;
			assert (params);
			if (params.modify) {
				r ~= i;
			}
		}
		return r;
	}

	/// Does undo or redo. TODO comment
	void undo() {
		checkWidget();
		checkInit();
		_um.undo();
	}
	/// ditto
	void redo() {
		checkWidget();
		checkInit();
		_um.redo();
	}
}
