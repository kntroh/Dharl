
/// This module includes Common and members related to it. 
module dharl.common;

private import util.types;
private import util.properties;

private import std.conv;
private import std.exception;
private import std.path;
private import std.string;
private import std.xml;

/// Common data and methods for the application.
class DCommon {
	/// Module file path of the application.
	private string _moduleFileName;
	/// All messages and texts.
	private DText _text;
	/// All icons and images.
	private DImages _image;
	/// Application configuration.
	private DConfig _conf;

	/// The only constructor.
	this (string moduleFileName) {
		_moduleFileName = moduleFileName;
		_text = new DText;
		_image = new DImages;
		_conf = new DConfig;
	}

	/// Module file path of the application.
	@property
	string moduleFileName() { return _moduleFileName; }
	/// All messages and texts.
	@property
	DText text() { return _text; }
	/// All icons and images.
	@property
	DImages image() { return _image; }
	/// Application configuration.
	@property
	DConfig conf() { return _conf; }
}

/// A image ID and data.
struct DImage {
	/// Image ID.
	string id;
	/// Image data.
	ubyte[] data;
}
/// Creates DImage instance from File.
@property
private DImage importImage(string File)() {
	static if (is(typeof(import(File)))) {
		return DImage(File.stripExtension(), cast(ubyte[]) import(File).dup);
	} else {
		pragma(msg, "Resource not found: " ~ File);
		return DImage(File.stripExtension(), []);
	}
}

/// All images ID and data in the application.
class DImages {
	/// Application icon.
	const DImage dharl = importImage!("dharl.png");
	/// Application logo.
	const DImage dharlLogo = importImage!("dharl_logo.png");

	/// Image file icon.
	const DImage imageFile = importImage!("image_file.png");

	/// Image data for cursors.
	const DImage cursorPen = importImage!("cursor_pen.png");
	const DImage cursorDropper = importImage!("cursor_dropper.png"); /// ditto
	const DImage cursorBucket = importImage!("cursor_bucket.png"); /// ditto
	const DImage cursorCross = importImage!("cursor_cross.png"); /// ditto

	/// Image data for toolbars and menus.
	const DImage up = importImage!("up.png"); /// ditto
	const DImage down = importImage!("down.png"); /// ditto

	const DImage createNewImage = importImage!("create_new_image.png");
	const DImage openImage = importImage!("open_image.png"); /// ditto
	const DImage saveOverwrite = importImage!("save_overwrite.png"); /// ditto
	const DImage saveWithName = importImage!("save_with_name.png"); /// ditto
	const DImage saveAll = importImage!("save_all.png"); /// ditto
	const DImage exit = importImage!("exit.png"); /// ditto

	const DImage undo = importImage!("undo.png"); /// ditto
	const DImage redo = importImage!("redo.png"); /// ditto
	const DImage cut = importImage!("cut.png"); /// ditto
	const DImage copy = importImage!("copy.png"); /// ditto
	const DImage paste = importImage!("paste.png"); /// ditto
	const DImage del = importImage!("del.png"); /// ditto
	const DImage selectAll = importImage!("select_all.png"); /// ditto
	const DImage addLayer = importImage!("add_layer.png"); /// ditto
	const DImage removeLayer = importImage!("remove_layer.png"); /// ditto
	const DImage resizeCanvas = importImage!("resize_canvas.png"); /// ditto

	const DImage createGradation = importImage!("create_gradation.png"); /// ditto
	const DImage enabledBackColor = importImage!("enabled_back_color.png"); /// ditto
	const DImage maskMode = importImage!("mask_mode.png"); /// ditto
	const DImage paletteOperation = importImage!("palette_operation.png"); /// ditto
	const DImage palette = importImage!("palette.png"); /// ditto
	const DImage addPalette = importImage!("add_palette.png"); /// ditto
	const DImage removePalette = importImage!("remove_palette.png"); /// ditto
	const DImage copyPalette = importImage!("copy_palette.png"); /// ditto
	const DImage paletteTransfer = importImage!("palette_transfer.png"); /// ditto

	const DImage selection = importImage!("selection.png"); /// ditto
	const DImage freePath = importImage!("free_path.png"); /// ditto
	const DImage straight = importImage!("straight.png"); /// ditto
	const DImage ovalLine = importImage!("oval_line.png"); /// ditto
	const DImage rectLine = importImage!("rect_line.png"); /// ditto
	const DImage ovalFill = importImage!("oval_fill.png"); /// ditto
	const DImage rectFill = importImage!("rect_fill.png"); /// ditto
	const DImage fillArea = importImage!("fill_area.png"); /// ditto

	const DImage noTone = importImage!("no_tone.png"); /// ditto

	const DImage resize = importImage!("resize.png"); /// ditto
	const DImage mirrorHorizontal = importImage!("mirror_horizontal.png"); /// ditto
	const DImage mirrorVertical = importImage!("mirror_vertical.png"); /// ditto
	const DImage flipHorizontal = importImage!("flip_horizontal.png"); /// ditto
	const DImage flipVertical = importImage!("flip_vertical.png"); /// ditto
	const DImage rotateRight = importImage!("rotate_right.png"); /// ditto
	const DImage rotateLeft = importImage!("rotate_left.png"); /// ditto
	const DImage rotateUp = importImage!("rotate_up.png"); /// ditto
	const DImage rotateDown = importImage!("rotate_down.png"); /// ditto
	const DImage turn90 = importImage!("turn_90.png"); /// ditto
	const DImage turn180 = importImage!("turn_180.png"); /// ditto
	const DImage turn270 = importImage!("turn_270.png"); /// ditto
	const DImage turn = importImage!("turn.png"); /// ditto

	const DImage editCombination = importImage!("edit_combination.png"); /// ditto
	const DImage addCombination = importImage!("add_combination.png"); /// ditto
	const DImage removeCombination = importImage!("remove_combination.png"); /// ditto

	const DImage configuration = importImage!("configuration.png"); /// ditto

	const DImage about = importImage!("about.png"); /// ditto
}

/// All messages and texts in the application.
class DText {
	/// Menu texts.
	mixin Prop!("menu", DMenuText);

	/// Messages.
	mixin MsgProp!("appName", "Dharl");
	mixin MsgProp!("fAppNameWithImage", "%s - %s"); /// ditto
	mixin MsgProp!("fAppNameWithImageChanged", "*%s - %s"); /// ditto

	mixin MsgProp!("fQuestionDialog", "Question - %s"); /// ditto
	mixin MsgProp!("fWarningDialog", "Warning - %s"); /// ditto

	mixin MsgProp!("ok", "&OK"); /// ditto
	mixin MsgProp!("cancel", "&Cancel"); /// ditto
	mixin MsgProp!("yes", "&Yes"); /// ditto
	mixin MsgProp!("no", "&No"); /// ditto
	mixin MsgProp!("apply", "&Apply"); /// ditto

	mixin MsgProp!("selectFile", "..."); /// ditto
	mixin MsgProp!("fAskFilesOverwrite", "%s files already exists,\noverwrite it?"); /// ditto
	mixin MsgProp!("newFilename", "NewImage");

	mixin MsgProp!("noName", "(No name)"); /// ditto
	mixin MsgProp!("fChanged", "*%s"); /// ditto
	mixin MsgProp!("newLayer", "(New layer)"); /// ditto
	mixin MsgProp!("layerName", "Name"); /// ditto
	mixin MsgProp!("layerVisible", "Visible"); /// ditto
	mixin MsgProp!("descLayerVisibility", "Click to toggle the visibility."); /// ditto
	mixin MsgProp!("descLayerTransparentPixel", "Transparent pixel.\nIt switches by Shift+Rightclick on the palette."); /// ditto
	mixin MsgProp!("descLayerName", "Click to edit the layer name."); /// ditto

	mixin MsgProp!("fQuestion", "Question - %s"); /// ditto
	mixin MsgProp!("fWarning", "Warning - %s"); /// ditto

	mixin MsgProp!("paintAreaChanged", "The paint area has been changed.\nAre you sure you want to quit?"); /// ditto
	mixin MsgProp!("fCanvasChanged", "%s has been changed.\nDo you want to save it?"); /// ditto
	mixin MsgProp!("warningDisappearsData", "If you didn't save with *.dhr, data such as layers disappears.\nDo you want to save it?"); /// ditto

	mixin MsgProp!("fLoadImageType", "Image file (%s)"); /// ditto
	mixin MsgProp!("fSaveImageTypeDharl", "Dharl image (*.dhr)"); /// ditto
	mixin MsgProp!("fSaveImageTypeBitmap", "%d-bit (%d colors) bitmap image (*.bmp)"); /// ditto
	mixin MsgProp!("fSaveImageTypePNG", "%d-bit (%d colors) PNG image (*.png)"); /// ditto

	mixin MsgProp!("noTone", "(No tone)"); /// ditto

	mixin MsgProp!("zoom", "Zoom"); /// ditto
	mixin MsgProp!("lineWidth", "Line width"); /// ditto

	mixin MsgProp!("fPaletteOperation", "Palette operation - %s"); /// ditto
	mixin MsgProp!("palettes", "Palettes"); /// ditto
	mixin MsgProp!("palettePreview", "Preview"); /// ditto
	mixin MsgProp!("to", "to"); /// ditto

	mixin MsgProp!("fPaletteTransfer", "Palette transfer - %s"); /// ditto
	mixin MsgProp!("paletteTransferSource", "Transfer source"); /// ditto
	mixin MsgProp!("paletteTransferDestination", "Transfer destination"); /// ditto

	mixin MsgProp!("fResize", "Resize character - %s"); /// ditto
	mixin MsgProp!("fResizeCanvas", "Resize canvas - %s"); /// ditto
	mixin MsgProp!("width", "Width"); /// ditto
	mixin MsgProp!("height", "Height"); /// ditto
	mixin MsgProp!("resizeTo", "Size"); /// ditto
	mixin MsgProp!("resizeWithPixelCount", "Resize with pixel count"); /// ditto
	mixin MsgProp!("resizeWithPercentage", "Resize with percentage"); /// ditto
	mixin MsgProp!("resizeOption", "Option"); /// ditto
	mixin MsgProp!("maintainAspectRatio", "Maintain aspect ratio"); /// ditto
	mixin MsgProp!("scaling", "Perform image scaling"); /// ditto

	mixin MsgProp!("fTurn", "Turn - %s"); /// ditto
	mixin MsgProp!("angle", "Angle of turn"); /// ditto
	mixin MsgProp!("angleDegree", "Angle (degree)"); /// ditto

	mixin MsgProp!("fEditCombinationDialog", "Combination - %s"); /// ditto
	mixin MsgProp!("fConfigDialog", "Configuration - %s"); /// ditto
	mixin MsgProp!("characterSize", "Character size"); /// ditto
	mixin MsgProp!("characterWidth", "Character width"); /// ditto
	mixin MsgProp!("characterHeight", "Character height"); /// ditto

	mixin MsgProp!("fStatusTextXY", "%s, %s"); /// ditto
	mixin MsgProp!("fStatusTextRange", "%s, %s to %s, %s (%s x %s)"); /// ditto

	mixin MsgProp!("combinations", "Combinations"); /// ditto
	mixin MsgProp!("combinationVisibility", "Visibility"); /// ditto
	mixin MsgProp!("combinationOutput", "Output"); /// ditto
	mixin MsgProp!("fPaletteName", "Palette %s"); /// ditto
	mixin MsgProp!("targetFolder", "Target Folder:"); /// ditto
	mixin MsgProp!("saveCombination", "&Save"); /// ditto
	mixin MsgProp!("selectFolderDialogTitle", "Select folder"); /// ditto
	mixin MsgProp!("selectCombinationOutputFolder", "Please select layer combinations output folder."); /// ditto

	mixin MsgProp!("fAbout", "About - %s"); /// ditto
	mixin MsgProp!("aboutMessage1", "Dharl - The Pixelation Editor."); /// ditto
	mixin MsgProp!("aboutMessage2", "The Dharl is an example of DWT application."); /// ditto

	mixin PropIO!("i18n");
}
/// ditto
struct DMenuText {
	/// Menu texts.
	mixin MsgProp!("file", "&File");
	mixin MsgProp!("createNewImage", "Create &new image\tCtrl+N"); /// ditto
	mixin MsgProp!("openImage", "&Open image...\tCtrl+O"); /// ditto
	mixin MsgProp!("saveOverwrite", "&Save overwrite\tCtrl+S"); /// ditto
	mixin MsgProp!("saveWithName", "S&ave with name...\tCtrl+Shift+S"); /// ditto
	mixin MsgProp!("saveAll", "Sa&ve all images"); /// ditto
	mixin MsgProp!("exit", "E&xit\tAlt+F4"); /// ditto

	mixin MsgProp!("view", "&View"); /// ditto
	mixin MsgProp!("mainGrid", "&Main grid"); /// ditto
	mixin MsgProp!("subGrid", "&Sub grid"); /// ditto

	mixin MsgProp!("edit", "&Edit"); /// ditto
	mixin MsgProp!("undo", "&Undo\tCtrl+Z"); /// ditto
	mixin MsgProp!("redo", "&Redo\tCtrl+Y"); /// ditto
	mixin MsgProp!("cut", "Cu&t\tCtrl+X"); /// ditto
	mixin MsgProp!("copy", "&Copy\tCtrl+C"); /// ditto
	mixin MsgProp!("paste", "&Paste\tCtrl+V"); /// ditto
	mixin MsgProp!("del", "&Delete\tDelete"); /// ditto
	mixin MsgProp!("selectAll", "Select&All\tCtrl+A"); /// ditto
	mixin MsgProp!("up", "Up"); /// ditto
	mixin MsgProp!("down", "Down"); /// ditto
	mixin MsgProp!("addLayer", "Add &Layer"); /// ditto
	mixin MsgProp!("removeLayer", "Remove La&yer"); /// ditto

	mixin MsgProp!("mode", "&Mode"); /// ditto
	mixin MsgProp!("enabledBackColor", "Background color is &transparent\tCtrl+P"); /// ditto
	mixin MsgProp!("selection", "&Selection\tCtrl+1"); /// ditto
	mixin MsgProp!("freePath", "&Free path\tCtrl+2"); /// ditto
	mixin MsgProp!("straight", "&Straight\tCtrl+3"); /// ditto
	mixin MsgProp!("ovalLine", "&Oval\tCtrl+4"); /// ditto
	mixin MsgProp!("rectLine", "&Rectangle\tCtrl+5"); /// ditto
	mixin MsgProp!("ovalFill", "O&val (fill)\tCtrl+6"); /// ditto
	mixin MsgProp!("rectFill", "R&ectangle (fill)\tCtrl+7"); /// ditto
	mixin MsgProp!("fillArea", "F&ill area\tCtrl+8"); /// ditto

	mixin MsgProp!("palette", "&Palette"); /// ditto
	mixin MsgProp!("createGradation", "Create &gradation"); /// ditto
	mixin MsgProp!("maskMode", "Edit &mask"); /// ditto
	mixin MsgProp!("paletteOperation", "Pale&tte operation"); /// ditto
	mixin MsgProp!("addPalette", "&Add palette"); /// ditto
	mixin MsgProp!("removePalette", "&Remove palette"); /// ditto
	mixin MsgProp!("copyPalette", "&Copy"); /// ditto
	mixin MsgProp!("paletteTransfer", "Pale&tte transfer"); /// ditto

	mixin MsgProp!("tool", "&Tool"); /// ditto
	mixin MsgProp!("editCombination", "Edit c&ombination..."); /// ditto
	mixin MsgProp!("resize", "&Resize character..."); /// ditto
	mixin MsgProp!("resizeCanvas", "R&esize canvas..."); /// ditto
	mixin MsgProp!("mirrorHorizontal", "&Mirror horizontal"); /// ditto
	mixin MsgProp!("mirrorVertical", "M&irror vertical"); /// ditto
	mixin MsgProp!("flipHorizontal", "&Flip horizontal"); /// ditto
	mixin MsgProp!("flipVertical", "Fli&p vertical"); /// ditto
	mixin MsgProp!("rotateRight", "Rotate &right\tCtrl+Arrow_Right"); /// ditto
	mixin MsgProp!("rotateLeft", "Rotate &left\tCtrl+Arrow_Left"); /// ditto
	mixin MsgProp!("rotateUp", "Rotate &up\tCtrl+Arrow_Up"); /// ditto
	mixin MsgProp!("rotateDown", "Rotate &down\tCtrl+Arrow_Down"); /// ditto
	mixin MsgProp!("turn90", "&90 degree turn"); /// ditto
	mixin MsgProp!("turn180", "&180 degree turn"); /// ditto
	mixin MsgProp!("turn270", "&270 degree turn"); /// ditto
	mixin MsgProp!("turn", "&Turn"); /// ditto

	mixin MsgProp!("addCombination", "Add combination"); /// ditto
	mixin MsgProp!("removeCombination", "Remove combination"); /// ditto

	mixin MsgProp!("configuration", "&Configuration..."); /// ditto

	mixin MsgProp!("help", "&Help"); /// ditto
	mixin MsgProp!("about", "&About"); /// ditto

	mixin PropIO!("menu");
}

/// Application configuration.
class DConfig {
	/// Susie Plug-in directory.
	mixin Prop!("susiePluginDir", string, "plugin");

	/// Character (paint area) size.
	mixin Prop!("character", PSize, PSize(100, 100));
	/// Maximum count of undo operation.
	mixin Prop!("undoMax", uint, 1024);
	/// Tones.
	mixin Prop!("tones", PArray!("tone", Tone), PArray!("tone", Tone)([
		Tone("Tone A", [
			[1, 0],
			[0, 1],
		]),
		Tone("Tone B", [
			[1, 0],
			[0, 0],
		]),
		Tone("Tone C", [
			[1, 0],
			[0, 0],
			[0, 1],
			[0, 0],
		]),
	]));

	/// Parameters of layout.
	mixin Prop!("mainWindow", WindowParameter, WindowParameter(int.min, int.min, 900, 700));

	mixin Prop!("sashPosWork_List",     int, 550); /// ditto
	mixin Prop!("sashPosPaint_Preview", int, 100); /// ditto
	mixin Prop!("sashPosPreview_Tools", int, 150); /// ditto
	mixin Prop!("sashPosPaint_Palette", int, 400); /// ditto

	mixin Prop!("dialogButtonWidth", uint, 80, true); /// ditto

	/// History of files.
	mixin Prop!("fileHistory", PArray!("path", string), PArray!("path", string).init);
	mixin Prop!("fileHistoryMax", uint, 15); /// ditto
	mixin Prop!("fileHistoryOmitLength", uint, 50, true); /// ditto

	mixin Prop!("lastOpenedFiles", PArray!("path", string), PArray!("path", string).init); /// ditto

	/// Selected drawing tool. 0 is range select mode.
	mixin Prop!("tool", uint, 1);
	/// Selected tone. 0 is not used tone.
	mixin Prop!("tone", uint, 0);
	/// Zoom magnification.
	mixin Prop!("zoom", uint, 1);
	/// Line width.
	mixin Prop!("lineWidth", uint, 1);

	/// Palette state.
	mixin Prop!("enabledBackColor", bool, false);
	mixin Prop!("maskMode", bool, false); /// ditto

	/// Palette operation parameters.
	mixin Prop!("paletteOperationDialog", WindowParameter, WindowParameter(int.min, int.min, 500, 350));
	mixin Prop!("paletteTransferDialog", WindowParameter, WindowParameter(int.min, int.min, 500, 400));
	mixin Prop!("sashPosPaletteFrom_PaletteTo", int, -1); /// ditto

	/// Resize relation parameters.
	mixin Prop!("resizePixelCountMax", uint, 9999);
	mixin Prop!("resizePercentMax", uint, 1000); /// ditto
	mixin Prop!("maintainAspectRatio", bool, true); /// ditto
	mixin Prop!("scaling", bool, true); /// ditto
	mixin Prop!("canvasMaintainAspectRatio", bool, true); /// ditto
	mixin Prop!("canvasScaling", bool, false); /// ditto
	mixin Prop!("resizeValueType", uint, 0); /// ditto
	mixin Prop!("canvasResizeValueType", uint, 0); /// ditto

	/// Combination relation parameters.
	mixin Prop!("combinationDialog", WindowParameter, WindowParameter(int.min, int.min, 500, 500));
	mixin Prop!("combinationImageType", int, 0); /// ditto
	mixin Prop!("combinationFolder", string, ""); /// ditto
	mixin Prop!("sashPosPreview_Combinations", int, 200); /// ditto
	mixin Prop!("sashPosCombinations_Layers", int, 300); /// ditto

	mixin PropIO!("config");
}
