
/// Dharl main.
module dharl.dharl;

private import util.commprocess;
private import util.environment;
private import util.graphics;
private import util.utils;

private import dharl.common;

private import dharl.ui.mainpanel;
private import dharl.ui.paintarea;
private import dharl.ui.dialogs;
private import dharl.ui.uicommon;
private import dharl.ui.dwtfactory;
private import dharl.ui.dwtutils;

private import std.algorithm;
private import std.array;
private import std.file;
private import std.path;
private import std.string;

private import org.eclipse.swt.all;

private import java.lang.all : ArrayWrapperString2;

/// Entry point of program.
void main(string[] args) {
	string exe = .moduleFileName(args[0]);
	.consoleoutf("Execute: %s", exe);

	// Pipe name for process communication.
	static immutable PIPE_NAME = "dharl";
	// Commands of process communication.
	static immutable MSG_EXECUTE      = "execute";
	static immutable MSG_GET_ARGUMENT = "get argument";
	static immutable MSG_ARGUMENT     = "argument "; // appends filepath after space
	static immutable MSG_QUIT         = "quit";

	// Files in startup arguments.
	auto argFiles = new string[args.length - 1];
	foreach (i, arg; args[1 .. $]) {
		argFiles[i] = arg.absolutePath().buildNormalizedPath();
	}

	// Sends message to existing process (if exist it).
	size_t sentArg = 0;
	bool send = sendToPipe(PIPE_NAME, (in char[] reply) {
		if (reply is null) {
			return MSG_EXECUTE;
		} else if (MSG_GET_ARGUMENT == reply) {
			if (sentArg < args.length) {
				auto msg = MSG_ARGUMENT ~ argFiles[sentArg];
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

	// Load application configuration.
	string appData = .appData(exe.dirName(), true).buildPath("dharl").buildPath("settings.xml");
	.consoleoutf("AppData: %s", appData);
	auto c = new DCommon;
	if (appData.exists()) {
		try {
			c.conf.readXMLFile(appData);
		} catch (Exception e) {
			.erroroutf("Read failure: %s", appData);
		}
	}

	// Creates window and controls.
	auto shell = basicShell(c.text.appName, null, GL.window);
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

	// Open window.
	shell.open();
	while (!shell.p_disposed) {
		if (!display.readAndDispatch()) {
			display.sleep();
		}
	}
	display.dispose();
	sendToPipe(PIPE_NAME, MSG_QUIT);

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

	// The toolbar.
	auto toolBar = basicToolBar(shell, SWT.FLAT | SWT.HORIZONTAL | SWT.WRAP);
	toolBar.p_layoutData = GD(GridData.FILL_HORIZONTAL);

	// The main panel.
	auto mainPanel = new MainPanel(shell, SWT.NONE);
	mainPanel.p_layoutData = GD(GridData.FILL_BOTH);
	mainPanel.init(c);

	// Menus.
	auto mFile = basicDropDownMenu(shell, c.text.menu.file);
	int mFileHistFrom, mFileHistTo;
	auto mEdit = basicDropDownMenu(shell, c.text.menu.edit);
	auto mMode = basicDropDownMenu(shell, c.text.menu.mode);
	auto mPalette = basicDropDownMenu(shell, c.text.menu.palette);
	auto mTool = basicDropDownMenu(shell, c.text.menu.tool);

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
		foreach_reverse (i; mFileHistFrom .. mFileHistTo) {
			mFile.getItem(i).dispose();
		}

		if (c.conf.fileHistory.length) {
			void createItem(int index, string file) {
				basicMenuItem(mFile, file.omitPath(c.conf.fileHistoryOmitLength), null, {
					mainPanel.loadImage(file);
				}, SWT.PUSH, false, mFileHistFrom + index);
			}
			foreach (i, file; c.conf.fileHistory) {
				createItem(i, file);
			}
			separator(mFile, mFileHistFrom + c.conf.fileHistory.length);
			mFileHistTo = mFileHistFrom + c.conf.fileHistory.length + 1;
		} else {
			mFileHistTo = mFileHistFrom;
		}
	}

	/* ---- File menu -------------------------------------------------- */

	basicMenuItem(mFile, toolBar, c.text.menu.createNewImage, cimg(c.image.createNewImage), {
		mainPanel.createNewImage(100, 100, true);
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
	separator(mFile);
	mFileHistFrom = mFile.getItemCount();
	mFileHistTo   = mFileHistFrom;
	auto exit = basicMenuItem(mFile, c.text.menu.exit, cimg(c.image.exit), &shell.close);

	MenuItem[PaintMode] modeItems;
	MenuItem tSel;


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

	separator(toolBar);
	auto resizeCW = basicSpinner(toolBar, 1, 9999);
	resizeCW.p_selection = 16;
	auto tResizeCW = basicToolItem(toolBar, resizeCW);
	auto resizeCH = basicSpinner(toolBar, 1, 9999);
	resizeCH.p_selection = 16;
	auto tResizeCH = basicToolItem(toolBar, resizeCH);
	auto tResizeC = basicToolItem(toolBar, c.text.menu.resizeCanvas, cimg(c.image.resizeCanvas), {
		int w = resizeCW.p_selection;
		int h = resizeCH.p_selection;
		mainPanel.resizeCanvas(w, h, true);
	});


	/* ---- Mode menu -------------------------------------------------- */

	MenuItem mBack;
	mBack = basicMenuItem(mMode, c.text.menu.enabledBackColor, cimg(c.image.enabledBackColor), {
		mainPanel.paintArea.enabledBackColor = mBack.p_selection;
	}, SWT.CHECK);
	separator(mMode);
	tSel = basicMenuItem(mMode, c.text.menu.selection, cimg(c.image.selection), {
		mainPanel.paintArea.rangeSelection = tSel.p_selection;
	}, SWT.RADIO, mainPanel.paintArea.rangeSelection);
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


	/* ---- Paletete menu ---------------------------------------------- */

	auto tGrad = basicMenuItem(mPalette, c.text.menu.createGradation, cimg(c.image.createGradation), {
		mainPanel.createGradation();
	});
	separator(mPalette);
	MenuItem tMask;
	tMask = basicMenuItem(mPalette, c.text.menu.maskMode, cimg(c.image.maskMode), {
		mainPanel.maskMode = tMask.p_selection;
	}, SWT.CHECK);

	separator(toolBar);
	basicMenuItem(mTool, toolBar, c.text.menu.mirrorHorizontal, cimg(c.image.mirrorHorizontal), {
		mainPanel.paintArea.mirrorHorizontal();
	});
	basicMenuItem(mTool, toolBar, c.text.menu.mirrorVertical, cimg(c.image.mirrorVertical), {
		mainPanel.paintArea.mirrorVertical();
	});
	basicMenuItem(mTool, toolBar, c.text.menu.flipHorizontal, cimg(c.image.flipHorizontal), {
		mainPanel.paintArea.flipHorizontal();
	});
	basicMenuItem(mTool, toolBar, c.text.menu.flipVertical, cimg(c.image.flipVertical), {
		mainPanel.paintArea.flipVertical();
	});
	basicMenuItem(mTool, toolBar, c.text.menu.rotateRight, cimg(c.image.rotateRight), {
		mainPanel.paintArea.rotateRight();
	});
	basicMenuItem(mTool, toolBar, c.text.menu.rotateLeft, cimg(c.image.rotateLeft), {
		mainPanel.paintArea.rotateLeft();
	});
	basicMenuItem(mTool, toolBar, c.text.menu.rotateUp, cimg(c.image.rotateUp), {
		mainPanel.paintArea.rotateUp();
	});
	basicMenuItem(mTool, toolBar, c.text.menu.rotateDown, cimg(c.image.rotateDown), {
		mainPanel.paintArea.rotateDown();
	});
	separator(mTool);


	/* ---- Tool menu -------------------------------------------------- */

	auto mConf = basicMenuItem(mTool, c.text.menu.configuration, cimg(c.image.configuration), {
		auto dlg = new ConfigDialog(shell, c);
		dlg.appliedReceivers ~= {
			// Character (paint area) size.
			// Default character size doesn't undo even if user undo.
			auto s = c.conf.character;
			mainPanel.paintArea.resize(s.width, s.height);
		};
		dlg.open();
	});

	separator(toolBar);
	auto turnDeg = basicSpinner(toolBar, 0, 360);
	turnDeg.p_selection = 90;
	basicToolItem(toolBar, turnDeg);
	basicToolItem(toolBar, c.text.menu.turn, cimg(c.image.turn), {
		int deg = turnDeg.p_selection;
		mainPanel.paintArea.turn(deg);
	});

	separator(toolBar);
	auto resizeW = basicSpinner(toolBar, 1, 9999);
	resizeW.p_selection = 50;
	auto tResizeW = basicToolItem(toolBar, resizeW);
	auto resizeH = basicSpinner(toolBar, 1, 9999);
	resizeH.p_selection = 50;
	auto tResizeH = basicToolItem(toolBar, resizeH);
	auto tResize = basicToolItem(toolBar, c.text.menu.resize, cimg(c.image.resize), {
		int w = resizeW.p_selection;
		int h = resizeH.p_selection;
		mainPanel.paintArea.scaledTo(w, h);
	});


	/* ---- Accept files drop ------------------------------------------ */

	auto ft = cast(Transfer) FileTransfer.getInstance();
	addDropFunctions(shell, DND.DROP_COPY, [ft], (DropTargetEvent e) {
		foreach (file; (cast(ArrayWrapperString2) e.data).array) {
			mainPanel.loadImage(file);
		}
	});
	tUndo.p_enabled = mainPanel.undoManager.canUndo;
	tRedo.p_enabled = mainPanel.undoManager.canRedo;


	/* ---- Others ----------------------------------------------------- */

	// Update menus state.
	void refreshMenu() {
		refreshTitle();

		auto selArea = mainPanel.paintArea.selectedArea;
		bool sel = selArea.width > 0 && selArea.height > 0;
		bool alive = !mainPanel.paintArea.empty;
		tCut.p_enabled = sel;
		tCopy.p_enabled = sel;
		tPaste.p_enabled = alive;
		tDelete.p_enabled = sel;
		tSelectAll.p_enabled = alive;

		tUndo.p_enabled = mainPanel.undoManager.canUndo;
		tRedo.p_enabled = mainPanel.undoManager.canRedo;

		bool range = mainPanel.paintArea.rangeSelection;
		tSel.p_selection = range;
		foreach (mode, item; modeItems) {
			item.p_selection = !range && mainPanel.paintArea.mode == mode;
		}
		tMask.p_selection = mainPanel.maskMode;
		mBack.p_selection = mainPanel.paintArea.enabledBackColor;

		int index = mainPanel.selectedIndex;
		tSaveOverwrite.p_enabled = -1 != index && mainPanel.isChanged(index);
		tSaveWithName.p_enabled = -1 != index;
		tSaveAll.p_enabled = mainPanel.isChanged(false);
		resizeCW.p_enabled = -1 != index;
		resizeCH.p_enabled = -1 != index;
		tResizeC.p_enabled = -1 != index;
	}
	mainPanel.statusChangedReceivers ~= &refreshMenu;

	// Open last opened files.
	foreach (file; c.conf.lastOpenedFiles) {
		try {
			mainPanel.loadImage(file);
		} catch (Exception e) {
			.erroroutf("Load failure: %s", file);
		}
	}

	// Update open history.
	mainPanel.loadedReceivers ~= (string file) {
		file = file.absolutePath().buildNormalizedPath();

		auto index = c.conf.fileHistory.countUntil(file);
		if (-1 == index) {
			if (c.conf.fileHistoryMax <= c.conf.fileHistory.length) {
				c.conf.fileHistory.popBack();
			}
		} else {
			c.conf.fileHistory = c.conf.fileHistory.remove(index);
		}
		c.conf.fileHistory.insertInPlace(0, file);

		refreshFileMenu();
	};

	// Processing of termination.
	shell.listeners!(SWT.Close) ~= (Event e) {
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
		c.conf.lastOpenedFiles = openFiles;
	};

	// Update state.
	refreshFileMenu();
	refreshMenu();
	shell.refWindow(c.conf.mainWindow.value);

	return mainPanel;
}
