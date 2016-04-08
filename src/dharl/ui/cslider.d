
/// This module includes CSlider and members related to it. 
///
/// License: Public Domain
/// Authors: kntroh
module dharl.ui.cslider;

private import util.utils;

private import dharl.ui.dwtutils;

private import core.thread;

private import std.algorithm;
private import std.concurrency;
private import std.datetime;

private import java.lang.System;
private import java.lang.Runnable;

private import org.eclipse.swt.all;

/// Creates basic style CSlider.
CSlider basicCSlider(Composite parent, int style, int min, int max, int pageIncrement) {
	auto slider = new CSlider(parent, style);
	slider.p_minimum = min;
	slider.p_maximum = max;
	slider.p_pageIncrement = pageIncrement;
	return slider;
}
/// ditto
CSlider basicHCSlider(Composite parent, int min, int max, int increment) {
	return basicCSlider(parent, SWT.HORIZONTAL, min, max, increment);
}
/// ditto
CSlider basicVCSlider(Composite parent, int min, int max, int increment) {
	return basicCSlider(parent, SWT.VERTICAL, min, max, increment);
}

/// Custom slider.
/// A purpose of this class, is a solution to problem
/// of Scale size and a improvement to usability.
class CSlider : Canvas {
	/// Present mouse operation.
	private enum Mouse {
		None, // None.
		PushedBar, // Pushed bar.
		PushedDown, // Pushed down button.
		PushedUp, // Pushed up button.
	}

	mixin BindListeners;

	private int _cWBar = 15; /// Width of a bar.
	private int _cWBtn = 13; /// Width of a up down button.

	private int _sValue = 0; /// Selected value.
	private int _sMax = 10; /// Maximum value.
	private int _sMin = 0; /// Minimum value.
	private int _sInc = 1; /// Value of increment for minimum slide.
	private int _sPageInc = 8; /// Value of increment for a page.

	private int _sPushedValue = -1; /// Value before a mouse button is pressed.

	/// If it is true, a bar is displayed in the reverse direction.
	private bool _reverseView = false;

	private int _style; /// CSlider style.

	private Mouse _mouse = Mouse.None; /// Present mouse operation.

	private Display _display;
	/// Value of _display.getDoubleClickTimer(). For timerMethod().
	private long _doubleClickTime;
	private Thread _timer; /// Timer for up down button.
	private TimerExec _timerExec; /// Execute from timer.

	/// Timer for up down button.
	private void timerMethod() {
		int count = 0;
		Thread.sleep(dur!"msecs"(_doubleClickTime));
		while (_mouse == Mouse.PushedUp || _mouse == Mouse.PushedDown) {
			Thread.sleep(dur!"msecs"(50));
			_display.syncExec(_timerExec);
			count++;
			if (count >= 30) {
				// accelerate
				_timerExec.addingValue *= 10;
				count = 0;
			}
		}
	}
	/// Please call this function before call _timer.start().
	private void initTimer() {
		checkWidget();
		_display = parent.p_display;
		_doubleClickTime = display.p_doubleClickTime;
		_timerExec.addingValue = _sInc;
	}
	/// Execute from timer.
	private class TimerExec : Runnable {
		int addingValue = 0;
		override void run() {
			if (this.outer.p_disposed) {
				_mouse = Mouse.None;
				return;
			}
			checkWidget();
			if (_mouse == Mouse.PushedUp) {
				this.outer.p_selection = this.outer.p_selection + addingValue;
			} else if (_mouse == Mouse.PushedDown) {
				this.outer.p_selection = this.outer.p_selection - addingValue;
			}
			redraw();
			auto se = new Event;
			se.time = cast(int)System.currentTimeMillis();
			se.stateMask = 0;
			se.doit = true;
			notifyListeners(SWT.Selection, se);
		}
	}

	/// The only constructor.
	this (Composite parent, int style) {
		// Scrollbars appears when SWT.HORIZONTAL or SWT.VERTICAL
		// is passed to Scrollable.
		// Therefore, these styles are excluded.
		super (parent, style & !(SWT.HORIZONTAL | SWT.VERTICAL) | SWT.DOUBLE_BUFFERED);
		if (style & SWT.HORIZONTAL || !(style & SWT.VERTICAL)) {
			_style = SWT.HORIZONTAL;
		} else {
			_style = SWT.VERTICAL;
		}

		// Create timer for up down button.
		_timer = new Thread(&timerMethod);
		_timerExec = new TimerExec;

		this.bindListeners();
	}

	~this () {
		if (_timer.isRunning) {
			_mouse = Mouse.None;
			_timer.join();
		}
	}

	/// Sets or gets a value of slider.
	void setSelection(int value) {
		checkWidget();
		value = max(_sMin, min(_sMax, value));
		if (_sValue != value) {
			_sValue = value;
			redraw();
		}
	}
	/// ditto
	const
	int getSelection() {
		return _sValue;
	}

	/// Sets or gets a maximum or minimum value.
	void setMaximum(int value) {
		checkWidget();
		_sMax = max(_sMin, value);
		this.p_selection = _sValue;
	}
	/// ditto
	const
	int getMaximum() {
		return _sMax;
	}
	/// ditto
	void setMinimum(int value) {
		checkWidget();
		_sMin = min(_sMax, value);
		this.p_selection = _sValue;
	}
	/// ditto
	const
	int getMinimum() {
		return _sMin;
	}

	/// Sets or gets a value of increment for minimum slide.
	void setIncrement(int increment) {
		checkWidget();
		_sInc = increment;
	}
	/// ditto
	const
	int getIncrement() {
		return _sInc;
	}

	/// Sets or gets a value of increment for page.
	void setPageIncrement(int pageIncrement) {
		checkWidget();
		_sPageInc = pageIncrement;
	}
	/// ditto
	const
	int getPageIncrement() {
		return _sPageInc;
	}

	/// If it is true, a bar is displayed in the reverse direction.
	@property
	void reverseView(bool reverseView) {
		checkWidget();
		if (_reverseView != reverseView) {
			_reverseView = reverseView;
			redraw();
		}
	}
	/// ditto
	@property
	const
	bool reverseView() {
		return _reverseView;
	}

	/// Converts control coordinates to a slider value.
	/// If coordinates on a up or down button,
	/// returns getMaximum() + 1 or getMinimum() - 1.
	private int ctos(int cx, int cy) {
		checkWidget();
		auto ca = this.p_clientArea;
		int c;
		int cLen; // A length of bar.
		if (_style & SWT.VERTICAL) {
			c = cy;
			cLen = ca.height;
		} else {
			c = cx;
			cLen = ca.width;
		}
		if (c < _cWBtn) {
			// At down button.
			return _sMin - 1;
		}
		cLen -= _cWBtn * 2;
		if (_cWBtn + cLen <= c) {
			// At up button.
			return _sMax + 1;
		}
		c -= _cWBtn; // Subtracts width of left button.
		int sRange = _sMax - _sMin; // A range of slider value.
		real cr = cast(real)sRange / cLen; // ratio
		return cast(int)(c * cr);
	}

	/// Converts a slider value to control coordinate (X or Y).
	private int stoc(int s) {
		checkWidget();
		auto ca = this.p_clientArea;
		int cLen; // A length of bar.
		if (_style & SWT.VERTICAL) {
			cLen = ca.height;
		} else {
			cLen = ca.width;
		}
		cLen -= _cWBtn * 2;
		int sRange = _sMax - _sMin; // A range of slider value.
		real sr = cast(real)cLen / sRange; // ratio
		int c = cast(int)(s * sr) + _cWBtn;

		// Adjustment of externals.
		if (_sMin < _sValue && c <= _cWBtn) {
			c = _cWBtn + 1;
		} else if (_sValue < _sMax && _cWBtn + cLen <= c) {
			c = _cWBtn + cLen - 1;
		}
		return c;
	}

	/// Raises selection event.
	void raiseSelectionEvent(Event e) {
		checkWidget();
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

	/// Draws slider.
	private void onPaint(Event e) {
		checkWidget();
		auto ca = this.p_clientArea;
		if (!(_style & SWT.VERTICAL)) {
			// Swap x and y coordinates,
			// To correspond to horizontal side.
			swap(ca.x, ca.y);
			swap(ca.width, ca.height);
		}
		auto d = e.display;
		auto colorDef = e.gc.p_background;
		auto color1 = d.getSystemColor(SWT.COLOR_WHITE);
		auto color2 = d.getSystemColor(SWT.COLOR_DARK_BLUE);
		auto color3 = d.getSystemColor(SWT.COLOR_BLUE);
		auto color4 = d.getSystemColor(SWT.COLOR_BLACK);
		int cMarkW = _cWBar / 2;
		int cMarkH = _cWBtn / 2;
		int cDLM = _cWBar / 2 - cMarkW / 2; // A distance from left to mark.
		int cDTM = _cWBtn / 2 - cMarkH / 2; // A distance from top to mark.

		// Calls e.gc.drawLine() according to a side.
		void cDrawLine(Color color, int cx1, int cy1, int cx2, int cy2) {
			e.gc.p_foreground = color;
			if (_style & SWT.VERTICAL) {
				e.gc.drawLine(cx1, cy1, cx2, cy2);
			} else {
				e.gc.drawLine(cy1, cx1, cy2, cx2);
			}
		}
		// Calls e.gc.fillRectangle() according to a side.
		void cFillRect(Color color, int cx, int cy, int cw, int ch) {
			e.gc.p_background = color;
			if (_style & SWT.VERTICAL) {
				e.gc.fillRectangle(cx, cy, cw, ch);
			} else {
				e.gc.fillRectangle(cy, cx, ch, cw);
			}
		}
		// Calls e.gc.drawFocus() according to a side.
		void cDrawFocus(Color color, int cx, int cy, int cw, int ch) {
			e.gc.p_background = color;
			if (_style & SWT.VERTICAL) {
				e.gc.drawFocus(cx, cy, cw, ch);
			} else {
				e.gc.drawFocus(cy, cx, ch, cw);
			}
		}
		// Calls e.gc.fillPolygon() according to a side.
		void cFillPoly(Color color, int[] cPoly) {
			e.gc.p_background = color;
			e.gc.p_antialias = SWT.ON;
			scope (exit) e.gc.p_antialias = SWT.DEFAULT;
			if (!(_style & SWT.VERTICAL)) {
				for (size_t i = 0; i < cPoly.length; i += 2) {
					swap(cPoly[i], cPoly[i + 1]);
				}
			}
			e.gc.fillPolygon(cPoly);
		}
		// Draws a button or a bar.
		void cDrawBox(int cx, int cy, int cw, int ch) {
			cFillRect(color2, cx + 1, cy + 1, cw - 2, ch - 2);
			if (ch > 2) {
				cFillRect(color2, cx + 2, cy + 2, cw - 4, ch - 4);
				cDrawLine(color3, cx + cw - 3, cy + 3, cx + cw - 3, cy + ch - 2);
				cDrawLine(color3, cx + 3, cy + ch - 3, cx + cw - 3, cy + ch - 3);
				cDrawLine(color4, cx + 2, cy + 3, cx + 2, cy + ch - 2);
				cDrawLine(color4, cx + 3, cy + 2, cx + cw - 3, cy + 2);
			}
		}
		// Draws a pushed button.
		void cDrawPushedBox(int cx, int cy, int cw, int ch) {
			cFillRect(color2, cx + 1, cy + 1, cw - 2, ch - 2);
			if (ch > 2) {
				cFillRect(color1, cx + 2, cy + 2, cw - 4, ch - 4);
			}
		}

		// background
		cFillRect(color1, ca.x, ca.y, ca.width, ca.height);

		// down button
		if (_mouse == Mouse.PushedDown) {
			cDrawPushedBox(0, 0, _cWBar, _cWBtn);
		} else {
			cDrawBox(0, 0, _cWBar, _cWBtn);
		}

		// up button
		if (_mouse == Mouse.PushedUp) {
			cDrawPushedBox(0, ca.height - _cWBtn, _cWBar, _cWBtn);
		} else {
			cDrawBox(0, ca.height - _cWBtn, _cWBar, _cWBtn);
		}

		// bar
		int cy = stoc(_sValue);
		if (_reverseView) {
			if (_sValue < _sMax) {
				cDrawBox(0, cy - 1, _cWBar, ca.height - _cWBtn - cy + 2);
			}
		} else {
			if (_sMin < _sValue) {
				cDrawBox(0, _cWBtn - 1, _cWBar, cy - _cWBtn + 2);
			}
		}

		// focus
		if (this.p_focusControl) {
			cDrawFocus(colorDef, ca.x, ca.y + _cWBtn - 1, ca.width, ca.height - _cWBtn * 2 + 2);
		}

		// Because e.gc.drawLine() doesn't work
		// when e.gc.setAntialias() is used,
		// call cFillPoly() late.
		auto cDPoly = [
			cDLM, cDTM + cMarkH,
			cDLM + cMarkW, cDTM + cMarkH,
			_cWBar / 2, cDTM,
		];
		cFillPoly(_mouse == Mouse.PushedDown ? color2 : color1, cDPoly);
		auto cUPoly = [
			cDLM, ca.height - (cDTM + cMarkH),
			cDLM + cMarkW, ca.height - (cDTM + cMarkH),
			_cWBar / 2, ca.height - (cDTM),
		];
		cFillPoly(_mouse == Mouse.PushedUp ? color2 : color1, cUPoly);
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

	/// Does up or down.
	private void onKeyDown(Event e) {
		checkWidget();
		if (_mouse != Mouse.None) return;
		switch (e.keyCode) {
		case SWT.ARROW_UP, SWT.ARROW_LEFT:
			this.p_selection = this.p_selection - _sInc;
			_mouse = Mouse.PushedDown;
			if (!_timer.isRunning) {
				initTimer();
				_timer.start();
			}
			break;
		case SWT.ARROW_DOWN, SWT.ARROW_RIGHT:
			this.p_selection = this.p_selection + _sInc;
			_mouse = Mouse.PushedUp;
			if (!_timer.isRunning) {
				initTimer();
				_timer.start();
			}
			break;
		case SWT.PAGE_UP:
			this.p_selection = this.p_selection - _sPageInc;
			break;
		case SWT.PAGE_DOWN:
			this.p_selection = this.p_selection + _sPageInc;
			break;
		default:
			return;
		}
		redraw();
		raiseSelectionEvent(e);
	}
	/// ditto
	private void onKeyUp(Event e) {
		checkWidget();
		switch (e.keyCode) {
		case SWT.ARROW_UP, SWT.ARROW_LEFT, SWT.ARROW_DOWN, SWT.ARROW_RIGHT:
			_mouse = Mouse.None;
			redraw();
			break;
		default:
			return;
		}
	}
	/// ditto
	private void onMouseDown(Event e) {
		checkWidget();
		if (e.button != 1) return;
		if (_mouse != Mouse.None) return;
		int s = ctos(e.x, e.y);
		_sPushedValue = this.p_selection;
		if (s < _sMin) {
			// At down button.
			this.p_selection = this.p_selection - _sInc;
			_mouse = Mouse.PushedDown;
			if (!_timer.isRunning) {
				initTimer();
				_timer.start();
			}
		} else if (_sMax < s) {
			// At up button.
			this.p_selection = this.p_selection + _sInc;
			_mouse = Mouse.PushedUp;
			if (!_timer.isRunning) {
				initTimer();
				_timer.start();
			}
		} else {
			this.p_selection = s;
			_mouse = Mouse.PushedBar;
		}
		redraw();
		raiseSelectionEvent(e);
	}
	/// ditto
	private void onMouseUp(Event e) {
		checkWidget();
		if (e.button != 1) return;
		_mouse = Mouse.None;
		redraw();
	}
	/// ditto
	private void onMouseWheel(Event e) {
		checkWidget();
		if (0 == e.count) return;
		int sVal;
		if (e.count < 0) {
			sVal = _sPageInc;
		} else {
			assert (0 < e.count);
			sVal = -_sPageInc;
		}

		this.p_selection = this.p_selection + sVal;
		redraw();
		raiseSelectionEvent(e);
	}
	/// ditto
	private void onMouseMove(Event e) {
		checkWidget();
		if (_mouse != Mouse.PushedBar) return;
		static immutable POINTER_MOVABLE_RANGE_X = 100;
		static immutable POINTER_MOVABLE_RANGE_Y = 10;
		auto cb = this.p_bounds;
		cb.x -= POINTER_MOVABLE_RANGE_X;
		cb.width += POINTER_MOVABLE_RANGE_X * 2;
		cb.y -= POINTER_MOVABLE_RANGE_Y;
		cb.height += POINTER_MOVABLE_RANGE_Y * 2;
		if (cb.contains(e.x, e.y)) {
			int s = max(_sMin, min(_sMax, ctos(e.x, e.y)));
			this.p_selection = s;
		} else {
			// pointer is away
			this.p_selection = _sPushedValue;
		}
		redraw();
		raiseSelectionEvent(e);
	}
	private void onFocusIn(Event e) {
		redraw();
	}
	private void onFocusOut(Event e) {
		redraw();
	}

	override int getStyle() {
		checkWidget();
		return super.getStyle() | _style;
	}

	alias Canvas.computeSize computeSize;

	override Point computeSize(int wHint, int hHint, bool changed) {
		checkWidget();
		int cbw = this.p_borderWidth * 2;
		int cw, ch;
		if (_style & SWT.VERTICAL) {
			cw = (wHint == SWT.DEFAULT) ? _cWBar + cbw : wHint;
			ch = (hHint == SWT.DEFAULT) ? _sMax - _sMin + _cWBtn * 2 + cbw : hHint;
		} else {
			cw = (wHint == SWT.DEFAULT) ? _sMax - _sMin + _cWBtn * 2 + cbw : wHint;
			ch = (hHint == SWT.DEFAULT) ? _cWBar + cbw : hHint;
		}
		return CPoint(cw, ch);
	}
}
