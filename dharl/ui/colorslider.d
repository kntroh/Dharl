
/// This module includes ColorSlider and members related to it. 
module dharl.ui.colorslider;

private import dharl.util.utils;
private import dharl.ui.cslider;
private import dharl.ui.dwtfactory;
private import dharl.ui.dwtutils;

private import std.conv;

private import org.eclipse.swt.all;

/// A color model.
enum ColorModel {
	RGB, /// RGB model.
	HSV, /// HSV model.
}

/// Sliders for editing a color.
/// ColorSlider includes three slider and three spinner
/// for editing a RGB and HSV color.
class ColorSlider : Canvas {
	private CSlider _sl1; /// For R or H.
	private Text _sp1; /// ditto
	private CSlider _sl2; /// For G or S.
	private Text _sp2; /// ditto
	private CSlider _sl3; /// For B or V.
	private Text _sp3; /// ditto

	private bool _setting = false; /// When calling methods is false. TODO comment

	private ColorModel _cModel = ColorModel.RGB; /// Color model.

	private int _style; /// ColorSlider style.

	/// The only constructor.
	this (Composite parent, int style) {
		// Scrollbars appears when SWT.HORIZONTAL or SWT.VERTICAL
		// is passed to Scrollable.
		// Therefore, these styles are excluded.
		super (parent, style & !(SWT.HORIZONTAL | SWT.VERTICAL));
		if (style & SWT.HORIZONTAL || !(style & SWT.VERTICAL)) {
			_style = SWT.HORIZONTAL;
		} else {
			_style = SWT.VERTICAL;
		}

		// layout
		if (_style & SWT.VERTICAL) {
			this.p_layout = GL.minimum(3, true).margin(0);
		} else {
			this.p_layout = GL.minimum(2, false).margin(0);
		}

		// If this is focus control setted true. TODO comment
		bool fIn = false;
		// widgets
		void createWidgets(out CSlider sl, out Text sp) {
			// Layout is switched by a SWT.HORIZONTAL or SWT.VERTICAL.
			Composite parent;

			// scale
			if (_style & SWT.VERTICAL) {
				parent = new Composite(this, SWT.NONE);
				parent.p_layout = GL.minimum(1).margin(0);
				sl = basicVCSlider(parent, 0, 255, 8);
				sl.reverseView = true;
			} else {
				parent = this;
				sl = basicHCSlider(parent, 0, 255, 8);
			}
			sl.p_selection = sptosl(0, sl.p_maximum);

			// spinner
			sp = basicNumber(parent, 0, 255, SWT.CENTER);
			sp.p_background = parent.p_background; // Fusions to parent.
			auto ts = computeTextSize(sp, "000");
			auto sps = sp.computeSize(ts.x, ts.y);

			// synchronization
			sl.listeners!(SWT.Selection) ~= (Event e) {
				sp.p_text = to!string(sltosp(sl.p_selection, sl.p_maximum));
				editedColor(e);
			};
			sp.listeners!(SWT.Modify) ~= (Event e) {
				// Using e.text. See description of basicNumber().
				sl.p_selection = sptosl(to!(int)(e.text), sl.p_maximum);
				if (!_setting) {
					editedColor(e);
				}
			};

			// Layout widgets for one color.
			if (_style & SWT.VERTICAL) {
				sl.p_layoutData = GD(GridData.FILL_VERTICAL | GridData.HORIZONTAL_ALIGN_CENTER).hHint(128);
				sp.p_layoutData = GD(GridData.HORIZONTAL_ALIGN_CENTER).wHint(sps.x);
			} else {
				sl.p_layoutData = GD(GridData.FILL_HORIZONTAL).wHint(128);
				sp.p_layoutData = GD(SWT.NONE).wHint(sps.x);
			}
		}
		createWidgets(_sl1, _sp1);
		createWidgets(_sl2, _sp2);
		createWidgets(_sl3, _sp3);
	}

	/// Converts slider value to spinner value.
	private int sptosl(int sp, int slMax) {
		return slMax - sp;
	}
	/// Converts spinner value to slider value.
	private int sltosp(int sl, int slMax) {
		return slMax - sl;
	}

	/// Called when a edited color.
	private void editedColor(Event e) {
		checkWidget();

		auto se = new Event;
		se.time = e.time;
		se.stateMask = e.stateMask;
		se.doit = e.doit;
		notifyListeners(SWT.Selection, se);
		e.doit = se.doit;
	}

	/// Gets color.
	@property
	RGB color() {
		int r = sltosp(_sl1.p_selection, _sl1.p_maximum);
		int g = sltosp(_sl2.p_selection, _sl2.p_maximum);
		int b = sltosp(_sl3.p_selection, _sl3.p_maximum);
		return new RGB(r, g, b);
	}
	/// Sets color.
	void setColor(int r, int g, int b) {
		checkWidget();
		_setting = true;
		scope (exit) _setting = false;
		_sl1.p_selection = r;
		_sp1.p_text = to!string(r);
		_sl2.p_selection = g;
		_sp2.p_text = to!string(g);
		_sl3.p_selection = b;
		_sp3.p_text = to!string(b);
	}
	/// Sets color.
	@property
	void color(in RGB rgb) {
		checkWidget();
		setColor(rgb.red, rgb.green, rgb.blue);
	}

	/// Adds or removes a listener for selection event (edited color).
	void addSelectionListener(SelectionListener listener) {
		checkWidget();
		if (!listener) {
			SWT.error(__FILE__, __LINE__, SWT.ERROR_NULL_ARGUMENT);
		}
		auto tl = new TypedListener(listener);
		addListener(SWT.Selection, tl);
		addListener(SWT.DefaultSelection, tl);
	}
	/// ditto
	void removeSelectionListener(SelectionListener listener) {
		checkWidget();
		if (!listener) {
			SWT.error(__FILE__, __LINE__, SWT.ERROR_NULL_ARGUMENT);
		}
		removeListener(SWT.Selection, listener);
		removeListener(SWT.DefaultSelection, listener);
	}

	override int getStyle() {
		return super.getStyle() | _style;
	}
}
