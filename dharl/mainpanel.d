
/// This module includes MainPanel and members related to it. 
///
/// License: Public Domain
/// Authors: kntroh
module dharl.mainpanel;

private import util.graphics;
private import util.types;
private import util.undomanager;
private import util.utils;

private import dharl.combinationdialog;
private import dharl.common;
private import dharl.dialogs;
private import dharl.textdrawingtools;

private import dharl.image.dpx;
private import dharl.image.edg;
private import dharl.image.mlimage;
private import dharl.image.susie;

private import dharl.ui.paintarea;
private import dharl.ui.paletteview;
private import dharl.ui.colorslider;
private import dharl.ui.pimagelist;
private import dharl.ui.splitter;
private import dharl.ui.uicommon;
private import dharl.ui.dwtutils;

private import std.algorithm;
private import std.array;
private import std.exception;
private import std.path;
private import std.stream;
private import std.string;
private import std.traits;

private import org.eclipse.swt.all;

private import java.io.ByteArrayInputStream;

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

/// The main panel of dharl.
class MainPanel : Composite {
	/// Receivers of status changed event.
	void delegate()[] statusChangedReceivers;
	/// Receivers of selected event.
	void delegate()[] selectedReceivers;
	/// Receivers of loaded event.
	void delegate(string file)[] loadedReceivers;

	private DCommon _c = null;

	private SusiePlugin _susiePlugin = null;

	private PaintArea _paintArea = null;
	private PaintPreview _paintPreview = null;
	private LayerList _layerList = null;
	private PaletteView _paletteView = null;
	private ColorSlider _colorSlider = null;
	private PImageList _imageList = null;

	// Information of updated in paint area.
	private Label _paintAreaUpdated = null;

	/// For relayout.
	private Composite _paintPane = null;
	private Composite _palettePane = null; /// ditto
	private Composite _layerPane = null; /// ditto
	private Composite _listPane = null; /// ditto

	/// Switches processing of some with state of shift key.
	private KeyObserver _shiftDown = null;

	/// Table of ToolItem from PaintMode.
	private ToolItem[PaintMode] _modeItems;
	/// ToolItem of range selection mode.
	private ToolItem _toolOfRangeSelection = null;
	/// ToolItem of text drawing mode.
	private ToolItem _toolOfTextDrawing = null;
	/// It will be true while updating the mode menu.
	private bool _updateModeMenu = false;

	/// Tool window for text drawing.
	private TextDrawingTools _textDrawingTools = null;

	/// Tool bar for tones.
	private ToolBar _tones = null;

	private UndoManager _um = null;

	/// Name of the current editing item.
	private string _currentName = "";
	/// Pushed image before draws.
	private Object _pushBase = null;

	/// The only constructor.
	this (Composite parent, int style) {
		super (parent, style);

		_susiePlugin = new SusiePlugin;
	}
	/// Initialize instance.
	void init(DCommon c) {
		if (!c) {
			SWT.error(__FILE__, __LINE__, SWT.ERROR_NULL_ARGUMENT);
		}
		_c = c;

		_currentName = _c.text.newFilename;

		this.p_layout = new FillLayout;

		_shiftDown = new KeyObserver(this, SWT.SHIFT);

		_um = new UndoManager(_c.conf.undoMax);

		Composite paint, palette, layer, list;
		createParents(paint, palette, layer, list);

		// Creates controls.
		_paintPane = basicComposite(paint);
		_paintPane.p_layoutData = GD.fill(true, true);
		_palettePane = basicComposite(palette);
		_palettePane.p_layoutData = GD.fill(true, true);
		_layerPane = basicComposite(layer);
		_layerPane.p_layoutData = GD.fill(true, true);
		_listPane = basicComposite(list);
		_listPane.p_layoutData = GD.fill(true, true);
		constructPaintArea(_paintPane);
		constructPaletteAndTools(_palettePane);
		constructLayerList(_layerPane);
		constructImageList(_listPane);

		initControls();
	}

	/// Relayout controls with DCommon.conf.layout parameter.
	void relayout() {
		auto children = this.p_children;

		Composite paint, palette, layer, list;
		createParents(paint, palette, layer, list);
		_paintPane.setParent(paint);
		_palettePane.setParent(palette);
		_layerPane.setParent(layer);
		_listPane.setParent(list);

		foreach (child; children) {
			child.dispose();
		}

		layout(true, true);
	}

	void createParents(out Composite paint, out Composite palette, out Composite layer, out Composite list) {
		switch (_c.conf.layout.value) {
		case 0:
			// Splits PImageList and other controls.
			auto splitter = basicHSplitter(this, false);
			_c.conf.layout0_sashPosWork_List.value.refSelection(splitter);
			// Splitter of paint area and palette.
			auto ppSplitter = basicVSplitter(splitter, false);
			_c.conf.layout0_sashPosPaint_Palette.value.refSelection(ppSplitter);

			// Creates composites.
			// Paint area.
			paint = basicComposite(ppSplitter);
			paint.p_layout = GL.zero(1, true);
			// Palete and layer list.
			auto paletteAndLayer = basicComposite(ppSplitter, GL.window(2, false));
			// Palette and color controls.
			palette = basicComposite(paletteAndLayer);
			palette.p_layout = GL.zero(1, true);
			palette.p_layoutData = GD.fill(false, true);
			// Layer list.
			layer = basicComposite(paletteAndLayer);
			layer.p_layout = GL.zero(1, true);
			layer.p_layoutData = GD.fill(true, true);
			// Image list.
			list = basicComposite(splitter);
			list.p_layout = GL.zero(1, true);
			break;
		case 1:
			// Splits PImageList and other controls.
			auto splitter1 = basicHSplitter(this, false);
			_c.conf.layout1_sashPosPaint_Other.value.refSelection(splitter1);
			// Paint area.
			paint = basicComposite(splitter1);
			paint.p_layout = GL.zero(1, true);
			splitter1.resizable = paint;

			auto paletteAndImageList = basicComposite(splitter1, GL.window(1, true).margin(0));

			// Palette and color controls.
			palette = basicComposite(paletteAndImageList);
			palette.p_layout = GL.zero(1, true);
			palette.p_layoutData = GD.begin(true, false);

			// Splits layer list and paint area.
			auto splitter2 = basicHSplitter(paletteAndImageList, false);
			_c.conf.layout1_sashPosLayer_List.value.refSelection(splitter2);
			splitter2.p_layoutData = GD.fill(true, true);

			// Layer list.
			layer = basicComposite(splitter2);
			layer.p_layout = GL.zero(1, true);
			// Image list.
			list = basicComposite(splitter2);
			list.p_layout = GL.zero(1, true);
			break;
		default:
			goto case 0;
		}
	}

	/// Initializes controls.
	void initControls() {
		// Paint area.
		auto cs = _c.conf.character;
		_paintArea.init(cs.width, cs.height, _paletteView.createPalette());
		_paintArea.zoom = _c.conf.zoom;
		_paintArea.mode = PaintMode.FreePath;
		_paintArea.cursorSize = _c.conf.lineWidth;
		_paintArea.pixel = _paletteView.pixel1;
		_paintArea.backgroundPixel = _paletteView.pixel2;
		_paintArea.addLayer(0, _c.text.newLayer);
		auto pen = ccur(_c.image.cursorPen, CursorSpot.TopLeft);
		auto cross = ccur(_c.image.cursorCross, CursorSpot.Center);
		auto dropper = ccur(_c.image.cursorDropper, CursorSpot.TopLeft);
		auto bucket = ccur(_c.image.cursorBucket, CursorSpot.TopLeft);
		_paintArea.cursor(PaintMode.FreePath, pen);
		_paintArea.cursor(PaintMode.Straight, cross);
		_paintArea.cursor(PaintMode.OvalLine, cross);
		_paintArea.cursor(PaintMode.RectLine, cross);
		_paintArea.cursor(PaintMode.OvalFill, cross);
		_paintArea.cursor(PaintMode.RectFill, cross);
		_paintArea.cursor(PaintMode.Fill, bucket);
		_paintArea.cursorDropper = dropper;
		_paintArea.cursorSelRange = cross;
		_paintArea.statusTextXY = _c.text.fStatusTextXY;
		_paintArea.statusTextRange = _c.text.fStatusTextRange;
		_paintPreview.init(_paintArea);
		_paletteView.p_cursor = dropper;
		_layerList.init(_paintArea);
		_colorSlider.color = _paletteView.color(_paletteView.selectedPixel);

		// Selection tool.
		if (_c.conf.tool == 0) {
			_paintArea.rangeSelection = true;
		} else if (_c.conf.tool == EnumMembers!PaintMode.length + 1) {
			_paintArea.textDrawing = true;
		} else {
			_paintArea.rangeSelection = false;
			foreach (i, mode; EnumMembers!PaintMode) {
				if (_c.conf.tool == i + 1) {
					_paintArea.mode = mode;
					break;
				}
			}
		}
		updateModeMenu();

		// Selection tone.
		auto toneIndex = cast(int)_c.conf.tone - 1;
		if (0 <= toneIndex && toneIndex < _c.conf.tones.length) {
			_paintArea.tone = _c.conf.tones[toneIndex].value;
		}
		refreshTonesToolBar();

		// Selection grids.
		_paintArea.grid1 = _c.conf.mainGrid;
		_paintArea.grid2 = _c.conf.subGrid;

		// Stores image data for undo operation.
		_pushBase = _paintArea.image.storeData;

		// Register event handlers.
		_paletteView.p_listeners!(SWT.Selection) ~= {
			_um.resetRetryWord();
			_paintArea.pixel = _paletteView.pixel1;
			_paintArea.backgroundPixel = _paletteView.pixel2;
			_paintArea.mask = _paletteView.mask;
			_colorSlider.color = _paletteView.color(_paletteView.selectedPixel);
		};
		_paletteView.changedTransparentPixelReceivers ~= (int tPixel) {
			auto layers = _paintArea.selectedLayers;
			foreach (l; layers) {
				_paintArea.transparentPixel(l, tPixel);
			}
		};
		_paintArea.changedMaskReceivers ~= (size_t pixel) {
			_um.resetRetryWord();
			_paletteView.reverseMask(pixel);
		};
		_paintArea.p_listeners!(SWT.Selection) ~= {
			_um.resetRetryWord();
			_paletteView.pixel1 = _paintArea.pixel;
			_colorSlider.color = _paletteView.color(_paletteView.selectedPixel);
		};
		_paintArea.restoreReceivers ~= (UndoMode mode) {
			_paletteView.colors = _paintArea.palette;
			_colorSlider.color = _paletteView.color(_paintArea.pixel);
		};
		_layerList.p_listeners!(SWT.Selection) ~= {
			int tPixel = -1;
			auto layers = _paintArea.selectedLayers;
			if (layers.length) {
				tPixel = _paintArea.image.layer(layers[0]).image.transparentPixel;
				if (tPixel < 0) tPixel = -1;
				foreach (l; layers[1 .. $]) {
					if (_paintArea.image.layer(l).image.transparentPixel != tPixel) {
						tPixel = -1;
						break;
					}
				}
			}
			_paletteView.transparentPixel = tPixel;
		};
		_layerList.p_listeners!(SWT.MouseMove) ~= (Event e) {
			string toolTip = "";
			if (!toolTip.length) {
				foreach (b; _layerList.nameBounds) {
					if (b.contains(e.x, e.y)) {
						toolTip = _c.text.descLayerName;
						break;
					}
				}
			}
			if (!toolTip.length) {
				foreach (b; _layerList.visibilityBoxBounds) {
					if (b.contains(e.x, e.y)) {
						toolTip = _c.text.descLayerVisibility;
						break;
					}
				}
			}
			if (!toolTip.length) {
				foreach (b; _layerList.transparentPixelBoxBounds) {
					if (b.contains(e.x, e.y)) {
						toolTip = _c.text.descLayerTransparentPixel;
						break;
					}
				}
			}
			_layerList.p_toolTipText = toolTip;
		};
		_colorSlider.p_listeners!(SWT.Selection) ~= {
			auto pixel = _paletteView.selectedPixel;
			auto rgb = _colorSlider.color;
			if (rgb == _paletteView.color(pixel)) return;

			// Stores palette data of image on paintArea and imageList.
			_um.store(_paletteView, null, "Slide color");

			// Reflects color.
			_paletteView.color(pixel, rgb);
			_paintArea.color(pixel, rgb);
			_paintPreview.redraw();
		};

		_imageList.p_listeners!(SWT.Selection) ~= {
			selectImage(_imageList.selectedIndex);
		};
		_imageList.p_listeners!(SWT.MouseDown) ~= (Event e) {
			if (e.button != 1 && e.button != 3) return;
			int sel = _imageList.indexOf(e.x, e.y);
			if (-1 == sel) return;
			_paintAreaUpdated.p_redraw = false;
			scope (exit) _paintAreaUpdated.p_redraw = true;
			switch (e.button) {
			case 1:
				// Send on paintArea to imageList item.
				auto item = _imageList.item(sel);
				bool pushed = _um.store(item.image, {
					_paintArea.fixPasteOrText();
					if (item.pushImage(_paintArea.image)) {
						_pushBase = _paintArea.image.storeData;
						_currentName = item.dataTo!PImageParams.name;
						modified(item);
						return true;
					}
					return false;
				});
				if (pushed) paintAreaUpdated = false;
				break;
			case 3:
				// Send on imageList item to paintArea.
				auto item = _imageList.item(sel);
				auto image = item.image;
				auto bounds = item.selectedPiece;
				_paintArea.pushImage(image, bounds.x, bounds.y);

				_paletteView.colors = _paintArea.palette;
				_colorSlider.color = _paletteView.color(_paintArea.pixel);
				_paintPreview.redraw();
				_layerList.redraw();
				_pushBase = _paintArea.image.storeData;
				_currentName = item.dataTo!PImageParams.name;
				paintAreaUpdated = false;
				break;
			default: assert (0);
			}
		};
		_um.statusChangedReceivers ~= {
			statusChangedReceivers.raiseEvent();
			paintAreaUpdated = true;
		};
		_paintArea.statusChangedReceivers ~= {
			statusChangedReceivers.raiseEvent();
			textDrawingTools.visible = _toolOfTextDrawing.p_selection;
		};
		_paintArea.selectChangedReceivers ~= (int x, int y, int w, int h) {
			statusChangedReceivers.raiseEvent();
		};
		_paintArea.resizeReceivers ~= (int w, int h) {
			_imageList.setPieceSize(w, h);
		};
		_paletteView.statusChangedReceivers ~= {
			statusChangedReceivers.raiseEvent();
		};
		_paletteView.colorChangeReceivers ~= (int pixel, in RGB afterRGB) {
			_um.store(_paletteView, {
				_paintArea.color(pixel, afterRGB);
				return true;
			});
		};
		_paletteView.colorSwapReceivers ~= (int pixel1, int pixel2) {
			Undoable[] us = [cast(Undoable)_paletteView, _paintArea];
			_um.store(us, {
				_paintArea.swapColor(pixel1, pixel2);
				return true;
			});
		};
		_imageList.removedReceivers ~= {
			if (0 == _imageList.imageCount) {
				_paintArea.setCanvasSize(0, 0);
			}
			statusChangedReceivers.raiseEvent();
		};
		_imageList.itemResizedReceivers ~= (PImageItem item) {
			_paintArea.setCanvasSize(item.image.width, item.image.height);
		};
		_paletteView.restoreReceivers ~= (UndoMode mode) {
			_paintArea.colors = _paletteView.colors;
			_colorSlider.color = _paletteView.color(_paletteView.selectedPixel);
			_paintPreview.redraw();
		};
		_imageList.removeReceivers ~= &canCloseImage;

		// Tool window.
		typeof(this.p_shell.shellActivated ~= {}) info;
		info = this.p_shell.shellActivated ~= {
			if (_paintArea.textDrawing) {
				textDrawingTools.visible = true;
			}
			info.remove();
		};
	}

	/// If doesn't initialized throws exception.
	const
	private void checkInit() {
		enforce(_c, new Exception("MainPanel is no initialized.", __FILE__, __LINE__));
	}

	/// Creates controls of paint area and palette.
	private void constructPaintArea(Composite parent) {
		checkWidget();
		checkInit();
		parent.p_layout = GL.zero(1, false);

		// Splitter of paintArea and tools.
		auto paintSplitter = basicHSplitter(parent, false);
		paintSplitter.p_layoutData = GD.fill(true, true);
		_c.conf.sashPosPaint_Preview.value.refSelection(paintSplitter);

		auto tools = basicComposite(paintSplitter);
		tools.p_layout = GL.zero(1, true);

		// Information of updated in paint area.
		_paintAreaUpdated = basicLabel(tools, _c.text.noUpdated, SWT.CENTER | SWT.BORDER);
		_paintAreaUpdated.p_layoutData = GD.fill(true, false);

		// Splitter of preview and toolbar.
		auto ptSplitter = basicVSplitter(tools, false);
		ptSplitter.p_layoutData = GD.fill(true, true);
		_c.conf.sashPosPreview_Tools.value.refSelection(ptSplitter);
		// Preview of image in drawing.
		_paintPreview = new PaintPreview(ptSplitter, SWT.BORDER | SWT.DOUBLE_BUFFERED);
		// Tools for drawing.
		constructModeToolBar(ptSplitter);

		// Area of drawing.
		_paintArea = new PaintArea(paintSplitter, SWT.BORDER | SWT.DOUBLE_BUFFERED);
		_paintArea.undoManager = _um;
		_paintArea.enabledBackColor = _c.conf.enabledBackColor;
	}

	/// Creates palette control and related tools.
	void constructPaletteAndTools(Composite parent) {
		checkWidget();
		checkInit();
		parent.p_layout = GL.noMargin(2, false);

		// Slider for changing color.
		_colorSlider = basicVColorSlider(parent);
		_colorSlider.p_layoutData = GD(GridData.VERTICAL_ALIGN_BEGINNING);
		auto css = _colorSlider.computeSize(SWT.DEFAULT, SWT.DEFAULT);

		// Viewer of palette.
		_paletteView = new PaletteView(parent, SWT.BORDER | SWT.NO_BACKGROUND | SWT.DOUBLE_BUFFERED);
		_paletteView.p_layoutData = GD(GridData.VERTICAL_ALIGN_BEGINNING).vSpan(3);
		_paletteView.maskMode = _c.conf.maskMode;

		// Tools for color control.
		auto pToolBar = basicToolBar(parent, SWT.WRAP | SWT.FLAT);
		pToolBar.p_layoutData = GD(GridData.VERTICAL_ALIGN_BEGINNING | GridData.HORIZONTAL_ALIGN_CENTER);
		basicToolItem(pToolBar, _c.text.menu.createGradation,
			cimg(_c.image.createGradation),
			&createGradation);
		ToolItem tMask;
		tMask = basicToolItem(pToolBar, _c.text.menu.maskMode, cimg(_c.image.maskMode), {
			maskMode = tMask.p_selection;
		}, SWT.CHECK);
		_c.conf.maskMode.value.refSelection(tMask);
		ToolItem tBack;
		tBack = basicToolItem(pToolBar, _c.text.menu.enabledBackColor, cimg(_c.image.enabledBackColor), {
			_paintArea.enabledBackColor = tBack.p_selection;
		}, SWT.CHECK);
		_c.conf.enabledBackColor.value.refSelection(tBack);
		void updatePaletteMenu() {
			tMask.p_selection = maskMode;
			tBack.p_selection = _paintArea.enabledBackColor;
		}
		statusChangedReceivers ~= &updatePaletteMenu;
		updatePaletteMenu();

		auto pToolBar2 = basicToolBar(parent, SWT.WRAP | SWT.FLAT);
		pToolBar2.p_layoutData = GD(GridData.VERTICAL_ALIGN_BEGINNING | GridData.HORIZONTAL_ALIGN_CENTER);
		auto tPOp = dropDownToolItem(pToolBar2, _c.text.menu.paletteOperation, .cimg(_c.image.paletteOperation), &paletteOperation);
		tPOp.menu.p_listeners!(SWT.Show) ~= {
			foreach (item; tPOp.menu.p_items) {
				item.dispose();
			}
			void createMenu(size_t i) {
				auto item = basicMenuItem(tPOp.menu, _c.text.fPaletteName.value.format(i + 1), {
					selectPalette(i);
				}, SWT.RADIO);
				item.p_selection = (i == _paintArea.selectedPalette);
			}
			foreach (i; 0 .. _paintArea.palettes.length) {
				createMenu(i);
			}
		};
	}

	/// Creates the layer list and related tools.
	void constructLayerList(Composite parent) {
		checkWidget();
		checkInit();
		parent.p_layout = GL.noMargin(1, true);

		// Tools for layer list.
		auto lToolBar = basicToolBar(parent);
		lToolBar.p_layoutData = GD.fill(true, false);
		basicToolItem(lToolBar, _c.text.menu.addLayer, cimg(_c.image.addLayer), &addLayer);
		basicToolItem(lToolBar, _c.text.menu.removeLayer, cimg(_c.image.removeLayer), &removeLayer);
		separator(lToolBar);
		auto tUpLayer = basicToolItem(lToolBar, _c.text.menu.up, cimg(_c.image.up), &upLayer);
		auto tDownLayer = basicToolItem(lToolBar, _c.text.menu.down, cimg(_c.image.down), &downLayer);
		separator(lToolBar);
		auto lUniteLayers = basicToolItem(lToolBar, _c.text.menu.uniteLayers, cimg(_c.image.uniteLayers), &uniteLayers);

		// List of layers.
		_layerList = new LayerList(parent, SWT.BORDER | SWT.DOUBLE_BUFFERED);
		_layerList.p_layoutData = GD.fill(true, true);
		_layerList.undoManager = _um;
		_layerList.p_listeners!(SWT.Selection) ~= {
			tUpLayer.p_enabled = canUpLayer;
			tDownLayer.p_enabled = canDownLayer;
			lUniteLayers.p_enabled = canUniteLayers;
			statusChangedReceivers.raiseEvent();
		};
	}

	/// Creates paint mode toolbar.
	private void constructModeToolBar(Composite parent) {
		checkWidget();
		checkInit();
		auto comp = basicComposite(parent, GL.noMargin(2, false));
		void createSeparator() {
			auto sep = separator(comp);
			sep.p_layoutData = GD(GridData.FILL_HORIZONTAL).wHint(0).hSpan(2);
		}
		void createLabel(string text) {
			auto label = basicLabel(comp, text);
			label.p_layoutData = GD(GridData.FILL_HORIZONTAL);
		}

		// Creates paint mode toolbar.
		auto mToolBar = basicToolBar(comp, SWT.WRAP | SWT.FLAT);
		mToolBar.p_layoutData = GD(GridData.FILL_HORIZONTAL).wHint(0).hSpan(2);
		void createModeItem(string text, Image img, PaintMode mode) {
			auto toolValue = mToolBar.p_itemCount;
			auto mt = basicToolItem(mToolBar, text, img, {
				_updateModeMenu = true;
				scope (exit) _updateModeMenu = false;
				_paintArea.mode = mode;
				if (!_paintArea.rangeSelection && !_paintArea.textDrawing) {
					_c.conf.tool = toolValue - 1;
				}
			}, SWT.RADIO);
			_modeItems[mode] = mt;
		}
		// Selection mode.
		_toolOfRangeSelection = basicToolItem(mToolBar, _c.text.menu.selection, cimg(_c.image.selection), {
			_updateModeMenu = true;
			scope (exit) _updateModeMenu = false;
			_paintArea.rangeSelection = _toolOfRangeSelection.p_selection;
			if (_paintArea.rangeSelection) {
				_c.conf.tool = 0;
			}
		}, SWT.RADIO);

		// Paint mode.
		createModeItem(_c.text.menu.freePath, cimg(_c.image.freePath), PaintMode.FreePath);
		createModeItem(_c.text.menu.straight, cimg(_c.image.straight), PaintMode.Straight);
		createModeItem(_c.text.menu.ovalLine, cimg(_c.image.ovalLine), PaintMode.OvalLine);
		createModeItem(_c.text.menu.rectLine, cimg(_c.image.rectLine), PaintMode.RectLine);
		createModeItem(_c.text.menu.ovalFill, cimg(_c.image.ovalFill), PaintMode.OvalFill);
		createModeItem(_c.text.menu.rectFill, cimg(_c.image.rectFill), PaintMode.RectFill);
		createModeItem(_c.text.menu.fillArea, cimg(_c.image.fillArea), PaintMode.Fill);

		// Text drawing mode.
		auto textDrawValue = mToolBar.p_itemCount;
		_toolOfTextDrawing = basicToolItem(mToolBar, _c.text.menu.textDrawing, cimg(_c.image.textDrawing), {
			_updateModeMenu = true;
			scope (exit) _updateModeMenu = false;
			_paintArea.textDrawing = _toolOfTextDrawing.p_selection;
			if (_paintArea.textDrawing) {
				_c.conf.tool = textDrawValue;
				_paintArea.inputtedText = textDrawingTools.inputtedText;
				_paintArea.drawingFont = textDrawingTools.drawingFont;
			}
		}, SWT.RADIO);

		statusChangedReceivers ~= &updateModeMenu;

		createSeparator();

		// Toolbar of tones.
		_tones = basicToolBar(comp, SWT.WRAP | SWT.FLAT);
		_tones.p_layoutData = GD(GridData.FILL_HORIZONTAL).wHint(0).hSpan(2);

		auto noTone = basicToolItem(_tones, _c.text.noTone, cimg(_c.image.noTone), {
			_paintArea.tone = null;
			_c.conf.tone = 0;
		}, SWT.RADIO, 0 == _c.conf.tone);
		_tones.p_listeners!(SWT.Dispose) ~= &clearTonesToolBar;

		createSeparator();

		// Zoom and line width.
		createLabel(_c.text.zoom);
		auto zoom = basicSpinner(comp, 1, PaintArea.ZOOM_MAX);
		_c.conf.zoom.value.refSelection(zoom);
		zoom.p_listeners!(SWT.Selection) ~= {
			_paintArea.zoom = zoom.p_selection;
		};
		createLabel(_c.text.lineWidth);
		auto lineWidth = basicSpinner(comp, 1, 16);
		_c.conf.lineWidth.refSelection(lineWidth);
		lineWidth.p_listeners!(SWT.Selection) ~= {
			_paintArea.cursorSize = lineWidth.p_selection;
		};
		void refreshZoomAndLineWidth() {
			zoom.p_selection = _paintArea.zoom;
			lineWidth.p_selection = _paintArea.cursorSize;
		}
		statusChangedReceivers ~= &refreshZoomAndLineWidth;

		createSeparator();

		// Toolbar of transform operation.
		auto trans = basicToolBar(comp, SWT.WRAP | SWT.FLAT);
		trans.p_layoutData = GD(GridData.FILL_HORIZONTAL).wHint(0).hSpan(2);
		basicToolItem(trans, _c.text.menu.turn90, .cimg(_c.image.turn90), &turn90);
		basicToolItem(trans, _c.text.menu.turn270, .cimg(_c.image.turn270), &turn270);
		basicToolItem(trans, _c.text.menu.turn180, .cimg(_c.image.turn180), &turn180);
		basicToolItem(trans, _c.text.menu.turn, .cimg(_c.image.turn), &turn);
		basicToolItem(trans, _c.text.menu.mirrorHorizontal, .cimg(_c.image.mirrorHorizontal), &mirrorHorizontal);
		basicToolItem(trans, _c.text.menu.mirrorVertical, .cimg(_c.image.mirrorVertical), &mirrorVertical);
		basicToolItem(trans, _c.text.menu.flipHorizontal, .cimg(_c.image.flipHorizontal), &flipHorizontal);
		basicToolItem(trans, _c.text.menu.flipVertical, .cimg(_c.image.flipVertical), &flipVertical);
		basicToolItem(trans, _c.text.menu.rotateLeft, .cimg(_c.image.rotateLeft), &rotateLeft);
		basicToolItem(trans, _c.text.menu.rotateDown, .cimg(_c.image.rotateDown), &rotateDown);
		basicToolItem(trans, _c.text.menu.rotateUp, .cimg(_c.image.rotateUp), &rotateUp);
		basicToolItem(trans, _c.text.menu.rotateRight, .cimg(_c.image.rotateRight), &rotateRight);
		basicToolItem(trans, _c.text.menu.increaseBrightness, .cimg(_c.image.increaseBrightness), &increaseBrightness);
		basicToolItem(trans, _c.text.menu.decreaseBrightness, .cimg(_c.image.decreaseBrightness), &decreaseBrightness);
		basicToolItem(trans, _c.text.menu.resize, .cimg(_c.image.resize), &resize);

		createSeparator();

		// Toolbar of grid switches.
		auto grids = basicToolBar(comp, SWT.WRAP | SWT.FLAT);
		grids.p_layoutData = GD(GridData.FILL_HORIZONTAL).wHint(0).hSpan(2);
		ToolItem tMainGrid;
		tMainGrid = basicToolItem(grids, _c.text.menu.mainGrid, .cimg(_c.image.mainGrid), {
			paintArea.grid1 = tMainGrid.p_selection;
		}, SWT.CHECK);
		_c.conf.mainGrid.value.refSelection(tMainGrid);
		ToolItem tSubGrid;
		tSubGrid = basicToolItem(grids, _c.text.menu.subGrid, .cimg(_c.image.subGrid), {
			paintArea.grid2 = tSubGrid.p_selection;
		}, SWT.CHECK);
		_c.conf.subGrid.value.refSelection(tSubGrid);
		void updateGrid() {
			tMainGrid.p_selection = paintArea.grid1;
			tSubGrid.p_selection = paintArea.grid2;
		}
		statusChangedReceivers ~= &updateGrid;
	}
	/// Tools for text drawing.
	@property
	private TextDrawingTools textDrawingTools() {
		if (_textDrawingTools) return _textDrawingTools;
		_textDrawingTools = new TextDrawingTools(this.p_shell, _c);
		_textDrawingTools.statusChangedReceivers ~= {
			_paintArea.inputtedText = _textDrawingTools.inputtedText;
			_paintArea.drawingFont = _textDrawingTools.drawingFont;
		};
		return _textDrawingTools;
	}
	/// Updates mode toolbar and configration.
	private void updateModeMenu() {
		.enforce(_toolOfRangeSelection);
		.enforce(_toolOfTextDrawing);
		.enforce(_paintArea);
		if (_updateModeMenu) return;
		bool range = _paintArea.rangeSelection;
		_toolOfRangeSelection.p_selection = range;
		bool textDrawing = _paintArea.textDrawing;
		_toolOfTextDrawing.p_selection = textDrawing;
		foreach (mode, item; _modeItems) {
			item.p_selection = !range && !textDrawing && _paintArea.mode == mode;
		}
	}
	/// Updates tones toolbar.
	private void refreshTonesToolBar() {
		.enforce(_tones);
		checkWidget();
		auto d = this.p_display;

		clearTonesToolBar();

		bool useTone = false;
		void toneItem(size_t index, in Tone tone) {
			bool useIt = tone.value == _paintArea.tone;
			auto icon = toneIcon(tone.value, 16, 16);
			basicToolItem(_tones, tone.name, new Image(d, icon), {
				_paintArea.tone = tone.value;
				_c.conf.tone = index + 1;
			}, SWT.RADIO, useIt);
			if (useIt) useTone = true;
		}
		foreach (i, tone; _c.conf.tones.array) {
			toneItem(i, tone);
		}
		if (useTone) {
			_tones.getItem(0).p_selection = false;
		} else {
			_tones.getItem(0).p_selection = true;
			_paintArea.tone = null;
		}
	}
	/// Clears tones toolbar.
	private void clearTonesToolBar() {
		enforce(_tones);
		checkWidget();
		_tones.getItem(0).p_selection = true;
		foreach_reverse (i; 1 .. _tones.p_itemCount) {
			auto item = _tones.getItem(i);
			auto img = item.p_image;
			item.dispose();
			img.dispose();
		}
	}

	/// Creates imageList.
	private void constructImageList(Composite parent) {
		checkWidget();
		checkInit();
		parent.p_layout = GL.zero(1, true);

		_imageList = new PImageList(parent, SWT.BORDER | SWT.DOUBLE_BUFFERED);
		_imageList.p_layoutData = GD.fill(true, true);
		auto cs = _c.conf.character;
		_imageList.setPieceSize(cs.width, cs.height);
	}

	/// Display information of paint area updated.
	@property
	private void paintAreaUpdated(bool updated) {
		if (updated) {
			auto d = _paintAreaUpdated.getDisplay();
			_paintAreaUpdated.p_background = d.getSystemColor(SWT.COLOR_RED);
			_paintAreaUpdated.p_foreground = d.getSystemColor(SWT.COLOR_WHITE);
			_paintAreaUpdated.p_text = _c.text.updated;
		} else {
			_paintAreaUpdated.p_background = this.p_background;
			_paintAreaUpdated.p_foreground = this.p_foreground;
			_paintAreaUpdated.p_text = _c.text.noUpdated;
		}
	}

	/// Area of drawing.
	@property
	PaintArea paintArea() {
		checkWidget();
		checkInit();
		return _paintArea;
	}

	/// Manager of undo and redo operation.
	@property
	UndoManager undoManager() {
		checkWidget();
		checkInit();
		return _um;
	}

	/// Gets selection index at imageList.
	@property
	const
	int selectedIndex() {
		checkInit();
		return _imageList.selectedIndex;
	}
	/// Count of open image.
	@property
	const
	size_t imageCount() {
		checkInit();
		return _imageList.imageCount;
	}
	/// Gets image name at index.
	string imageName(size_t index) {
		checkWidget();
		checkInit();
		auto params = _imageList.item(index).dataTo!PImageParams;
		assert (params);
		return params.name;
	}
	/// Gets base file path of image at index.
	string imagePath(size_t index) {
		checkWidget();
		checkInit();
		auto params = _imageList.item(index).dataTo!PImageParams;
		assert (params);
		return params.path;
	}
	/// Gets canvas size at index.
	PSize canvasSize(size_t index) {
		checkWidget();
		checkInit();
		auto item = _imageList.item(index);
		return PSize(item.image.width, item.image.height);
	}

	/// Notify modify of image.
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

	/// If image is modified, returns true.
	bool modified(size_t index) {
		checkInit();
		auto params = _imageList.item(index).dataTo!PImageParams;
		return params.modCountS != params.modCount;
	}

	/// Returns file path of directory of selection image.
	@property
	private string currentDir() {
		int i = selectedIndex;
		if (-1 != i) {
			auto path = imagePath(i);
			if (path.length) {
				return path.dirName();
			}
		}
		return "";
	}

	/// Creates new image.
	void createNewImage(int width, int height, bool copyPalette) {
		checkWidget();
		checkInit();
		auto img = new MLImage;
		if (copyPalette) {
			img.init(width, height, _paletteView.createPalette());
		} else {
			img.init(width, height, PaletteView.createDefaultPalette());
		}
		img.addLayer(0, _c.text.newLayer);
		loadImage(img, _c.text.noName, "", 8, false);
	}

	/// Calls loadSusiePlugins().
	private bool initSusiePlugin() {
		if (_c.conf.susiePluginDir.length) {
			try {
				_susiePlugin.loadSusiePlugins(_c.conf.susiePluginDir.absolutePath(_c.moduleFileName.dirName()));
				return true;
			} catch (Exception e) {
				// Susie Plug-in initialize failure.
			}
		}
		return false;
	}

	/// Loads image from a file.
	/// A loaded image adds to image list.
	bool loadImage() {
		checkWidget();
		checkInit();
		auto dlg = new FileDialog(this.p_shell, SWT.OPEN | SWT.MULTI);

		// File filter.
		string[] filter = SUPPORTED_FORMATS.dup;
		if (initSusiePlugin()) {
			filter ~= _susiePlugin.susieExtensions;
			filter = filter.sort().uniq().array();
		}
		auto filterString = std.string.join(filter, ";");

		string type = _c.text.fLoadImageType.value;
		dlg.p_filterNames = [type.format(filterString)];
		dlg.p_filterExtensions = [filterString];
		auto cur = currentDir;
		if (cur.length) dlg.p_filterPath = cur;
		if (!dlg.open()) return false;
		auto fPath = dlg.p_filterPath;
		auto names = dlg.p_fileNames;
		foreach (file; names) {
			auto path = fPath.buildPath(file);
			try {
				loadImage(path, true);
			} catch (Exception e) {
				.erroroutf("Load failure: %s", file);
			}
		}
		return true;
	}
	/// ditto
	void loadImage(string file) {
		loadImage(file, false);
	}
	/// ditto
	private void loadImage(string file, bool initializedSusiePlugin) {
		checkWidget();
		checkInit();
		if (!initializedSusiePlugin) {
			initSusiePlugin();
		}

		auto fname = file.baseName();
		auto ext = fname.extension();
		ubyte[MLImage] depths;
		auto imgs = _susiePlugin.loadWithSusie(file, _c.text.newLayer, (string ext, lazy ubyte[] data) {
			MLImage[] r;
			ext = ext.toLower();
			try {
				if (0 == ext.filenameCmp(".dhr")) {
					r ~= new MLImage(data);
				} else if (0 == ext.filenameCmp(".dpx")) {
					auto s = new MemoryStream(data);
					scope (exit) s.close();
					r ~= .loadDPX(s);
				} else if (0 == ext.filenameCmp(".edg")) {
					auto s = new MemoryStream(data);
					scope (exit) s.close();
					r ~= .loadEDG(s);
				} else {
					foreach (filter; SUPPORTED_FORMATS) {
						if (filter.endsWith(ext)) {
							auto buf = new ByteArrayInputStream(cast(byte[])data());
							auto imgData = new ImageData(buf);
							auto depth = cast(ubyte)imgData.depth;
							auto img = new MLImage;
							img.init(imgData, _c.text.newLayer);
							r ~= img;
							depths[img] = depth;
							break;
						}
					}
				}
			} catch (Exception e) {
				// Load failure.
			}
			return r;
		});
		foreach (i, img; imgs) {
			if (!img.layerCount) continue;
			auto data = img.layer(0).image;
			assert (data.depth <= 8);
			ubyte depth = cast(ubyte)data.depth;
			auto pDepth = img in depths;
			if (pDepth) depth = *pDepth;
			bool saved = !data.palette.isDirect && depth <= 8;
			if (saved) {
				if (0 != ext.filenameCmp(".dhr") && 0 != ext.filenameCmp(".bmp") && 0 != ext.filenameCmp(".png")) {
					saved = false;
				}
			}
			string name = fname;
			if (1 < imgs.length) {
				name ~= " (%s)".format(i + 1);
			}
			loadImage(img, name, file, cast(ubyte).min(depth, 8), saved);
		}
	}
	private void loadImage(MLImage img, string name, string path, ubyte depth, bool saved) {
		checkWidget();
		checkInit();
		if (_paintArea.empty) {
			// Creates first layer.
			_paintArea.addLayer(0, _c.text.newLayer);
		}
		auto pi = new PImageItem(_imageList, SWT.NONE);
		pi.p_text = name;
		pi.image = img;
		pi.toolTip = path; // Sets tool tip hint (fullpath of file).

		auto params = new PImageParams;
		params.saved = saved;
		params.path = path;
		params.name = name;
		params.depth = depth;
		params.modCount = 0;
		params.modCountS = 0;
		pi.p_data = params;

		pi.p_listeners!(SWT.Dispose) ~= {
			img.dispose();
		};
		size_t index = _imageList.imageCount - 1;

		
		// Selects loaded image.
		selectImage(index);
		_imageList.showSelection();

		pi.image.restoreReceivers ~= (UndoMode mode) {
			final switch (mode) {
			case UndoMode.Undo:
				params.modCount--;
				break;
			case UndoMode.Redo:
				params.modCount++;
				break;
			}
			string fChanged = _c.text.fChanged;
			if (params.modify) {
				pi.p_text = fChanged.format(params.name);
			} else {
				pi.p_text = params.name;
			}
		};

		statusChangedReceivers.raiseEvent();
		if (path.length) {
			loadedReceivers.raiseEvent(path.absolutePath().buildNormalizedPath());
		}
	}

	/// Saves image to a file.
	/// Switch image type by extention (bmp, png).
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
		dlg.p_fileName = params.path.length ? params.path : _c.text.newFilename;
		string dhr = _c.text.fSaveImageTypeDharl;
		string bmp = _c.text.fSaveImageTypeBitmap;
		string png = _c.text.fSaveImageTypePNG;
		dlg.p_filterNames = [
			dhr,
			bmp.format(8, 256),
			bmp.format(4, 16),
			bmp.format(1, 2),
			png.format(8, 256),
			png.format(4, 16),
			png.format(1, 2),
		];
		dlg.p_filterExtensions = [
			"*.dhr",
			"*.bmp",
			"*.bmp",
			"*.bmp",
			"*.png",
			"*.png",
			"*.png"
		];
		size_t fi = 0; // filter index
		auto ext = params.path.extension();
		if (0 == ext.filenameCmp(".dhr")) {
			fi = 0;
		} else if (0 == ext.filenameCmp(".bmp")) {
			switch (params.depth) {
			case 8: fi = 1; break;
			case 4: fi = 2; break;
			case 1: fi = 3; break;
			default: break;
			}
		} else if (0 == ext.filenameCmp(".png")) {
			switch (params.depth) {
			case 8: fi = 4; break;
			case 4: fi = 5; break;
			case 1: fi = 6; break;
			default: break;
			}
		} else {
			fi = 0;
			dlg.p_fileName = dlg.p_fileName.setExtension(".dhr");
		}
		dlg.p_filterIndex = fi;
		dlg.p_overwrite = true;
		auto cur = currentDir;
		if (cur.length) dlg.p_filterPath = cur;
		if (!dlg.open()) return false;
		if (!dlg.p_fileName || !dlg.p_fileName.length) return false;
		auto fPath = dlg.p_filterPath;
		auto file = fPath.buildPath(dlg.p_fileName);
		ubyte depth;
		switch (dlg.p_filterIndex) {
		case 0: depth = 8; break;
		case 1, 4: depth = 8; break;
		case 2, 5: depth = 4; break;
		case 3, 6: depth = 1; break;
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

	/// Saves all image.
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

		auto ext = file.extension().toLower();
		if (0 == ext.filenameCmp(".dhr")) {
			item.image.write(file);
		} else {
			if (1 < item.image.layerCount || item.image.combinations.length) {
				auto title = _c.text.fQuestionDialog.value.format(_c.text.appName);
				int yesNo = showYesNoDialog(this.p_shell, _c.text.warningDisappearsData, title);
				if (SWT.YES != yesNo) return;
			}

			auto loader = new ImageLoader;
			auto data = item.image.createImageData(depth);
			loader.data ~= data;
			switch (ext) {
			case ".bmp":
				loader.save(file, SWT.IMAGE_BMP);
				break;
			case ".png":
				loader.save(file, SWT.IMAGE_PNG);
				break;
			default:
				SWT.error(__FILE__, __LINE__, SWT.ERROR_INVALID_ARGUMENT);
			}
		}
		params.saved = true;
		params.path = file;
		params.name = file.baseName();
		params.depth = depth;
		params.modCountS = params.modCount;
		item.p_text = params.name;
		item.toolTip = params.path;

		statusChangedReceivers.raiseEvent();
		loadedReceivers.raiseEvent(file.absolutePath().buildNormalizedPath());
	}

	/// Selects image in imageList by index.
	void selectImage(int index) {
		checkWidget();
		checkInit();
		_imageList.selectedIndex = index;
		if (-1 == index) {
			selectedReceivers.raiseEvent();
			return;
		}
		auto item = _imageList.item(index);
		auto params = item.dataTo!PImageParams;
		assert (params);
		_paletteView.depth = params.depth;

		_paintArea.setCanvasSize(item.image.width, item.image.height);

		selectedReceivers.raiseEvent();
	}

	/// If can close the paintArea or a image, returns true.
	/// If modified image existed, asks save to user.
	@property
	bool canClosePaintArea() {
		checkWidget();
		checkInit();
		if (!isPaintAreaChanged) return true;
		auto title = _c.text.fQuestionDialog.value.format(_c.text.appName);
		return SWT.CANCEL != showOkCancelDialog(this.p_shell, _c.text.paintAreaChanged, title);
	}
	/// ditto
	bool canCloseImage(size_t index) {
		checkWidget();
		checkInit();
		auto item = _imageList.item(index);
		auto params = item.dataTo!PImageParams;
		if (!params.modify) return true;

		static const DLG_STYLE = SWT.YES | SWT.NO | SWT.CANCEL | SWT.ICON_QUESTION;
		string cChanged = _c.text.fCanvasChanged;
		auto title = _c.text.fQuestionDialog.value.format(_c.text.appName);
		int r = showYesNoCancelDialog(this.p_shell, cChanged.format(params.name), title);
		if (SWT.YES == r) {
			return saveImageOverwrite(index);
		} else if (SWT.CANCEL == r) {
			return false;
		}
		assert (SWT.NO == r);
		return true;
	}

	/// Close canvas.
	void closeImage() {
		checkWidget();
		checkInit();
		auto sel = _imageList.selectedIndex;
		if (-1 == sel) return;
		closeImage(sel);
	}
	/// ditto
	void closeImage(size_t index) {
		checkWidget();
		checkInit();
		if (canCloseImage(index)) {
			auto item = _imageList.item(index);
			item.dispose();
		}
	}

	/// Resizes character (paint area).
	void resize() {
		auto dialog = new ResizeDialog(this.p_shell, _c, ResizeTarget.Character);
		auto area = paintArea.resizeArea;
		dialog.init(area.width, area.height);
		dialog.appliedReceivers ~= {
			resize(dialog.width, dialog.height, dialog.scaling);
		};
		dialog.open();
	}
	/// ditto
	void resize(uint w, uint h, bool scaling) {
		checkWidget();
		checkInit();

		auto area = paintArea.resizeArea;
		if (area.width == w && area.height == h) return;
		_paintArea.resize(w, h, scaling);
	}

	/// Resizes canvas on imageList.
	void resizeCanvas() {
		checkWidget();
		checkInit();
		int sel = _imageList.selectedIndex;
		if (-1 == sel) return;

		auto dialog = new ResizeDialog(this.p_shell, _c, ResizeTarget.Canvas);

		auto size = canvasSize(sel);
		dialog.init(size.width, size.height);
		dialog.appliedReceivers ~= {
			resizeCanvas(sel, dialog.width, dialog.height, dialog.scaling);
		};

		dialog.open();
	}
	/// ditto
	void resizeCanvas(uint w, uint h, bool scaling) {
		checkWidget();
		checkInit();
		int sel = _imageList.selectedIndex;
		if (-1 == sel) return;
		resizeCanvas(sel, w, h, scaling);
	}
	/// ditto
	void resizeCanvas(size_t index, uint w, uint h, bool scaling) {
		checkWidget();
		checkInit();

		auto item = _imageList.item(index);
		if (item.image.width == w && item.image.height == h) return;
		_um.store(item.image);
		if (scaling) {
			item.scaledTo(w, h);
		} else {
			item.resize(w, h, _paletteView.pixel2);
		}
		if (index == _imageList.selectedIndex) {
			_paintArea.setCanvasSize(w, h);
		}
		modified(item);
	}

	/// Turns any degrees the image.
	/// This method shows a dialog box for degree inputs.
	void turn() {
		checkWidget();
		checkInit();
		bool shiftDown = _shiftDown.keyDown;
		auto dialog = new TurnDialog(this.p_shell, _c);
		dialog.init(0);
		dialog.appliedReceivers ~= {
			turnImpl(dialog.degree, shiftDown);
		};
		dialog.open();
	}
	/// Turns any degrees the image.
	void turn(int degree) {
		checkWidget();
		checkInit();
		turnImpl(degree, _shiftDown.keyDown);
	}
	/// ditto
	void turnImpl(int degree, bool shiftDown) {
		degree = normalizeRange(degree, 0, 360);
		if (0 == degree) return;
		_paintArea.turn(degree, shiftDown);
	}
	/// ditto
	void turn90() {
		checkWidget();
		checkInit();
		turn(90);
	};
	/// ditto
	void turn270() {
		checkWidget();
		checkInit();
		turn(270);
	};
	/// ditto
	void turn180() {
		checkWidget();
		checkInit();
		turn(180);
	};

	/// Creates gradation colors from selected pixel 1 to pixel 2.
	void createGradation() {
		checkWidget();
		checkInit();

		// Stores palette data of image on paintArea.
		_um.store(_paletteView, {
			size_t p1 = _paletteView.pixel1;
			size_t p2 = _paletteView.pixel2;
			if (p1 > p2) swap(p1, p2);
			_paletteView.createGradation();

			bool mod = false;
			foreach (p; p1 .. p2 + 1) {
				auto rgb = _paletteView.color(p);
				if (rgb == _paintArea.color(p)) continue;
				_paintArea.color(p, rgb);
				mod = true;
			}
			if (mod) {
				_paintPreview.redraw();
			}
			return mod;
		});
		// pixel1 or pixel2 has been selected certainly,
		// Update of ColorSlider is not need.
	}

	/// Transforms image data to mirror horizontally or vertically.
	void mirrorHorizontal() {
		checkWidget();
		checkInit();
		_paintArea.mirrorHorizontal(_shiftDown.keyDown);
	}
	/// ditto
	void mirrorVertical() {
		checkWidget();
		checkInit();
		_paintArea.mirrorVertical(_shiftDown.keyDown);
	}

	/// Flips image data horizontally or vertically.
	void flipHorizontal() {
		checkWidget();
		checkInit();
		_paintArea.flipHorizontal(_shiftDown.keyDown);
	}
	/// ditto
	void flipVertical() {
		checkWidget();
		checkInit();
		_paintArea.flipVertical(_shiftDown.keyDown);
	}

	/// Moves image data in each direction.
	/// Rotates a pixel of bounds.
	void rotateLeft() {
		checkWidget();
		checkInit();
		_paintArea.rotateLeft(_shiftDown.keyDown);
	}
	/// ditto
	void rotateDown() {
		checkWidget();
		checkInit();
		_paintArea.rotateDown(_shiftDown.keyDown);
	}
	/// ditto
	void rotateUp() {
		checkWidget();
		checkInit();
		_paintArea.rotateUp(_shiftDown.keyDown);
	}
	/// ditto
	void rotateRight() {
		checkWidget();
		checkInit();
		_paintArea.rotateRight(_shiftDown.keyDown);
	}

	/// Increase or decrease brightness.
	void increaseBrightness() {
		checkWidget();
		checkInit();
		_paintArea.changeBrightness(32, _shiftDown.keyDown);
	}
	/// ditto
	void decreaseBrightness() {
		checkWidget();
		checkInit();
		_paintArea.changeBrightness(-32, _shiftDown.keyDown);
	}

	/// Is editing color mask?
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

	/// Layers management.
	void addLayer() {
		checkWidget();
		checkInit();
		_paintArea.addLayer(_paintArea.selectedLayers.sort[0], _c.text.newLayer);
	}
	/// ditto
	void removeLayer() {
		checkWidget();
		checkInit();
		auto ls = _paintArea.selectedLayers;
		assert (0 != ls.length);
		_paintArea.removeLayers(ls[0], ls[$ - 1] + 1);
	}
	/// ditto
	void uniteLayers() {
		checkWidget();
		checkInit();
		if (!canUniteLayers) return;
		auto ls = _paintArea.selectedLayers;
		assert (0 != ls.length);
		assert (ls[0] + 1 < _paintArea.image.layerCount);
		_paintArea.uniteLayers(ls[0] + 1, ls[0]);
	}
	/// ditto
	void upLayer() {
		checkWidget();
		checkInit();
		if (!canUpLayer) return;
		auto layers = _paintArea.selectedLayers.sort;
		foreach (l; layers) {
			if (0 == l) break;
			_paintArea.swapLayers(l - 1, l);
		}
	}
	/// ditto
	@property
	const
	bool canUniteLayers() {
		checkInit();
		return _paintArea.image.layerCount != _paintArea.selectedLayers[$ - 1] + 1;
	}
	/// ditto
	@property
	const
	bool canUpLayer() {
		checkInit();
		return 0 != _paintArea.selectedLayers[0];
	}
	/// ditto
	void downLayer() {
		checkWidget();
		checkInit();
		if (!canDownLayer) return;
		auto layers = _paintArea.selectedLayers.sort;
		foreach_reverse (l; layers) {
			if (_paintArea.image.layerCount == l + 1) break;
			_paintArea.swapLayers(l + 1, l);
		}
	}
	/// ditto
	@property
	const
	bool canDownLayer() {
		checkInit();
		return _paintArea.image.layerCount != _paintArea.selectedLayers[$ - 1] + 1;
	}

	/// Opens dialog for edit combinations of layers in MLImage.
	void editCombination() {
		checkWidget();
		checkInit();
		if (!canEditCombination()) return;

		auto image = _paintArea.image.createMLImage();
		auto dlg = new CombinationDialog(_imageList.p_shell, _c, _um, image, _currentName);
		dlg.appliedReceivers ~= {
			if (_paintArea.image.combinations == dlg.combinations) return;
			_um.store(_paintArea.image);
			_paintArea.image.combinations = dlg.combinations;
			statusChangedReceivers.raiseEvent();
		};
		dlg.open();
	}
	/// ditto
	@property
	const
	bool canEditCombination() {
		checkInit();
		return true;
	}

	/// Open palette operation dialog.
	void paletteOperation() {
		checkWidget();
		checkInit();

		auto dialog = new PaletteOperationDialog(this.p_shell, _c);
		dialog.init(_paintArea.palettes, _paintArea.selectedPalette);
		dialog.appliedReceivers ~= {
			auto palettes = dialog.palettes;
			.enforce(palettes.length);
			auto sel = dialog.selectedPalette;
			.enforce(sel < dialog.palettes.length);

			setPalettes(palettes, sel);
		};
		dialog.open();
	}
	/// Selects palette of paint area by index.
	void selectPalette(size_t index) {
		if (_paintArea.palettes.length <= index) {
			SWT.error(__FILE__, __LINE__, SWT.ERROR_INVALID_ARGUMENT);
		}
		if (_paintArea.selectedPalette == index) return;

		setPalettes(null, index);
	}
	/// ditto
	private void setPalettes(in PaletteData[] palettes, size_t sel) {
		Undoable[] storeData = [cast(Undoable)_paintArea, _paletteView];
		_um.store(storeData);

		// update palette
		if (palettes) {
			_paintArea.setPalettes(palettes, sel);
		} else {
			_paintArea.selectedPalette = sel;
		}

		// update controls
		_paletteView.colors = _paintArea.palette;
		_colorSlider.color = _paletteView.color(_paintArea.pixel);
	}

	/// Open palette transfer dialog.
	void paletteTransfer() {
		checkWidget();
		checkInit();
		if (!_imageList.imageCount) return;

		auto names = new string[_imageList.imageCount];
		foreach (i; 0 .. _imageList.imageCount) {
			names[i] = _imageList.item(i).p_text;
		}
		auto dialog = new PaletteTransferDialog(this.p_shell, _c);
		dialog.init(names, 0, []);
		dialog.appliedReceivers ~= {
			auto from = dialog.from;
			if (-1 == from) return;
			auto to = dialog.to;
			if (!to.length) return;
			int sel = _imageList.selectedIndex;

			// palette transfer
			auto source = _imageList.item(from).image;
			PImageItem[] items;
			Undoable[] storeData;
			foreach (i; to) {
				if (i == from) continue;
				auto item = _imageList.item(i);
				if (source.equalsPalette(item.image)) continue;
				items ~= item;
				storeData ~= item.image;
			}
			if (!storeData.length) return;

			_um.store(storeData);
			foreach (item; items) {
				item.setPalettes(source.palettes, source.selectedPalette);
				modified(item);
			}
			// update palette view
			if (-1 != to.countUntil(sel)) selectImage(sel);
		};
		dialog.open();
	}

	/// If paintArea is changed after push, returns true.
	@property
	const
	bool isPaintAreaChanged() {
		checkInit();
		return !_paintArea.image.equalsTo(_pushBase);
	}
	/// If has changed image after save, returns true.
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
	/// If changed image after save, returns true.
	bool isChanged(size_t index) {
		checkWidget();
		checkInit();

		auto item = _imageList.item(index);
		auto params = item.dataTo!PImageParams;
		assert (params);
		return params.modify;
	}
	/// Gets indices of changed images after save.
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

	/// Base filepath of a index.
	/// If it is new image, returns "".
	string path(size_t index) {
		checkWidget();
		checkInit();

		auto item = _imageList.item(index);
		auto params = item.dataTo!PImageParams;
		assert (params);
		return params.path;
	}

	/// Executes undo or redo operation.
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
