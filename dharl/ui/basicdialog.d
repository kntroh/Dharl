
/// This module includes basic style dialog and members related to it.
///
/// License: Public Domain
/// Authors: kntroh
module dharl.ui.basicdialog;

private import util.utils;

private import dwtutils.utils;

private import std.algorithm;
private import std.traits;

private import org.eclipse.swt.all;

/// Bitmasks of dialog buttons.
enum DBtn {
	Yes    = 0b00000001, /// Yes.
	Ok     = 0b00000010, /// OK.
	No     = 0b00000100, /// No.
	Cancel = 0b00001000, /// Cancel.
	Apply  = 0b00010000, /// Apply.
}

/// States of dialog.
struct DialogState {
	/// Dialog is modal?
	bool modal = true;
	/// Dialog is resizable?
	bool resizable = true;
	/// Enable Enter or Esc key?
	bool keyOperation = true;

	string yes    = "&Yes";    /// Button text of Yes.
	string ok     = "&Ok";     /// Button text of OK.
	string no     = "&No";     /// Button text of No.
	string cancel = "&Cancel"; /// Button text of Cancel.
	string apply  = "&Apply";  /// Button text of Apply.

	/// A button width (minimum).
	int buttonWidthMin = 80;
}

/// Abstract dialog.
abstract class BasicDialog {
	/// Receivers of applied event.
	void delegate()[] appliedReceivers;

	/// Shell of dialog.
	private Shell _shl;
	/// Area of controls.
	private Composite _area;

	/// Buttons.
	private Button[DBtn] _buttons;

	/// The only constructor.
	this (Shell parent, string title, Image image, DBtn buttons, in DialogState state = DialogState.init) {
		if (!buttons) {
			SWT.error(__FILE__, __LINE__, SWT.ERROR_INVALID_ARGUMENT);
		}
		bool valid = false;
		foreach (b; EnumMembers!DBtn) {
			if (b & buttons) {
				valid = true;
				break;
			}
		}
		if (!valid) {
			SWT.error(__FILE__, __LINE__, SWT.ERROR_INVALID_ARGUMENT);
		}

		// Creates dialog shell and controls area.
		int style = state.resizable ? SWT.SHELL_TRIM : SWT.DIALOG_TRIM;
		if (state.modal) style |= SWT.APPLICATION_MODAL;
		_shl = basicShell(parent, title, image, GL.window, style);
		_shl.p_layout = GL.window(1, true).zero;

		_area = basicComposite(_shl);
		_area.p_layoutData = GD.fill(true, true);

		auto sep = separator(_shl, SWT.HORIZONTAL);
		sep.p_layoutData = GD.fill(true, false);

		// Creates buttons.
		auto bComp = basicComposite(_shl, RL.horizontal);
		bComp.p_layoutData = GD(GridData.HORIZONTAL_ALIGN_END);
		void initButton(DBtn b) {
			string text;
			final switch (b) {
			case DBtn.Yes:
				text = state.yes;
				break;
			case DBtn.Ok:
				text = state.ok;
				break;
			case DBtn.Apply:
				text = state.apply;
				break;
			case DBtn.No:
				text = state.no;
				break;
			case DBtn.Cancel:
				text = state.cancel;
				break;
			}
			Button button;
			button = basicButton(bComp, text, {
				final switch (b) {
				case DBtn.Yes, DBtn.Ok, DBtn.Apply:
					bool close;
					if (!apply(b, close)) return;
					appliedReceivers.raiseEvent();
					if (DBtn.Apply is b) {
						button.p_enabled = false;
					}
					if (!close) return;
					_shl.close();
					break;
				case DBtn.No, DBtn.Cancel:
					_shl.close();
					break;
				}
			});
			auto size = button.computeSize(SWT.DEFAULT, SWT.DEFAULT);
			uint dw = state.buttonWidthMin;
			button.p_layoutData = RD(max(size.x, dw), SWT.DEFAULT);

			if (state.keyOperation && (DBtn.Yes is b || DBtn.Ok is b)) {
				_shl.p_defaultButton = button;
			}

			_buttons[b] = button;
		}
		foreach (b; EnumMembers!DBtn) {
			if (!(buttons & b)) continue;
			initButton(b);
		}
	}
	private bool apply(DBtn button, out bool close) {
		if (apply()) {
			close = DBtn.Apply !is button;
			return true;
		}
		return false;
	}

	/// Opens dialog.
	void open() {
		setup(_area);

		// First state of apply button is not enable.
		auto pApply = DBtn.Apply in _buttons;
		if (pApply) pApply.p_enabled = false;

		_shl.pack();
		auto parent = _shl.p_parent;
		if (parent) {
			auto pb = parent.p_bounds;
			auto ss = _shl.p_size;
			int x = pb.x + (pb.width  - ss.x) / 2;
			int y = pb.y + (pb.height - ss.y) / 2;
			_shl.p_location = CPoint(x, y);
		}

		onOpen(_shl);
		_shl.open();
	}

	/// Gets instance of Display this dialog belongs.
	Display getDisplay() { return _shl.p_display; }

	/// If dialog is disposed, returns true.
	bool isDisposed() { return _shl.p_disposed; }

	/// This method is call when shell open.
	protected void onOpen(Shell shell) {
		// No processing.
	}

	/// Creates controls of dialog.
	protected abstract void setup(Composite area);
	/// This method is called when the Apply button is pushed.
	protected abstract bool apply() { return true; }

	/// Set enable to apply button.
	protected void enableApply() {
		auto pApply = DBtn.Apply in _buttons;
		if (!pApply) {
			SWT.error(__FILE__, __LINE__, SWT.ERROR_INVALID_ARGUMENT);
		}
		pApply.p_enabled = true;
	}
	/// When control changed, set enable to apply button.
	protected void mod(C)(C control) {
		if (control.p_shell !is _shl) {
			SWT.error(__FILE__, __LINE__, SWT.ERROR_INVALID_ARGUMENT);
		}
		auto pApply = DBtn.Apply in _buttons;
		if (!pApply) {
			SWT.error(__FILE__, __LINE__, SWT.ERROR_INVALID_ARGUMENT);
		}

		static if (is(typeof(control.addModifyListener))) {
			control.p_listeners!(SWT.Modify) ~= { pApply.p_enabled = true; };
		} else static if (is(typeof(control.addSelectionListener))) {
			control.p_listeners!(SWT.Selection) ~= { pApply.p_enabled = true; };
		} else static assert (0);
	}
}
