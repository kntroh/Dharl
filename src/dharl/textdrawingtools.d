
/// This module includes tool window for text drawing.
///
/// License: Public Domain
/// Authors: kntroh
module dharl.textdrawingtools;

private import util.utils;

private import dharl.common;

private import dharl.ui.dwtutils;
private import dharl.ui.uicommon;

private import std.algorithm;
private import std.array;

private import org.eclipse.swt.all;

/// Tool window for text drawing.
/// The window includes text box and controls of font style.
class TextDrawingTools {
	/// Receivers of status changed event.
	void delegate()[] statusChangedReceivers;

	private DCommon _c = null;

	/// Tool window for text drawing.
	private Shell _shell = null;
	/// Visibility of the shell.
	private bool _visible = false;

	/// The inputted text for text drawing.
	private string _inputtedText = "";

	/// Parameters of font.
	private string _fontName = "";
	private int _fontPoint = 12; /// ditto
	private bool _bold = false; /// ditto
	private bool _italic = false; /// ditto

	/// The only constructor.
	this (Shell parent, DCommon c) {
		_c = c;
		auto d = parent.p_display;

		auto layout = GL.window(1, true).margin(0);
		_shell = toolShell(parent, _c.text.textDrawing, true, false, layout);

		// Controls of font style.
		auto fontComp = basicComposite(_shell, GL.window(3, false).margin(0));
		// font name
		string[] fontNames;
		foreach (fontData; d.getFontList(null, true)) {
			fontNames ~= fontData.p_name;
			if (_c.conf.fontName == fontData.p_name) {
				_fontName = _c.conf.fontName;
			}
		}
		fontNames = fontNames.sort;
		fontNames = fontNames.uniq().array();
		auto name = basicCombo(fontComp, true, fontNames.sort);
		name.p_listeners!(SWT.Modify) ~= {
			_fontName = name.p_text;
			_c.conf.fontName = _fontName;
			statusChangedReceivers.raiseEvent();
		};
		if (_fontName == "") {
			_fontName = name.p_text;
		} else {
			name.p_text = _fontName;
		}
		// font size (pt)
		_fontPoint = _c.conf.fontPoint;
		auto point = basicSpinner(fontComp, 1, 256);
		point.p_selection = _fontPoint;
		point.widgetSelected ~= {
			_fontPoint = point.p_selection;
			_c.conf.fontPoint = _fontPoint;
			statusChangedReceivers.raiseEvent();
		};
		// font style
		auto styleTools = basicToolBar(fontComp);
		ToolItem bold, italic;
		_bold = _c.conf.bold;
		_italic = _c.conf.italic;
		bold = basicToolItem(styleTools, _c.text.menu.bold, cimg(_c.image.bold), {
			_bold = bold.p_selection;
			_c.conf.bold = _bold;
			statusChangedReceivers.raiseEvent();
		}, SWT.CHECK);
		bold.p_selection = _bold;
		italic = basicToolItem(styleTools, _c.text.menu.italic, cimg(_c.image.italic), {
			_italic = italic.p_selection;
			_c.conf.italic = _italic;
			statusChangedReceivers.raiseEvent();
		}, SWT.CHECK);
		italic.p_selection = _italic;

		// The text box.
		Text text;
		text = multiLineText(_shell, {
			_inputtedText = text.p_text;
			statusChangedReceivers.raiseEvent();
		}, _inputtedText);
		text.p_layoutData = GD.fill(true, true);

		// window bounds
		c.conf.textDrawingTools.value.refWindow(_shell);
	}

	/// Visibility of the shell.
	@property
	const
	bool visible() { return _visible; }
	/// ditto
	@property
	void visible(bool v) {
		_visible = v;
		_shell.p_visible = v;
	}

	/// The inputted text for text drawing.
	@property
	const
	string inputtedText() { return _inputtedText; }

	/// The font for text drawing.
	@property
	const
	FontData drawingFont() {
		int style = SWT.NONE;
		if (_bold) style |= SWT.BOLD;
		if (_italic) style |= SWT.ITALIC;
		return new FontData(_fontName, _fontPoint, style);
	}
}
