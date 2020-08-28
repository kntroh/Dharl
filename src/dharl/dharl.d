
/// Dharl main.
///
/// License: Public Domain
/// Authors: kntroh
module dharl.dharl;

private import util.commprocess;
private import util.environment;
private import util.graphics;
private import util.utils;

private import dharl.combinationdialog;
private import dharl.common;
private import dharl.dialogs;
private import dharl.mainpanel;

private import dharl.image.mlimage;
private import dharl.image.susie;

private import dharl.ui.dwtutils;
private import dharl.ui.paintarea;
private import dharl.ui.simpletextdialog;
private import dharl.ui.uicommon;

private import std.algorithm;
private import std.array;
private import std.conv;
private import std.file;
private import std.getopt;
private import std.path;
private import std.string;

private import org.eclipse.swt.all;

private import java.lang.all : ArrayWrapperString2;
private import java.nonstandard.Locale;

/// Pipe name for process communication.
private immutable PIPE_NAME = "dharl";

/// Commands of process communication.
private immutable MSG_EXECUTE      = "execute";
/// ditto
private immutable MSG_GET_ARGUMENT = "get argument";
/// ditto
private immutable MSG_ARGUMENT     = "argument "; // appends filepath after space
/// ditto
private immutable MSG_QUIT         = "quit";

version (LDC) {
	version (Windows) {
		// The libcmt.lib that comes with the LDC requires a C runtime entry point
		// when specified "/ENTRY:mainCRTStartup" as a linker option.
		private import core.runtime;
		private import core.stdc.string;
		private import core.sys.windows.windows;
		/// Entry point of C runtime.
		extern (C) INT main(INT argc, const char** argv) {
			Runtime.initialize();
			scope (exit) Runtime.terminate();
			string[] args;
			foreach (i; 0 .. argc) args ~= .to!string(argv);
			try {
				dmain(args);
				return 0;
			} catch (Throwable e) {
				return -1;
			}
		}
	} else {
		/// Entry point of D runtime.
		void main(string[] args) { dmain(args); }
	}
} else {
	/// Entry point of D runtime.
	void main(string[] args) { dmain(args); }
}

/// Entry point of the program.
private void dmain(string[] args) {
	string exe = .thisExePath();
	.coutf("Execute: %s", exe);
	.errorLog = "%s.log".format(exe);

	// Load application configuration.
	string appData = .appData(exe.dirName(), true).buildPath("dharl".hiddenFileName()).buildPath("settings.xml");
	.coutf("AppData: %s", appData);
	auto c = new DCommon(exe);
	if (appData.exists()) {
		try {
			c.conf.readXMLFile(appData);
		} catch (Exception e) {
			.erroroutf("Read failure: %s", appData);
		}
	}
	// Reads language file.
	auto lang = c.moduleFileName.dirName().buildPath("lang").buildPath(.caltureName().setExtension(".xml"));
	if (lang.exists()) {
		try {
			c.text.readXMLFile(lang);
		} catch (Exception e) {
			.erroroutf("Read failure: %s", lang);
		}
	}

	// Gets command line options.
	bool help = false;
	bool writeCombi = false;
	int imageType = c.conf.combinationImageType;
	string targDir = ".";
	.getopt(
		args,
		"h|help", &help,
		"w|write-combinations", &writeCombi,
		"t|image-type", &imageType,
		"d|target-directory", &targDir
	);

	if (help) {
		// Print help message.
		auto supportFormats = SUPPORTED_FORMATS.dup.join(";");

		string[] imageTypes;
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
			string type = c.text.fImageTypeInUsage;
			imageTypes ~= type.format(typeValue, f.format(depth, 1 << depth));
		}

		string message = c.text.usage.value.format(VERSION, supportFormats, imageTypes.join("\n"));
		.coutf(message);

		auto dialog = new SimpleTextDialog(null, c.text.appName, .cmimg(c.image.dharl), dialogStateFrom(c));
		dialog.p_message = message;
		dialog.open();
		dialog.p_display.startApplication(&dialog.isDisposed);

		return;
	}

	// Files in startup arguments.
	string[] argFiles;
	foreach (i, arg; args[1 .. $]) {
		foreach (file; arg.glob()) {
			argFiles ~= file;
		}
	}

	if (writeCombi) {
		// Write combinations from *.dhr files to image file.
		string[] argFilesDhr;
		foreach (i, arg; argFiles) {
			if (0 == arg.extension().filenameCmp(".dhr")) {
				argFilesDhr ~= arg;
			}
		}
		writeCombinations(argFilesDhr, imageType, targDir);
		return;
	}

	// Sends message to existing process (if exist it).
	size_t sentArg = 0;
	bool send = sendToPipe(PIPE_NAME, (in char[] reply) {
		if (reply is null) {
			return MSG_EXECUTE;
		} else if (MSG_GET_ARGUMENT == reply) {
			if (sentArg < argFiles.length) {
				auto msg = MSG_ARGUMENT ~ argFiles[sentArg].absolutePath();
				sentArg++;
				return msg;
			}
		}
		return "";
	});
	if (send) {
		// Opened files at existing process.
		// So quit this process.
		return;
	}

	// Creates window and controls.
	auto shell = basicShell(c.text.appName, .cmimg(c.image.dharl), GL.window);
	shell.initMouseWheel();
	auto display = shell.p_display;
	auto mainPanel = initialize(c, shell);

	// Open files from arguments.
	foreach (file; argFiles) {
		try {
			mainPanel.loadImage(file);
		} catch (Exception e) {
			.erroroutf("Load failure: %s", file);
		}
	}

	// Starts pipe server.
	bool startServer = startPipeServer(PIPE_NAME, (in char[] recv, out bool quit) {
		if (MSG_QUIT == recv) {
			quit = true;
			return "";
		} else if (MSG_EXECUTE == recv) {
			display.syncExecWith({
				shell.p_minimized = false;
				shell.open();
			});
			return MSG_GET_ARGUMENT;
		} else if (recv.startsWith(MSG_ARGUMENT)) {
			display.syncExecWith({
				auto file = recv[(MSG_ARGUMENT).length .. $].idup;
				try {
					mainPanel.loadImage(file);
				} catch (Exception e) {
					.erroroutf("Load failure: %s", file);
				}
			});
			return MSG_GET_ARGUMENT;
		}
		return "";
	}, false, 1000);
	if (!startServer) {
		auto msg = .format("Pipe creation failure: %s", PIPE_NAME);
		.erroroutf(msg);
		throw new Exception(msg);
	}
	scope (exit) sendToPipe(PIPE_NAME, MSG_QUIT);

	// Open window.
	shell.startApplication((Throwable e) {
		.errorout(e);
		showErrorDialog(shell, .text(e), c.text.fErrorDialog.value.format(c.text.appName));
		return true;
	});

	// Save application configuration.
	try {
		auto appDir = appData.dirName();
		if (!appDir.exists()) appDir.mkdirRecurse();

		c.conf.writeXMLFile(appData);

	} catch (Exception e) {
		.erroroutf("Write failure: %s", appData);
	}
}

/// Initialize main window.
private MainPanel initialize(DCommon c, Shell shell) {
	auto d = shell.p_display;

	// The toolbar.
	auto toolBar = basicToolBar(shell, SWT.FLAT | SWT.HORIZONTAL | SWT.WRAP);
	toolBar.p_layoutData = GD(GridData.FILL_HORIZONTAL);

	// The main panel.
	auto mainPanel = new MainPanel(shell, SWT.NONE);
	mainPanel.p_layoutData = GD(GridData.FILL_BOTH);
	mainPanel.init(c);

	// Menus.
	auto mFile = basicDropDownMenu(shell, c.text.menu.file);
	int mFileHistFrom;
	auto mEdit = basicDropDownMenu(shell, c.text.menu.edit);
	auto mView = basicDropDownMenu(shell, c.text.menu.view);
	auto mMode = basicDropDownMenu(shell, c.text.menu.mode);
	auto mPalette = basicDropDownMenu(shell, c.text.menu.palette);
	auto mTool = basicDropDownMenu(shell, c.text.menu.tool);
	auto mHelp = basicDropDownMenu(shell, c.text.menu.help);

	// Sets title of shell from state.
	void refreshTitle() {
		int i = mainPanel.selectedIndex;
		if (-1 == i) {
			shell.p_text = c.text.appName;
		} else {
			string title;
			if (mainPanel.modified(i)) {
				title = c.text.fAppNameWithImageChanged;
			} else {
				title = c.text.fAppNameWithImage;
			}
			shell.p_text = title.format(mainPanel.imageName(i), c.text.appName);
		}
	}
	mainPanel.selectedReceivers ~= &refreshTitle;

	// Puts history of opened to mFile.
	void refreshFileMenu() {
		foreach_reverse (i; mFileHistFrom .. mFile.p_itemCount) {
			mFile.getItem(i).dispose();
		}

		if (c.conf.fileHistory.length) {
			separator(mFile, mFileHistFrom);
			void createItem(int index, string file) {
				basicMenuItem(mFile, file.omitPath(c.conf.fileHistoryOmitLength), .cimg(c.image.imageFile), {
					try {
						mainPanel.loadImage(file);
					} catch (Exception e) {
						.erroroutf("Load failure: %s", file);
					}
				}, SWT.PUSH, false, mFileHistFrom + index);
			}
			foreach (i, file; c.conf.fileHistory) {
				createItem(cast(int)i + 1, file);
			}
		}
	}

	/* ---- File menu -------------------------------------------------- */

	basicMenuItem(mFile, toolBar, c.text.menu.createNewImage, cimg(c.image.createNewImage), {
		auto cs = c.conf.character;
		mainPanel.createNewImage(cs.width, cs.height, true);
	});
	separator(mFile, toolBar);
	basicMenuItem(mFile, toolBar, c.text.menu.openImage, cimg(c.image.openImage), {
		mainPanel.loadImage();
	});
	auto tSaveOverwrite = basicMenuItem(mFile, toolBar, c.text.menu.saveOverwrite, cimg(c.image.saveOverwrite), {
		mainPanel.saveImageOverwrite();
	});
	separator(mFile, toolBar);
	auto tSaveWithName = basicMenuItem(mFile, toolBar, c.text.menu.saveWithName, cimg(c.image.saveWithName), {
		mainPanel.saveImageWithName();
	});
	separator(mFile, toolBar);
	auto tSaveAll = basicMenuItem(mFile, toolBar, c.text.menu.saveAll, cimg(c.image.saveAll), {
		mainPanel.saveAll();
	});

	MenuItem[PaintMode] modeItems;
	MenuItem tLSel, tSel, tTextDrawing;


	/* ---- Edit menu -------------------------------------------------- */

	separator(toolBar);
	auto tUndo = basicMenuItem(mEdit, toolBar, c.text.menu.undo, cimg(c.image.undo), {
		mainPanel.undo();
	});
	auto tRedo = basicMenuItem(mEdit, toolBar, c.text.menu.redo, cimg(c.image.redo), {
		mainPanel.redo();
	});

	separator(mEdit, toolBar);
	auto tCut = basicMenuItem(mEdit, toolBar, c.text.menu.cut, cimg(c.image.cut), {
		mainPanel.paintArea.cut();
	});
	auto tCopy = basicMenuItem(mEdit, toolBar, c.text.menu.copy, cimg(c.image.copy), {
		mainPanel.paintArea.copy();
	});
	auto tPaste = basicMenuItem(mEdit, toolBar, c.text.menu.paste, cimg(c.image.paste), {
		mainPanel.paintArea.paste();
	});
	auto tDelete = basicMenuItem(mEdit, toolBar, c.text.menu.del, cimg(c.image.del), {
		mainPanel.paintArea.del();
	});
	separator(mEdit, toolBar);
	auto tSelectAll = basicMenuItem(mEdit, toolBar, c.text.menu.selectAll, cimg(c.image.selectAll), {
		mainPanel.paintArea.selectAll();
	});
	separator(mEdit);
	auto tAddLayer = basicMenuItem(mEdit, c.text.menu.addLayer, cimg(c.image.addLayer), {
		mainPanel.addLayer();
	});
	auto tRemoveLayer = basicMenuItem(mEdit, c.text.menu.removeLayer, cimg(c.image.removeLayer), {
		mainPanel.removeLayer();
	});
	separator(mEdit);
	auto tUpLayer = basicMenuItem(mEdit, c.text.menu.up, cimg(c.image.up), {
		mainPanel.upLayer();
	});
	auto tDownLayer = basicMenuItem(mEdit, c.text.menu.down, cimg(c.image.down), {
		mainPanel.downLayer();
	});
	separator(mEdit);
	auto tUniteLayers = basicMenuItem(mEdit, c.text.menu.uniteLayers, cimg(c.image.uniteLayers), {
		mainPanel.uniteLayers();
	});
	separator(mEdit);
	auto tSelectAllLayers = basicMenuItem(mEdit, c.text.menu.selectAllLayers, cimg(c.image.selectAllLayers), {
		mainPanel.selectAllLayers();
	});


	/* ---- View menu -------------------------------------------------- */

	MenuItem mMainGrid;
	mMainGrid = basicMenuItem(mView, c.text.menu.mainGrid, cimg(c.image.mainGrid), {
		mainPanel.paintArea.grid1 = mMainGrid.p_selection;
	}, SWT.CHECK);
	MenuItem mSubGrid;
	mSubGrid = basicMenuItem(mView, c.text.menu.subGrid, cimg(c.image.subGrid), {
		mainPanel.paintArea.grid2 = mSubGrid.p_selection;
	}, SWT.CHECK);


	/* ---- Mode menu -------------------------------------------------- */

	MenuItem mBack;
	mBack = basicMenuItem(mMode, c.text.menu.enabledBackColor, cimg(c.image.enabledBackColor), {
		mainPanel.paintArea.enabledBackColor = mBack.p_selection;
	}, SWT.CHECK);
	separator(mMode);
	auto updSel = {
		if (tLSel.p_selection) {
			mainPanel.paintArea.rangeSelection = SelectMode.lasso;
		} else if (tSel.p_selection) {
			mainPanel.paintArea.rangeSelection = SelectMode.rect;
		} else {
			mainPanel.paintArea.rangeSelection = SelectMode.notSelection;
		}
	};
	tLSel = basicMenuItem(mMode, c.text.menu.freeSelection, cimg(c.image.freeSelection), updSel, SWT.RADIO, mainPanel.paintArea.rangeSelection is SelectMode.lasso);
	tSel = basicMenuItem(mMode, c.text.menu.selection, cimg(c.image.selection), updSel, SWT.RADIO, mainPanel.paintArea.rangeSelection is SelectMode.rect);
	MenuItem createModeItem(string text, Image img, PaintMode mode) {
		auto result = basicMenuItem(mMode, text, img, {
			mainPanel.paintArea.mode = mode;
		}, SWT.RADIO);
		modeItems[mode] = result;
		return result;
	}
	auto tFreePath = createModeItem(c.text.menu.freePath, cimg(c.image.freePath), PaintMode.FreePath);
	auto tStraight = createModeItem(c.text.menu.straight, cimg(c.image.straight), PaintMode.Straight);
	auto tOvalLine = createModeItem(c.text.menu.ovalLine, cimg(c.image.ovalLine), PaintMode.OvalLine);
	auto tRectLine = createModeItem(c.text.menu.rectLine, cimg(c.image.rectLine), PaintMode.RectLine);
	auto tOvalFill = createModeItem(c.text.menu.ovalFill, cimg(c.image.ovalFill), PaintMode.OvalFill);
	auto tRectFill = createModeItem(c.text.menu.rectFill, cimg(c.image.rectFill), PaintMode.RectFill);
	auto tFill = createModeItem(c.text.menu.fillArea, cimg(c.image.fillArea), PaintMode.Fill);
	tTextDrawing = basicMenuItem(mMode, c.text.menu.textDrawing, cimg(c.image.textDrawing), {
		mainPanel.paintArea.textDrawing = tTextDrawing.p_selection;
	}, SWT.RADIO, mainPanel.paintArea.textDrawing);


	/* ---- Paletete menu ---------------------------------------------- */

	separator(toolBar);

	auto tGrad = basicMenuItem(mPalette, c.text.menu.createGradation, cimg(c.image.createGradation), {
		mainPanel.createGradation();
	});
	separator(mPalette);
	MenuItem tMask;
	tMask = basicMenuItem(mPalette, c.text.menu.maskMode, cimg(c.image.maskMode), {
		mainPanel.maskMode = tMask.p_selection;
	}, SWT.CHECK);
	separator(mPalette);
	auto mPTrans = basicMenuItem(mPalette, toolBar, c.text.menu.paletteTransfer, .cimg(c.image.paletteTransfer), &mainPanel.paletteTransfer);


	/* ---- Tool menu -------------------------------------------------- */

	separator(toolBar);

	auto mCombi = basicMenuItem(mTool, toolBar, c.text.menu.editCombination, cimg(c.image.editCombination), {
		mainPanel.editCombination();
	});
	separator(mTool, toolBar);
	auto tResizeC = basicMenuItem(mTool, toolBar, c.text.menu.resizeCanvas, cimg(c.image.resizeCanvas), &mainPanel.resizeCanvas);
	separator(toolBar);
	auto tCloseImage = basicMenuItem(mFile, toolBar, c.text.menu.closeImage, cimg(c.image.closeImage), &mainPanel.closeImage);
	separator(mFile);
	auto exit = basicMenuItem(mFile, c.text.menu.exit, cimg(c.image.exit), &shell.close);
	mFileHistFrom = mFile.getItemCount();

	separator(mTool);
	auto tResize = basicMenuItem(mTool, c.text.menu.resize, cimg(c.image.resize), &mainPanel.resize);
	separator(mTool);
	basicMenuItem(mTool, c.text.menu.turn90,  cimg(c.image.turn90), &mainPanel.turn90);
	basicMenuItem(mTool, c.text.menu.turn270, cimg(c.image.turn270), &mainPanel.turn270);
	basicMenuItem(mTool, c.text.menu.turn180, cimg(c.image.turn180), &mainPanel.turn180);
	separator(mTool);
	basicMenuItem(mTool, c.text.menu.turn, cimg(c.image.turn), &mainPanel.turn);
	separator(mTool);
	basicMenuItem(mTool, c.text.menu.mirrorHorizontal, cimg(c.image.mirrorHorizontal), &mainPanel.mirrorHorizontal);
	basicMenuItem(mTool, c.text.menu.mirrorVertical, cimg(c.image.mirrorVertical), &mainPanel.mirrorVertical);
	separator(mTool);
	basicMenuItem(mTool, c.text.menu.flipHorizontal, cimg(c.image.flipHorizontal), &mainPanel.flipHorizontal);
	basicMenuItem(mTool, c.text.menu.flipVertical, cimg(c.image.flipVertical), &mainPanel.flipVertical);
	separator(mTool);
	basicMenuItem(mTool, c.text.menu.rotateLeft, cimg(c.image.rotateLeft), &mainPanel.rotateLeft);
	basicMenuItem(mTool, c.text.menu.rotateDown, cimg(c.image.rotateDown), &mainPanel.rotateDown);
	basicMenuItem(mTool, c.text.menu.rotateUp, cimg(c.image.rotateUp), &mainPanel.rotateUp);
	basicMenuItem(mTool, c.text.menu.rotateRight, cimg(c.image.rotateRight), &mainPanel.rotateRight);
	separator(mTool);
	basicMenuItem(mTool, c.text.menu.increaseBrightness, cimg(c.image.increaseBrightness), &mainPanel.increaseBrightness);
	basicMenuItem(mTool, c.text.menu.decreaseBrightness, cimg(c.image.decreaseBrightness), &mainPanel.decreaseBrightness);

	separator(mTool, toolBar);
	auto mConf = basicMenuItem(mTool, toolBar, c.text.menu.configuration, cimg(c.image.configuration), {
		auto dialog = new ConfigDialog(shell, c);

		int layout = c.conf.layout;
		dialog.appliedReceivers ~= {
			if (layout != c.conf.layout) {
				layout = c.conf.layout;
				mainPanel.relayout();
			}
		};

		dialog.open();
	});


	/* ---- Help menu -------------------------------------------------- */

	basicMenuItem(mHelp, c.text.menu.about, cimg(c.image.about), {
		auto dialog = new AboutDialog(shell, c);
		dialog.open();
	});


	/* ---- Accept files drop ------------------------------------------ */

	auto ft = cast(Transfer)FileTransfer.getInstance();
	addDropFunctions(shell, DND.DROP_COPY, [ft], (DropTargetEvent e) {
		foreach (file; (cast(ArrayWrapperString2)e.data).array) {
			try {
				mainPanel.loadImage(file);
			} catch (Exception e) {
				.erroroutf("Load failure: %s", file);
			}
		}
	});
	tUndo.p_enabled = mainPanel.undoManager.canUndo;
	tRedo.p_enabled = mainPanel.undoManager.canRedo;


	/* ---- Others ----------------------------------------------------- */

	auto cb = new Clipboard(d);

	// Update menus state.
	void refreshMenu() {
		refreshTitle();

		int selCanvas = mainPanel.selectedIndex;
		auto selArea = mainPanel.paintArea.selectedArea;
		bool sel = selArea.width > 0 && selArea.height > 0;
		bool alive = !mainPanel.paintArea.empty;
		bool cbHasImage = false;
		auto tImg = ImageTransfer.getInstance();
		foreach (tData; cb.p_availableTypes) {
			if (tImg.isSupportedType(tData)) {
				cbHasImage = true;
				break;
			}
		}

		tCloseImage.p_enabled = -1 != selCanvas;

		tCut.p_enabled = sel;
		tCopy.p_enabled = sel;
		tPaste.p_enabled = alive && cbHasImage;
		tDelete.p_enabled = sel;
		tSelectAll.p_enabled = alive;

		tUndo.p_enabled = mainPanel.undoManager.canUndo;
		tRedo.p_enabled = mainPanel.undoManager.canRedo;

		mMainGrid.p_selection = mainPanel.paintArea.grid1;
		mSubGrid.p_selection = mainPanel.paintArea.grid2;

		auto selMode = mainPanel.paintArea.rangeSelection;
		tLSel.p_selection = selMode is SelectMode.lasso;
		tSel.p_selection = selMode is SelectMode.rect;
		bool textDrawing = mainPanel.paintArea.textDrawing;
		tTextDrawing.p_selection = textDrawing;
		foreach (mode, item; modeItems) {
			item.p_selection = selMode is SelectMode.notSelection && !textDrawing && mainPanel.paintArea.mode == mode;
		}
		tMask.p_selection = mainPanel.maskMode;
		mBack.p_selection = mainPanel.paintArea.enabledBackColor;
		mPTrans.p_enabled = 0 < mainPanel.imageCount;

		tSaveOverwrite.p_enabled = -1 != selCanvas && (mainPanel.isChanged(selCanvas) || !mainPanel.path(selCanvas).length);
		tSaveWithName.p_enabled = -1 != selCanvas;
		tSaveAll.p_enabled = mainPanel.isChanged(false);
		tResizeC.p_enabled = -1 != selCanvas;

		tUpLayer.p_enabled = mainPanel.canUpLayer;
		tDownLayer.p_enabled = mainPanel.canDownLayer;
		tUniteLayers.p_enabled = mainPanel.canUniteLayers;
		tSelectAllLayers.p_enabled = mainPanel.canSelectAllLayers;

		mCombi.p_enabled = mainPanel.canEditCombination;
	}
	mainPanel.statusChangedReceivers ~= &refreshMenu;
	mainPanel.selectedReceivers ~= &refreshMenu;
	shell.p_listeners!(SWT.Activate) ~= &refreshMenu;

	// Open last opened files.
	string[] lastOpenedFiles = c.conf.lastOpenedFiles;
	foreach (file; lastOpenedFiles.uniq()) {
		try {
			mainPanel.loadImage(file);
		} catch (Exception e) {
			.erroroutf("Load failure: %s", file);
		}
	}

	// Update open history.
	mainPanel.loadedReceivers ~= (string file) {
		file = file.absolutePath().buildNormalizedPath();

		string[] fileHistory = c.conf.fileHistory;
		auto index = fileHistory.countUntil(file);
		if (-1 == index) {
			if (c.conf.fileHistoryMax <= c.conf.fileHistory.length) {
				fileHistory.popBack();
			}
		} else {
			fileHistory = fileHistory.remove(index);
		}
		fileHistory.insertInPlace(0, file);
		c.conf.fileHistory.value = fileHistory;

		refreshFileMenu();
	};

	// Processing of termination.
	shell.p_listeners!(SWT.Close) ~= (Event e) {
		if (!mainPanel.canClosePaintArea) {
			e.doit = false;
			return;
		}
		auto indices = mainPanel.changedImages;
		foreach (i; indices) {
			if (!mainPanel.canCloseImage(i)) {
				e.doit = false;
				return;
			}
		}

		string[] openFiles;
		foreach (i; 0 .. mainPanel.imageCount) {
			auto path = mainPanel.imagePath(i);
			if (path.length) {
				openFiles ~= path.absolutePath().buildNormalizedPath();
			}
		}
		c.conf.lastOpenedFiles.value = openFiles;
	};

	// Update state.
	refreshFileMenu();
	refreshMenu();
	c.conf.mainWindow.value.refWindow(shell);

	return mainPanel;
}

/// Writes combinations in *.dhr files to image files.
void writeCombinations(in string[] dhrFiles, int imageType, string targDir) {
	int imageFormat;
	ubyte depth;
	try {
		imageFormat = .combinationImageTypeToFormat(imageType);
		depth = .combinationImageTypeToDepth(imageType);
	} catch (SWTException e) {
		.erroroutf("Invalid image type: %s", imageType);
		return;
	}
	foreach (file; dhrFiles) {
		MLImage image;
		try {
			image = new MLImage(file);
		} catch (Exception e) {
			.erroroutf("Failed to read file: %s", file);
			continue;
		}
		try {
			image.writeCombination(imageFormat, depth, targDir);
		} catch (Exception e) {
			.erroroutf("Failed to write combinations: %s", file);
			continue;
		}
	}
}
