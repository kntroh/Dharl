
/// This module includes dialog for display a simple text message.
///
/// License: Public Domain
/// Authors: kntroh
module dharl.ui.simpletextdialog;

private import dwtutils.factory;
private import dwtutils.utils;

private import dharl.ui.basicdialog;

private import org.eclipse.swt.all;

/// Dialog for display a simple text message.
/// Difference of this dialog and MessageBox is that
/// users can copy a message displayed.
class SimpleTextDialog : BasicDialog {

	/// The mesasge (read only).
	private Text _message = null;
	/// Temporary field of message for initialize.
	private string _messageTemp = "";

	/// The only constructor.
	this (Shell parent, string title, Image icon, in DialogState state = DialogState.init) {
		super (parent, title, icon, DBtn.Ok, state);
	}

	/// The displayed message.
	void setMessage(string message) {
		_messageTemp = message;
		if(_message) {
			_message.p_text = _messageTemp;
		}
	}
	/// ditto
	const
	string getMessage() {
		return _messageTemp;
	}

	protected override void setup(Composite area) {
		area.p_layout = new FillLayout;

		_message = .basicText(area, _messageTemp, SWT.BORDER | SWT.MULTI | SWT.V_SCROLL | SWT.READ_ONLY);
	}

	protected override bool apply() {
		return true;
	}
}
