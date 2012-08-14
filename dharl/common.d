
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
	/// All messages and texts.
	private DText _text;
	/// All icons and images.
	private DImages _image;
	/// Application configuration.
	private DConfig _conf;

	/// The only constructor.
	this () {
		_text = new DText;
		_image = new DImages;
		_conf = new DConfig;
	}

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
	return DImage(File.stripExtension(), cast(ubyte[]) import(File).dup);
}

/// All images ID and data in the application.
class DImages {
	/// Image data for cursors.
	const DImage cursorPen = importImage!("cursor_pen.png");
	const DImage cursorDropper = importImage!("cursor_dropper.png"); /// ditto
	const DImage cursorBucket = importImage!("cursor_bucket.png"); /// ditto

	/// Image data for toolbars and menus.
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
	const DImage turn = importImage!("turn.png"); /// ditto

	const DImage configuration = importImage!("configuration.png"); /// ditto
}

/// All messages and texts in the application.
class DText {
	/// Menu texts.
	mixin Prop!("menu", DMenuText);

	/// Messages.
	mixin MsgProp!("appName", "Dharl");
	mixin MsgProp!("fAppNameWithImage", "%s - %s"); /// ditto
	mixin MsgProp!("fAppNameWithImageChanged", "*%s - %s"); /// ditto

	mixin MsgProp!("ok", "&OK"); /// ditto
	mixin MsgProp!("cancel", "&Cancel"); /// ditto
	mixin MsgProp!("yes", "&Yes"); /// ditto
	mixin MsgProp!("no", "&No"); /// ditto
	mixin MsgProp!("apply", "&Apply"); /// ditto

	mixin MsgProp!("noName", "(No name)"); /// ditto
	mixin MsgProp!("fChanged", "*%s"); /// ditto
	mixin MsgProp!("newLayer", "(New layer)"); /// ditto
	mixin MsgProp!("layerName", "Name"); /// ditto
	mixin MsgProp!("layerVisible", "Visible"); /// ditto

	mixin MsgProp!("question", "Question"); /// ditto
	mixin MsgProp!("paintAreaChanged", "The paint area has been changed.\nAre you sure you want to quit?"); /// ditto
	mixin MsgProp!("fCanvasChanged", "%s has been changed.\nDo you want to save it?"); /// ditto

	mixin MsgProp!("fLoadImageType", "Image file (%s)"); /// ditto
	mixin MsgProp!("fSaveImageTypeBitmap", "%d-bit (%d colors) bitmap image (*.bmp)"); /// ditto
	mixin MsgProp!("fSaveImageTypePNG", "%d-bit (%d colors) PNG image (*.png)"); /// ditto

	mixin MsgProp!("noTone", "(No tone)"); /// ditto

	mixin MsgProp!("zoom", "Zoom"); /// ditto
	mixin MsgProp!("lineWidth", "Line width"); /// ditto

	mixin MsgProp!("fConfigDialog", "Configuration - %s"); /// ditto
	mixin MsgProp!("characterSize", "Character size"); /// ditto
	mixin MsgProp!("characterWidth", "Character width"); /// ditto
	mixin MsgProp!("characterHeight", "Character height"); /// ditto

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
	mixin MsgProp!("addLayer", "Add &Layer"); /// ditto
	mixin MsgProp!("removeLayer", "Remove La&yer"); /// ditto
	mixin MsgProp!("resizeCanvas", "R&esize Canvas"); /// ditto

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

	mixin MsgProp!("tool", "&Tool"); /// ditto
	mixin MsgProp!("resize", "&Resize..."); /// ditto
	mixin MsgProp!("mirrorHorizontal", "&Mirror horizontal"); /// ditto
	mixin MsgProp!("mirrorVertical", "M&irror vertical"); /// ditto
	mixin MsgProp!("flipHorizontal", "&Flip horizontal"); /// ditto
	mixin MsgProp!("flipVertical", "Fli&p vertical"); /// ditto
	mixin MsgProp!("rotateRight", "Rotate &right\tCtrl+Arrow_Right"); /// ditto
	mixin MsgProp!("rotateLeft", "Rotate &left\tCtrl+Arrow_Left"); /// ditto
	mixin MsgProp!("rotateUp", "Rotate &up\tCtrl+Arrow_Up"); /// ditto
	mixin MsgProp!("rotateDown", "Rotate &down\tCtrl+Arrow_Down"); /// ditto
	mixin MsgProp!("turn", "&Turn"); /// ditto

	mixin MsgProp!("configuration", "&Configuration..."); /// ditto

	mixin MsgProp!("help", "&Help"); /// ditto
	mixin MsgProp!("ver", "&Version"); /// ditto

	mixin PropIO!("menu");
}

/// Application configuration.
class DConfig {
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
	mixin Prop!("mainWindow", WindowParameter, WindowParameter(100, 700, 900, 700));

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

	/// Resizing values.
	mixin Prop!("scaled", PSize, PSize(16, 16));
	mixin Prop!("turnDegree", int, 90); /// ditto
	mixin Prop!("resizeCanvas", PSize, PSize(100, 100)); /// ditto

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

	mixin PropIO!("config");
}
