
/// This module includes PaintArea and members related to it. 
///
/// License: Public Domain
/// Authors: kntroh
module dharl.ui.paintarea;

private import util.graphics;
private import util.types;
private import util.undomanager;
private import util.utils;

private import dharl.image.mlimage;

private import dharl.ui.dwtutils;

private import std.algorithm;
private import std.array;
private import std.conv;
private import std.datetime;
private import std.exception;
private import std.string;

private import org.eclipse.swt.all;

private import java.lang.all : System;

/// This class has a image by division layers,
/// Edit from user to each layer is accepted. 
class PaintArea : Canvas, Undoable {
	static const ZOOM_MAX = 32;

	/// Receivers of draw event.
	void delegate()[] drawReceivers;
	/// Receivers of status changed event.
	void delegate()[] statusChangedReceivers;
	/// Receivers of select changed event.
	void delegate(int x, int y, int w, int h)[] selectChangedReceivers;
	/// Receivers of restore event.
	void delegate(UndoMode mode)[] restoreReceivers;
	/// Receivers of changed layer event.
	void delegate()[] changedLayerReceivers;
	/// Receivers of area resized event.
	void delegate(int w, int h)[] resizeReceivers;
	/// Receivers of change mask event.
	void delegate(size_t pixel)[] changedMaskReceivers;

	/// ID of this instance.
	private string _id;

	/// The image in drawing.
	private MLImage _image = null;
	/// Selection layers.
	private size_t[] _layers = [0];
	/// Layer of source of paste.
	private MLImage _pasteLayer = null;
	/// A coordinates of mouse cursor temporary for moving pasteLayer.
	private int _iPCatchX, _iPCatchY;

	/// Index of selection color.
	private size_t _pixel = 0;
	/// Index of background color.
	private size_t _backPixel = 1;

	/// Index of color temporary for iGetPixels().
	private int[] _pixelsTemp;

	/// Is enabled background color?
	private bool _enabledBackColor = false;

	/// Settings of mask color.
	private bool[256] _mask;

	/// Zoom magnification.
	private uint _zoom = 1;

	/// Cursor.
	private Point _iCurFrom, _iCurTo;
	/// Cursor size.
	private uint _iCurSize = 1;

	/// Range selection mode.
	private bool _rangeSel = false;
	/// Selection range.
	private Rectangle _iSelRange;
	/// Range of moving.
	private Rectangle _iMoveRange;
	/// When moving is true.
	private bool _moving = false;
	/// Direction of caught point of selection range.
	private bool _catchN = false;
	private bool _catchE = false; /// ditto
	private bool _catchS = false; /// ditto
	private bool _catchW = false; /// ditto
	/// Caught coordinates.
	private int _iCatchX = -1, _iCatchY = -1;
	/// Last selected range before caught.
	private Rectangle _iOldSelRange;

	/// Doesn't send select changed event with same value continuously. 
	private Rectangle _iOldCursorArea = null;

	/// Paint mode.
	private PaintMode _mode = PaintMode.FreePath;

	/// Is mouse button downing?
	private int _mouseDown = -1;
	/// Is there mouse cursor?
	private bool _mouseEnter = false;

	/// Manager of undo operation.
	private UndoManager _um = null;

	/// Tone.
	private bool[][] _tone = null;

	/// Showing grid?
	private bool _grid1 = false, _grid2 = false;

	/// Canvas size.
	private uint _iCanvasW = 0, _iCanvasH = 0;

	/// Cache of showingIamge().
	private Image[] _cache = [];

	/// A cursor of every paint mode.
	private Cursor[PaintMode] _cursor;

	/// A cursor of dropper mode.
	private Cursor _cursorDropper = null;
	/// A cursor of range selection mode.
	private Cursor _cursorSelRange = null;

	/// Cache of wallpaper.
	private Image _shadeCache = null;
	/// Size of wallpaper cache.
	private Rectangle _shadeCacheRect = null;

	/// Tooltip for display of status.
	private ToolTip _status = null;
	/// Format of status texts.
	private string _statusTextXY = "%s, %s";
	/// ditto
	private string _statusTextRange = "%s, %s to %s, %s (%s x %s)";

	/// The only constructor.
	this (Composite parent, int style) {
		super (parent, style | SWT.H_SCROLL | SWT.V_SCROLL | SWT.NO_BACKGROUND);
		_id = format("%x-%d", &this, Clock.currTime().stdTime);

		_image = new MLImage;
		_image.resizeReceivers ~= &resizeReceiver;
		_image.initializeReceivers ~= &resizeReceiver;
		_iCurFrom = CPoint(0, 0);
		_iCurTo = CPoint(0, 0);
		_iSelRange = CRect(0, 0, 0, 0);
		_iMoveRange = CRect(0, 0, 0, 0);
		_iOldSelRange = CRect(0, 0, 0, 0);

		_status = basicToolTip(this.p_shell, false);

		auto d = parent.p_display;
		this.p_background = d.getSystemColor(SWT.COLOR_GRAY);
		this.p_foreground = d.getSystemColor(SWT.COLOR_DARK_GRAY);

		auto hs = this.p_horizontalBar;
		assert (hs);
		hs.p_listeners!(SWT.Selection) ~= &redraw;
		auto vs = this.p_verticalBar;
		assert (vs);
		vs.p_listeners!(SWT.Selection) ~= &redraw;

		this.bindListeners();
	}

	/// Calculates parameters of scrollbars.
	private void calcScrollParams() {
		checkWidget();
		auto ca = this.p_clientArea;

		// list size
		int cw = itoc(_image.width);
		int ch = itoc(_image.height);

		auto hs = this.p_horizontalBar;
		assert (hs);
		auto vs = this.p_verticalBar;
		assert (vs);

		vs.setValues(vs.p_selection, 0, ch, ca.height, ca.height / 10, ca.height / 2);
		bool vsv = vs.p_visible;
		vs.p_visible = ca.height < ch;
		if (vsv != vs.p_visible) {
			ca = this.p_clientArea;
		}
		hs.setValues(hs.p_selection, 0, cw, ca.width, ca.width / 10, ca.width / 2);
		hs.p_visible = ca.width < cw;
	}

	/// If doesn't initialized throws exception.
	const
	private void checkInit() {
		enforce(isInitialized, new Exception("PantArea is no initialized.", __FILE__, __LINE__));
	}
	/// Is initialized?
	@property
	const
	bool isInitialized() {
		return _image !is null;
	}

	private void raiseSelectChangedEvent() {
		auto ia = iCursorArea;
		if (!_iOldCursorArea || _iOldCursorArea != ia) {
			_iOldCursorArea = ia;
			selectChangedReceivers.raiseEvent(ia.x, ia.y, ia.width, ia.height);
		}
	}

	/// Initializes this paint area.
	/// If call a other methods before called this,
	/// it throws exception.
	void init(ImageData image, string layerName) {
		checkWidget();
		_pixel = 1;
		_backPixel = 0;
		_image.resizeReceivers.removeReceiver(&resizeReceiver);
		scope (exit) _image.resizeReceivers ~= &resizeReceiver;
		_image.init(image, layerName);
		clearCache(false);
	}
	/// ditto
	void init(uint w, uint h, PaletteData palette) {
		checkWidget();
		_pixel = 1;
		_backPixel = 0;
		_image.resizeReceivers.removeReceiver(&resizeReceiver);
		scope (exit) _image.resizeReceivers ~= &resizeReceiver;
		_image.init(w, h, palette);
		clearCache(false);
	}

	private void resizeReceiver() {
		cancelPaste();
		calcScrollParams();
		redraw();
		int iw = _image.width;
		int ih = _image.height;
		resizeReceivers.raiseEvent(iw, ih);
		statusChangedReceivers.raiseEvent();
	}

	/// Manager of undo and redo operation.
	@property
	void undoManager(UndoManager um) { _um = um; }
	/// ditto
	@property
	const
	const(UndoManager) undoManager() { return _um; }

	/// Returns image in this paintArea.
	@property
	MLImage image() {
		checkWidget();
		checkInit();
		return _image;
	}
	/// ditto
	@property
	const
	const(MLImage) image() {
		checkInit();
		return _image;
	}

	/// Push src to image in this paintArea starting from srcX and srcY.
	bool pushImage(MLImage src, int srcX, int srcY) {
		if (!src) {
			SWT.error(__FILE__, __LINE__, SWT.ERROR_NULL_ARGUMENT);
		}
		checkWidget();
		checkInit();
		cancelPaste();

		if (_um) _um.store(this);
		auto r = _image.pushImage(src, srcX, srcY, _backPixel);

		size_t[] layers;
		foreach (l; _layers) {
			if (l < _image.layerCount) {
				layers ~= l;
			}
		}
		if (!layers.length) layers ~= _image.layerCount - 1;
		_layers = layers;

		clearCache(false);
		redraw();

		drawReceivers.raiseEvent();
		changedLayerReceivers.raiseEvent();
		statusChangedReceivers.raiseEvent();

		return r;
	}

	/// If image haven't layer, returns true.
	@property
	const
	bool empty() {
		checkInit();
		return _image.empty;
	}

	/// Adds layer.
	/// A layer after second,
	/// is a first color treats as transparent pixel.
	void addLayer(size_t index, string layerName) {
		if (!layerName) {
			SWT.error(__FILE__, __LINE__, SWT.ERROR_NULL_ARGUMENT);
		}
		checkWidget();
		checkInit();
		if (!_image.empty) {
			if (_um) _um.store(this);
		}
		_image.addLayer(index, layerName);
		_layers.length = 1;
		_layers[0] = index;
		clearCache(false);
		changedLayerReceivers.raiseEvent();
		statusChangedReceivers.raiseEvent();
	}
	/// Removes layer.
	void removeLayer(size_t index) {
		if (_image.layerCount <= index) {
			SWT.error(__FILE__, __LINE__, SWT.ERROR_INVALID_ARGUMENT);
		}
		checkWidget();
		checkInit();
		if (_um) _um.store(this);
		if (1 == _image.layerCount) {
			// Last layer don't remove. clear it.
			auto ib = CRect(0, 0, _image.width, _image.height);
			iFillRect((int ix, int iy) {
				iSetPixels(ix, iy, _backPixel);
			}, ib);
			clearCache(false);
			drawReceivers.raiseEvent();
			return;
		}
		_image.removeLayer(index);
		_layers = remove!(SwapStrategy.unstable)(_layers, index);
		if (!_layers.length) {
			_layers.length = 1;
			_layers[0] = .min(index, _image.layerCount - 1);
		}
		clearCache(false);
		redraw();
		drawReceivers.raiseEvent();
		changedLayerReceivers.raiseEvent();
		statusChangedReceivers.raiseEvent();
	}
	/// ditto
	void removeLayers(size_t from, size_t to) {
		if (from >= to) {
			SWT.error(__FILE__, __LINE__, SWT.ERROR_INVALID_ARGUMENT);
		}
		if (_image.layerCount < to) {
			SWT.error(__FILE__, __LINE__, SWT.ERROR_INVALID_ARGUMENT);
		}
		assert (from < _image.layerCount);
		checkWidget();
		checkInit();
		if (_um) _um.store(this);
		if (_image.layerCount == to - from) {
			// Last layer don't remove. clear it.
			assert (0 == from);
			from++;
			auto ib = CRect(0, 0, _image.width, _image.height);
			iFillRect((int ix, int iy) {
				iSetPixel(ix, iy, _backPixel, 0, true);
			}, ib);
			if (from == to) {
				clearCache(false);
				drawReceivers.raiseEvent();
				return;
			}
		}
		_image.removeLayers(from, to);
		size_t index = _layers[0];
		size_t[] nLayers;
		foreach (l; _layers) {
			if (l < from || to <= l) {
				nLayers ~= l;
			}
		}
		_layers = nLayers;
		if (!_layers.length) {
			_layers.length = 1;
			if (_image.layerCount <= index) {
				index = _image.layerCount - 1;
			}
			_layers[0] = index;
		}
		clearCache(false);
		redraw();
		drawReceivers.raiseEvent();
		changedLayerReceivers.raiseEvent();
		statusChangedReceivers.raiseEvent();
	}
	/// Swap layer index.
	void swapLayers(size_t index1, size_t index2) {
		if (_image.layerCount < index1) {
			SWT.error(__FILE__, __LINE__, SWT.ERROR_INVALID_ARGUMENT);
		}
		if (_image.layerCount < index2) {
			SWT.error(__FILE__, __LINE__, SWT.ERROR_INVALID_ARGUMENT);
		}
		checkWidget();
		checkInit();
		if (index1 == index2) return;
		if (_um) _um.store(this);
		_image.swapLayers(index1, index2);

		int sel1 = _layers.countUntil(index1);
		int sel2 = _layers.countUntil(index2);
		if (sel1 != -1 && sel2 == -1) {
			selectedLayers = _layers.remove!(SwapStrategy.stable)(sel1) ~ index2;
		}
		if (sel1 == -1 && sel2 != -1) {
			selectedLayers = _layers.remove!(SwapStrategy.stable)(sel2) ~ index1;
		}

		clearCache(false);
		redraw();
		drawReceivers.raiseEvent();
		changedLayerReceivers.raiseEvent();
		statusChangedReceivers.raiseEvent();
	}
	/// Unite layers
	void uniteLayers(size_t destIndex, size_t srcIndex) {
		if (_image.layerCount <= destIndex) {
			SWT.error(__FILE__, __LINE__, SWT.ERROR_INVALID_ARGUMENT);
		}
		if (_image.layerCount <= srcIndex) {
			SWT.error(__FILE__, __LINE__, SWT.ERROR_INVALID_ARGUMENT);
		}
		checkWidget();
		checkInit();
		if (destIndex == srcIndex) return;
		if (_um) _um.store(this);
		_image.uniteLayers(destIndex, srcIndex);
		_layers = remove!(SwapStrategy.unstable)(_layers, srcIndex);
		if (!_layers.length) {
			_layers.length = 1;
			_layers[0] = .min(srcIndex, _image.layerCount - 1);
		}
		clearCache(false);
		redraw();
		drawReceivers.raiseEvent();
		changedLayerReceivers.raiseEvent();
		statusChangedReceivers.raiseEvent();
	}

	/// Sets selection indices of layers.
	@property
	void selectedLayers(in size_t[] layers) {
		if (!layers) {
			SWT.error(__FILE__, __LINE__, SWT.ERROR_NULL_ARGUMENT);
		}
		foreach (l; layers) {
			if (_image.layerCount <= l) {
				SWT.error(__FILE__, __LINE__, SWT.ERROR_INVALID_ARGUMENT);
			}
		}
		checkWidget();
		checkInit();

		auto ls = layers.dup.sort().uniq().array();
		if (_layers == ls) return;

		fixPaste();
		_layers = ls;
		clearCache(false);
		redrawCursorArea();
		drawReceivers.raiseEvent();
	}
	/// ditto
	@property
	const
	size_t[] selectedLayers() {
		checkInit();
		if (_image.empty) return [];
		return _layers.dup;
	}
	/// ditto
	@property
	const
	bool[] selectedInfo()
	out (result) {
		assert (result.length == _image.layerCount);
	} body {
		checkInit();
		auto r = new bool[_image.layerCount];
		foreach (l; _layers) {
			r[l] = true;
		}
		return r;
	}
	/// ditto
	@property
	void selectedInfo(in bool[] info) {
		if (!info) {
			SWT.error(__FILE__, __LINE__, SWT.ERROR_NULL_ARGUMENT);
		}
		if (info.length != _image.layerCount) {
			SWT.error(__FILE__, __LINE__, SWT.ERROR_INVALID_ARGUMENT);
		}
		checkWidget();
		checkInit();
		size_t[] sel;
		foreach (l, b; info) {
			if (b) sel ~= l;
		}
		selectedLayers = sel;
	}

	/// Gets selection range.
	@property
	Rectangle selectedArea() {
		checkWidget();
		checkInit();
		if (empty || !_rangeSel) return CRect(0, 0, 0, 0);
		return iCursorArea;
	}

	/// Selection pixel (Index of palette).
	@property
	const
	size_t pixel() { return _pixel; }
	/// ditto
	@property
	void pixel(size_t v) {
		checkWidget();
		checkInit();
		if (_image.palette.colors.length <= v) {
			SWT.error(__FILE__, __LINE__, SWT.ERROR_INVALID_ARGUMENT);
		}
		_pixel = v;
		clearCache(false);
		redrawCursorArea();
		drawReceivers.raiseEvent();
	}

	/// Background pixel (Index of palette).
	@property
	const
	size_t backgroundPixel() { return _backPixel; }
	/// ditto
	@property
	void backgroundPixel(size_t v) {
		checkWidget();
		checkInit();
		if (_image.palette.colors.length <= v) {
			SWT.error(__FILE__, __LINE__, SWT.ERROR_INVALID_ARGUMENT);
		}
		_backPixel = v;
		if (_pasteLayer) {
			clearCache(false);
			redrawCursorArea();
			drawReceivers.raiseEvent();
		}
	}

	/// Is enabled background color?
	@property
	const
	bool enabledBackColor() { return _enabledBackColor; }
	/// ditto
	@property
	void enabledBackColor(bool v) {
		checkWidget();
		checkInit();
		_enabledBackColor = v;
		if (_pasteLayer) {
			clearCache(false);
			redrawCursorArea();
			drawReceivers.raiseEvent();
		}
		statusChangedReceivers.raiseEvent();
	}

	/// Transparent pixel (Index of palette).
	@property
	const
	int transparentPixel(size_t layer) {
		checkInit();
		return _image.layer(layer).image.transparentPixel;
	}
	/// ditto
	@property
	void transparentPixel(size_t layer, int v) {
		checkWidget();
		checkInit();
		if (v < -1 || cast(int)_image.palette.colors.length <= v) {
			SWT.error(__FILE__, __LINE__, SWT.ERROR_INVALID_ARGUMENT);
		}
		_image.layer(layer).image.transparentPixel = v;
		clearCache(false);
		redraw();
		drawReceivers.raiseEvent();
	}

	/// Settings of mask color.
	@property
	const
	const(bool)[] mask() { return _mask; }
	/// ditto
	@property
	void mask(in bool[] v) {
		if (!v) {
			SWT.error(__FILE__, __LINE__, SWT.ERROR_NULL_ARGUMENT);
		}
		if (v.length != _mask.length) {
			SWT.error(__FILE__, __LINE__, SWT.ERROR_INVALID_ARGUMENT);
		}
		checkWidget();
		_mask[] = v[0 .. _mask.length];
		clearCache(false);
		redrawCursorArea();
		drawReceivers.raiseEvent();
	}

	/// Tone. A default value is null.
	@property
	const
	const(bool[])[] tone() { return _tone; }
	/// ditto
	@property
	void tone(in bool[][] v) {
		if (v && 0 < v.length) {
			/// v must be a rectangle.
			if (!v[0]) {
				SWT.error(__FILE__, __LINE__, SWT.ERROR_NULL_ARGUMENT);
			}
			size_t w = v[0].length;
			foreach (i; 1 .. v.length) {
				if (!v[i]) {
					SWT.error(__FILE__, __LINE__, SWT.ERROR_NULL_ARGUMENT);
				}
				if (v[i].length != w) {
					SWT.error(__FILE__, __LINE__, SWT.ERROR_INVALID_ARGUMENT);
				}
			}
		}
		checkWidget();
		_tone = new bool[][v.length];
		foreach (i, ref ln; _tone) {
			ln = v[i].dup;
		}
		clearCache(false);
		redrawCursorArea();
		drawReceivers.raiseEvent();
	}

	/// Showing grid?
	@property
	void grid1(bool v) {
		checkWidget();
		checkInit();
		if (_grid1 == v) return;
		_grid1 = v;
		redraw();
		statusChangedReceivers.raiseEvent();
	}
	/// ditto
	@property
	const
	bool grid1() {
		checkInit();
		return _grid1;
	}
	/// ditto
	@property
	void grid2(bool v) {
		checkWidget();
		checkInit();
		if (_grid2 == v) return;
		_grid2 = v;
		redraw();
		statusChangedReceivers.raiseEvent();
	}
	/// ditto
	@property
	const
	bool grid2() {
		checkInit();
		return _grid2;
	}

	/// Canvas size.
	void setCanvasSize(uint w, uint h) {
		checkWidget();
		checkInit();
		if (_iCanvasW == w && _iCanvasH == h) return;
		_iCanvasW = w;
		_iCanvasH = h;
		redraw();
	}
	/// ditto
	@property
	const
	Point canvasSize() {
		checkInit();
		return CPoint(_iCanvasW, _iCanvasH);
	}

	/// Gets palette.
	@property
	const
	const(PaletteData) palette() {
		checkInit();
		return _image.palette;
	}

	/// Gets color of palette.
	const
	RGB color(size_t index) {
		checkInit();
		return _image.color(index);
	}
	/// Sets color of palette.
	void color(size_t index, int r, int g, int b) {
		checkWidget();
		checkInit();
		_image.color(index, r, g, b);
		if (_pasteLayer) {
			_pasteLayer.color(index, r, g, b);
		}
		clearCache(false);
		redraw();
		drawReceivers.raiseEvent();
	}
	/// Sets color of palette.
	void color(size_t index, in RGB rgb) {
		checkWidget();
		checkInit();
		_image.color(index, rgb);
		if (_pasteLayer) {
			_pasteLayer.color(index, rgb);
		}
		clearCache(false);
		redraw();
		drawReceivers.raiseEvent();
	}
	/// Sets all colors.
	@property
	void colors(in RGB[] rgbs) {
		checkWidget();
		checkInit();
		_image.colors = rgbs;
		if (_pasteLayer) {
			_pasteLayer.colors = rgbs;
		}
		clearCache(false);
		redraw();
		drawReceivers.raiseEvent();
	}
	/// Swap pixel colors.
	void swapColor(int pixel1, int pixel2) {
		checkWidget();
		checkInit();

		_image.swapColor(pixel1, pixel2);

		clearCache(false);
		redraw();
		drawReceivers.raiseEvent();
	}

	/// Sets palettes.
	void setPalettes(in PaletteData[] palettes, size_t selectedPalette) {
		checkWidget();
		checkInit();
		_image.setPalettes(palettes, selectedPalette);
		this.selectedPalette = selectedPalette;
	}
	/// Gets palette.
	@property
	const
	const(PaletteData)[] palettes() {
		checkInit();
		return _image.palettes;
	}

	/// Index of selection palette.
	@property
	const
	size_t selectedPalette() {
		checkInit();
		return _image.selectedPalette;
	}
	/// ditto
	@property
	void selectedPalette(size_t index) {
		checkWidget();
		checkInit();
		_image.selectedPalette = index;
		if (_pasteLayer) {
			_pasteLayer.colors = this.palette.colors;
		}
		clearCache(false);
		redraw();
		drawReceivers.raiseEvent();
	}

	/// Zoom magnification.
	@property
	const
	uint zoom() {
		checkInit();
		return _zoom;
	}
	/// ditto
	@property
	void zoom(uint v) {
		checkWidget();
		checkInit();
		if (v == _zoom) return;
		_zoom = v;
		calcScrollParams();

		clearCache(false);
		redraw();
		drawReceivers.raiseEvent();
	}

	/// Range selection mode.
	@property
	const
	bool rangeSelection() {
		checkInit();
		return _rangeSel;
	}
	/// ditto
	@property
	void rangeSelection(bool v) {
		checkWidget();
		checkInit();
		if (_rangeSel == v) return;
		fixPaste();
		redrawCursorArea();
		_rangeSel = v;
		_mouseDown = -1;
		resetSelectedRange();

		clearCache(false);
		redrawCursorArea();
		drawReceivers.raiseEvent();
		statusChangedReceivers.raiseEvent();
	}

	/// Paint mode.
	@property
	const
	PaintMode mode() {
		checkInit();
		return _mode;
	}
	/// ditto
	@property
	void mode(PaintMode v) {
		checkWidget();
		checkInit();
		this.p_cursor = cursor(v);
		if (_mode == v) return;
		fixPaste();
		redrawCursorArea();
		_mode = v;
		_mouseDown = -1;
		resetSelectedRange();

		clearCache(false);
		redrawCursorArea();
		drawReceivers.raiseEvent();
		statusChangedReceivers.raiseEvent();
	}

	/// Cursor size.
	/// If it is 0, no draws cursor pixel.
	@property
	const
	uint cursorSize() {
		checkInit();
		return _iCurSize;
	}
	/// ditto
	@property
	void cursorSize(uint v) {
		checkWidget();
		checkInit();
		if (_iCurSize == v) return;
		redrawCursorArea();
		_iCurSize = v;

		clearCache(false);
		redrawCursorArea();
		drawReceivers.raiseEvent();
		statusChangedReceivers.raiseEvent();
	}

	/// A cursor of every paint mode.
	/// If it is null, use cursor is arrow.
	const
	const(Cursor) cursor(PaintMode mode) { return _cursor.get(mode, null); }
	/// ditto
	Cursor cursor(PaintMode mode) {
		checkWidget();
		return _cursor.get(mode, null);
	}
	/// ditto
	void cursor(PaintMode mode, Cursor cursor) {
		checkWidget();
		if (cursor is null) {
			if (mode in _cursor) {
				_cursor.remove(mode);
			}
		} else {
			_cursor[mode] = cursor;
		}
		if (mode is this.mode) {
			this.p_cursor = cursorNow;
		}
	}

	/// A cursor of syringe mode.
	/// If it is null, use cursor(PaintMode).
	@property
	const
	const(Cursor) cursorDropper() { return _cursorDropper; }
	/// ditto
	@property
	Cursor cursorDropper() { 
		checkWidget();
		return _cursorDropper;
	}
	/// ditto
	@property
	void cursorDropper(Cursor cursor) {
		checkWidget();
		_cursorDropper = cursor;
		this.p_cursor = cursorNow;
	}

	/// A cursor of range selection mode.
	/// If it is null, use cursor(PaintMode).
	@property
	const
	const(Cursor) cursorSelRange() { return _cursorSelRange; }
	/// ditto
	@property
	Cursor cursorSelRange() { 
		checkWidget();
		return _cursorSelRange;
	}
	/// ditto
	@property
	void cursorSelRange(Cursor cursor) {
		checkWidget();
		_cursorSelRange = cursor;
		this.p_cursor = cursorNow;
	}

	/// Cursor in use.
	@property
	Cursor cursorNow() {
		if (dropperMode && _cursorDropper) {
			return _cursorDropper;
		}
		if (rangeSelection && _cursorSelRange) {
			return _cursorSelRange;
		}
		return cursor(this.mode);
	}
	/// ditto
	private Cursor iCursorNow(int ix, int iy) {
		if (rangeSelection && iCursorArea.contains(ix, iy)) {
			return this.p_display.getSystemCursor(SWT.CURSOR_HAND);
		}
		return cursorNow;
	}

	/// Dropper mode?
	@property
	const
	bool dropperMode() {
		return 3 == _mouseDown;
	}

	/// Format for status texts.
	@property
	const
	string statusTextXY() { return _statusTextXY; }
	/// ditto
	@property
	void statusTextXY(string v) {
		_statusTextXY = v;
		updateStatusText();
	}
	/// ditto
	@property
	const
	string statusTextRange() { return _statusTextRange; }
	/// ditto
	@property
	void statusTextRange(string v) {
		_statusTextRange = v;
		updateStatusText();
	}

	/// Update status text.
	private void updateStatusText() {
		_status.p_visible = false;

		auto d = this.p_display;
		if (d.p_cursorControl !is this) return;

		auto ia = selectedArea;

		if (0 == ia.width && 0 == ia.height) {
			// no selection
			auto cLoc = toControl(d.p_cursorLocation);
			int ix1 = cxtoix(cLoc.x);
			int iy1 = cytoiy(cLoc.y);
			if (1 == _mouseDown && _mode != PaintMode.FreePath && _mode != PaintMode.Fill) {
				// drawing range
				int ix2 = _iCurFrom.x;
				int iy2 = _iCurFrom.y;
				int ixF = .min(ix1, ix2);
				int iyF = .min(iy1, iy2);
				int ixT = .max(ix1, ix2);
				int iyT = .max(iy1, iy2);
				int iw = ixT - ixF + 1;
				int ih = iyT - iyF + 1;
				_status.p_message = statusTextRange.format(ixF, iyF, ixT, iyT, iw, ih);
			} else {
				// x, y
				_status.p_message = statusTextXY.format(ix1, iy1);
			}
		} else {
			// selected range
			int iw = ia.width;
			int ih = ia.height;
			int ixTo = ia.x + iw;
			int iyTo = ia.y + ih;
			_status.p_message = statusTextRange.format(ia.x, ia.y, ixTo, iyTo, iw, ih);
		}

		auto bounds = this.p_bounds;
		auto cp = toDisplay(CPoint(0, bounds.height));
		auto cTSize = this.computeTextSize(_status.p_message);
		cp.x -= cTSize.x;
		cp.y -= cTSize.y;
		_status.p_location = cp;
		_status.p_visible = true;
	}

	/// Executes operation of cut, copy, paste, and delete.
	void cut() {
		checkWidget();
		checkInit();
		if (_image.empty) return;
		if (!_rangeSel) return;
		auto ia = iCursorArea;
		if (0 == ia.width || 0 == ia.height) return;
		copy();
		del();
		resetSelectedRange();
		drawReceivers.raiseEvent();
	}
	/// ditto
	void copy() {
		checkWidget();
		checkInit();
		if (_image.empty) return;
		if (!_rangeSel) return;
		auto ia = iCursorArea;
		if (0 == ia.width || 0 == ia.height) return;

		auto d = this.p_display;
		auto cb = new Clipboard(d);
		scope (exit) cb.dispose();

		Object data;
		if (_pasteLayer) {
			data = _pasteLayer.createImageData(8);
		} else {
			data = _image.createImageData(ia, 8, _layers);
		}
		auto it = cast(Transfer)ImageTransfer.getInstance();
		cb.setContents([data], [it]);

		statusChangedReceivers.raiseEvent();
	}
	/// ditto
	void paste() {
		checkWidget();
		checkInit();
		if (_image.empty) return;

		auto d = this.p_display;
		auto cb = new Clipboard(d);
		scope (exit) cb.dispose();

		auto data = cast(ImageData)cb.getContents(ImageTransfer.getInstance());
		if (!data) return;

		fixPaste();
		if (_um) _um.store(this);
		rangeSelection = true;
		auto imageData = new ImageData(data.width, data.height, 8, _image.copyPalette());

		auto colors = new CRGB[imageData.palette.colors.length];
		foreach (i, rgb; imageData.palette.colors) {
			colors[i].r = cast(ubyte)rgb.red;
			colors[i].g = cast(ubyte)rgb.green;
			colors[i].b = cast(ubyte)rgb.blue;
		}
		auto tree = new ColorTree(colors, false);
		foreach (idx; 0 .. data.width) {
			foreach (idy; 0 .. data.height) {
				auto rgb = data.palette.getRGB(data.getPixel(idx, idy));
				CRGB c;
				c.r = cast(ubyte)rgb.red;
				c.g = cast(ubyte)rgb.green;
				c.b = cast(ubyte)rgb.blue;
				int pixel = tree.searchLose(c);
				imageData.setPixel(idx, idy, pixel);
			}
		}
		_pasteLayer = new MLImage;
		_pasteLayer.init(imageData, "paste layer");
		auto ia = iCursorArea();
		int ix = ia.x;
		int iy = ia.y;
		if (0 == ia.width && 0 == ia.height) {
			// Paste to top left on visible area.
			ix = iVisibleLeft;
			iy = iVisibleTop;
		}
		initPasteLayer(ix, iy);
		_moving = true;
	}
	/// Initializes paste source layer.
	private void initPasteLayer(int ix, int iy) {
		enforce(_pasteLayer);
		_iSelRange.x = ix;
		_iSelRange.y = iy;
		_iSelRange.width = _pasteLayer.width;
		_iSelRange.height = _pasteLayer.height;
		redrawCursorArea();
		raiseSelectChangedEvent();

		clearCache(false);
		drawReceivers.raiseEvent();
	}
	/// ditto
	void del() {
		checkWidget();
		checkInit();
		if (_image.empty) return;
		if (!_rangeSel) return;
		if (_pasteLayer) {
			iFillRect((int ix, int iy) {
				iSetPixels(ix, iy, _backPixel);
			}, _iMoveRange);
			cancelPaste();
			return;
		}
		auto ia = iCursorArea;
		if (0 == ia.width || 0 == ia.height) return;
		if (_um) _um.store(this);

		delImpl();
		resetSelectedRange();
		drawReceivers.raiseEvent();
	}
	/// ditto
	private void delImpl() {
		enforce(!_image.empty);
		auto ia = iCursorArea;
		iFillRect((int ix, int iy) {
			iSetPixels(ix, iy, _backPixel);
		}, ia);
		clearCache(false);
		redrawCursorArea();
	}

	/// Paste from source layer to image.
	void fixPaste() {
		checkWidget();
		checkInit();
		if (_image.empty) return;
		if (!_pasteLayer) return;

		fixPasteImpl(_enabledBackColor, _backPixel);
	}
	/// ditto
	private void fixPasteImpl(bool enabledBackColor, int backPixel) {
		iFillRect((int ix, int iy) {
			iSetPixels(ix, iy, backPixel);
		}, _iMoveRange);
		foreach (l; _layers) {
			if (!_image.layer(l).visible) continue;
			auto pll = _pasteLayer.layer(l % _pasteLayer.layerCount).image;
			foreach (ix; 0 .. _pasteLayer.width) {
				foreach (iy; 0 .. _pasteLayer.height) {
					int pixel = pll.getPixel(ix, iy);
					if (!enabledBackColor || pixel != backPixel) {
						iSetPixel(_iSelRange.x + ix, _iSelRange.y + iy, pixel, l, false);
					}
				}
			}
		}
		redrawCursorArea();
		resetPasteParams();
	}
	/// Cancels paste operation.
	void cancelPaste() {
		checkWidget();
		checkInit();
		if (_image.empty) return;
		if (!_pasteLayer) return;
		redrawCursorArea();
		resetPasteParams();
	}
	private void resetPasteParams() {
		_moving = false;
		_iCurFrom.x = _iSelRange.x;
		_iCurFrom.y = _iSelRange.y;
		_iCurTo.x = _iCurFrom.x;
		_iCurTo.y = _iCurFrom.y;
		_iMoveRange.x = 0;
		_iMoveRange.y = 0;
		_iMoveRange.width = 0;
		_iMoveRange.height = 0;
		resetSelectedRange();
		_pasteLayer = null;
		clearCache(false);
		raiseSelectChangedEvent();
		drawReceivers.raiseEvent();
	}

	/// Selects entire image.
	/// Sets true to rangeSelection.
	void selectAll() {
		checkWidget();
		checkInit();
		if (_image.empty) return;
		fixPaste();
		rangeSelection = true;
		_iSelRange.x = 0;
		_iSelRange.y = 0;
		_iSelRange.width = _image.width;
		_iSelRange.height = _image.height;
		clearCache(false);
		redrawCursorArea();
		raiseSelectChangedEvent();
	}

	/// Scrolls to x, y (image coordinates) in viewport.
	void scroll(int x, int y) {
		checkWidget();
		checkInit();
		iScroll(x, y);
	}
	/// ditto
	private void iScroll(int ix, int iy) {
		checkWidget();
		checkInit();
		// Common method for horizontal and vertical.
		void iScrImpl(int ix, int iw, ScrollBar bar) {
			if (!bar.p_visible) return;
			int chss = bar.p_selection;
			int ihss = ctoi(chss);
			if (ix < ihss) {
				bar.p_selection = itoc(ix);
				redraw();
			} else {
				int ihw = ctoi(bar.p_thumb);
				if (ihss + ihw <= ix) {
					bar.p_selection = itoc(ix - ihw);
					redraw();
				}
			}
		}
		auto hs = this.p_horizontalBar;
		assert (hs);
		iScrImpl(ix, _image.width, hs);
		auto vs = this.p_verticalBar;
		assert (vs);
		iScrImpl(iy, _image.height, vs);
	}

	/// Center coordinate at viewport.
	@property
	private Point iCenter() {
		checkWidget();
		checkInit();
		int ix, iy;
		auto hs = this.p_horizontalBar;
		assert (hs);
		if (hs.p_visible) {
			ix = iVisibleLeft + ctoi(hs.p_thumb) / 2;
		} else {
			ix = _image.width / 2;
		}
		auto vs = this.p_verticalBar;
		assert (vs);
		if (vs.p_visible) {
			iy = iVisibleTop + ctoi(vs.p_thumb) / 2;
		} else {
			iy = _image.height / 2;
		}
		return CPoint(ix, iy);
	}
	/// ditto
	@property
	private void iCenter(in Point ip) {
		checkWidget();
		checkInit();
		auto hs = this.p_horizontalBar;
		assert (hs);
		if (hs.p_visible) {
			hs.p_selection = itoc(ip.x - ctoi(hs.p_thumb) / 2);
			redraw();
		}
		auto vs = this.p_verticalBar;
		assert (vs);
		if (vs.p_visible) {
			vs.p_selection = itoc(ip.y - ctoi(vs.p_thumb) / 2);
			redraw();
		}
	}

	/// Utility methods for transform.
	private int[] iPGetPixels(int ix, int iy) {
		.enforce(_pasteLayer);
		auto ps = new int[_pasteLayer.layerCount];
		foreach (i, ref p; ps) {
			p = _pasteLayer.layer(i).image.getPixel(ix, iy);
		}
		return ps;
	}
	/// ditto
	private void iPSetPixels(int ix, int iy, int[] pixels) {
		.enforce(_pasteLayer);
		assert (pixels.length == _pasteLayer.layerCount);
		foreach (i, p; pixels) {
			_pasteLayer.layer(i).image.setPixel(ix, iy, p);
		}
	}
	/// ditto
	private int[] iGetPixels2(int ix, int iy, bool allLayers) {
		checkWidget();
		checkInit();
		if (allLayers) {
			if (_image.empty) return [];
			if (!iInImage(ix, iy)) return [];
			_pixelsTemp.length = _image.layerCount;
			foreach (l; 0 .. _image.layerCount) {
				_pixelsTemp[l] = _image.layer(l).image.getPixel(ix, iy);
			}
			return _pixelsTemp.dup;
		} else {
			return iGetPixels(ix, iy).dup;
		}
	}
	/// ditto
	private void iSetPixels2(int ix, int iy, bool allLayers, int[] pixels) {
		checkWidget();
		checkInit();
		if (allLayers) {
			.enforce(pixels.length == _image.layerCount);
			if (_image.empty) return;
			if (!iInImage(ix, iy)) return;
			foreach (l; 0 .. _image.layerCount) {
				if (-1 == pixels[l]) continue;
				_image.layer(l).image.setPixel(ix, iy, pixels[l]);
			}
			clearCache(false);
			redraw(ixtocx(ix), iytocy(iy), itoc(1), itoc(1), false);
		} else {
			iSetPixels(ix, iy, pixels);
		}
	}

	/// Increase or decrease brightness.
	void changeBrightness(int upDown, bool allLayers) {
		checkWidget();
		checkInit();
		if (_image.empty) return;

		auto colors = image.palette.colors;
		auto rgbs = new CRGB[colors.length];
		foreach (i, ref rgb; rgbs) {
			rgb.r = cast(ubyte)colors[i].red;
			rgb.g = cast(ubyte)colors[i].green;
			rgb.b = cast(ubyte)colors[i].blue;
		}
		auto tree = new ColorTree(rgbs, false);
		void chg(ref int[] ps) {
			foreach (ref p; ps) {
				auto rgb = rgbs[p];
				ubyte r = roundCast!ubyte(rgb.r + upDown);
				ubyte g = roundCast!ubyte(rgb.g + upDown);
				ubyte b = roundCast!ubyte(rgb.b + upDown);
				p = tree.searchLose(CRGB(r, g, b));
			}
		}
		if (_pasteLayer) {
			iFillRect((int ix, int iy) {
				auto ps = iPGetPixels(ix, iy);
				chg(ps);
				iPSetPixels(ix, iy, ps);
			}, 0, 0, _pasteLayer.width, _pasteLayer.height);
			clearCache(false);
			redrawCursorArea();
		} else if (_iSelRange.p_empty) {
			if (_um) _um.store(this);
			clearCache(false);
			iFillRect((int ix, int iy) {
				auto ps = iGetPixels2(ix, iy, allLayers);
				chg(ps);
				iSetPixels2(ix, iy, allLayers, ps);
			}, 0, 0, _image.width, _image.height);
		} else {
			if (_um) _um.store(this);
			clearCache(false);
			auto ir = iInImageRect(_iSelRange.x, _iSelRange.y, _iSelRange.width, _iSelRange.height);
			iFillRect((int ix, int iy) {
				auto ps = iGetPixels2(ix, iy, allLayers);
				chg(ps);
				iSetPixels2(ix, iy, allLayers, ps);
			}, ir.x, ir.y, ir.width, ir.height);
		}
		clearCache(false);
		drawReceivers.raiseEvent();
	}

	/// Transforms image.
	private void transform(bool allLayers, void function
			(int[] delegate(int x, int y) pget,
			void delegate(int x, int y, int[] pixels) pset,
			int sx, int sy, int w, int h) func) {
		checkWidget();
		checkInit();
		if (_image.empty) return;
		if (_pasteLayer) {
			func(&iPGetPixels, &iPSetPixels, 0, 0, _pasteLayer.width, _pasteLayer.height);
			clearCache(false);
			redrawCursorArea();
		} else if (_iSelRange.p_empty) {
			if (_um) _um.store(this);
			clearCache(false);
			auto pget = (int x, int y) => iGetPixels2(x, y, allLayers);
			auto pset = (int x, int y, int[] pixels) => iSetPixels2(x, y, allLayers, pixels);
			func(pget, pset, 0, 0, _image.width, _image.height);
		} else {
			if (_um) _um.store(this);
			clearCache(false);
			auto ir = iInImageRect(_iSelRange.x, _iSelRange.y, _iSelRange.width, _iSelRange.height);
			auto pget = (int x, int y) => iGetPixels2(x, y, allLayers);
			auto pset = (int x, int y, int[] pixels) => iSetPixels2(x, y, allLayers, pixels);
			func(pget, pset, ir.x, ir.y, ir.width, ir.height);
		}
		drawReceivers.raiseEvent();
	}

	/// Transforms image data to mirror horizontally or vertically.
	void mirrorHorizontal(bool allLayers) {
		transform(allLayers, &.mirrorHorizontal!(int[]));
	}
	/// ditto
	void mirrorVertical(bool allLayers) {
		transform(allLayers, &.mirrorVertical!(int[]));
	}
	/// Flips image data horizontally or vertically.
	void flipHorizontal(bool allLayers) {
		transform(allLayers, &.flipHorizontal!(int[]));
	}
	/// ditto
	void flipVertical(bool allLayers) {
		transform(allLayers, &.flipVertical!(int[]));
	}
	/// Moves image data in each direction.
	/// Rotates a pixel of bounds.
	void rotateRight(bool allLayers) {
		transform(allLayers, &.rotateRight!(int[]));
	}
	/// ditto
	void rotateLeft(bool allLayers) {
		transform(allLayers, &.rotateLeft!(int[]));
	}
	/// ditto
	void rotateUp(bool allLayers) {
		transform(allLayers, &.rotateUp!(int[]));
	}
	/// ditto
	void rotateDown(bool allLayers) {
		transform(allLayers, &.rotateDown!(int[]));
	}
	/// Turns image.
	void turn(real deg, bool allLayers) {
		checkWidget();
		checkInit();
		if (_image.empty) return;
		if (_pasteLayer) {
			auto back = new int[_pasteLayer.layerCount];
			back[] = backgroundPixel;
			.turn(deg, &iPGetPixels, &iPSetPixels, 0, 0,
				_pasteLayer.width, _pasteLayer.height, back);
			clearCache(false);
			redrawCursorArea();
		} else if (_iSelRange.p_empty) {
			if (_um) _um.store(this);
			clearCache(false);
			auto back = new int[_layers.length];
			back[] = backgroundPixel;
			auto pget = (int x, int y) => iGetPixels2(x, y, allLayers);
			auto pset = (int x, int y, int[] pixels) => iSetPixels2(x, y, allLayers, pixels);
			.turn(deg, pget, pset, 0, 0, _image.width, _image.height, back);
		} else {
			if (_um) _um.store(this);
			clearCache(false);
			auto back = new int[_layers.length];
			back[] = backgroundPixel;
			auto ir = iInImageRect(_iSelRange.x, _iSelRange.y, _iSelRange.width, _iSelRange.height);
			auto pget = (int x, int y) => iGetPixels2(x, y, allLayers);
			auto pset = (int x, int y, int[] pixels) => iSetPixels2(x, y, allLayers, pixels);
			.turn(deg, pget, pset, ir.x, ir.y, ir.width, ir.height, back);
		}
		clearCache(false);
		drawReceivers.raiseEvent();
	}

	/// Gets area of resize operation.
	@property
	Rectangle resizeArea() {
		checkInit();
		if (_pasteLayer) {
			return CRect(_iSelRange.x, _iSelRange.y, _iSelRange.width, _iSelRange.height);
		} else {
			auto iSelRange = iInImageRect(_iSelRange.x, _iSelRange.y, _iSelRange.width, _iSelRange.height);
			if (!iSelRange.p_empty) {
				return iSelRange;
			} else {
				return CRect(0, 0, _image.width, _image.height);
			}
		}
	}
	/// Resizes paint area.
	void resizePaintArea(int w, int h, bool scaling) {
		checkWidget();
		checkInit();
		if (_image.empty) return;

		if (_image.width == w && _image.height == h) return;

		if (_um) _um.store(this);
		resetPasteParams();
		if (scaling) {
			_image.scaledTo(w, h);
		} else {
			_image.resize(w, h, backgroundPixel);
		}

		resizeReceivers.raiseEvent(w, h);
		drawReceivers.raiseEvent();
	}
	/// Do resizing or scaling.
	void resize(int newW, int newH, bool scaling) {
		checkWidget();
		checkInit();
		if (_image.empty) return;

		auto iRArea = resizeArea();
		int iNewW = newW;
		int iNewH = newH;
		if (iNewW == iRArea.width && iNewH == iRArea.height) return;

		int iw, ih;
		void iSetBackPixel(int ix, int iy) {
			iSetPixels(ix, iy, _backPixel);
		}
		void fillRest(int ifx, int ify) {
			if (iNewW < iw && iNewH < ih) {
				iFillRect(&iSetBackPixel, ifx + iNewW, ify, iw - iNewW, iNewH + (ih - iNewH));
				iFillRect(&iSetBackPixel, ifx, ify + iNewH, iNewW, ih - iNewH);
				return;
			}
			if (iNewW < iw) {
				iFillRect(&iSetBackPixel, ifx + iNewW, ify, iw - iNewW , iNewH);
			}
			if (iNewH < ih) {
				iFillRect(&iSetBackPixel, ifx, ify + iNewH, iNewW, ih - iNewH);
			}
		}
		if (_pasteLayer) {
			redrawCursorArea();
			iw = _pasteLayer.width;
			ih = _pasteLayer.height;
			if (scaling) {
				_pasteLayer.scaledTo(iNewW, iNewH);
			} else {
				_pasteLayer.resize(iNewW, iNewH, _backPixel);
			}
			_iSelRange.width = iNewW;
			_iSelRange.height = iNewH;
			redrawCursorArea();
		} else {
			auto iSelRange = iInImageRect(_iSelRange.x, _iSelRange.y, _iSelRange.width, _iSelRange.height);
			if (!iSelRange.p_empty) {
				int ix = iSelRange.x;
				int iy = iSelRange.y;
				iw = iSelRange.width;
				ih = iSelRange.height;
				if (iw == iNewW && ih == iNewH) return;
				if (_um) _um.store(this);
				redrawCursorArea();
				if (scaling) {
					.resize!(int[])(iNewW, iNewH, &iGetPixels, &iSetPixels, ix, iy, iw, ih);
				} else {
					if (iw < iNewW) {
						iFillRect(&iSetBackPixel, ix + iw, iy, iNewW - iw, ih);
					}
					if (ih < iNewH) {
						iFillRect(&iSetBackPixel, ix, iy + ih, iw, iNewH - ih);
					}
				}
				_iSelRange.width = ix;
				_iSelRange.width = iy;
				_iSelRange.width = iNewW;
				_iSelRange.height = iNewH;
				fillRest(ix, iy);
				redrawCursorArea();
			} else {
				resizePaintArea(iNewW, iNewH, scaling);
				return;
			}
		}
		clearCache(false);
		drawReceivers.raiseEvent();
	}

	private void onMouseEnter(Event e) {
		checkWidget();
		checkInit();
		_mouseEnter = true;
		updateStatusText();
		clearCache(false);
		redrawCursorArea();
	}
	private void onMouseExit(Event e) {
		checkWidget();
		checkInit();
		_mouseEnter = false;
		updateStatusText();
		clearCache(false);
		redrawCursorArea();
	}

	/// If range of parameters intersect range of image,
	/// returns true. (Image coordinate)
	const
	private void iInImageRect(ref Rectangle iRect) {
		checkInit();
		auto iBounds = CRect(0, 0, _image.width, _image.height);
		if (!iBounds.intersects(iRect)) {
			iRect.width = 0;
			iRect.height = 0;
			return;
		}
		if (iRect.x < 0) {
			iRect.width += iRect.x;
			iRect.x = 0;
		}
		if (iRect.y < 0) {
			iRect.height += iRect.y;
			iRect.y = 0;
		}
		if (_image.width < iRect.x + iRect.width) {
			iRect.width -= iRect.x + iRect.width - _image.width;
		}
		if (_image.height < iRect.y + iRect.height) {
			iRect.height -= iRect.y + iRect.height - _image.height;
		}
	}
	/// ditto
	const
	private Rectangle iInImageRect(int ix, int iy, int iw, int ih) {
		checkInit();
		auto ir = CRect(ix, iy, iw, ih);
		iInImageRect(ir);
		return ir;
	}

	/// Gets area of drawing range (image coordinates).
	@property
	private Rectangle iCursorArea() {
		checkWidget();
		checkInit();
		if (_pasteLayer || _rangeSel) {
			int ix = _iSelRange.x;
			int iy = _iSelRange.y;
			int iw = _iSelRange.width;
			int ih = _iSelRange.height;
			if (_pasteLayer) {
				return CRect(ix, iy, iw, ih);
			} else {
				return iInImageRect(ix, iy, iw, ih);
			}
		} else {
			int iCurSize = mode is PaintMode.Fill ? 1 : _iCurSize;
			if (0 == iCurSize) {
				return CRect(0, 0, 0, 0);
			}
			int ix, iy, iw, ih;
			int ics = _rangeSel ? 0 : iCurSize - 1;
			if (_iCurFrom.x != _iCurTo.x || _iCurFrom.y != _iCurTo.y) {
				ix = min(_iCurFrom.x, _iCurTo.x) - ics;
				iy = min(_iCurFrom.y, _iCurTo.y) - ics;
				iw = max(_iCurFrom.x, _iCurTo.x) + (ics * 2) + 1 - ix;
				ih = max(_iCurFrom.y, _iCurTo.y) + (ics * 2) + 1 - iy;
			} else {
				ix = _iCurFrom.x - ics;
				iy = _iCurFrom.y - ics;
				iw = ics * 2 + 1;
				ih = ics * 2 + 1;
			}
			return iInImageRect(ix, iy, iw, ih);
		}
	}
	/// Gets area of drawing range (control coordinates).
	@property
	private Rectangle cCursorArea() {
		auto ia = iCursorArea;
		return itoc(ia);
	}

	/// Redraws area of drawing range.
	private void redrawCursorArea() {
		checkWidget();
		checkInit();
		auto ca = cCursorArea;
		redraw(ca.x - 1, ca.y - 1, ca.width + 2, ca.height + 2, false);
		if (!_iMoveRange.p_empty) {
			auto cmr = itoc(_iMoveRange);
			redraw(cmr.x, cmr.y, cmr.width, cmr.height, false);
		}
	}

	/// Resets area of drawing range.
	private void resetSelectedRange() {
		_iSelRange.x = 0;
		_iSelRange.y = 0;
		_iSelRange.width = 0;
		_iSelRange.height = 0;
		resetCatchParams();
		clearCache(false);
		raiseSelectChangedEvent();
	}
	/// Reset caught frame parameters.
	private void resetCatchParams() {
		_catchN = false;
		_catchE = false;
		_catchS = false;
		_catchW = false;
		_iCatchX = -1;
		_iCatchY = -1;
		_iOldSelRange.x = 0;
		_iOldSelRange.y = 0;
		_iOldSelRange.width = 0;
		_iOldSelRange.height = 0;
	}

	/// Beginning coordinates of visible area on this control.
	@property
	private int iVisibleLeft() {
		checkWidget();
		checkInit();
		auto hs = this.p_horizontalBar;
		assert (hs);
		int chss = hs.p_selection;
		return ctoi(chss);
	}
	@property
	private int iVisibleTop() {
		checkWidget();
		checkInit();
		auto vs = this.p_verticalBar;
		assert (vs);
		int cvss = vs.p_selection;
		return ctoi(cvss);
	}

	/// Beginning coordinates of draw image on this control.
	@property
	private int cImageLeft() {
		checkWidget();
		checkInit();
		auto ca = this.p_clientArea;
		int ciw = itoc(_image.width);
		if (ca.width == ciw) {
			return 0;
		} else if (ca.width > ciw) {
			return (ca.width / 2) - (ciw / 2);
		} else {
			auto hs = this.p_horizontalBar;
			assert (hs);
			int chss = hs.p_selection;
			return -chss;
		}
	}
	/// ditto
	@property
	private int cImageTop() {
		checkWidget();
		checkInit();
		auto ca = this.p_clientArea;
		int cih = itoc(_image.height);
		if (ca.height == cih) {
			return 0;
		} else if (ca.height > cih) {
			return (ca.height / 2) - (cih / 2);
		} else {
			auto vs = this.p_verticalBar;
			assert (vs);
			int cvss = vs.p_selection;
			return -cvss;
		}
	}

	/// Converts a control coordinate to a image coordinate.
	const
	private int ctoi(int c) {
		checkInit();
		return c / cast(int)_zoom;
	}
	/// ditto
	private int cxtoix(int c) {
		checkInit();
		return ctoi(c - cImageLeft);
	}
	/// ditto
	private int cytoiy(int c) {
		checkInit();
		return ctoi(c - cImageTop);
	}
	/// ditto
	private Rectangle ctoi(in Rectangle c) {
		checkInit();
		return CRect(cxtoix(c.x), cytoiy(c.y), ctoi(c.width), ctoi(c.height));
	}
	/// Converts a image coordinate to a control coordinate.
	const
	private int itoc(int i) {
		checkInit();
		return i * cast(int)_zoom;
	}
	/// ditto
	private int ixtocx(int i) {
		checkInit();
		return itoc(i) + cImageLeft;
	}
	/// ditto
	private int iytocy(int i) {
		checkInit();
		return itoc(i) + cImageTop;
	}
	/// ditto
	private Rectangle itoc(in Rectangle i) {
		checkInit();
		return CRect(ixtocx(i.x), iytocy(i.y), itoc(i.width), itoc(i.height));
	}

	/// Is coordinates in the image?
	/// This method uses control coordinates.
	private bool cInImage(int cx, int cy) {
		checkInit();
		return iInImage(cxtoix(cx), cytoiy(cy));
	}

	/// Is coordinates in the image?
	/// This method uses image coordinates.
	const
	private bool iInImage(int ix, int iy) {
		checkInit();
		return 0 <= ix && 0 <= iy && ix < _image.width && iy < _image.height;
	}

	/// Is cx, cy on the frame of selected range? (Control coordinates)
	private void cIsCatchedFocus(int cx, int cy, out bool n, out bool e, out bool s, out bool w) {
		checkInit();
		n = false;
		e = false;
		s = false;
		w = false;
		if (!_rangeSel || _iSelRange.p_empty) return;
		auto cRect = itoc(_iSelRange);
		int csx = cRect.x;
		int csy = cRect.y;
		int csw = cRect.width;
		int csh = cRect.height;
		static const cC_SIZE = 5;
		static const cC_WIDTH = cC_SIZE * 2 + 1;

		// north
		cRect.x = csx - cC_SIZE;
		cRect.y = csy - cC_SIZE;
		cRect.width = csw + cC_WIDTH;
		cRect.height = cC_WIDTH;
		n = cRect.contains(cx, cy);

		// east
		cRect.x = csx + csw - cC_SIZE;
		cRect.y = csy - cC_SIZE;
		cRect.width = cC_WIDTH;
		cRect.height = csh + cC_WIDTH;
		e = cRect.contains(cx, cy);

		// south
		cRect.x = csx - cC_SIZE;
		cRect.y = csy + csh - cC_SIZE;
		cRect.width = csw + cC_WIDTH;
		cRect.height = cC_WIDTH;
		s = cRect.contains(cx, cy);

		// west
		cRect.x = csx - cC_SIZE;
		cRect.y = csy - cC_SIZE;
		cRect.width = cC_WIDTH;
		cRect.height = csh + cC_WIDTH;
		w = cRect.contains(cx, cy);
	}

	/// If coordinate can draw, returns true. (Image coordinate)
	private bool iCanDraw(int ix, int iy, size_t layer) {
		if (iMask(ix, iy, layer)) return false;
		if (_tone && 0 < _tone.length) {
			auto toneLn = _tone[iy % $];
			return 0 == toneLn.length || toneLn[ix % $];
		}
		return true;
	}

	/// If coordinate is masked, returns true. (Image coordinate)
	private bool iMask(int ix, int iy, size_t layer) {
		return _mask[iGetPixel(ix, iy, layer)];
	}

	/// Sets one pixel of current layer.
	/// This method uses image coordinates.
	private void iSetPixels(int ix, int iy) {
		iSetPixels(ix, iy, _pixel);
	}
	/// ditto
	private void iSetPixels(int ix, int iy, int pixel) {
		checkWidget();
		checkInit();
		if (_image.empty) return;
		if (!iInImage(ix, iy)) return;
		if (-1 == pixel) return;
		foreach (l; _layers) {
			if (!iCanDraw(ix, iy, l)) continue;
			auto il = _image.layer(l);
			if (!il.visible) continue;
			il.image.setPixel(ix, iy, pixel);
		}
		clearCache(false);
		redraw(ixtocx(ix), iytocy(iy), itoc(1), itoc(1), false);
	}
	/// ditto
	private void iSetPixels(int ix, int iy, int[] pixels) {
		checkWidget();
		checkInit();
		enforce(pixels.length == _layers.length);
		if (_image.empty) return;
		if (!iInImage(ix, iy)) return;
		foreach (i, l; _layers) {
			if (!_image.layer(l).visible) continue;
			if (!iCanDraw(ix, iy, l)) continue;
			if (-1 == pixels[i]) continue;
			_image.layer(l).image.setPixel(ix, iy, pixels[i]);
		}
		clearCache(false);
		redraw(ixtocx(ix), iytocy(iy), itoc(1), itoc(1), false);
	}
	/// ditto
	private void iSetPixel(int ix, int iy, int pixel, int layer, bool force) {
		checkWidget();
		checkInit();
		if (_image.empty) return;
		if (!iInImage(ix, iy)) return;
		if (!force && !iCanDraw(ix, iy, layer)) return;
		auto l = _image.layer(layer);
		if (!l.visible) return;
		l.image.setPixel(ix, iy, pixel);
		clearCache(false);
		redraw(ixtocx(ix), iytocy(iy), itoc(1), itoc(1), false);
	}
	/// Gets pixel of current layer.
	/// If coordinates is out of area, returns -1.
	/// This method uses image coordinates.
	private int[] iGetPixels(int ix, int iy) {
		checkWidget();
		checkInit();
		if (_image.empty) return [];
		if (!iInImage(ix, iy)) return [];
		if (_pixelsTemp.length != _layers.length) {
			_pixelsTemp.length = _layers.length;
		}
		foreach (i, l; _layers) {
			_pixelsTemp[i] = _image.layer(l).image.getPixel(ix, iy);
		}
		return _pixelsTemp;
	}
	/// ditto
	private int iGetPixel(int ix, int iy, size_t layer) {
		checkWidget();
		checkInit();
		if (_image.empty) return -1;
		if (!iInImage(ix, iy)) return -1;
		auto pixels = new int[_layers.length];
		return _image.layer(layer).image.getPixel(ix, iy);
	}

	/// Calls dlg(X, Y) with points of path, from cursor and mode.
	const
	private void iPath(void delegate(int, int) dlg) {
		checkInit();
		pointsOfPath(dlg, _mode, _iCurFrom.x, _iCurFrom.y, _iCurTo.x, _iCurTo.y, _image.width, _image.height, _iCurSize);
	}
	/// Calls dlg(X, Y) with each coordinates in rectangle.
	private void iFillRect(void delegate(int ix, int iy) dlg, Rectangle ia) {
		iFillRect(dlg, ia.x, ia.y, ia.width, ia.height);
	}
	/// ditto
	private void iFillRect(void delegate(int ix, int iy) dlg, int ix, int iy, int iw, int ih) {
		pointsOfPath(dlg, PaintMode.RectFill,
			ix, iy, ix + iw - 1, iy + ih - 1, _image.width, _image.height, 1);
	}

	/// Draws paste source layer.
	private void pushPasteLayer(ImageData dest, size_t pLayerIndex, size_t layer) {
		enforce(_pasteLayer);
		checkWidget();
		checkInit();

		if (!_iMoveRange.p_empty) {
			foreach (ix; _iMoveRange.x .. _iMoveRange.x + _iMoveRange.width) {
				foreach (iy; _iMoveRange.y .. _iMoveRange.y + _iMoveRange.height) {
					dest.setPixel(ix, iy, _backPixel);
				}
			}
		}

		int ipx = _iSelRange.x;
		int ipy = _iSelRange.y;
		int ipw = _pasteLayer.width;
		int iph = _pasteLayer.height;
		auto iRect = iInImageRect(ipx, ipy, ipw, iph);
		if (iRect.p_empty) return;

		bool ebc = enabledBackColor;
		auto l = _pasteLayer.layer(pLayerIndex).image;
		foreach (ix; iRect.x .. iRect.x + iRect.width) {
			foreach (iy; iRect.y .. iRect.y + iRect.height) {
				int pixel = l.getPixel(ix - ipx, iy - ipy);
				if (!ebc || _backPixel != pixel) {
					if (!iMask(ix, iy, layer)) {
						dest.setPixel(ix, iy, pixel);
					}
				}
			}
		}
	}

	/// Clears cache for showingIamge().
	private void clearCache(bool selectionOnly) {
		if (selectionOnly) {
			foreach (l; _layers) {
				if (l < _cache.length && _cache[l]) {
					_cache[l].dispose();
					_cache[l] = null;
				}
			}
		} else {
			foreach (i, ref c; _cache) {
				if (c) {
					c.dispose();
					c = null;
				}
			}
		}
		_cache.length = _image.layerCount;
	}
	/// Creates an image to be showing.
	private Image showingImage(size_t layer, bool oneLayer, in Rectangle iRange) {
		checkWidget();
		checkInit();

		if (layer < _cache.length && _cache[layer] && !oneLayer) {
			return _cache[layer];
		}

		auto d = this.p_display;

		auto selLayer = selectedInfo;

		int iRX, iRY, iRW, iRH;
		if (iRange) {
			iRX = iRange.x;
			iRY = iRange.x;
			iRW = iRange.width;
			iRH = iRange.height;
			if (iRX < 0) {
				iRW += iRX;
				iRX = 0;
			}
			if (iRY < 0) {
				iRH += iRY;
				iRY = 0;
			}
		} else {
			iRX = 0;
			iRY = 0;
			iRW = _image.width;
			iRH = _image.height;
		}

		// Draws layer.
		auto data = new ImageData(_image.width, _image.height, 8, _image.palette);
		if (iRW <= 0 || iRH <= 0) {
			return new Image(d, data);
		}

		auto l = _image.layer(layer).image;
		int tPixel = l.transparentPixel;
		if (!oneLayer) {
			data.transparentPixel = tPixel;
		}
		if (tPixel < 0 && !selLayer[layer]) {
			data.data[] = l.data;
		} else {
			foreach (ix; iRX .. iRW) {
				foreach (iy; iRY .. iRH) {
					// Fill background pixel to area before move.
					if (selLayer[layer] && _iMoveRange.contains(ix, iy)) {
						data.setPixel(ix, iy, tPixel);
						continue;
					}
					data.setPixel(ix, iy, l.getPixel(ix, iy));
				}
			}
		}
		if (selLayer[layer]) {
			if (_pasteLayer) {
				size_t pLayerIndex = 0;
				foreach (i; 0 .. layer) {
					if (selLayer[i]) pLayerIndex++;
				}
				pushPasteLayer(data, pLayerIndex, layer);
			} else if (!_rangeSel && 1 == _mouseDown) {
				/// Draws cursor in drawing.
				if (_mode is PaintMode.FreePath) {
					// Unnecessary. After painted.
				} else {
					// Draws path.
					iPath((int ix, int iy) {
						if (iInImage(ix, iy) && iCanDraw(ix, iy, layer)) {
							data.setPixel(ix, iy, _pixel);
						}
					});
				}
			}
		}

		auto img = new Image(d, data);
		if (!oneLayer && iRX == 0 && iRY == 0 && iRW == _image.width && iRH == _image.height) {
			_cache[layer] = img;
		}
		return img;
	}

	private void onDispose(Event e) {
		clearCache(false);
		if (_shadeCache) _shadeCache.dispose();
	}

	private void onResize(Event e) {
		checkWidget();
		calcScrollParams();
	}

	/// Draws paint area.
	private void onPaint(Event e) {
		checkWidget();
		checkInit();
		auto d = this.p_display;
		auto ca = this.p_clientArea;

		bool showImage = false;
		bool hasNoTransparent = false;
		foreach (l; 0 .. _image.layerCount) {
			if (_image.layer(l).visible) {
				showImage = true;
				if (_image.layer(l).image.transparentPixel < 0) {
					hasNoTransparent= true;
					break;
				}
			}
		}

		auto ib = CRect(0, 0, _image.width, _image.height);
		auto cb = itoc(ib);
		if (!hasNoTransparent || !showImage || ((cb.width < ca.width || cb.height < ca.height)
				&& !(cb.contains(e.x, e.y) && cb.contains(e.x + e.width, e.y + e.height)))) {
			if (!_shadeCache || !_shadeCacheRect || _shadeCacheRect != ca) {
				// Creates wallpaper cache.
				auto cSize =  this.p_size;
				if (_shadeCache) _shadeCache.dispose();
				auto shade = new Image(d, cSize.x, cSize.y);
				auto gc = new GC(shade);
				scope (exit) gc.dispose();
				gc.p_background = e.gc.p_background;
				gc.p_foreground = e.gc.p_foreground;
				gc.fillRectangle(ca);
				gc.drawShade(ca);
				_shadeCache = shade;
				_shadeCacheRect = ca;
			}
			e.gc.drawImage(_shadeCache, e.x, e.y, e.width, e.height, e.x, e.y, e.width, e.height);
		}

		bool showCursor = false;
		auto selInfo = selectedInfo;

		void valid(ref Rectangle rect, int width, int height) {
			if (rect.x < 0) {
				rect.width += rect.x;
				rect.x = 0;
			}
			if (rect.y < 0) {
				rect.height += rect.y;
				rect.y = 0;
			}
			if (width < rect.x + rect.width) {
				rect.width = width - rect.x;
			}
			if (height < rect.y + rect.height) {
				rect.height = height - rect.y;
			}
		}
		auto cPaint = CRect(e.x, e.y, e.width, e.height);
		auto iPaint = ctoi(cPaint);
		// Extends a drawing range for leakage of drawing doesn't occur.
		iPaint.x -= 2;
		iPaint.y -= 2;
		iPaint.width += 4;
		iPaint.height += 4;
		valid(iPaint, ib.width, ib.height);
		cPaint = itoc(iPaint);
		if (0 < iPaint.width && 0 < iPaint.height) {
			foreach_reverse (l; 0 .. _image.layerCount) {
				if (!_image.layer(l).visible) continue;
				auto img = showingImage(l, false, null); // uses cache
				if (!img) continue;
				e.gc.drawImage(img, iPaint.x, iPaint.y, iPaint.width, iPaint.height,
					cPaint.x, cPaint.y, cPaint.width, cPaint.height);
				if (selInfo[l]) {
					showCursor = true;
				}
			}
		}

		// Draws grid.
		if (_grid1 && 4 <= _zoom) {
			auto oldForeground = e.gc.p_foreground;
			scope (exit) e.gc.p_foreground = oldForeground;

			e.gc.p_foreground = d.getSystemColor(SWT.COLOR_BLACK);
			foreach (ix; iPaint.x .. iPaint.x + iPaint.width) {
				e.gc.drawLine(ixtocx(ix), iytocy(0), ixtocx(ix), iytocy(ib.height));
			}
			foreach (iy; iPaint.y .. iPaint.y + iPaint.height) {
				e.gc.drawLine(ixtocx(0), iytocy(iy), ixtocx(ib.width), iytocy(iy));
			}
			e.gc.p_foreground = d.getSystemColor(SWT.COLOR_WHITE);
			foreach (ix; iPaint.x .. iPaint.x + iPaint.width) {
				foreach (iy; iPaint.y .. iPaint.y + iPaint.height) {
					e.gc.drawPoint(ixtocx(ix), iytocy(iy));
				}
			}
		}
		if (_grid2) {
			static const GRID_2_INTERVAL = 16;
			auto oldForeground = e.gc.p_foreground;
			scope (exit) e.gc.p_foreground = oldForeground;
			int iStartX = GRID_2_INTERVAL * (iPaint.x / GRID_2_INTERVAL);
			int iStartY = GRID_2_INTERVAL * (iPaint.y / GRID_2_INTERVAL);
			int ch = itoc(1) / 2;

			for (int ix = iStartX; ix < iPaint.x + iPaint.width; ix += GRID_2_INTERVAL) {
				e.gc.p_foreground = d.getSystemColor(SWT.COLOR_BLACK);
				e.gc.drawLine(ixtocx(ix), iytocy(0), ixtocx(ix), iytocy(ib.height));
				e.gc.p_foreground = d.getSystemColor(SWT.COLOR_WHITE);
				for (int iy = iPaint.y; iy < iPaint.y + iPaint.height; iy++) {
					e.gc.drawPoint(ixtocx(ix), iytocy(iy));
					if (4 <= _zoom) e.gc.drawPoint(ixtocx(ix), iytocy(iy) + ch);
				}
			}
			for (int iy = iStartY; iy < iPaint.y + iPaint.height; iy += GRID_2_INTERVAL) {
				e.gc.p_foreground = d.getSystemColor(SWT.COLOR_BLACK);
				e.gc.drawLine(ixtocx(0), iytocy(iy), ixtocx(ib.width), iytocy(iy));
				e.gc.p_foreground = d.getSystemColor(SWT.COLOR_WHITE);
				for (int ix = iPaint.x; ix < iPaint.x + iPaint.width; ix++) {
					e.gc.drawPoint(ixtocx(ix), iytocy(iy));
					if (4 <= _zoom) e.gc.drawPoint(ixtocx(ix) + ch, iytocy(iy));
				}
			}
		}
		if (0 != _iCanvasW && 0 != _iCanvasH) {
			int icw = .min(_iCanvasW, ib.width);
			int ich = .min(_iCanvasH, ib.height);
			if (icw < ib.width) {
				e.gc.drawLine(ixtocx(icw), iytocy(0), ixtocx(icw), iytocy(ich));
			}
			if (ich < ib.height) {
				e.gc.drawLine(ixtocx(0), iytocy(ich), ixtocx(icw), iytocy(ich));
			}
		}

		if ((_pasteLayer || _rangeSel) && !_iSelRange.p_empty) {
			// If selection area, draw focus line.
			auto cca = cCursorArea();
			auto color1 = d.getSystemColor(SWT.COLOR_BLACK);
			auto color2 = d.getSystemColor(SWT.COLOR_WHITE);
			.drawColorfulFocus(e.gc, color1, color2, cca.x, cca.y, cca.width - 1, cca.height - 1);
		} else {
			// Draws cursor.
			if (showCursor && 1 != _mouseDown && _mouseEnter && 0 != _layers.length) {
				// Draws only pixel under a mouse cursor.
				auto ia = iCursorArea;
				iInImageRect(ia);
				if (!ia.p_empty) {
					int ix1 = ia.x, ix2 = ia.x + ia.width - 1;
					int iy1 = ia.y, iy2 = ia.y + ia.height - 1;
					int piDraw = _pixel;
					auto color = new Color(d, _image.palette.colors[piDraw]);
					scope (exit) color.dispose();
					e.gc.p_background = color;
					int ccs = itoc(1);
					pointsOfPath((int ix, int iy) {
						if (!iInImage(ix, iy)) return;
						int cx = ixtocx(ix);
						int cy = iytocy(iy);
						if (ccs <= 4) {
							e.gc.fillRectangle(cx, cy, ccs, ccs);
						} else {
							// Draws cursor square.
							if (ix == ix1) {
								e.gc.fillRectangle(cx, cy, 2, ccs);
							}
							if (ix == ix2) {
								e.gc.fillRectangle(cx + ccs - 2, cy, 2, ccs);
							}
							if (iy == iy1) {
								e.gc.fillRectangle(cx, cy, ccs, 2);
							}
							if (iy == iy2) {
								e.gc.fillRectangle(cx, cy + ccs - 2, ccs, 2);
							}
						}
					}, PaintMode.RectLine, ix1, iy1, ix2, iy2, ib.width, ib.height, 1);
				}
			}
		}
	}

	/// Handling key traversal.
	private void onTraverse(Event e) {
		checkWidget();
		checkInit();
		switch (e.detail) {
		case SWT.TRAVERSE_RETURN, SWT.TRAVERSE_TAB_PREVIOUS, SWT.TRAVERSE_TAB_NEXT:
			e.doit = true;
			break;
		default:
			e.doit = false;
			break;
		}
	}
	/// ditto
	private void onKeyDown(Event e) {}

	/// Moves the cursor.
	private void onMouseMove(Event e) {
		checkWidget();
		checkInit();
		if (_image.empty) return;
		int ix = cxtoix(e.x);
		int iy = cytoiy(e.y);
		auto d = this.p_display;

		scope (exit) updateStatusText();

		// Operation for image.
		if (1 == _mouseDown) {
			auto cursor = iCursorNow(ix, iy);
			if (_pasteLayer) {
				scope (exit) this.p_cursor = cursor;
				int isx = ix - _iPCatchX;
				int isy = iy - _iPCatchY;
				if (_iSelRange.x != isx || _iSelRange.y != isy) {
					if (!_moving) {
						if (_um) _um.store(this);
					}
					_moving = true;
					redrawCursorArea();
					_iSelRange.x = isx;
					_iSelRange.y = isy;
					clearCache(true);
					redrawCursorArea();
					raiseSelectChangedEvent();
					drawReceivers.raiseEvent();
				}
				return;
			}
			if (_iCurTo.x == ix && _iCurTo.y == iy) {
				return;
			}
			scope (exit) this.p_cursor = cursor;
			clearCache(false);
			redrawCursorArea();
			int iOldX = _iCurTo.x;
			int iOldY = _iCurTo.y;
			_iCurTo.x = ix;
			_iCurTo.y = iy;
			if (_rangeSel) {
				// Resizes selection range.
				if (_catchN || _catchE || _catchS || _catchW) {
					static void catchCommon(ref int isx, ref int isw, bool catchE, bool catchW,
							int iCatchX, int iCurToX, int iOldX, int iOldW, int imgWidth) {
						if (!catchE && !catchW) return;
						int irx = iCatchX - iCurToX;
						if (catchW) {
							isx = iOldX - irx;
							isx = min(isx, iOldX + iOldW);
							isx = max(isx, 0);
							irx = iOldX - isx;
						} else {
							irx = -irx;
						}
						isw = iOldW + irx;
						isw = min(isw, imgWidth - isx);
						isw = max(isw, 0);
					}
					catchCommon(_iSelRange.x, _iSelRange.width, _catchE, _catchW,
						_iCatchX, _iCurTo.x, _iOldSelRange.x, _iOldSelRange.width, _image.width);
					catchCommon(_iSelRange.y, _iSelRange.height, _catchS, _catchN,
						_iCatchY, _iCurTo.y, _iOldSelRange.y, _iOldSelRange.height, _image.height);
				} else {
					// Selects range.
					_iSelRange.x = min(_iCurFrom.x, _iCurTo.x);
					_iSelRange.y = min(_iCurFrom.y, _iCurTo.y);
					_iSelRange.width = max(_iCurFrom.x, _iCurTo.x) - _iSelRange.x;
					_iSelRange.height = max(_iCurFrom.y, _iCurTo.y) - _iSelRange.y;
					cursor = cursorNow;
				}
				iScroll(ix, iy);
				raiseSelectChangedEvent();
			} else if (_mode is PaintMode.FreePath) {
				// Only FreePath paints before mouse up.
				// Supplements space, when away from a old coordinates.
				bool first = true;
				pointsOfPath((int ix, int iy) {
					if (iInImage(ix, iy)) {
						if (first) {
							if (_um) _um.store(this, null, format("%s_FreePath", _id));
							first = false;
						}
						iSetPixels(ix, iy);
					}
				}, PaintMode.Straight, iOldX, iOldY, cxtoix(e.x), cytoiy(e.y), _image.width, _image.height, _iCurSize);
				iScroll(ix, iy);
				drawReceivers.raiseEvent();
			} else {
				iScroll(ix, iy);
				drawReceivers.raiseEvent();
			}
			redrawCursorArea();
		} else {
			if (_pasteLayer) {
				this.p_cursor = iCursorNow(ix, iy);
				return;
			}
			if (_rangeSel) {
				// Set cursor according to state.
				bool no, ea, so, we;
				cIsCatchedFocus(e.x, e.y, no, ea, so, we);
				if ((no && ea) || (so && we)) {
					this.p_cursor = d.getSystemCursor(SWT.CURSOR_SIZENESW);
				} else if ((no && we) || (ea && so)) {
					this.p_cursor = d.getSystemCursor(SWT.CURSOR_SIZENWSE);
				} else if (no || so) {
					this.p_cursor = d.getSystemCursor(SWT.CURSOR_SIZENS);
				} else if (ea || we) {
					this.p_cursor = d.getSystemCursor(SWT.CURSOR_SIZEWE);
				} else {
					this.p_cursor = iCursorNow(ix, iy);
				}
				return;
			}
			this.p_cursor = iCursorNow(ix, iy);
			if (_iCurFrom.x == ix && _iCurFrom.y == iy) {
				return;
			}
			redrawCursorArea();
			_iCurFrom.x = ix;
			_iCurFrom.y = iy;
			_iCurTo.x = ix;
			_iCurTo.y = iy;
			redrawCursorArea();
		}
	}

	/// Starting paint.
	private void onMouseDown(Event e) {
		checkWidget();
		checkInit();
		if (_image.empty) return;
		switch (e.button) {
		case 1:
			if (1 == _mouseDown) return;
			scope (exit) this.p_cursor = iCursorNow(cxtoix(e.x), cytoiy(e.y));
			_mouseDown = 1;
			if (_pasteLayer) {
				auto ca = cCursorArea;
				if (ca.contains(e.x, e.y)) {
					_iPCatchX = cxtoix(e.x) - _iSelRange.x;
					_iPCatchY = cytoiy(e.y) - _iSelRange.y;
					return;
				}
				fixPaste();
			}
			redrawCursorArea();
			_iCurFrom.x = cxtoix(e.x);
			_iCurFrom.y = cytoiy(e.y);
			_iCurTo.x = _iCurFrom.x;
			_iCurTo.y = _iCurFrom.y;
			if (_rangeSel) {
				bool no, ea, so, we;
				cIsCatchedFocus(e.x, e.y, no, ea, so, we);
				if (no || ea || so || we) {
					// Catches frame of selection range.
					_catchN = no;
					_catchE = ea;
					_catchS = so;
					_catchW = we;
					_iCatchX = _iCurTo.x;
					_iCatchY = _iCurTo.y;
					_iOldSelRange.x = _iSelRange.x;
					_iOldSelRange.y = _iSelRange.y;
					_iOldSelRange.width = _iSelRange.width;
					_iOldSelRange.height = _iSelRange.height;
					return;
				}
				auto ca = cCursorArea;
				if (ca.contains(e.x, e.y)) {
					// Starts move of selection range.
					_moving = false;
					auto ia = iCursorArea;
					_pasteLayer = _image.createMLImage(ia, _layers);
					_iMoveRange.x = ia.x;
					_iMoveRange.y = ia.y;
					_iMoveRange.width = ia.width;
					_iMoveRange.height = ia.height;
					initPasteLayer(ia.x, ia.y);
					_iPCatchX = cxtoix(e.x) - _iSelRange.x;
					_iPCatchY = cytoiy(e.y) - _iSelRange.y;
					return;
				}
				_iSelRange.x = _iCurFrom.x;
				_iSelRange.y = _iCurFrom.y;
				_iSelRange.width = 0;
				_iSelRange.height = 0;
				raiseSelectChangedEvent();
			} else {
				int ifx = _iCurFrom.x;
				int ify = _iCurFrom.y;
				// Starts drawing.
				// Only FreePath and Fill paints before mouse up.
				if (_mode is PaintMode.FreePath) {
					int ix = cxtoix(e.x);
					int iy = cytoiy(e.y);
					bool first = true;
					pointsOfPath((int ix, int iy) {
						if (iInImage(ix, iy)) {
							if (first) {
								if (_um) _um.store(this, null, format("%s_FreePath", _id));
								first = false;
							}
							iSetPixels(ix, iy);
						}
					}, PaintMode.FreePath, ix, iy, ix, iy, _image.width, _image.height, _iCurSize);
					redrawCursorArea();
					drawReceivers.raiseEvent();
				} else if (_mode is PaintMode.Fill && iInImage(ifx, ify)) {
					// Fills area.
					foreach (l; _layers) {
						if (!_image.layer(l).visible) continue;
						int pixel = iGetPixel(_iCurFrom.x, _iCurFrom.y, l);
						if (pixel != _pixel) {
							bool first = true;
							pointsOfFill((int ix, int iy) {
								if (!iMask(ix, iy, l)) {
									if (first) {
										if (_um) _um.store(this);
										first = false;
									}
									iSetPixel(ix, iy, _pixel, l, false);
								}
							}, (int ix, int iy) {
								return iInImage(ix, iy) && iGetPixel(ix, iy, l) == pixel;
							}, _iCurFrom.x, _iCurFrom.y, _image.width, _image.height);
							if (!first) {
								drawReceivers.raiseEvent();
							}
						}
					}
				}
			}
			break;
		case 3:
			scope (exit) this.p_cursor = iCursorNow(cxtoix(e.x), cytoiy(e.y));
			_mouseDown = 3;
			break;
		default:
			break;
		}
	}

	/// If left clicked, paints a pixel.
	/// If right clicked, gets a color of pixel.
	private void onMouseUp(Event e) {
		checkWidget();
		checkInit();
		resetCatchParams();
		if (_image.empty) return;
		int dropper() {
			assert (cInImage(e.x, e.y));
			int ix = cxtoix(e.x);
			int iy = cytoiy(e.y);

			// Selects most upper opacity pixel
			int pixel = iGetPixel(ix, iy, _image.layerCount - 1);
			foreach (l; 0 .. _image.layerCount - 1) {
				if (!_image.layer(l).visible) continue;
				auto p = iGetPixel(ix, iy, l);
				if (_image.layer(l).image.transparentPixel != p) {
					pixel = p;
					break;
				}
			}
			return pixel;
		}
		switch (e.button) {
		case 1:
			scope (exit) this.p_cursor = iCursorNow(cxtoix(e.x), cytoiy(e.y));
			_mouseDown = -1;
			if (_pasteLayer) return;
			if (_rangeSel) {
				// Don't draws.
				return;
			}
			scope (exit) {
				_iCurFrom.x = _iCurTo.x;
				_iCurFrom.y = _iCurTo.y;
			}
			if (_mode is PaintMode.FreePath || _mode is PaintMode.Fill) {
				// Unnecessary. After painted.
				if (_um) _um.resetRetryWord();
				return;
			}
			if (_um) _um.store(this);
			iPath((int ix, int iy) {
				iSetPixels(ix, iy);
			});
			drawReceivers.raiseEvent();
			break;
		case 2:
			// Sets mask color.
			if (cInImage(e.x, e.y)) {
				size_t pixel = dropper();
				_mask[pixel] = !_mask[pixel];
				changedMaskReceivers.raiseEvent(pixel);
			}
			break;
		case 3:
			// Do dropper.
			scope (exit) this.p_cursor = iCursorNow(cxtoix(e.x), cytoiy(e.y));
			_mouseDown = -1;
			if (cInImage(e.x, e.y)) {
				_pixel = dropper();
				redrawCursorArea();

				auto se = new Event;
				se.time = e.time;
				se.stateMask = e.stateMask;
				se.doit = e.doit;
				notifyListeners(SWT.Selection, se);
				e.doit = se.doit;
			}
			break;
		default:
			break;
		}
	}

	/// Change zoom magnification.
	private void onMouseWheel(Event e) {
		checkWidget();
		if (0 == e.count) return;
		auto old = zoom;

		if (e.count < 0) {
			zoom = max(1, zoom / 2);
		} else {
			assert (0 < e.count);
			zoom = min(cast(int)zoom * 2, ZOOM_MAX);
		}

		if (zoom != old) {
			statusChangedReceivers.raiseEvent();
		}
		e.doit = false;
	}

	/// Adds or removes a listener for selection event (got color).
	void addSelectionListener(SelectionListener listener) {
		checkWidget();
		checkInit();
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
		checkInit();
		if (!listener) {
			SWT.error(__FILE__, __LINE__, SWT.ERROR_NULL_ARGUMENT);
		}
		removeListener(SWT.Selection, listener);
		removeListener(SWT.DefaultSelection, listener);
	}

	override Point computeSize(int wHint, int hHint, bool changed) {
		checkWidget();
		checkInit();
		int cbw = this.p_borderWidth * 2;
		int cw = (wHint == SWT.DEFAULT) ? itoc(_image.width) + cbw : wHint;
		int ch = (hHint == SWT.DEFAULT) ? itoc(_image.height) + cbw : hHint;
		return CPoint(cw, ch);
	}

	/// A data object for undo.
	private static class StoreData {
		/// Selection layers.
		size_t[] layers;
		/// StoreData of MLImage.
		Object image = null;
		/// Paste source layer.
		MLImage pasteLayer = null;
		/// Coordinates of paste source.
		int iPasteX = 0;
		/// ditto
		int iPasteY = 0;
		/// Range of moving.
		int iMoveX = 0;
		/// ditto
		int iMoveY = 0;
		/// ditto
		int iMoveW = 0;
		/// ditto
		int iMoveH = 0;
		/// Is enabled background color?
		bool enabledBackColor = false;
		/// Background pixel.
		int backPixel = 0;
	}
	@property
	override Object storeData() {
		auto data = new StoreData;
		data.layers = _layers.dup;
		data.image = _image.storeData;
		if (_pasteLayer) {
			data.pasteLayer = _pasteLayer.createMLImage();
			data.iPasteX = _iSelRange.x;
			data.iPasteY = _iSelRange.y;
			data.iMoveX = _iMoveRange.x;
			data.iMoveY = _iMoveRange.y;
			data.iMoveW = _iMoveRange.width;
			data.iMoveH = _iMoveRange.height;
			data.enabledBackColor = _enabledBackColor;
			data.backPixel = _backPixel;
		}
		return data;
	}
	override void restore(Object data, UndoMode mode) {
		cancelPaste();
		auto st = cast(StoreData)data;
		enforce(st);
		_image.restore(st.image, mode);
		if (st.pasteLayer) {
			auto layers = _layers;
			scope (exit) _layers = layers;
			_layers = st.layers;
			_pasteLayer = st.pasteLayer.createMLImage();
			initPasteLayer(st.iPasteX, st.iPasteY);
			_iMoveRange.x = st.iMoveX;
			_iMoveRange.y = st.iMoveY;
			_iMoveRange.width = st.iMoveW;
			_iMoveRange.height = st.iMoveH;
			fixPasteImpl(st.enabledBackColor, st.backPixel);
		}
		clearCache(false);
		redraw();
		drawReceivers.raiseEvent();
		changedLayerReceivers.raiseEvent();
		restoreReceivers.raiseEvent(mode);
	}
	@property
	override bool enabledUndo() {
		return !this.p_disposed && _image.enabledUndo;
	}
}

/// This class is previewer for image.
class PaintPreview : Canvas {
	/// Preview this area.
	private PaintArea _paintArea = null;

	/// Coordinates of left top of preview area.
	private int _px = 0, _py = 0;

	/// Is mouse button downing?
	private bool _mouseDown = false;
	/// Mouse downed coordinates.
	private int _mx = -1, _my = -1;
	/// Coordinates of when mouse downed.
	private int _mpx = 0, _mpy = 0;

	/// The only constructor.
	this (Composite parent, int style) {
		super (parent, style);

		auto d = parent.p_display;
		this.p_background = d.getSystemColor(SWT.COLOR_GRAY);
		this.p_foreground = d.getSystemColor(SWT.COLOR_DARK_GRAY);

		this.bindListeners();
	}

	/// Sets preview target image.
	void init(PaintArea paintArea) {
		checkWidget();
		if (_paintArea) {
			_paintArea.drawReceivers.removeReceiver(&redraw);
			_paintArea.image.resizeReceivers.removeReceiver(&resizeReceiver);
		}
		if (paintArea) {
			paintArea.checkInit();
			paintArea.drawReceivers ~= &redraw;
			paintArea.image.resizeReceivers ~= &resizeReceiver;

			auto d = this.p_display;
			auto ca = this.p_clientArea;
			if (ca.width < paintArea.image.width || ca.height < paintArea.image.height) {
				this.p_cursor = d.getSystemCursor(SWT.CURSOR_HAND);
			}
		} else {
			this.p_cursor = null;
		}
		_paintArea = paintArea;
		_px = 0;
		_py = 0;
		_mouseDown = false;
		_mx = -1;
		_my = -1;
		redraw();
	}

	/// This method is called when resizing.
	private void resizeReceiver() {
		if (!_paintArea || _paintArea.image.empty) {
			return;
		}
		checkWidget();
		auto ca = this.p_clientArea;

		int iw = _paintArea.image.width;
		int ih = _paintArea.image.height;
		if (ca.width < iw || ca.height < ih) {
			auto d = this.p_display;
			this.p_cursor = d.getSystemCursor(SWT.CURSOR_HAND);
		} else {
			this.p_cursor = null;
		}

		if (iw <= ca.width) {
			_px = 0;
		} else if ((iw - _px) < ca.width) {
			_px -= ca.width - (iw - _px);
		}
		if (ih <= ca.height) {
			_py = 0;
		} else if ((ih - _py) < ca.height) {
			_py -= ca.height - (ih - _py);
		}
		_mouseDown = false;
		_mx = -1;
		_my = -1;
	}
	/// ditto
	private void onResize(Event e) {
		checkWidget();
		resizeReceiver();
	}

	private void onDispose(Event e) {
		checkWidget();
		if (_paintArea) {
			_paintArea.drawReceivers.removeReceiver(&redraw);
			_paintArea.image.resizeReceivers.removeReceiver(&resizeReceiver);
		}
	}

	/// Draws image preview.
	private void onPaint(Event e) {
		checkWidget();
		auto ca = this.p_clientArea;
		if (!_paintArea || _paintArea.image.empty) {
			drawShade(e.gc, ca);
			return;
		}
		bool painted = false;

		if (_paintArea.image.width < ca.width || _paintArea.image.height < ca.height) {
			drawShade(e.gc, ca);
			painted = true;
		}
		auto d = this.p_display;

		int iw = _paintArea.image.width;
		int ih = _paintArea.image.height;

		int srcX = .max(0, _px);
		int srcY = .max(0, _py);
		int destX = iw < ca.width  ? (ca.width  - iw) / 2 : 0;
		int destY = ih < ca.height ? (ca.height - ih) / 2 : 0;
		int w = .min(ca.width, iw - srcX);
		int h = .min(ca.height, ih - srcY);

		foreach_reverse (l; 0 .. _paintArea.image.layerCount) {
			if (!_paintArea.image.layer(l).visible) continue;
			auto img = _paintArea.showingImage(l, false, null);
			if (!img) continue;
			e.gc.drawImage(img, srcX, srcY, w, h, destX, destY, w, h);
			painted = true;
		}

		if (!painted) {
			drawShade(e.gc, ca);
		}
	}

	/// Moves preview range.
	private void onMouseMove(Event e) {
		if (!_paintArea || _paintArea.image.empty) {
			return;
		}
		checkWidget();
		auto ca = this.p_clientArea;
		int iw = _paintArea.image.width;
		int ih = _paintArea.image.height;
		if (iw <= ca.width && ih <= ca.height) return;
		if (!_mouseDown) return;

		int px = _mpx + (_mx - e.x);
		int py = _mpy + (_my - e.y);

		px = max(0, px);
		px = min(px, iw - ca.width);
		py = max(0, py);
		py = min(py, ih - ca.height);

		if (px != _px || py != _py) {
			_px = px;
			_py = py;
			redraw();
		}
	}
	/// ditto
	private void onMouseDown(Event e) {
		if (!_paintArea || _paintArea.image.empty) {
			return;
		}
		checkWidget();
		if (1 != e.button) return;
		_mouseDown = true;
		_mx = e.x;
		_my = e.y;
		_mpx = _px;
		_mpy = _py;
	}
	/// ditto
	private void onMouseUp(Event e) {
		if (!_paintArea || _paintArea.image.empty) {
			return;
		}
		checkWidget();
		if (1 != e.button) return;
		_mouseDown = false;
		_mx = -1;
		_my = -1;
	}

	override Point computeSize(int wHint, int hHint, bool changed) {
		checkWidget();
		int cbw = this.p_borderWidth * 2;
		int cw, ch;
		if (wHint == SWT.DEFAULT) {
			if (_paintArea && !_paintArea.image.empty) {
				cw = _paintArea.image.width + cbw;
			} else {
				cw = cbw;
			}
		} else {
			cw = wHint;
		}
		if (hHint == SWT.DEFAULT) {
			if (_paintArea && !_paintArea.image.empty) {
				ch = _paintArea.image.height + cbw;
			} else {
				ch = cbw;
			}
		} else {
			ch = hHint;
		}
		return CPoint(cw, ch);
	}
}

/// List of layers for PaintArea.
class LayerList : Canvas {
	/// Height of a layer view of one.
	private static const LAYER_H = 60;

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
			paintArea.checkInit();
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
					if (ib.height < LAYER_H) y += (LAYER_H - ib.height) / 2;
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
