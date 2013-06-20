
/// This module includes Common and members related to it. 
///
/// License: Public Domain
/// Authors: kntroh
module dharl.common;

private import util.types;
private import util.properties;

private import std.conv;
private import std.exception;
private import std.path;
private import std.string;
private import std.xml;

/// Version of the application.
immutable VERSION = import("@version.txt").chomp();

/// Supported image formats of Dharl.
immutable SUPPORTED_FORMATS = "*.dhr;*.bmp;*.png;*.jpg;*.jpeg;*.tif;*.tiff;*.dpx;*.edg".split(";");

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
	/// ditto
	@property
	const
	const(DText) text() { return _text; }
	/// All icons and images.
	@property
	const
	const(DImages) image() { return _image; }
	/// Application configuration.
	@property
	DConfig conf() { return _conf; }
	/// ditto
	@property
	const
	const(DConfig) conf() { return _conf; }
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
		return DImage(File.stripExtension(), cast(ubyte[])import(File).dup);
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
	const DImage closeImage = importImage!("close_image.png"); /// ditto
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
	const DImage uniteLayers = importImage!("unite_layers.png"); /// ditto
	const DImage resizeCanvas = importImage!("resize_canvas.png"); /// ditto

	const DImage mainGrid = importImage!("main_grid.png"); /// ditto
	const DImage subGrid = importImage!("sub_grid.png"); /// ditto

	const DImage createGradation = importImage!("create_gradation.png"); /// ditto
	const DImage enabledBackColor = importImage!("enabled_back_color.png"); /// ditto
	const DImage maskMode = importImage!("mask_mode.png"); /// ditto
	const DImage paletteOperation = importImage!("palette_operation.png"); /// ditto
	const DImage palette = importImage!("palette.png"); /// ditto
	const DImage addPalette = importImage!("add_palette.png"); /// ditto
	const DImage removePalette = importImage!("remove_palette.png"); /// ditto
	const DImage copyPalette = importImage!("copy_palette.png"); /// ditto
	const DImage paletteTransfer = importImage!("palette_transfer.png"); /// ditto

	const DImage freeSelection = importImage!("free_selection.png"); /// ditto
	const DImage selection = importImage!("selection.png"); /// ditto
	const DImage freePath = importImage!("free_path.png"); /// ditto
	const DImage straight = importImage!("straight.png"); /// ditto
	const DImage ovalLine = importImage!("oval_line.png"); /// ditto
	const DImage rectLine = importImage!("rect_line.png"); /// ditto
	const DImage ovalFill = importImage!("oval_fill.png"); /// ditto
	const DImage rectFill = importImage!("rect_fill.png"); /// ditto
	const DImage fillArea = importImage!("fill_area.png"); /// ditto
	const DImage textDrawing = importImage!("text_drawing.png"); /// ditto

	const DImage bold = importImage!("bold.png"); /// ditto
	const DImage italic = importImage!("italic.png"); /// ditto

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
	const DImage increaseBrightness = importImage!("increase_brightness.png"); /// ditto
	const DImage decreaseBrightness = importImage!("decrease_brightness.png"); /// ditto

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

	mixin MsgProp!("usage", r"Dharl - The Pixel Art Editor
Version.%s
Usage:
  dharl files ... { -options }

  files                   Image files (%s)
  -h --help               Print help and quit program
  -w --write-combinations Write combinations from files (*.dhr) to image files
  -t --image-type         Specified along with -w, specify the image format:
%s
  -d --target-directory   Specified along with -w, specify the output folder"); /// ditto
	mixin MsgProp!("fImageTypeInUsage", "                            %s: %s"); /// ditto

	mixin MsgProp!("fAppNameWithImage", "%s - %s"); /// ditto
	mixin MsgProp!("fAppNameWithImageChanged", "*%s - %s"); /// ditto

	mixin MsgProp!("fQuestionDialog", "Question - %s"); /// ditto
	mixin MsgProp!("fWarningDialog", "Warning - %s"); /// ditto
	mixin MsgProp!("fErrorDialog", "Error - %s"); /// ditto

	mixin MsgProp!("ok", "&OK"); /// ditto
	mixin MsgProp!("cancel", "&Cancel"); /// ditto
	mixin MsgProp!("yes", "&Yes"); /// ditto
	mixin MsgProp!("no", "&No"); /// ditto
	mixin MsgProp!("apply", "&Apply"); /// ditto

	mixin MsgProp!("selectFile", "..."); /// ditto
	mixin MsgProp!("fAskFilesOverwrite", "%s files already exists,\noverwrite it?"); /// ditto
	mixin MsgProp!("newFilename", "NewImage");

	mixin MsgProp!("noName", "(No Name)"); /// ditto
	mixin MsgProp!("fChanged", "*%s"); /// ditto
	mixin MsgProp!("newLayer", "(New Layer)"); /// ditto
	mixin MsgProp!("layerName", "Name"); /// ditto
	mixin MsgProp!("layerVisible", "Visible"); /// ditto
	mixin MsgProp!("descLayerVisibility", "Click to toggle the visibility."); /// ditto
	mixin MsgProp!("descLayerTransparentPixel", "Transparent pixel.\nIt switches by Shift+Rightclick on the palette."); /// ditto
	mixin MsgProp!("descLayerName", "Click to edit the layer name."); /// ditto

	mixin MsgProp!("noUpdated", "No Updated"); /// ditto
	mixin MsgProp!("updated", "Updated"); /// ditto
	mixin MsgProp!("paintAreaChanged", "The paint area has been changed.\nAre you sure you want to quit?"); /// ditto
	mixin MsgProp!("fCanvasChanged", "%s has been changed.\nDo you want to save it?"); /// ditto
	mixin MsgProp!("warningDisappearsData", "If you didn't save with *.dhr, data such as layers disappears.\nDo you want to save it?"); /// ditto

	mixin MsgProp!("fLoadImageType", "Image File (%s)"); /// ditto
	mixin MsgProp!("fSaveImageTypeDharl", "Dharl Image (*.dhr)"); /// ditto
	mixin MsgProp!("fSaveImageTypeBitmap", "%d-bit (%d colors) Bitmap Image (*.bmp)"); /// ditto
	mixin MsgProp!("fSaveImageTypePNG", "%d-bit (%d colors) PNG Image (*.png)"); /// ditto

	mixin MsgProp!("textDrawing", "Text Drawing"); /// ditto

	mixin MsgProp!("noTone", "(No Tone)"); /// ditto

	mixin MsgProp!("zoom", "Zoom"); /// ditto
	mixin MsgProp!("lineWidth", "Line Width"); /// ditto

	mixin MsgProp!("fPaletteOperation", "Palette Operation - %s"); /// ditto
	mixin MsgProp!("palettes", "Palettes"); /// ditto
	mixin MsgProp!("palettePreview", "Preview"); /// ditto
	mixin MsgProp!("to", "to"); /// ditto

	mixin MsgProp!("fPaletteTransfer", "Palette Transfer - %s"); /// ditto
	mixin MsgProp!("paletteTransferSource", "Transfer Source"); /// ditto
	mixin MsgProp!("paletteTransferDestination", "Transfer Destination"); /// ditto

	mixin MsgProp!("fResize", "Resize Character - %s"); /// ditto
	mixin MsgProp!("fResizeCanvas", "Resize Canvas - %s"); /// ditto
	mixin MsgProp!("width", "Width"); /// ditto
	mixin MsgProp!("height", "Height"); /// ditto
	mixin MsgProp!("resizeTo", "Size"); /// ditto
	mixin MsgProp!("resizeWithPixelCount", "Resize with pixel count"); /// ditto
	mixin MsgProp!("resizeWithPercentage", "Resize with percentage"); /// ditto
	mixin MsgProp!("resizeOption", "Option"); /// ditto
	mixin MsgProp!("maintainAspectRatio", "Maintain aspect ratio"); /// ditto
	mixin MsgProp!("scaling", "Perform image scaling"); /// ditto

	mixin MsgProp!("fTurn", "Turn - %s"); /// ditto
	mixin MsgProp!("angle", "Angle of Turn"); /// ditto
	mixin MsgProp!("angleDegree", "Angle (degree)"); /// ditto

	mixin MsgProp!("fEditCombinationDialog", "Combination - %s"); /// ditto
	mixin MsgProp!("fConfigDialog", "Configuration - %s"); /// ditto
	mixin MsgProp!("characterSize", "Character Size"); /// ditto
	mixin MsgProp!("characterWidth", "Character Width"); /// ditto
	mixin MsgProp!("characterHeight", "Character Height"); /// ditto
	mixin MsgProp!("layout", "Layout"); /// ditto
	mixin MsgProp!("fLayoutName", "Layout %s"); /// ditto

	mixin MsgProp!("fStatusTextXY", "%s, %s"); /// ditto
	mixin MsgProp!("fStatusTextRange", "%s, %s to %s, %s (%s x %s)"); /// ditto

	mixin MsgProp!("combinations", "Combinations"); /// ditto
	mixin MsgProp!("combinationVisibility", "Visibility"); /// ditto
	mixin MsgProp!("combinationOutput", "Output"); /// ditto
	mixin MsgProp!("fPaletteName", "Palette %s"); /// ditto
	mixin MsgProp!("targetFolder", "Target Folder:"); /// ditto
	mixin MsgProp!("saveCombination", "&Save"); /// ditto
	mixin MsgProp!("selectFolderDialogTitle", "Select Folder"); /// ditto
	mixin MsgProp!("selectCombinationOutputFolder", "Please select layer combinations output folder."); /// ditto

	mixin MsgProp!("fAbout", "About - %s"); /// ditto
	mixin MsgProp!("aboutMessage", "Dharl - The Pixel Art Editor\nVersion.%s\nThe Dharl is a free software."); /// ditto

	mixin PropIO!("i18n");
}
/// ditto
struct DMenuText {
	/// Menu texts.
	mixin MsgProp!("file", "&File");
	mixin MsgProp!("createNewImage", "&New Image\tCtrl+N"); /// ditto
	mixin MsgProp!("openImage", "&Open Image...\tCtrl+O"); /// ditto
	mixin MsgProp!("saveOverwrite", "&Save Overwrite\tCtrl+S"); /// ditto
	mixin MsgProp!("saveWithName", "Save &As...\tCtrl+Shift+S"); /// ditto
	mixin MsgProp!("saveAll", "Sa&ve All Images"); /// ditto
	mixin MsgProp!("closeImage", "&Close Image"); /// ditto
	mixin MsgProp!("exit", "E&xit\tAlt+F4"); /// ditto

	mixin MsgProp!("view", "&View"); /// ditto
	mixin MsgProp!("mainGrid", "&Main Grid"); /// ditto
	mixin MsgProp!("subGrid", "&Sub Grid"); /// ditto

	mixin MsgProp!("edit", "&Edit"); /// ditto
	mixin MsgProp!("undo", "&Undo\tCtrl+Z"); /// ditto
	mixin MsgProp!("redo", "&Redo\tCtrl+Y"); /// ditto
	mixin MsgProp!("cut", "Cu&t\tCtrl+X"); /// ditto
	mixin MsgProp!("copy", "&Copy\tCtrl+C"); /// ditto
	mixin MsgProp!("paste", "&Paste\tCtrl+V"); /// ditto
	mixin MsgProp!("del", "Delete\tDelete"); /// ditto
	mixin MsgProp!("selectAll", "Select &All\tCtrl+A"); /// ditto
	mixin MsgProp!("up", "&Up"); /// ditto
	mixin MsgProp!("down", "&Down"); /// ditto
	mixin MsgProp!("addLayer", "Add &Layer"); /// ditto
	mixin MsgProp!("removeLayer", "Remove La&yer"); /// ditto
	mixin MsgProp!("uniteLayers", "&Unite Layers"); /// ditto

	mixin MsgProp!("mode", "&Mode"); /// ditto
	mixin MsgProp!("enabledBackColor", "Background Color is &Transparent\tCtrl+P"); /// ditto
	mixin MsgProp!("freeSelection", "&Free Selection\tCtrl+0"); /// ditto
	mixin MsgProp!("selection", "&Selection\tCtrl+1"); /// ditto
	mixin MsgProp!("freePath", "Free &Path\tCtrl+2"); /// ditto
	mixin MsgProp!("straight", "&Straight\tCtrl+3"); /// ditto
	mixin MsgProp!("ovalLine", "&Oval\tCtrl+4"); /// ditto
	mixin MsgProp!("rectLine", "&Rectangle\tCtrl+5"); /// ditto
	mixin MsgProp!("ovalFill", "O&val (Fill)\tCtrl+6"); /// ditto
	mixin MsgProp!("rectFill", "R&ectangle (Fill)\tCtrl+7"); /// ditto
	mixin MsgProp!("fillArea", "F&ill Area\tCtrl+8"); /// ditto
	mixin MsgProp!("textDrawing", "&Text Drawing\tCtrl+9"); /// ditto

	mixin MsgProp!("bold", "&Bold"); /// ditto
	mixin MsgProp!("italic", "&Italic"); /// ditto

	mixin MsgProp!("palette", "&Palette"); /// ditto
	mixin MsgProp!("createGradation", "Create &Gradation"); /// ditto
	mixin MsgProp!("maskMode", "Edit &Mask"); /// ditto
	mixin MsgProp!("paletteOperation", "Pale&tte Operation..."); /// ditto
	mixin MsgProp!("addPalette", "&Add Palette"); /// ditto
	mixin MsgProp!("removePalette", "&Remove Palette"); /// ditto
	mixin MsgProp!("copyPalette", "&Copy"); /// ditto
	mixin MsgProp!("paletteTransfer", "Palette &Transfer..."); /// ditto

	mixin MsgProp!("tool", "&Tool"); /// ditto
	mixin MsgProp!("editCombination", "Edit C&ombination..."); /// ditto
	mixin MsgProp!("resize", "&Resize Character..."); /// ditto
	mixin MsgProp!("resizeCanvas", "R&esize Canvas..."); /// ditto
	mixin MsgProp!("mirrorHorizontal", "&Mirror Horizontal"); /// ditto
	mixin MsgProp!("mirrorVertical", "M&irror Vertical"); /// ditto
	mixin MsgProp!("flipHorizontal", "&Flip Horizontal\tCtrl+R"); /// ditto
	mixin MsgProp!("flipVertical", "Fli&p Vertical"); /// ditto
	mixin MsgProp!("rotateRight", "Rotate &Right\tCtrl+Arrow_Right"); /// ditto
	mixin MsgProp!("rotateLeft", "Rotate &Left\tCtrl+Arrow_Left"); /// ditto
	mixin MsgProp!("rotateUp", "Rotate &Up\tCtrl+Arrow_Up"); /// ditto
	mixin MsgProp!("rotateDown", "Rotate &Down\tCtrl+Arrow_Down"); /// ditto
	mixin MsgProp!("turn90", "&90 degree Turn"); /// ditto
	mixin MsgProp!("turn180", "&180 degree Turn"); /// ditto
	mixin MsgProp!("turn270", "&270 degree Turn"); /// ditto
	mixin MsgProp!("turn", "&Turn..."); /// ditto
	mixin MsgProp!("increaseBrightness", "Increase &Brightness"); /// ditto
	mixin MsgProp!("decreaseBrightness", "Decrease B&rightness"); /// ditto

	mixin MsgProp!("addCombination", "Add Combination"); /// ditto
	mixin MsgProp!("removeCombination", "Remove Combination"); /// ditto

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
	mixin Prop!("dialogButtonWidth", uint, 80, true); /// ditto
	mixin Prop!("sashPosPaint_Preview", int, 100); /// ditto
	mixin Prop!("sashPosPreview_Tools", int, 150); /// ditto

	mixin Prop!("layout", int, 0); /// Layout number. 0 or 1 available now.

	/// Parameters of layout = 0.
	mixin Prop!("layout0_sashPosWork_List",     int, 550);
	mixin Prop!("layout0_sashPosPaint_Palette", int, 400); /// ditto

	/// Parameters of layout = 1.
	mixin Prop!("layout1_sashPosPaint_Other", int, 550);
	mixin Prop!("layout1_sashPosLayer_List",  int, 100); /// ditto

	/// History of files.
	mixin Prop!("fileHistory", PArray!("path", string), PArray!("path", string).init);
	mixin Prop!("fileHistoryMax", uint, 15); /// ditto
	mixin Prop!("fileHistoryOmitLength", uint, 50, true); /// ditto

	mixin Prop!("lastOpenedFiles", PArray!("path", string), PArray!("path", string).init); /// ditto

	/// Grids.
	mixin Prop!("mainGrid", bool, false);
	mixin Prop!("subGrid", bool, false);

	/// Selected drawing tool. 0 is range select mode.
	mixin Prop!("tool", uint, 1);
	/// Selected tone. 0 is not used tone.
	mixin Prop!("tone", uint, 0);
	/// Zoom magnification.
	mixin Prop!("zoom", uint, 1);
	/// Line width.
	mixin Prop!("lineWidth", uint, 1);

	/// Values of tool window for text drawing.
	mixin Prop!("textDrawingTools", WindowParameter, WindowParameter(int.min, int.min, 200, 50));
	mixin Prop!("fontName", string, "Arial"); /// ditto
	mixin Prop!("fontPoint", uint, 12); /// ditto
	mixin Prop!("bold", bool, false); /// ditto
	mixin Prop!("italic", bool, false); /// ditto

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
