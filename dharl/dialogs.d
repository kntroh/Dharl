
/// This module includes dialogs and members related to it.
module dharl.dialogs;

private import dharl.common;

private import dharl.ui.basicdialog;
private import dharl.ui.dwtutils;
private import dharl.ui.uicommon;

private import std.string;

private import org.eclipse.swt.all;

/// Abstract dialog for Dharl.
abstract class DharlDialog : BasicDialog {

	private DCommon _c;

	/// The only constructor.
	this (DCommon c, Shell parent, string title, Image image, bool modal, bool resizable, bool keyOperation, DBtn buttons) {
		_c = c;

		DialogState state;
		state.modal        = modal;
		state.resizable    = resizable;
		state.keyOperation = keyOperation;
		state.yes    = c.text.yes;
		state.ok     = c.text.ok;
		state.no     = c.text.no;
		state.cancel = c.text.cancel;
		state.apply  = c.text.apply;
		state.buttonWidthMin = c.conf.dialogButtonWidth;

		super (parent, title, image, buttons, state);
	}

	/// Common functions and texts of application.
	@property
	protected DCommon c() { return _c; }
}

/// Dialog of application configuration.
class ConfigDialog : DharlDialog {

	/// Character (paint area) size.
	private Spinner _cw, _ch;

	/// The only constructor.
	this (Shell parent, DCommon c) {
		auto title  = c.text.fConfigDialog.value.format(c.text.appName);
		auto image  = .cimg(c.image.configuration);
		auto buttons = DBtn.Ok | DBtn.Apply | DBtn.Cancel;
		super (c, parent, title, image, true, false, true, buttons);
	}

	protected override void setup(Composite area) {
		area.p_layout = GL(1, false);

		// Character (paint area) size.
		auto group = basicGroup(area, c.text.characterSize, GL(2, false));
		group.p_layoutData = GD.fill(true, true);

		basicLabel(group, c.text.characterWidth);
		_cw = basicSpinner(group, 1, 9999);
		mod(_cw);
		basicLabel(group, _c.text.characterHeight);
		_ch = basicSpinner(group, 1, 9999);
		mod(_ch);

		// Sets configuration to controls.
		_cw.p_selection = c.conf.character.width;
		_ch.p_selection = c.conf.character.height;
	}

	protected override bool apply() {

		// Character (paint area) size.
		c.conf.character.width  = _cw.p_selection;
		c.conf.character.height = _ch.p_selection;

		return true;
	}
}

/// Dialog of resize image operation.
class ResizeDialog {
	// TODO
}

/// Dialog of resize canvas operation.
class ResizeCanvasDialog {
	// TODO
}
