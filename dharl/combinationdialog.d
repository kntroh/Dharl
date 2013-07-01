
/// This module includes dialog of editor for
/// combinations of layers in MLImage and members related to it.
///
/// License: Public Domain
/// Authors: kntroh
module dharl.combinationdialog;

private import util.undomanager;
private import util.utils;

private import dharl.common;
private import dharl.dialogs;

private import dharl.image.mlimage;

private import dharl.ui.basicdialog;
private import dharl.ui.dwtutils;
private import dharl.ui.pimagelist;
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
	private PImageList _preview = null;

	/// Combination data.
	private Combination[] _combiData = [];
	/// Combination list.
	private Table _combiList = null;
	/// Editor for combination name.
	private Editor _combiName = null;

	/// Layer list.
	private Table _layers = null;
	/// Selection palette of combination.
	private Combo _palette = null;

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

	/// Combination data.
	@property
	const
	const(Combination)[] combinations() {
		return _combiData;
	}

	protected override void setup(Composite area) {
		area.p_layout = new FillLayout;

		/* ----- Preview ----------------------------------------------- */
		_splitterV = basicVSplitter(area, false);
		_preview = new PImageList(_splitterV, SWT.BORDER | SWT.DOUBLE_BUFFERED | SWT.READ_ONLY);
		_splitterV.resizable = _preview;
		_preview.p_listeners!(SWT.Selection) ~= {
			_combiList.deselectAll();
			_combiList.select(_preview.selectedIndex);
			_combiList.showSelection();
			updateLayerList();
		};

		/* ----- Createes controls ------------------------------------- */
		auto controls = basicComposite(_splitterV);
		controls.p_layout = GL.window(1);

		_splitterH = basicHSplitter(controls, false);
		_splitterH.p_layoutData = GD.fill(true, true);

		// Combination list.
		auto combiGrp = basicGroup(_splitterH, c.text.combinations);
		_splitterH.resizable = combiGrp;
		combiGrp.p_layout = GL(1, true).spacing(GL.WINDOW_SPACING);
		combinationToolBar(combiGrp);
		_combiList = listTable(combiGrp, true);
		_combiList.p_layoutData = GD.fill(true, true);
		void updateList() {
			_preview.selectedIndex = _combiList.p_selectionIndex;
			_preview.showSelection();
			updateLayerList();
		}
		_combiList.p_listeners!(SWT.Selection) ~= &updateList;
		_combiName = createEditor(_combiList, true, (int index, string name) {
			_combiData[index].name = name;
			_combiList.getItem(index).p_text = name;
			auto item = _preview.item(index);
			item.p_text = name;
			item.toolTip = name;
			enableApply();
		});

		// Layer list.
		auto layerGrp = basicGroup(_splitterH, c.text.combinationVisibility);
		layerGrp.p_layout = GL(1, true).spacing(GL.WINDOW_SPACING);
		_layers = listTable(layerGrp, false, true);
		_layers.p_layoutData = GD.fill(true, true);
		_layers.p_listeners!(SWT.Selection) ~= (Event e) {
			if (SWT.CHECK != e.detail) return;
			auto item = cast(TableItem)e.item;
			checkLayer(_layers.indexOf(item), item.p_checked);
		};
		// palette
		_palette = basicCombo(layerGrp);
		mod(_palette);
		_palette.p_layoutData = GD.fill(true, false);
		_palette.p_listeners!(SWT.Selection) ~= {
			auto index = _palette.p_selectionIndex;
			if (-1 == index) return;
			auto indices = _combiList.p_selectionIndices;
			foreach (i; indices) {
				_combiData[i].selectedPalette = index;
				_preview.item(i).combination = _combiData[i];
			}
			_preview.redraw();
		};

		// Settings for output.
		auto output = basicGroup(controls, c.text.combinationOutput);
		output.p_layoutData = GD.fill(true, false);
		output.p_layout = GL(3, false);

		// image type and depth
		_imageType = basicCombo(output);
		_imageType.p_layoutData = GD.fill(true, false).hSpan(3);
		void updateImageType() {
			foreach (l; 0 .. _preview.imageCount) {
				_preview.item(l).depth = selectedDepth;
			}
		}
		_imageType.p_listeners!(SWT.Selection) ~= &updateImageType;

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
			_combiData ~= combi.clone;

			// preview
			auto pi = new PImageItem(_preview, SWT.NONE);
			pi.p_text = combi.name;
			pi.image = _image;
			pi.toolTip = combi.name;
			pi.combination = combi;
		}
		if (_combiList.p_itemCount) _combiList.select(0);
		// layer list
		foreach (i; 0 .. _image.layerCount) {
			auto itm = basicTableItem(_layers, _image.layer(i).name);
			itm.p_checked = true;
			itm.p_grayed = true;
		}
		// palette
		foreach (i; 0 .. _image.palettes.length) {
			_palette.add(c.text.fPaletteName.value.format(i + 1));
		}

		// image type and depth
		foreach (typeValue; COMBINATION_IMAGE_TYPES) {
			ubyte depth = .combinationImageTypeToDepth(typeValue);
			string f;
			switch (.combinationImageTypeToFormat(typeValue)) {
			case SWT.IMAGE_BMP:
				f = c.text.fSaveImageTypeBitmap;
				break;
			case SWT.IMAGE_PNG:
				f = c.text.fSaveImageTypePNG;
				break;
			default:
				assert (0);
			}
			_imageType.add(f.format(depth, 1 << depth));
		}
		c.conf.combinationImageType.value.refSelectionIndex(_imageType);

		// output folder
		c.conf.combinationFolder.value.refText(_target);

		updateImageType();
		updateList();
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
			int selected = _combiList.p_selectionIndex;
			int index = selected + 1;
			string name = "%s_%s".format(_name.stripExtension(), index + 1);
			_combiList.add(name, index);
			auto visible = new bool[_image.layerCount];
			int selectedPalette = 0;
			if (selected == -1) {
				visible[] = false;
			} else {
				visible[] = _combiData[selected].visible;
				selectedPalette = _combiData[selected].selectedPalette;
			}
			auto combi = Combination(name, visible, selectedPalette);
			_combiData.insertInPlace(index, combi);
			auto pi = new PImageItem(_preview, SWT.NONE, index);
			pi.p_text = combi.name;
			pi.image = _image;
			pi.toolTip = combi.name;
			pi.combination = combi;
			pi.depth = selectedDepth;

			_combiList.deselectAll();
			_combiList.select(index);
			enableApply();
			updateLayerList();
		});
		_tRemove = basicToolItem(combiTools, c.text.menu.removeCombination, .cimg(c.image.removeCombination), {
			int[] indices = _combiList.p_selectionIndices;
			if (!indices.length) return;
			_combiList.remove(indices);
			foreach_reverse (i; indices.sort) {
				_combiData = _combiData.remove(i);
				_preview.item(i).dispose();
			}
			_preview.selectedIndex = -1;
			updateLayerList();
			enableApply();
			updateEnabled();
		});

		separator(combiTools);

		// Swap combinations.
		void swapCombi(int index1, int index2) {
			_combiList.swapItems(index1, index2);
			.swap(_combiData[index1], _combiData[index2]);
			_preview.move(index1, index2);
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
			_combiList.showSelection();
			_preview.showSelection();
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
			_combiList.showSelection();
			_preview.showSelection();
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
		_palette.p_enabled = _layers.p_enabled;
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
			_palette.deselectAll();
		} else if (1 == indices.length) {
			foreach (i, itm; _layers.p_items) {
				itm.p_grayed = false;
				itm.p_checked = _combiData[indices[0]].visible[i];
			}
			_palette.select(_combiData[indices[0]].selectedPalette);
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
			int selectedPalette = _combiData[indices[0]].selectedPalette;
			foreach (ci; indices[1 .. $]) {
				if (selectedPalette != _combiData[ci].selectedPalette) {
					selectedPalette = -1;
					break;
				}
			}
			if (-1 == selectedPalette) {
				_palette.deselectAll();
			} else {
				_palette.select(selectedPalette);
			}
		}
		updateEnabled();
	}

	/// This method is called when checked layer list item.
	private void checkLayer(int index, bool check) {
		auto indices = _combiList.p_selectionIndices;
		foreach (i; indices) {
			_combiData[i].visible[index] = check;
			_preview.item(i).combination = _combiData[i];
		}
		enableApply();
	}

	/// Selection depth.
	@property
	private ubyte selectedDepth() {
		return .combinationImageTypeToDepth(_imageType.p_selectionIndex);
	}
	/// Selection image format.
	@property
	private int selectedImageFormat() {
		return .combinationImageTypeToFormat(_imageType.p_selectionIndex);
	}

	/// Save combinations.
	private void saveCombination() {
		ubyte depth = selectedDepth;
		int imageType = selectedImageFormat;
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
		return true;
	}
}

/// Selectable combination image types.
immutable COMBINATION_IMAGE_TYPES = [0, 1, 2, 3, 4, 5];

/// Gets color depth from image type value.
ubyte combinationImageTypeToDepth(int imageType) {
	switch (imageType) {
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
		SWT.error(__FILE__, __LINE__, SWT.ERROR_INVALID_ARGUMENT);
		assert (0);
	}
}

/// Gets image format from image type value.
int combinationImageTypeToFormat(int imageType) {
	switch (imageType) {
	case 0: // 256-colors bitmap
	case 1: // 16-colors bitmap
	case 2: // 2-colors bitmap
		return SWT.IMAGE_BMP;
	case 3: // 256-colors png
	case 4: // 16-colors png
	case 5: // 2-colors png
		return SWT.IMAGE_PNG;
	default:
		SWT.error(__FILE__, __LINE__, SWT.ERROR_INVALID_ARGUMENT);
		assert (0);
	}
}
