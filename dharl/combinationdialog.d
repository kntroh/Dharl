
/// This module includes dialog of editor for combinations of layers in MLImage.
module dharl.combinationdialog;

private import util.undomanager;
private import util.utils;

private import dharl.common;
private import dharl.dialogs;

private import dharl.image.mlimage;

private import dharl.ui.basicdialog;
private import dharl.ui.dwtutils;
private import dharl.ui.splitter;
private import dharl.ui.uicommon;

private import std.algorithm;
private import std.path;
private import std.range;
private import std.string;

private import org.eclipse.swt.all;

/// Dialog of editor for combinations of layers in MLImage.
class CombinationDialog : DharlDialog {

	/// Target of edit.
	private MLImage _image = null;
	/// Name of image.
	private string _name;

	/// Splitters.
	private Splitter _splitterV = null;
	private Splitter _splitterH = null; /// ditto

	/// Preview.
	private Preview _preview = null;

	/// Combination data.
	private Combination[] _combiData = [];
	/// Combination list.
	private Table _combiList = null;
	/// Editor for combination name.
	private Editor _combiName = null;

	/// Layer list.
	private Table _layers = null;

	/// Image type and depth.
	private Combo _imageType = null;
	/// Button of Save.
	private Button _save = null;
	/// Target folder of saving combinations.
	private Text _target = null;

	/// Items of combination toolbar.
	private ToolItem _tAdd = null, _tRemove = null, _tUp = null, _tDown = null;

	/// Manager of undo and redo operation.
	private UndoManager _um = null;

	/// The only constructor.
	this (Shell parent, DCommon c, UndoManager um, MLImage image, string name) {
		_um = um;
		_image = image;
		_name = name;
		auto title  = c.text.fEditCombinationDialog.value.format(name);
		auto buttons = DBtn.Ok | DBtn.Apply | DBtn.Cancel;
		super (c, parent, title, .cimg(c.image.editCombination), true, true, false, buttons);
	}

	protected override void setup(Composite area) {
		area.p_layout = new FillLayout;

		/* ----- Preview ----------------------------------------------- */
		_splitterV = basicVSplitter(area);
		_preview = new Preview(_splitterV, SWT.DOUBLE_BUFFERED);

		/* ----- Createes controls ------------------------------------- */
		auto controls = basicComposite(_splitterV);
		controls.p_layout = GL.window(1);

		_splitterH = basicHSplitter(controls);
		_splitterH.p_layoutData = GD.fill(true, true);

		// Combination list.
		auto combiPane = basicComposite(_splitterH);
		_splitterH.resizable = combiPane;
		combiPane.p_layout = GL.window(1, true).margin(0);
		combinationToolBar(combiPane);
		_combiList = listTable(combiPane, true);
		_combiList.p_layoutData = GD.fill(true, true);
		_combiList.listeners!(SWT.Selection) ~= &updateLayerList;
		_combiName = createEditor(_combiList, true, (int index, string name) {
			_combiData[index].name = name;
			_combiList.getItem(index).p_text = name;
		});

		// Layer list.
		_layers = listTable(_splitterH, false, true);
		_layers.listeners!(SWT.Selection) ~= (Event e) {
			if (SWT.CHECK != e.detail) return;
			auto item = cast(TableItem) e.item;
			checkLayer(_layers.indexOf(item), item.p_checked);
		};

		// Settings for output.
		auto output = basicGroup(controls, c.text.combinationOutput);
		output.p_layoutData = GD.fill(true, false);
		output.p_layout = GL(3, false);

		// image type and depth
		_imageType = basicCombo(output);
		_imageType.p_layoutData = GD.fill(true, false).hSpan(3);
		_imageType.listeners!(SWT.Selection) ~= &_preview.redraw;

		// folder
		basicLabel(output, c.text.targetFolder);
		string dialogTitle = c.text.selectFolderDialogTitle;
		string dialogMsg = c.text.selectCombinationOutputFolder;
		auto target = folderField(output, dialogTitle, dialogMsg, c.text.selectFile);
		target.pane.p_layoutData = GD.fill(true, false);
		_target = target.text;
		_save = basicButton(output, c.text.saveCombination, .cimg(c.image.editCombination), &saveCombination);

		/* ----- Initializes controls ---------------------------------- */
		// combination list
		foreach (combi; _image.combinations) {
			_combiList.add(combi.name);
			_combiData ~= Combination(combi.name, combi.visible.dup);
		}
		// layer list
		foreach (i; 0 .. _image.layerCount) {
			auto itm = basicTableItem(_layers, _image.layer(i).name);
			itm.p_checked = true;
			itm.p_grayed = true;
		}

		// image type and depth
		string bmp = c.text.fSaveImageTypeBitmap;
		string png = c.text.fSaveImageTypePNG;
		_imageType.add(bmp.format(8, 256));
		_imageType.add(bmp.format(4, 16));
		_imageType.add(bmp.format(1, 2));
		_imageType.add(png.format(8, 256));
		_imageType.add(png.format(4, 16));
		_imageType.add(png.format(1, 2));
		c.conf.combinationImageType.value.refSelectionIndex(_imageType);

		// output folder
		c.conf.combinationFolder.value.refText(_target);

		updateEnabled();
	}

	protected override void onOpen(Shell shell) {
		// dialog bounds
		c.conf.combinationDialog.value.refWindow(shell);
		// splitters
		c.conf.sashPosPreview_Combinations.value.refSelection(_splitterV);
		c.conf.sashPosCombinations_Layers.value.refSelection(_splitterH);
	}

	/// Creates combination control toolbar.
	private void combinationToolBar(Composite parent) {
		auto combiTools = basicToolBar(parent);
		_tAdd = basicToolItem(combiTools, c.text.menu.addCombination, .cimg(c.image.addCombination), {
			int index = _combiList.p_selectionIndex + 1;
			string name = "%s_%s".format(_name.stripExtension(), index + 1);
			_combiList.add(name, index);
			auto visible = new bool[_image.layerCount];
			visible[] = true;
			_combiData.insertInPlace(index, Combination(name, visible));

			_combiList.deselectAll();
			_combiList.select(index);
			enableApply();
			updateLayerList();
		});
		_tRemove = basicToolItem(combiTools, c.text.menu.removeCombination, .cimg(c.image.removeCombination), {
			int[] indices = _combiList.p_selectionIndices;
			if (!indices.length) return;
			_combiList.remove(indices);
			foreach_reverse (i; indices) {
				_combiData.remove(i);
			}
			enableApply();
			updateEnabled();
		});

		separator(combiTools);

		// Swap combinations.
		void swapCombi(int index1, int index2) {
			_combiList.swapItems(index1, index2);
			.swap(_combiData[index1], _combiData[index2]);
		}
		_tUp = basicToolItem(combiTools, c.text.menu.up, .cimg(c.image.up), {
			auto indices = _combiList.p_selectionIndices.sort;
			if (!indices.length) return;
			if (0 == indices[0]) return;
			foreach (i; indices) {
				swapCombi(i - 1, i);
			}
			indices[] -= 1;
			_combiList.deselectAll();
			_combiList.select(indices);
			enableApply();
			updateEnabled();
		});
		_tDown = basicToolItem(combiTools, c.text.menu.down, .cimg(c.image.down), {
			auto indices = _combiList.p_selectionIndices.sort;
			if (!indices.length) return;
			if (_combiList.p_itemCount - 1 == indices[$ - 1]) return;
			foreach_reverse (i; indices) {
				swapCombi(i, i + 1);
			}
			indices[] += 1;
			_combiList.deselectAll();
			_combiList.select(indices);
			enableApply();
			updateEnabled();
		});
	}

	/// Sets enabled or disabled of a controls from state.
	private void updateEnabled() {
		bool existsCombi = 0 < _combiList.p_itemCount;
		auto selCombi = _combiList.p_selectionIndices.sort;
		_combiList.p_enabled = existsCombi;
		_layers.p_enabled = 0 < selCombi.length;
		_save.p_enabled = existsCombi;
		_tAdd.p_enabled = true;
		_tRemove.p_enabled = 0 < selCombi.length;
		_tUp.p_enabled = selCombi.length && 0 < selCombi[0];
		_tDown.p_enabled = selCombi.length && selCombi[$ - 1] + 1 < _combiList.p_itemCount;

		_preview.redraw();
	}

	/// Update layer list from selection combination.
	private void updateLayerList() {
		auto indices = _combiList.p_selectionIndices;
		if (0 == indices.length) {
			foreach (i, itm; _layers.p_items) {
				itm.p_grayed = true;
				itm.p_checked = true;
			}
		} else if (1 == indices.length) {
			foreach (i, itm; _layers.p_items) {
				itm.p_grayed = false;
				itm.p_checked = _combiData[indices[0]].visible[i];
			}
		} else {
			auto checked = _combiData[indices[0]].visible.dup;
			foreach (i, itm; _layers.p_items) {
				bool grayed = false;
				foreach (ci; indices[1 .. $]) {
					if (checked[i] != _combiData[ci].visible[i]) {
						grayed = true;
						break;
					}
				}
				if (grayed) {
					itm.p_grayed = true;
					itm.p_checked = true;
				} else {
					itm.p_grayed = false;
					itm.p_checked = checked[i];
				}
			}
		}
		updateEnabled();
	}

	/// This method is called when checked layer list item.
	private void checkLayer(int index, bool check) {
		auto indices = _combiList.p_selectionIndices;
		foreach (i; indices) {
			_combiData[i].visible[index] = check;
		}
		enableApply();
		_preview.redraw();
	}

	/// Selection depth.
	@property
	private ubyte selectedDepth() {
		switch (_imageType.p_selectionIndex) {
		case 0: // 256-colors bitmap
			return 8;
		case 1: // 16-colors bitmap
			return 4;
		case 2: // 2-colors bitmap
			return 1;
		case 3: // 256-colors png
			return 8;
		case 4: // 16-colors png
			return 4;
		case 5: // 2-colors png
			return 1;
		default:
			SWT.error(SWT.ERROR_INVALID_ARGUMENT);
			assert (0);
		}
	}

	/// Save combinations.
	private void saveCombination() {
		ubyte depth = selectedDepth;
		int imageType;
		string dir = _target.p_text.absolutePath(c.moduleFileName.dirName());
		try {
			_image.writeCombination(imageType, depth, dir, (ref string[] filename, out bool cancel) {
				// ask to overwrite
				string title = c.text.fQuestionDialog.value.format(c.text.appName);
				string msg = c.text.fAskFilesOverwrite.value.format(filename.length);
				switch (.showYesNoDialog(_save.p_shell, msg, title)) {
				case SWT.YES:
					cancel = false;
					break;
				case SWT.NO:
					cancel = true;
					filename.length = 0;
					break;
				default: assert (0);
				}
			}, _combiData);
		} catch (Exception e) {
			.erroroutf("Save failure.");
		}
	}

	protected override bool apply() {
		if (_image.combinations != _combiData) {
			if (_um) _um.store(_image);
			_image.combinations = _combiData;
			return true;
		}
		return false;
	}

	/// Preview of combination.
	private class Preview : Canvas {

		/// The only constructor.
		this (Composite parent, int style) {
			super (parent, style);

			auto d = this.p_display;
			this.p_background = d.getSystemColor(SWT.COLOR_GRAY);
			this.p_foreground = d.getSystemColor(SWT.COLOR_DARK_GRAY);

			this.bindListeners();
		}

		private void onPaint(Event e) {
			auto d = this.p_display;
			auto ca = this.p_clientArea;
			e.gc.drawShade(ca);

			auto index = _combiList.p_selectionIndex;
			if (-1 == index) return;

			size_t[] ls;
			int x = (ca.width - _image.width) / 2;
			int y = (ca.height - _image.height) / 2;
			foreach_reverse (l, v; _combiData[index].visible) {
				if (!v) continue;
				auto img = new Image(d, _image.layer(l).image);
				scope (exit) img.dispose();
				e.gc.drawImage(img, x, y);
			}
		}
	}
}
