
/// This module includes Common and members related to it. 
module dharl.common;

private import dharl.util.types;
private import dharl.util.properties;

private import std.conv;
private import std.exception;
private import std.path;
private import std.string;
private import std.xml;

/// Common data and method for the application. TODO comment
class DCommon {
	/// All message and text. TODO comment
	private DText _text;
	/// All icon and image. TODO comment
	private DImages _image;
	/// Application config. TODO comment
	private DConfig _conf;

	/// The only constructor. TODO comment
	this () {
		_text = new DText;
		_image = new DImages;
		_conf = new DConfig;
	}

	/// All message and text. TODO comment
	@property
	DText text() { return _text; }
	/// All icon and image. TODO comment
	@property
	DImages image() { return _image; }
	/// Application config. TODO comment
	@property
	DConfig conf() { return _conf; }
}

/// Image ID and data. TODO comment
struct DImage {
	/// Image ID. TODO comment
	string id;
	/// Image data. TODO comment
	ubyte[] data;
}
/// Creates DImage instance from File. TODO comment
@property
private DImage importImage(string File)() {
	return DImage(File.stripExtension(), cast(ubyte[]) import(File).dup);
}

/// All image ID and data in the appilication. TODO comment
class DImages {
	/// Image data for cursors.
	const DImage cursorPen = importImage!("cursor_pen.png");

	/// Image data for tool bar and menu. TODO comment
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
	const DImage rotateRight = importImage!("rotate_right.png"); /// ditto
	const DImage rotateLeft = importImage!("rotate_left.png"); /// ditto
	const DImage rotateUp = importImage!("rotate_up.png"); /// ditto
	const DImage rotateDown = importImage!("rotate_down.png"); /// ditto

	const DImage configuration = importImage!("configuration.png"); /// ditto
}

/// All message and text in the application. TODO comment
class DText {
	/// Menu text. TODO comment
	mixin Prop!("menu", DMenuText);

	/// Messages. TODO comment
	mixin MsgProp!("appName", "pa");
	mixin MsgProp!("fAppNameWithImage", "%s - pa"); /// ditto

	mixin MsgProp!("ok", "&OK"); /// ditto
	mixin MsgProp!("cancel", "&Cancel"); /// ditto
	mixin MsgProp!("yes", "&Yes"); /// ditto
	mixin MsgProp!("no", "&No"); /// ditto
	mixin MsgProp!("apply", "&Apply"); /// ditto

	mixin MsgProp!("noName", "(No name)"); /// ditto
	mixin MsgProp!("fChanged", "%s*"); /// ditto
	mixin MsgProp!("newLayer", "(New layer)"); /// ditto
	mixin MsgProp!("layerName", "Name"); /// ditto
	mixin MsgProp!("layerVisible", "Visible"); /// ditto

	mixin MsgProp!("question", "Question"); /// ditto
	mixin MsgProp!("paintAreaChanged", "Paint area is changed.\nDo quit?"); /// ditto
	mixin MsgProp!("fCanvasChanged", "%s is changed.\nIs it save?"); /// ditto

	mixin MsgProp!("fLoadImageType", "Image file (%s)"); /// ditto
	mixin MsgProp!("fSaveImageTypeBitmap", "%d-bit (%d colors) bitmap image (*.bmp)"); /// ditto
	mixin MsgProp!("fSaveImageTypePNG", "%d-bit (%d colors) PNG image (*.png)"); /// ditto

	mixin MsgProp!("noTone", "(No tone)"); /// ditto

	mixin MsgProp!("zoom", "Zoom"); /// ditto
	mixin MsgProp!("lineWidth", "Line width"); /// ditto

	mixin MsgProp!("fConfigDialog", "Configuration - %s");
	mixin MsgProp!("characterSize", "Character size");
	mixin MsgProp!("characterWidth", "Character width");
	mixin MsgProp!("characterHeight", "Character height");

	mixin PropIO!("i18n");
}
struct DMenuText {
	/// Menu texts. TODO comment
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
	mixin MsgProp!("mirrorHorizontal", "Mirror &horizontal"); /// ditto
	mixin MsgProp!("mirrorVertical", "Mirror &vertical"); /// ditto
	mixin MsgProp!("rotateRight", "Rotate &right"); /// ditto
	mixin MsgProp!("rotateLeft", "Rotate &left"); /// ditto
	mixin MsgProp!("rotateUp", "Rotate &up"); /// ditto
	mixin MsgProp!("rotateDown", "Rotate &down"); /// ditto
	mixin MsgProp!("configuration", "&Configuration..."); /// ditto

	mixin MsgProp!("help", "&Help"); /// ditto
	mixin MsgProp!("ver", "&Version"); /// ditto

	mixin PropIO!("menu");
}

/// Application config. TODO comment
class DConfig {
	/// Character (paint area) size. TODO comment
	mixin Prop!("character", PSize, PSize(100, 100));
	/// Maximum count of undo operation. TODO comment
	mixin Prop!("undoMax", uint, 1024);
	/// Tones. TODO comment
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
	mixin Prop!("weightsWork_List", Weights, Weights(3, 2));
	mixin Prop!("weightsPaint_Preview", Weights, Weights(1, 4));
	mixin Prop!("weightsPreview_Tools", Weights, Weights(1, 4));
	mixin Prop!("weightsPaint_Palette", Weights, Weights(3, 2));

	mixin Prop!("dialogButtonWidth", uint, 200, true);

	mixin PropIO!("config");
}