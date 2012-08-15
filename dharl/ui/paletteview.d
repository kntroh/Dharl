
/// This module includes PaletteView and members related to it. 
module dharl.ui.paletteview;

private import util.graphics;
private import util.types;
private import util.undomanager;
private import util.utils;

private import dharl.ui.dwtutils;

private import std.algorithm;
private import std.exception;

private import org.eclipse.swt.all;

/// Viewer and chooser for colors of palette.
class PaletteView : Canvas, Undoable {
	/// Receivers of restore event.
	void delegate()[] restoreReceivers;
	/// Receivers of status changed event.
	void delegate()[] statusChangedReceivers;
	/// Receivers of color change event.
	/// This event raises before process executed.
	void delegate(int pixel, in RGB afterRGB)[] colorChangeReceivers;
	/// Color swap event receivers.
	/// This event raises before process executed.
	void delegate(int pixel1, int pixel2)[] colorSwapReceivers;

	/// Size for box of color.
	private int _cBoxWidth = 16;
	/// ditto
	private int _cBoxHeight = 12;

	/// Palette.
	private RGB[256] _colors;
	/// Settings of mask.
	private bool[256] _mask;
	/// Bitmap depth.
	private ubyte _depth = 8;
	/// Index of selected color.
	private int _pixel1 = 1, _pixel2 = 0;
	/// Index of drop target.
	private int _piTo = -1;

	/// If edit mask mode is true.
	private bool _maskMode = false;
	/// Range of change operation of mask.
	private int _piMaskFrom = -1;
	private int _piMaskTo = -1;

	/// A downing mouse button.
	/// No downing is -1.
	private int _downButton = -1;

	/// Index of last edited mask.
	private int _piEditMask = -1;

	/// Manager of undo and redo operation.
	private UndoManager _um = null;

	/// The only constructor.
	this (Composite parent, int style) {
		super (parent, style);
		this.bindListeners();

		initPalette(_colors);
	}

	// Initialize palette. (Default 16 colors)
	private static void initPalette(RGB[] colors) {
		assert (256 == colors.length);
		colors[ 0] = new RGB(255, 255, 255);
		colors[ 1] = new RGB(  0,   0,   0);
		colors[ 2] = new RGB(172, 172, 172);
		colors[ 3] = new RGB(128, 128, 128);
		colors[ 4] = new RGB(255,   0,   0);
		colors[ 5] = new RGB(128,   0,   0);
		colors[ 6] = new RGB(  0, 255,   0);
		colors[ 7] = new RGB(  0, 128,   0);
		colors[ 8] = new RGB(  0,   0, 255);
		colors[ 9] = new RGB(  0,   0, 128);
		colors[10] = new RGB(255, 255,   0);
		colors[11] = new RGB(128, 128,   0);
		colors[12] = new RGB(255,   0, 255);
		colors[13] = new RGB(128,   0, 128);
		colors[14] = new RGB(  0, 255, 255);
		colors[15] = new RGB(  0, 128, 128);
		foreach (i; 16 .. colors.length) {
			colors[i] = new RGB(0, 0, 0);
		}
	}

	/// Creates default palette (16 colors).
	static PaletteData createDefaultPalette() {
		auto colors = new RGB[256];
		initPalette(colors);
		return new PaletteData(colors);
	}

	/// Manager of undo and redo operation.
	@property
	void undoManager(UndoManager um) { _um = um; }
	/// ditto
	@property
	const
	const(UndoManager) undoManager() { return _um; }

	/// Gets selected pixel.
	@property
	const
	size_t pixel1() {
		return _pixel1;
	}
	/// ditto
	@property
	void pixel1(size_t index) {
		checkWidget();
		if (_colors.length <= index) {
			SWT.error(__FILE__, __LINE__, SWT.ERROR_INVALID_ARGUMENT);
		}
		piRedrawColor(_pixel1);
		_pixel1 = index;
		piRedrawColor(index);
	}
	/// ditto
	@property
	const
	size_t pixel2() {
		return _pixel2;
	}
	/// ditto
	@property
	void pixel2(size_t index) {
		checkWidget();
		if (_colors.length <= index) {
			SWT.error(__FILE__, __LINE__, SWT.ERROR_INVALID_ARGUMENT);
		}
		piRedrawColor(_pixel2);
		_pixel2 = index;
		piRedrawColor(index);
	}

	/// Settings of mask.
	@property
	const
	const(bool)[] mask() { return _mask; }
	/// ditto
	@property
	void mask(bool[] v) {
		if (!v) {
			SWT.error(__FILE__, __LINE__, SWT.ERROR_NULL_ARGUMENT);
		}
		if (v.length != _mask.length) {
			SWT.error(__FILE__, __LINE__, SWT.ERROR_INVALID_ARGUMENT);
		}
		checkWidget();
		_mask[] = v[0 .. _mask.length];
		redraw();
	}

	/// Is editing color mask?
	@property
	const
	bool maskMode() { return _maskMode; }
	/// ditto
	@property
	void maskMode(bool v) {
		checkWidget();
		if (_maskMode == v) return;
		_maskMode = v;
		if (v) {
			piRedrawColor(_piTo);
		} else {
			piRedrawRange(_piMaskFrom, _piMaskTo);
		}
		_downButton = -1;
		_piEditMask = -1;
		_piTo = -1;
		_piMaskFrom = -1;
		_piMaskTo = -1;
		statusChangedReceivers.raiseEvent();
	}

	/// Gets new PaletteData.
	const
	PaletteData createPalette() {
		auto colors = new RGB[_colors.length];
		foreach (i, ref rgb; colors) {
			auto c = _colors[i];
			rgb = new RGB(c.red, c.green, c.blue);
		}
		return new PaletteData(colors);
	}

	/// Gets color of palette.
	const
	RGB color(size_t index) {
		if (_colors.length <= index) {
			SWT.error(__FILE__, __LINE__, SWT.ERROR_INVALID_ARGUMENT);
		}
		auto rgb = _colors[index];
		return new RGB(rgb.red, rgb.green, rgb.blue);
	}
	/// Sets color of palette.
	void color(size_t index, int r, int g, int b) {
		checkWidget();
		if (_colors.length <= index) {
			SWT.error(__FILE__, __LINE__, SWT.ERROR_INVALID_ARGUMENT);
		}
		auto rgb = _colors[index];
		rgb.red = r;
		rgb.green = g;
		rgb.blue = b;
		piRedrawColor(index);
	}
	/// Sets color of palette.
	void color(size_t index, in RGB rgb) {
		color(index, rgb.red, rgb.green, rgb.blue);
	}
	/// Gets all colors.
	@property
	const
	const(RGB)[] colors() {
		return _colors;
	}

	/// Gets count of colors.
	@property
	const
	size_t colorCount() { return _colors.length; }

	/// Sets colors from palette.
	/// This method not changes colorCount.
	/// If palette.colors.length is less than colorCount,
	/// fills it in RGB(0, 0, 0).
	@property
	void colors(in PaletteData palette) {
		foreach (i; 0 .. _colors.length) {
			if (palette.colors.length <= i) {
				_colors[i].red   = 0;
				_colors[i].green = 0;
				_colors[i].blue  = 0;
			} else {
				_colors[i].red   = palette.colors[i].red;
				_colors[i].green = palette.colors[i].green;
				_colors[i].blue  = palette.colors[i].blue;
			}
		}
		redraw();
	}

	/// Creates gradation colors from pixel1 to pixel2.
	void createGradation() {
		createGradation(pixel1, pixel2);
	}
	/// Creates gradation colors from index1 to index2.
	void createGradation(size_t index1, size_t index2) {
		if (_colors.length <= index1 || _colors.length <= index2) {
			SWT.error(__FILE__, __LINE__, SWT.ERROR_INVALID_ARGUMENT);
		}
		size_t pi1 = min(index1, index2);
		size_t pi2 = max(index1, index2);
		size_t piLen = pi2 - pi1;
		if (piLen <= 1) return;

		if (_um) _um.store(this);

		/// Base colors.
		auto rgb1 = _colors[pi1];
		auto rgb2 = _colors[pi2];

		/// Difference of color value.
		int mr = rgb2.red   - rgb1.red;
		int mg = rgb2.green - rgb1.green;
		int mb = rgb2.blue  - rgb1.blue;

		size_t i = 0;
		foreach (pi; pi1 + 1 .. pi2) {
			auto rgb = _colors[pi];
			real rt = cast(real) i / piLen; // Ratio from pi1 to pi2.
			rgb.red   = rgb1.red   + cast(int) (mr * rt);
			rgb.green = rgb1.green + cast(int) (mg * rt);
			rgb.blue  = rgb1.blue  + cast(int) (mb * rt);
			piRedrawColor(pi);
			i++;
		}
	}

	/// Bitmap depth.
	@property
	const
	ubyte depth() { return _depth; }
	/// ditto
	@property
	void depth(ubyte depth) {
		if (1 != depth && 2 != depth && 4 != depth && 8 != depth
				&& 16 != depth && 24 != depth && 32 != depth) {
			SWT.error(__FILE__, __LINE__, SWT.ERROR_INVALID_ARGUMENT);
		}
		checkWidget();
		_depth = depth;
		redraw();
	}

	/// Converts a control location to a pixel index.
	/// If location not in palette range, returns -1.
	private int ctopi(int cx, int cy) {
		checkWidget();
		auto ca = this.p_clientArea;
		int pCountInLine = ca.width / _cBoxWidth;
		if (!pCountInLine) pCountInLine = 1;
		int px = cx / _cBoxWidth;
		int py = cy / _cBoxHeight;
		int pi = py * pCountInLine + px;
		if (0 <= pi && pi < _colors.length) {
			return pi;
		}
		return -1;
	}
	/// Converts a pixel index to a control location.
	private Point pitoc(size_t pixel) {
		checkWidget();
		size_t tiCol, tiRow;
		pitoti(pixel, tiCol, tiRow);
		int cx = tiCol * _cBoxWidth;
		int cy = tiRow * _cBoxHeight;
		return CPoint(cx, cy);
	}
	/// Converts from a pixel index to a table index (column, row).
	private void pitoti(size_t pixel, ref size_t tiCol, ref size_t tiRow) {
		checkWidget();
		auto ca = this.p_clientArea;
		int pCountInLine = ca.width / _cBoxWidth;
		if (!pCountInLine) pCountInLine = 1;
		tiCol = pixel % pCountInLine;
		tiRow = pixel / pCountInLine;
	}
	/// Converts from a table index (column, row) to a pixel index.
	private size_t titopi(size_t tiCol, size_t tiRow) {
		checkWidget();
		auto ca = this.p_clientArea;
		int pCountInLine = ca.width / _cBoxWidth;
		if (!pCountInLine) pCountInLine = 1;
		return tiRow * pCountInLine + tiCol;
	}
	/// If pixel in rectangle of range, it returns true.
	private bool piInRange(size_t pixel, int piFrom, int piTo) {
		if (-1 == piFrom) return false;
		if (-1 == piTo) return false;
		if (piFrom == piTo) return piFrom == pixel;
		checkWidget();
		size_t tiCol1, tiRow1, tiCol2, tiRow2;
		pitoti(piFrom, tiCol1, tiRow1);
		pitoti(piTo, tiCol2, tiRow2);
		if (tiCol1 > tiCol2) swap(tiCol1, tiCol2);
		if (tiRow1 > tiRow2) swap(tiRow1, tiRow2);
		size_t tiCol, tiRow;
		pitoti(pixel, tiCol, tiRow);
		return tiCol1 <= tiCol && tiCol <= tiCol2 && tiRow1 <= tiRow && tiRow <= tiRow2;
	}
	/// Calls dlg with pixels in rectangle of range.
	private void piProcRange(void delegate(int pixel) dlg, int piFrom, int piTo) {
		if (-1 == piFrom) return;
		if (-1 == piTo) return;
		if (piFrom == piTo) {
			dlg(piFrom);
			return;
		}
		checkWidget();
		if (piFrom > piTo) swap(piFrom, piTo);
		size_t tiCol1, tiRow1, tiCol2, tiRow2;
		pitoti(piFrom, tiCol1, tiRow1);
		pitoti(piTo, tiCol2, tiRow2);
		foreach (tiCol; min(tiCol1, tiCol2) .. max(tiCol1, tiCol2) + 1) {
			foreach (tiRow; min(tiRow1, tiRow2) .. max(tiRow1, tiRow2) + 1) {
				size_t pi = titopi(tiCol, tiRow);
				if (pi < _colors.length) {
					dlg(pi);
				}
			}
		}
	}

	/// Fixes edited mask.
	private void fixEditMask(Event e) {
		bool doit = false;
		piProcRange((int pixel) {
			doit = true;
			_mask[pixel] = !_mask[pixel];
		}, _piMaskFrom, _piMaskTo);
		_piMaskFrom = -1;
		_piMaskTo = -1;

		raiseSelectionEvent(e);
	}

	private void piRedrawColor(int pixel) {
		if (-1 == pixel) return;
		checkWidget();
		auto cp = pitoc(pixel);
		redraw(cp.x - 1, cp.y - 1, _cBoxWidth + 2, _cBoxHeight + 2, false);
	}
	/// Redraws a rectangle of range.
	private void piRedrawRange(int piFrom, int piTo) {
		if (-1 == piFrom) return;
		if (-1 == piTo) return;
		if (piFrom == piTo) return;
		checkWidget();
		if (piFrom > piTo) swap(piFrom, piTo);
		auto cpf = pitoc(piFrom);
		auto cpt = pitoc(piTo);
		if (cpf.x > cpt.x) swap(cpf.x, cpt.x);
		if (cpf.y > cpt.y) swap(cpf.y, cpt.y);
		int cw = cpt.x - cpf.x + _cBoxWidth;
		int ch = cpt.y - cpf.y + _cBoxHeight;
		redraw(cpf.x - 1, cpf.y - 1, cw + 2, ch + 2, false);
	}

	/// Draws palette information.
	private void onPaint(Event e) {
		checkWidget();
		auto d = this.p_display;

		auto white = d.getSystemColor(SWT.COLOR_WHITE);
		auto black = d.getSystemColor(SWT.COLOR_BLACK);
		auto defBack = e.gc.p_background;
		auto ca = this.p_clientArea;

		int cx = 0;
		int cy = 0;
		int pim = 0x1 << depth;
		int cMinBS = min(_cBoxWidth, _cBoxHeight);
		int cMaskS = cMinBS - 4;
		int cMaskX1 = (_cBoxWidth - cMaskS) / 2;
		int cMaskX2 = _cBoxWidth - cMaskX1;
		int cMaskY1 = (_cBoxHeight - cMaskS) / 2;
		int cMaskY2 = _cBoxHeight - cMaskY1;

		e.gc.p_lineWidth = 2;
		foreach (pi, rgb; _colors) {
			auto color = new Color(d, rgb);
			scope (exit) color.dispose();
			e.gc.p_background = color;
			// Draws color box.
			e.gc.fillRectangle(cx, cy, _cBoxWidth, _cBoxHeight);

			if ((rgb.red + rgb.green + rgb.blue) / 3 >= ubyte.max / 2) {
				e.gc.p_foreground = black;
			} else {
				e.gc.p_foreground = white;
			}
			if (pim <= pi) {
				// Draws mark of nonuse color.
				e.gc.drawRectangle(cx, cy, _cBoxWidth - 1, _cBoxHeight - 1);
				e.gc.p_antialias = SWT.ON;
				scope (exit) e.gc.p_antialias = SWT.OFF;
				e.gc.drawLine(cx + _cBoxWidth - 1, cy, cx, cy + _cBoxHeight - 1);
			}
			bool mask = _mask[pi];
			if (piInRange(pi, _piMaskFrom, _piMaskTo)) {
				mask = !mask;
			}
			if (mask) {
				// Draws mark of mask (X).
				e.gc.p_antialias = SWT.ON;
				scope (exit) e.gc.p_antialias = SWT.OFF;
				e.gc.drawLine(cx + cMaskX1, cy + cMaskY1, cx + cMaskX2, cy + cMaskY2);
				e.gc.drawLine(cx + cMaskX2, cy + cMaskY1, cx + cMaskX1, cy + cMaskY2);
			}

			cx += _cBoxWidth;
			if (ca.width < cx + _cBoxWidth) {
				// wrap
				cx = 0;
				cy += _cBoxHeight;
			}
		}
		e.gc.p_lineWidth = 1;
		e.gc.p_background = defBack;

		// Draws focuses.
		void drawFocus(int pixel, int color) {
			auto cp = pitoc(pixel);
			auto color1 = d.getSystemColor(SWT.COLOR_WHITE);
			auto color2 = d.getSystemColor(color);
			int cFocusX = cp.x;
			int cFocusY = cp.y;
			int cFocusW = _cBoxWidth - 1;
			int cFocusH = _cBoxHeight - 1;
			drawColorfulFocus(e.gc, color1, color2, cFocusX, cFocusY, cFocusW, cFocusH);
		}
		if (_pixel1 == _pixel2) {
			drawFocus(_pixel1, SWT.COLOR_DARK_YELLOW);
		} else {
			drawFocus(_pixel1, SWT.COLOR_RED);
			drawFocus(_pixel2, SWT.COLOR_DARK_CYAN);
		}
		if (_piTo != -1) {
			drawFocus(_piTo, SWT.COLOR_GRAY);
		}
	}

	/// Gets a index of palette from number of a mouse button.
	/// No target is -1.
	private int piFromButton(int button) {
		switch (button) {
		case 1: return _pixel1;
		case 3: return _pixel2;
		default: return -1;
		}
	}

	/// Selects color.
	private void piSelectColorImpl(Event e, int pi) {
		piSelectColorImpl(e, e.button, pi);
	}
	/// ditto
	private void piSelectColorImpl(Event e, int button, int pi) {
		int piBtn = piFromButton(button);
		piRedrawColor(piBtn);
		switch (button) {
		case 1: _pixel1 = pi; break;
		case 3: _pixel2 = pi; break;
		default: assert (0);
		}
		piRedrawColor(pi);

		raiseSelectionEvent(e);
	}

	/// Controls color.
	private void onMouseDown(Event e) {
		checkWidget();
		int pi = ctopi(e.x, e.y);
		if (pi == -1) return;
		if (_maskMode) {
			if (e.button == 1) {
				_piMaskFrom = pi;
				_piMaskTo = pi;
				piRedrawColor(pi);
			} else if (e.button == 3) {
				piRedrawRange(_piMaskFrom, _piMaskTo);
				_piMaskFrom = -1;
				_piMaskTo = -1;
			}
		} else if (e.button == 2) {
			_piEditMask = pi;
			_mask[pi] = !_mask[pi];
			piRedrawColor(pi);
			_downButton = e.button;
			raiseSelectionEvent(e);
		} else {
			int piBtn = piFromButton(e.button);
			if (piBtn == -1) return;

			if (pi != piBtn) {
				piSelectColorImpl(e, pi);
			}
			_downButton = e.button;
			if (e.button == 1 && (e.stateMask & (SWT.SHIFT | SWT.CTRL))) {
				// Starts swap or copy.
				_piTo = piBtn;
			}
		}
	}
	/// ditto
	private void onMouseUp(Event e) {
		checkWidget();
		if (_maskMode) {
			if (e.button == 1) {
				fixEditMask(e);
			}
		} else {
			if (e.button != _downButton) return;
			_downButton = -1;
			_piEditMask = -1;

			// Drops color.
			if (_piTo == -1) return;
			if (e.button != 1) return;
			if (!(e.stateMask & (SWT.SHIFT | SWT.CTRL))) return;
			int piBtn = _pixel1;
			if (_colors[_piTo] == _colors[piBtn]) return;
			if (_um) _um.store(this);

			if (e.stateMask & SWT.SHIFT) {
				// swap
				colorSwapReceivers.raiseEvent(_piTo, piBtn);
				auto temp = color(piBtn);
				color(piBtn, color(_piTo));
				color(_piTo, temp);
				piRedrawColor(piBtn);
			} else if (e.stateMask & SWT.CTRL) {
				// copy
				colorChangeReceivers.raiseEvent(_piTo, cast(const) _colors[piBtn]);
				color(_piTo, color(piBtn));
			}
			piRedrawColor(_piTo);
			piSelectColorImpl(e, _piTo);
			_piTo = -1;
		}
	}
	/// ditto
	private void onMouseMove(Event e) {
		checkWidget();
		int pi = ctopi(e.x, e.y);
		if (pi == -1) return;
		if (_maskMode) {
			piRedrawRange(_piMaskFrom, _piMaskTo);
			_piMaskTo = pi;
			piRedrawRange(_piMaskFrom, _piMaskTo);
		} else if (_downButton == 2) {
			if (pi == _piEditMask) return;
			_piEditMask = pi;
			_mask[pi] = !_mask[pi];
			piRedrawColor(pi);
			raiseSelectionEvent(e);
		} else {
			int piBtn = piFromButton(_downButton);
			if (piBtn == -1) return;
			if (_piTo == -1) {
				// Selects color.
				piSelectColorImpl(e, _downButton, pi);
			} else {
				// Drags color.
				piRedrawColor(_piTo);
				piRedrawColor(pi);
				_piTo = pi;
			}
		}
	}
	/// ditto
	private void onMouseWheel(Event e) {
		checkWidget();
		if (0 == e.count) return;

		int pixel;
		if (e.stateMask & SWT.SHIFT) {
			pixel = pixel2;
		} else {
			pixel = pixel1;
		}
		if (e.count > 0) {
			// up
			if (pixel <= 0) return;
			pixel--;
		} else {
			assert (e.count < 0);
			// down
			if (_colors.length <= pixel + 1) return;
			pixel++;
		}
		if (e.stateMask & SWT.SHIFT) {
			pixel2 = pixel;
		} else {
			pixel1 = pixel;
		}
	}

	/// Handling key traversal.
	private void onTraverse(Event e) {
		checkWidget();
		switch (e.detail) {
		case SWT.TRAVERSE_RETURN, SWT.TRAVERSE_TAB_PREVIOUS, SWT.TRAVERSE_TAB_NEXT:
			e.doit = true;
			break;
		default:
			e.doit = false;
			break;
		}
	}
	/// Change selection
	private void onKeyDown(Event e) {
		auto ca = this.p_clientArea;
		int col = ca.width / _cBoxWidth;
		int row = _colors.length / col;
		// Number of color in current row.
		if (_colors.length % col) row++;

		bool shift = cast(bool) (e.stateMask & SWT.SHIFT);
		int pixel = shift ? pixel2 : pixel1;
		switch (e.keyCode) {
		case SWT.ARROW_UP:
			pixel -= col;
			if (pixel < 0) {
				// move up. (rotation)
				pixel += col * row;
				if (_colors.length <= pixel) {
					pixel -= col;
				}
			}
			break;
		case SWT.ARROW_DOWN:
			pixel += col;
			if (_colors.length <= pixel) {
				// move down. (rotation)
				pixel -= col * row;
			}
			break;
		case SWT.ARROW_LEFT:
			pixel--;
			if (pixel < 0) pixel = _colors.length - 1;
			break;
		case SWT.ARROW_RIGHT:
			pixel++;
			if (_colors.length <= pixel) pixel = 0;
			break;
		default:
			return;
		}
		if (shift) {
			piSelectColorImpl(e, 3, pixel);
		} else {
			piSelectColorImpl(e, 1, pixel);
		}
	}

	/// Raises selection event.
	private void raiseSelectionEvent(Event e) {
		auto se = new Event;
		se.time = e.time;
		se.stateMask = e.stateMask;
		se.doit = e.doit;
		notifyListeners(SWT.Selection, se);
		e.doit = se.doit;
	}

	/// Adds or removes a listener for selection event.
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

	override Point computeSize(int wHint, int hHint, bool changed) {
		checkWidget();
		int cbw = this.p_borderWidth * 2;
		int cw = (wHint == SWT.DEFAULT) ? _cBoxWidth * 16 + cbw : wHint;
		int ch = (hHint == SWT.DEFAULT) ? _cBoxHeight * 16 + cbw : hHint;
		return CPoint(cw, ch);
	}

	/// A data object for undo.
	private static class StoreData {
		/// Palette data.
		CRGB[256] colors;
	}
	@property
	override Object storeData() {
		auto data = new StoreData;
		foreach (i, ref rgb; data.colors) {
			auto c = _colors[i];
			rgb.r = cast(ubyte) c.red;
			rgb.g = cast(ubyte) c.green;
			rgb.b = cast(ubyte) c.blue;
		}
		return data;
	}
	override void restore(Object data, UndoMode mode) {
		auto st = cast(StoreData) data;
		enforce(st);
		foreach (i, ref rgb; st.colors) {
			color(i, rgb.r, rgb.g, rgb.b);
		}
		restoreReceivers.raiseEvent();
	}
	@property
	override bool enabledUndo() {
		return !this.p_disposed;
	}
}
