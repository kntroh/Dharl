
/// This module includes minimum dialogs and members related to it. TODO cent 
module dharl.ui.dialogs;

private import dharl.common;
private import dharl.util.utils;
private import dharl.ui.uicommon;
private import dharl.ui.dwtfactory;
private import dharl.ui.dwtutils;

private import std.algorithm;
private import std.exception;
private import std.string;

private import org.eclipse.swt.all;

/// Dialog buttons. TODO cent
enum DBtn {
	Yes    = 0b00000001, /// Yes.
	Ok     = 0b00000010, /// OK.
	Apply  = 0b00000100, /// Apply.
	No     = 0b00001000, /// No.
	Cancel = 0b00010000  /// Cancel.
}

/// Abstract dialog. TODO cent
abstract class CDialog {
	/// Applied event receivers. TODO cent
	void delegate()[] appliedReceivers;

	/// Dialog. TODO cent
	private Shell _shl;
	/// Controls area. TODO cent
	private Composite _area;

	private DCommon _c;

	/// The only constructor. TODO cent
	this (Shell parent, DCommon c, string title, Image image, bool modal, DBtn buttons) {
		enforce(buttons);
		bool valid = false;
		for (size_t b = DBtn.min; b <= DBtn.max; b <<= 1) {
			if (b & buttons) {
				valid = true;
				break;
			}
		}
		enforce(valid);

		_c = c;

		int style = SWT.SHELL_TRIM;
		if (modal) style |= SWT.APPLICATION_MODAL;
		_shl = basicShell(parent, title, image, GL.window, style);
		_shl.p_layout = GL.window(1, true).zero;

		_area = basicComposite(_shl);

		auto sep = separator(_shl, SWT.HORIZONTAL);
		sep.p_layoutData = GD.fill(true, false);

		// Creates buttons. TODO cent
		auto bComp = basicComposite(_shl, RL.horizontal);
		for (DBtn b = DBtn.min; b <= DBtn.max; b <<= 1) {
			if (!(buttons & b)) continue;
			string text;
			final switch (b) {
			case DBtn.Yes:
				text = c.text.yes;
				break;
			case DBtn.Ok:
				text = c.text.ok;
				break;
			case DBtn.Apply:
				text = c.text.apply;
				break;
			case DBtn.No:
				text = c.text.no;
				break;
			case DBtn.Cancel:
				text = c.text.cancel;
				break;
			}
			auto button = basicButton(bComp, text, (Event e) {
				final switch (b) {
				case DBtn.Yes, DBtn.Ok, DBtn.Apply:
					bool close;
					if (!apply(b, close)) return;
					appliedReceivers.raiseEvent();
					if (!close) return;
					_shl.dispose();
					break;
				case DBtn.No, DBtn.Cancel:
					_shl.dispose();
					break;
				}
			});
			auto size = button.computeSize(SWT.DEFAULT, SWT.DEFAULT);
			uint dw = c.conf.dialogButtonWidth;
			button.p_layoutData = RD(max(size.x, dw), SWT.DEFAULT);
		}
	}
	private bool apply(DBtn button, out bool close) {
		if (apply()) {
			close = DBtn.Apply !is button;
			return true;
		}
		return false;
	}

	/// Opens dialog. TODO cent
	void open() {
		setup(_area);
		_shl.pack();
		_shl.open();
	}

	/// DCommon from constructor. TODO cent
	@property
	protected DCommon c() { return _c; }

	/// Creates dialog controls. TODO cent
	protected abstract void setup(Composite area);
	/// When calls pushed button. TODO cent
	protected abstract bool apply() { return true; }
}

/// TODO cent
class ConfigDialog : CDialog {
	/// Character size. TODO cent
	private Spinner _cw, _ch;

	/// The only constructor. TODO cent
	this (Shell parent, DCommon c) {
		string configDialog = c.text.fConfigDialog;
		string appName = c.text.appName;
		auto img = cimg(c.image.configuration);
		auto btn = DBtn.Ok | DBtn.Apply | DBtn.Cancel;
		super (parent, c, format(configDialog, appName), img, true, btn);
	}

	protected override void setup(Composite area) {
		area.p_layout = GL(1, false);

		// Character size. TODO cent
		auto group = basicGroup(area, c.text.characterSize, GL(2, false));
		group.p_layoutData = GD.fill(true, true);

		basicLabel(group, c.text.characterWidth);
		_cw = basicSpinner(group, 1, 9999);
		basicLabel(group, c.text.characterHeight);
		_ch = basicSpinner(group, 1, 9999);

		// Reads configuration to controls. TODO cent
		_cw.p_selection = c.conf.character.width;
		_ch.p_selection = c.conf.character.height;
	}

	protected override bool apply() {
		c.conf.character.width = _cw.p_selection;
		c.conf.character.height = _ch.p_selection;
		return true;
	}
}

/// TODO cent
class ResizeDialog {
}

/// TODO cent
class ResizeCanvasDialog {
}
