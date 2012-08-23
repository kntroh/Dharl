
/// This module includes dialogs and members related to it.
module dharl.dialogs;

private import dharl.common;

private import dharl.ui.basicdialog;
private import dharl.ui.dwtutils;
private import dharl.ui.uicommon;

private import std.conv;
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

/// Target of resize operation.
enum ResizeTarget {
	Character, /// Character (paint area).
	Canvas, /// Canvas on image list.
}

/// Dialog of resize image operation.
class ResizeDialog : DharlDialog {

	/// Target of resize operation.
	private ResizeTarget _targ;

	/// Pixel count.
	private Spinner _pxw, _pxh;
	/// Percentage.
	private Spinner _pew, _peh;

	/// Is maintain aspect ratio?
	private Button _mRatio;
	/// Do scale an image?
	private Button _scale;
	/// ditto
	private bool _scaling = false;

	/// Size.
	private uint _width  = 0;
	/// ditto
	private uint _height = 0;

	/// The only constructor.
	this (Shell parent, DCommon c, ResizeTarget targ) {
		_targ = targ;

		string title;
		Image image;
		final switch (_targ) {
		case ResizeTarget.Character:
			title = c.text.fResize.value.format(c.text.appName);
			image = .cimg(c.image.resize);
			break;
		case ResizeTarget.Canvas:
			title = c.text.fResizeCanvas.value.format(c.text.appName);
			image = .cimg(c.image.resizeCanvas);
			break;
		}

		auto buttons = DBtn.Ok | DBtn.Apply | DBtn.Cancel;
		super (c, parent, title, image, true, false, true, buttons);
	}
	/// Sets size before change.
	void init(int baseWidth, int baseHeight) {
		_width  = baseWidth;
		_height = baseHeight;
	}

	/// Size after resizing by pixel.
	@property
	uint width() {
		return _pxw.p_disposed ? _width : _pxw.p_selection;
	}
	/// ditto
	@property
	uint height() {
		return _pxh.p_disposed ? _height : _pxh.p_selection;
	}

	/// Do scale an image?
	@property
	const
	bool scaling() { return _scaling; }

	/// If specifies pixel count, returns true.
	@property
	private bool specPixel() { return _pxw.p_enabled; }
	/// If specifies percentage, returns true.
	@property
	private bool specPercent() { return _pew.p_enabled; }

	protected override void setup(Composite area) {
		area.p_layout = GL(1, true);

		// size
		auto size = basicGroup(area, c.text.resizeTo);
		size.p_layoutData = GD.fill(true, true);
		size.p_layout = GL(4, false);

		Button pixel, percent;
		void updateResizeType() {
			_pxw.p_enabled = pixel.p_selection;
			_pxh.p_enabled = pixel.p_selection;
			_pew.p_enabled = !pixel.p_selection;
			_peh.p_enabled = !pixel.p_selection;
		}
		// pixel count
		pixel = basicRadio(size, c.text.resizeWithPixelCount, &updateResizeType);
		pixel.p_layoutData = GD(SWT.NONE).hSpan(4);
		basicLabel(size, c.text.width);
		_pxw = basicSpinner(size, 1, c.conf.resizePixelCountMax);
		mod(_pxw);
		basicLabel(size, c.text.height);
		_pxh = basicSpinner(size, 1, c.conf.resizePixelCountMax);
		mod(_pxh);

		// percent
		percent = basicRadio(size, c.text.resizeWithPercentage, &updateResizeType);
		percent.p_layoutData = GD(SWT.NONE).hSpan(4);
		basicLabel(size, c.text.width);
		_pew = basicSpinner(size, 1, c.conf.resizePercentMax);
		mod(_pew);
		basicLabel(size, c.text.height);
		_peh = basicSpinner(size, 1, c.conf.resizePercentMax);
		mod(_peh);

		bool inEvt = false;
		/// Update a width or height from other side.
		void refPxChg(Spinner fromPx, Spinner fromPer, uint fromBase, Spinner toPx, Spinner toPer, uint toBase) {
			if (inEvt) return;
			inEvt = true;
			scope (exit) inEvt = false;

			fromPer.p_selection = .roundTo!int(cast(real) fromPx.p_selection / fromBase * 100.0);
			if (_mRatio.p_selection) {
				toPer.p_selection = fromPer.p_selection;
				toPx.p_selection = .roundTo!int(toPer.p_selection / 100.0 * toBase);
			}
		}
		/// ditto
		void refPerChg(Spinner fromPx, Spinner fromPer, uint fromBase, Spinner toPx, Spinner toPer, uint toBase) {
			if (inEvt) return;
			inEvt = true;
			scope (exit) inEvt = false;

			fromPx.p_selection = .roundTo!int(fromPer.p_selection / 100.0 * fromBase);
			if (_mRatio.p_selection) {
				toPer.p_selection = fromPer.p_selection;
				toPx.p_selection = .roundTo!int(toPer.p_selection / 100.0 * toBase);
			}
		}

		// modify size
		_pxw.listeners!(SWT.Modify) ~= { refPxChg(_pxw, _pew, _width, _pxh, _peh, _height); };
		_pxh.listeners!(SWT.Modify) ~= { refPxChg(_pxh, _peh, _height, _pxw, _pew, _width); };
		_pew.listeners!(SWT.Modify) ~= { refPerChg(_pxw, _pew, _width, _pxh, _peh, _height); };
		_peh.listeners!(SWT.Modify) ~= { refPerChg(_pxh, _peh, _height, _pxw, _pew, _width); };

		// quit
		_pxw.listeners!(SWT.Dispose) ~= { _width  = _pxw.p_selection; };
		_pxh.listeners!(SWT.Dispose) ~= { _height = _pxh.p_selection; };

		// options
		auto option = basicGroup(area, c.text.resizeOption);
		option.p_layoutData = GD.fill(true, true);
		option.p_layout = GL(1, false);

		// maintain aspect ratio
		_mRatio = basicCheck(option, c.text.maintainAspectRatio, {
			if (!_mRatio.p_selection) return;
			if (specPixel) {
				refPxChg(_pxw, _pew, _width, _pxh, _peh, _height);
			} else {
				assert (specPercent);
				refPerChg(_pxw, _pew, _width, _pxh, _peh, _height);
			}
		});

		// scaling
		_scale = basicCheck(option, c.text.scaling, {
			_scaling = _scale.p_selection;
		});

		// initializes control
		_pxw.p_selection = _width;
		_pxh.p_selection = _height;
		_pew.p_selection = 100; // %
		_peh.p_selection = 100; // %
		final switch (_targ) {
		case ResizeTarget.Character:
			c.conf.maintainAspectRatio.value.refSelection(_mRatio);
			c.conf.scaling.value.refSelection(_scale);
			c.conf.resizeValueType.value.refRadioSelection([pixel, percent]);
			break;
		case ResizeTarget.Canvas:
			c.conf.canvasMaintainAspectRatio.value.refSelection(_mRatio);
			c.conf.canvasScaling.value.refSelection(_scale);
			c.conf.canvasResizeValueType.value.refRadioSelection([pixel, percent]);
			break;
		}
		updateResizeType();
		_scaling = _scale.p_selection;
	}

	protected override bool apply() {
		// No processing
		return true;
	}
}
