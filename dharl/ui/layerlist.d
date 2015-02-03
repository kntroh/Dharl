
/// This module includes LayerList and members related to it. 
///
/// License: Public Domain
/// Authors: kntroh
module dharl.ui.layerlist;

private import util.types;
private import util.undomanager;
private import util.utils;

private import dharl.ui.dwtutils;
private import dharl.ui.paintarea;

private import std.algorithm;
private import std.array;
private import std.conv;

private import java.lang.System;

private import org.eclipse.swt.all;

/// List of layers for PaintArea.
class LayerList : Canvas {
	/// Height of a layer view of one.
	private static immutable LAYER_H = 60;

	/// Show layers of this paintArea.
	private PaintArea _paintArea = null;

	/// Bounds of name area.
	private PBounds[] _nameBounds;
	/// Bounds of checkbox for visibility.
	private PBounds[] _vCheckBounds;
	/// Bounds of box for transparent pixel.
	private PBounds[] _transparentPixelBounds;

	/// Editor for layer name.
	private Editor _editor;
	/// Index of layer in editing name.
	private size_t _editing = 0;

	/// Manager of undo and redo operation.
	private UndoManager _um = null;

	/// The only constructor.
	this (Composite parent, int style) {
		super (parent, style | SWT.V_SCROLL);

		_editor = new Editor(this, true);

		auto d = parent.p_display;
		this.p_background = d.getSystemColor(SWT.COLOR_WHITE);
		this.p_foreground = d.getSystemColor(SWT.COLOR_BLUE);

		auto vs = this.p_verticalBar;
		assert (vs);
		vs.p_listeners!(SWT.Selection) ~= &redraw;

		this.bindListeners();
	}

	/// Manager of undo and redo operation.
	@property
	void undoManager(UndoManager um) { _um = um; }
	/// ditto
	@property
	const
	const(UndoManager) undoManager() { return _um; }

	/// Calculates parameters of scrollbars.
	private void calcScrollParams() {
		if (!_paintArea || _paintArea.image.empty) {
			return;
		}
		checkWidget();
		auto ca = this.p_clientArea;

		auto vs = this.p_verticalBar;
		assert (vs);

		int h = _paintArea.image.layerCount * (LAYER_H + 2);

		vs.setValues(vs.p_selection, 0, h, ca.height, ca.height / 10, ca.height / 2);

		redraw();
	}
	private void changedLayerReceiver() {
		if (!_paintArea || _paintArea.image.empty) {
			return;
		}
		checkWidget();
		_editor.cancel();

		_nameBounds.length = _paintArea.image.layerCount;
		_vCheckBounds.length = _paintArea.image.layerCount;
		_transparentPixelBounds.length = _paintArea.image.layerCount;
		calcScrollParams();

		auto se = new Event;
		se.widget = this;
		se.time = cast(int)System.currentTimeMillis();
		se.stateMask = 0;
		se.doit = true;
		notifyListeners(SWT.Selection, se);
	}

	/// Sets preview target image.
	void init(PaintArea paintArea) {
		checkWidget();
		_editor.cancel();
		if (_paintArea) {
			_paintArea.drawReceivers.removeReceiver(&redraw);
			_paintArea.changedLayerReceivers.removeReceiver(&changedLayerReceiver);
			_paintArea.image.restoreReceivers.removeReceiver(&redrawU);
		}
		if (paintArea) {
			paintArea.drawReceivers ~= &redraw;
			paintArea.changedLayerReceivers ~= &changedLayerReceiver;
			paintArea.image.restoreReceivers ~= &redrawU;
		}
		_paintArea = paintArea;
		changedLayerReceiver();
	}

	/// Gets layer index from coordinates.
	int indexOf(int x, int y) {
		if (!_paintArea || _paintArea.image.empty) {
			return -1;
		}
		checkWidget();
		auto vs = this.p_verticalBar;
		assert (vs);
		y += vs.p_selection;

		int i = y / (LAYER_H + 2);
		if (_paintArea.image.layerCount <= i) {
			return -1;
		}
		return i;
	}

	/// Edit layer name.
	void editLayerName(size_t l) {
		if (!_paintArea || _paintArea.image.empty) {
			return;
		}
		checkWidget();
		_editor.cancel();

		_editing = l;
		auto b = _nameBounds[l];
		_editor.start(b.x, b.y, _paintArea.image.layer(l).name, (string name) {
			auto img = _paintArea.image;
			if (img.layer(l).name == name) return;
			if (_um) _um.store(img);
			img.layer(l).name = name;
			redraw();
		});
	}

	/// Bounds of name area.
	@property
	const
	const(PBounds)[] nameBounds() { return _nameBounds; }
	/// Bounds of checkbox for visibility.
	@property
	const
	const(PBounds)[] visibilityBoxBounds() { return _vCheckBounds; }
	/// Bounds of box for transparent pixel.
	@property
	const
	const(PBounds)[] transparentPixelBoxBounds() { return _transparentPixelBounds; }

	/// Selects all layers.
	void selectAll() {
		if (!_paintArea || _paintArea.image.empty) {
			return;
		}
		checkWidget();

		_paintArea.selectedInfo = .replicate([true], _paintArea.image.layerCount);
	}

	/// Scrolls to showing selection item.
	void showSelection() {
		if (!_paintArea || _paintArea.image.empty) {
			return;
		}
		checkWidget();
		auto ca = this.p_clientArea;
		auto vs = this.p_verticalBar;
		assert (vs);

		int lh = LAYER_H + 2;

		int vFrom = vs.p_selection;
		int vTo = vFrom + ca.height;

		auto selLayer = _paintArea.selectedInfo;
		int up = int.max, down = int.max; // Scroll distance (minimum value).
		foreach (l; 0 .. _paintArea.image.layerCount) {
			if (!selLayer[l]) continue;
			int lFrom = lh * l;
			int lTo = lFrom + lh;
			if (vFrom <= lFrom && lTo <= vTo) {
				// l is being shown.
				return;
			}
			if (lFrom < vFrom) up = .min(vFrom - lFrom, up);
			if (vTo < lTo) down = .min(lTo - vTo, down);
		}
		if (int.max == up && int.max == down) return;
		_editor.cancel();
		if (up <= down) {
			vs.p_selection = vs.p_selection - up;
		} else {
			vs.p_selection = vs.p_selection + down;
		}
	}

	/// Calls redraw().
	private void redrawU(UndoMode mode) { redraw(); }

	/// Raises selection event.
	private void raiseSelectionEvent(Event e) {
		auto se = new Event;
		se.widget = this;
		se.time = e.time;
		se.stateMask = e.stateMask;
		se.doit = e.doit;
		notifyListeners(SWT.Selection, se);
		e.doit = se.doit;
	}

	/// Adds or removes a listener for image selection event.
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

	private void onResize(Event e) {
		if (!_paintArea || _paintArea.image.empty) {
			return;
		}
		checkWidget();
		calcScrollParams();
	}

	private void onDispose(Event e) {
		_editor.cancel();
		checkWidget();
		if (_paintArea && !_paintArea.p_disposed) {
			_paintArea.drawReceivers.removeReceiver(&redraw);
			_paintArea.changedLayerReceivers.removeReceiver(&calcScrollParams);
			_paintArea.image.restoreReceivers.removeReceiver(&redrawU);
		}
	}

	/// Draws layers list.
	private void onPaint(Event e) {
		if (!_paintArea || _paintArea.image.empty) {
			return;
		}
		checkWidget();
		auto d = this.p_display;
		auto ca = this.p_clientArea;

		auto vs = this.p_verticalBar;
		assert (vs);
		int vss = vs.p_selection;

		int y = -vss;
		auto selLayer = _paintArea.selectedInfo;
		auto ib = CRect(0, 0, _paintArea.image.width, _paintArea.image.height);
		int w;
		if (LAYER_H < ib.height) {
			w = cast(int)(ib.width * (cast(real)LAYER_H / ib.height));
		} else {
			w = ib.width;
		}
		int th = e.gc.p_fontMetrics.p_height;

		static immutable V_CHECK_W = 22;
		static immutable V_CHECK_H = 16;
		auto tPixelFont = pixelTextFont(d, e.gc.p_font, V_CHECK_W, V_CHECK_H);
		scope (exit) tPixelFont.dispose();

		foreach (l; 0 .. _paintArea.image.layerCount) {
			if (vss + ca.height <= y) break;
			if (0 <= y + LAYER_H + 2) {
				auto img = _paintArea.showingImage(l, true, null);
				auto layer = _paintArea.image.layer(l);
				scope (exit) img.dispose();

				if (selLayer[l]) {
					// Draws selection mark.
					e.gc.p_background = d.getSystemColor(SWT.COLOR_DARK_BLUE);
					e.gc.fillRectangle(w + 1, y - 1, ca.width - (w + 1), LAYER_H + 2 + 1);

					e.gc.p_lineStyle = SWT.LINE_SOLID;
					int ly = y - 1;
					e.gc.drawLine(0, ly, ca.width, ly);
					ly = y + LAYER_H + 1;
					e.gc.drawLine(0, ly, ca.width, ly);

					// color of name text.
					e.gc.p_foreground = d.getSystemColor(SWT.COLOR_WHITE);
				} else {
					// color of name text.
					e.gc.p_foreground = d.getSystemColor(SWT.COLOR_BLACK);
				}

				// Draws layer name.
				string name = layer.name;
				int tx = w + 2;
				int ty = y;
				if (!_editor.editing || _editing != l) {
					e.gc.drawText(name, tx, ty, true);
				}
				auto ts = e.gc.textExtent(name);
				_nameBounds[l] = PBounds(tx, ty, max(10, ts.x), th);

				// Draws checkbox of visibility.
				int vx = tx;
				int vy = ty + th + 2;
				e.gc.p_lineStyle = SWT.LINE_SOLID;
				e.gc.p_foreground = d.getSystemColor(SWT.COLOR_BLACK);
				e.gc.p_background = d.getSystemColor(SWT.COLOR_WHITE);
				e.gc.fillRectangle(vx, vy, V_CHECK_W, V_CHECK_H);
				e.gc.drawRectangle(vx, vy, V_CHECK_W - 1, V_CHECK_H - 1);
				if (layer.visible) {
					e.gc.p_background = d.getSystemColor(SWT.COLOR_DARK_BLUE);
					e.gc.fillRectangle(vx + 2, vy + 2, V_CHECK_W - 4, V_CHECK_H - 4);
				}
				_vCheckBounds[l] = PBounds(vx, vy, V_CHECK_W, V_CHECK_H);

				// Draws transparent pixel box.
				vx += V_CHECK_W + 2;
				e.gc.p_foreground = d.getSystemColor(SWT.COLOR_BLACK);
				e.gc.p_background = d.getSystemColor(SWT.COLOR_WHITE);
				e.gc.fillRectangle(vx, vy, V_CHECK_W, V_CHECK_H);
				e.gc.drawRectangle(vx, vy, V_CHECK_W - 1, V_CHECK_H - 1);
				auto imgData = _paintArea.image.layer(l).image;
				auto tPixel = imgData.transparentPixel;
				void tPixelText(string t) {
					e.gc.p_font = tPixelFont;
					auto cSize = e.gc.textExtent(t);
					auto ctx = vx + (V_CHECK_W - cSize.x) / 2;
					auto cty = vy + (V_CHECK_H - cSize.y) / 2;
					e.gc.drawText(t, ctx, cty, true);
				}
				if (0 <= tPixel) {
					auto rgb = imgData.palette.getRGB(tPixel);
					auto tColor = new Color(d, rgb);
					scope (exit) tColor.dispose();
					e.gc.p_background = tColor;
					e.gc.fillRectangle(vx + 2, vy + 2, V_CHECK_W - 4, V_CHECK_H - 4);
					e.gc.p_foreground = pixelTextColor(d, rgb);
					tPixelText(.text(tPixel));
				} else {
					e.gc.p_foreground = pixelTextColor(d, e.gc.p_background.p_rgb);
					tPixelText("-");
				}
				_transparentPixelBounds[l] = PBounds(vx, vy, V_CHECK_W, V_CHECK_H);

				// Draws image preview.
				if (LAYER_H - 1 < ib.height) {
					e.gc.drawImage(img, ib.x, ib.y, ib.width, ib.height, 1, y + 1, w - 1, LAYER_H - 1);
				} else {
					int iy = y;
					if (ib.height < LAYER_H) iy += (LAYER_H - ib.height) / 2;
					e.gc.drawImage(img, ib.x + 1, iy + 1);
				}

				e.gc.p_foreground = d.getSystemColor(SWT.COLOR_DARK_BLUE);
				int ly = y + LAYER_H + 1;
				e.gc.p_lineStyle = SWT.LINE_DOT;
				e.gc.drawLine(0, ly, ca.width, ly);
			}
			y += LAYER_H + 2;
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
	/// Change selection.
	private void onKeyDown(Event e) {
		checkWidget();
		auto sels =  _paintArea.selectedLayers;
		if (0 == sels.length) {
			switch (e.keyCode) {
			case SWT.ARROW_LEFT, SWT.ARROW_UP:
				sels ~= [_paintArea.image.layerCount - 1];
				break;
			case SWT.ARROW_RIGHT, SWT.ARROW_DOWN:
				sels ~= [0];
				break;
			default: return;
			}
			_paintArea.selectedLayers = sels;
			raiseSelectionEvent(e);
			return;
		}
		if (SWT.F2 == e.keyCode) {
			editLayerName(sels[0]);
			return;
		}
		bool range = (e.stateMask & SWT.SHIFT) || (e.stateMask & SWT.CTRL);
		size_t nl;
		switch (e.keyCode) {
		case SWT.ARROW_LEFT, SWT.ARROW_UP:
			if (0 < sels[0]) {
				nl = sels[0] - 1;
			} else {
				nl = _paintArea.image.layerCount - 1;
			}
			break;
		case SWT.ARROW_RIGHT, SWT.ARROW_DOWN:
			nl = (sels[$ - 1] + 1) % _paintArea.image.layerCount;
			break;
		default: return;
		}
		if (range) {
			sels ~= nl;
		} else {
			sels.length = 1;
			sels[0] = nl;
		}
		_paintArea.selectedLayers = sels;
		raiseSelectionEvent(e);
	}

	/// Selects layer.
	private void onMouseDown(Event e) {
		if (!_paintArea || _paintArea.image.empty) {
			return;
		}
		checkWidget();
		forceFocus();
		if (1 != e.button && 3 != e.button) return;
		bool reverse = (e.stateMask & SWT.SHIFT) || (e.stateMask & SWT.CTRL) || 3 == e.button;

		int l = indexOf(e.x, e.y);
		if (-1 == l) return;
		if (1 == e.button) {
			auto b = _nameBounds[l];
			if (b.contains(e.x, e.y)) {
				editLayerName(l);
				return;
			}
		}
		auto vb = _vCheckBounds[l];
		if (vb.contains(e.x, e.y)) {
			auto img = _paintArea.image;
			img.layer(l).visible = !img.layer(l).visible;
			_paintArea.redraw();
			_paintArea.drawReceivers.raiseEvent();
			return;
		}

		auto info = _paintArea.selectedInfo;
		if (reverse) {
			info[l] = !info[l];
			// Must selected one layer least.
			foreach (b; info) {
				if (b) {
					_paintArea.selectedInfo = info;
					break;
				}
			}
		} else {
			size_t[1] sel = [l];
			_paintArea.selectedLayers = sel;
		}
		raiseSelectionEvent(e);
	}

	/// Switch selection layer.
	private void onMouseWheel(Event e) {
		checkWidget();
		if (0 == e.count) return;

		auto layers = _paintArea.selectedLayers.sort;
		if (e.count > 0) {
			// up
			if (layers[0] <= 0) return;
			layers = [layers[0] - 1];
		} else {
			assert (e.count < 0);
			// down
			if (_paintArea.image.layerCount <= layers[$ - 1] + 1) return;
			layers = [layers[$ - 1] + 1];
		}
		_paintArea.selectedLayers = layers;
		showSelection();
		raiseSelectionEvent(e);
	}

	override Point computeSize(int wHint, int hHint, bool changed) {
		checkWidget();
		int cbw = this.p_borderWidth * 2;
		int cw = (wHint == SWT.DEFAULT) ? LAYER_H + cbw : wHint;
		int ch = (hHint == SWT.DEFAULT) ? LAYER_H + cbw : hHint;
		return CPoint(cw, ch);
	}
}
