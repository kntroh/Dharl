
/// This module includes PaintArea and members related to it. 
module dharl.ui.paintarea;

private import dharl.util.undomanager;
private import dharl.util.graphics;
private import dharl.util.types;
private import dharl.util.utils;
private import dharl.ui.mlimage;
private import dharl.ui.dwtutils;

private import std.algorithm;
private import std.conv;
private import std.datetime;
private import std.exception;
private import std.string;

private import org.eclipse.swt.all;

/// This class has a image by division layers,
/// Edit from user to each layer is accepted. 
class PaintArea : Canvas, Undoable {
	static const ZOOM_MAX = 32;

	/// Draw event receivers. TODO comment
	void delegate()[] drawReceivers;
	/// Status changed event receivers. TODO comment
	void delegate()[] statusChangedReceivers;
	/// Select changed event receivers. TODO comment
	void delegate(int x, int y, int w, int h)[] selectChangedReceivers;
	/// Restore event receivers. TODO comment
	void delegate()[] restoreReceivers;
	/// Changed layer event receivers. TODO comment
	void delegate()[] changedLayerReceivers;

	/// Identify of this. TODO comment
	private string _id;

	/// The image.
	private MLImage _image = null;
	/// Selected layers. TODO comment
	private size_t[] _layers = [0];
	/// Paste layer. TODO comment
	private MLImage _pasteLayer = null;
	/// Temporary of mouse cursor coordinates for moves paste layer. TODO comment
	private int _iPCatchX, _iPCatchY;

	/// Selected color.
	private size_t _pixel = 0;
	/// Background color. TODO comment
	private size_t _backPixel = 1;

	/// Temporary for iGetPixels() TODO comment
	private int[] _pixelsTemp;
	/// Temporary for iPGetPixels() TODO comment
	private int[] _pastePixelsTemp;

	/// Enabled to background color. TODO comment
	private bool _enabledBackColor = false;

	/// Settings of mask color. TODO comment
	private bool[256] _mask;

	/// Zoom magnification.
	private uint _zoom = 1;

	/// Cursor.
	private Point _iCurFrom, _iCurTo;
	/// Cursor size.
	private uint _iCurSize = 1;

	/// Range selection mode. TODO comment
	private bool _rangeSel = false;
	/// Selected range.
	private Rectangle _iSelRange;
	/// Moving range. TODO comment
	private Rectangle _iMoveRange;
	/// When moving is true. TODO comment
	private bool _moving = false;
	/// Directions at catched frame of selected range. TODO comment
	private bool _catchN = false;
	private bool _catchE = false; /// ditto
	private bool _catchS = false; /// ditto
	private bool _catchW = false; /// ditto
	/// Catched coordinates. TODO comment
	private int _iCatchX = -1, _iCatchY = -1;
	/// Selected range before catch.
	private Rectangle _iOldSelRange;

	/// Paint mode.
	private PaintMode _mode = PaintMode.FreePath;

	/// Is mouse button downing?
	private bool _mouseDown = false;
	/// Is there mouse cursor?
	private bool _mouseEnter = false;

	/// Undo manager. TODO comment
	private UndoManager _um = null;

	/// Paint's tone. TODO comment
	private bool[][] _tone = null;

	/// Is grid showing? TODO comment
	private bool _grid1 = false, _grid2 = false;

	/// Line of canvas size. TODO comment
	private uint _canvasW = 0, _canvasH = 0;

	/// Cache of showingIamge(). TODO comment
	private Image[] _cache = [];

	/// A cursor of every paint mode.
	private Cursor[PaintMode] _cursor;

	/// The only constructor.
	this (Composite parent, int style) {
		super (parent, style | SWT.H_SCROLL | SWT.V_SCROLL);
		_id = format("%x-%d", &this, Clock.currTime().stdTime);

		_image = new MLImage;
		_image.resizeReceivers ~= &resizeReceiver;
		_image.initializeReceivers ~= &resizeReceiver;
		_iCurFrom = CPoint(0, 0);
		_iCurTo = CPoint(0, 0);
		_iSelRange = CRect(0, 0, 0, 0);
		_iMoveRange = CRect(0, 0, 0, 0);
		_iOldSelRange = CRect(0, 0, 0, 0);

		auto d = parent.p_display;
		this.p_background = d.getSystemColor(SWT.COLOR_GRAY);
		this.p_foreground = d.getSystemColor(SWT.COLOR_DARK_GRAY);

		auto hs = this.p_horizontalBar;
		assert (hs);
		hs.listeners!(SWT.Selection) ~= &redraw;
		auto vs = this.p_verticalBar;
		assert (vs);
		vs.listeners!(SWT.Selection) ~= &redraw;

		this.bindListeners();
	}

	/// Calculates parameters of scroll bars. TODO comment
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
		enforce(_image, new Exception("PantArea is no initialized.", __FILE__, __LINE__));
	}

	private void raiseSelectChangedEvent() {
		auto ia = iCursorArea;
		selectChangedReceivers.raiseEvent(ia.x, ia.y, ia.width, ia.height);
	}

	/// Initializes this paint area.
	/// If call a other methods before didn't called this,
	/// It throws exception.
	/// TODO comment
	void init(ImageData image, string layerName) {
		checkWidget();
		_pixel = 1;
		_backPixel = 0;
		_image.resizeReceivers.removeReceiver(&resizeReceiver);
		scope (exit) _image.resizeReceivers ~= &resizeReceiver;
		_image.init(image, layerName);
		clearCache();
	}
	/// ditto
	void init(uint w, uint h, PaletteData palette) {
		checkWidget();
		_pixel = 1;
		_backPixel = 0;
		_image.resizeReceivers.removeReceiver(&resizeReceiver);
		scope (exit) _image.resizeReceivers ~= &resizeReceiver;
		_image.init(w, h, palette);
		clearCache();
	}

	private void resizeReceiver() {
		cancelPaste();
		calcScrollParams();
		redraw();
		statusChangedReceivers.raiseEvent();
	}

	/// Undo manager. TODO comment
	@property
	void undoManager(UndoManager um) { _um = um; }
	/// ditto
	@property
	const
	const(UndoManager) undoManager() { return _um; }

	/// Returns image in this. TODO comment
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

	/// TODO comment
	bool pushImage(MLImage src, int srcX, int srcY) {
		if (!src) {
			SWT.error(__FILE__, __LINE__, SWT.ERROR_NULL_ARGUMENT);
		}
		checkWidget();
		checkInit();
		cancelPaste();
		if (_um) _um.store(this);
		clearCache();
		redraw();
		return _image.pushImage(src, srcX, srcY, _backPixel);
	}

	/// If this hasn't layer, returns true. TODO comment
	@property
	const
	bool empty() {
		checkInit();
		return _image.empty;
	}

	/// Adds layer.
	/// A layer after second,
	/// is a first color treats as transparent pixel.
	void addLayer(string layerName) {
		if (!layerName) {
			SWT.error(__FILE__, __LINE__, SWT.ERROR_NULL_ARGUMENT);
		}
		checkWidget();
		checkInit();
		if (!_image.empty) {
			if (_um) _um.store(this);
		}
		_image.addLayer(layerName);
		_layers.length = 1;
		_layers[0] = _image.layerCount - 1;
		clearCache();
		changedLayerReceivers.raiseEvent();
		statusChangedReceivers.raiseEvent();
	}
	/// Removes layer.
	/// TODO comment
	void removeLayer(size_t index) {
		if (_image.layerCount <= index) {
			SWT.error(__FILE__, __LINE__, SWT.ERROR_INVALID_ARGUMENT);
		}
		checkWidget();
		checkInit();
		if (_um) _um.store(this);
		if (1 == _image.layerCount) {
			// Reserve one layer. TODO comment
			auto ib = CRect(0, 0, _image.width, _image.height);
			iFillRect((int ix, int iy) {
				iSetPixels(ix, iy, _backPixel);
			}, ib);
			clearCache();
			drawReceivers.raiseEvent();
			return;
		}
		_image.removeLayer(index);
		_layers = remove!(SwapStrategy.unstable)(_layers, index);
		if (!_layers.length) {
			_layers.length = 1;
			if (_image.layerCount <= index) index--;
			_layers[0] = index;
		}
		clearCache();
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
			// Reserve one layer. TODO comment
			assert (0 == from);
			from++;
			auto ib = CRect(0, 0, _image.width, _image.height);
			iFillRect((int ix, int iy) {
				iSetPixel(ix, iy, _backPixel, 0);
			}, ib);
			if (from == to) {
				clearCache();
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
		clearCache();
		redraw();
		drawReceivers.raiseEvent();
		changedLayerReceivers.raiseEvent();
		statusChangedReceivers.raiseEvent();
	}

	/// Selected layers. TODO comment
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

		auto ls = layers.dup;
		ls = ls.sort;
		ls = ls.unify;
		if (_layers == ls) return;

		fixPaste();
		_layers = ls;
		clearCache();
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

	/// Selected area. TODO comment
	@property
	Rectangle selectedArea() {
		checkWidget();
		checkInit();
		if (empty || !_rangeSel) return CRect(0, 0, 0, 0);
		return iCursorArea;
	}

	/// Selected pixel (Index of palette).
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
		clearCache();
		redrawCursorArea();
		drawReceivers.raiseEvent();
	}

	/// Background pixel (Index of palette). TODO comment
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
			clearCache();
			redrawCursorArea();
			drawReceivers.raiseEvent();
		}
	}

	/// Enabled to background color. TODO comment
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
			clearCache();
			redrawCursorArea();
			drawReceivers.raiseEvent();
		}
		statusChangedReceivers.raiseEvent();
	}

	/// Settings of color mask. TODO comment
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
		clearCache();
		redrawCursorArea();
		drawReceivers.raiseEvent();
	}

	/// Paint's tone.
	/// Default value is null. TODO comment
	@property
	const
	const(bool[])[] tone() { return _tone; }
	/// ditto
	@property
	void tone(in bool[][] v) {
		if (v && 0 < v.length) {
			/// Require rectangle. TODO comment
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
		clearCache();
		redrawCursorArea();
		drawReceivers.raiseEvent();
	}

	/// Is grid showing? TODO comment
	@property
	void grid1(bool v) {
		checkWidget();
		checkInit();
		if (_grid1 == v) return;
		_grid1 = v;
		redraw();
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
	}
	/// ditto
	@property
	const
	bool grid2() {
		checkInit();
		return _grid2;
	}

	/// Line of canvas size. TODO comment
	void setCanvasSize(uint w, uint h) {
		checkWidget();
		checkInit();
		if (_canvasW == w && _canvasH == h) return;
		_canvasW = w;
		_canvasH = h;
		redraw();
	}
	/// ditto
	@property
	const
	Point canvasSize() {
		checkInit();
		return CPoint(_canvasW, _canvasH);
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
		clearCache();
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
		clearCache();
		redraw();
		drawReceivers.raiseEvent();
	}
	/// Sets all colors. TODO comment
	@property
	void colors(in RGB[] rgbs) {
		checkWidget();
		checkInit();
		_image.colors = rgbs;
		if (_pasteLayer) {
			_pasteLayer.colors = rgbs;
		}
		clearCache();
		redraw();
		drawReceivers.raiseEvent();
	}
	/// Swap pixel colors.
	void swapColor(int pixel1, int pixel2) {
		checkWidget();
		checkInit();

		_image.swapColor(pixel1, pixel2);

		clearCache();
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
		auto ip = iCenter;
		_zoom = v;
		calcScrollParams();
		iCenter = ip;

		clearCache();
		redraw();
		drawReceivers.raiseEvent();
	}

	/// Range selection mode. TODO comment
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
		_mouseDown = false;
		resetSelectedRange();

		clearCache();
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
		_mouseDown = false;
		resetSelectedRange();

		clearCache();
		redrawCursorArea();
		drawReceivers.raiseEvent();
		statusChangedReceivers.raiseEvent();
	}

	/// Cursor size.
	/// If it is 0, no draws. TODO comment
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

		clearCache();
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
			this.p_cursor = cursor;
		}
	}

	/// Operations to cut, copy, paste, and delete. TODO comment
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
		auto it = cast(Transfer) ImageTransfer.getInstance();
		cb.setContents([data], [it]);
	}
	/// ditto
	void paste() {
		checkWidget();
		checkInit();
		if (_image.empty) return;

		auto d = this.p_display;
		auto cb = new Clipboard(d);
		scope (exit) cb.dispose();

		auto data = cast(ImageData) cb.getContents(ImageTransfer.getInstance());
		if (!data) return;

		fixPaste();
		if (_um) _um.store(this);
		rangeSelection = true;
		auto imageData = new ImageData(data.width, data.height, 8, _image.copyPalette());

		auto colors = new CRGB[imageData.palette.colors.length];
		foreach (i, rgb; imageData.palette.colors) {
			colors[i].r = cast(ubyte) rgb.red;
			colors[i].g = cast(ubyte) rgb.green;
			colors[i].b = cast(ubyte) rgb.blue;
		}
		auto tree = new ColorTree(colors, false);
		foreach (idx; 0 .. data.width) {
			foreach (idy; 0 .. data.height) {
				auto rgb = data.palette.getRGB(data.getPixel(idx, idy));
				CRGB c;
				c.r = cast(ubyte) rgb.red;
				c.g = cast(ubyte) rgb.green;
				c.b = cast(ubyte) rgb.blue;
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
			// Paste to top left at visible area. TODO comment
			ix = iVisibleLeft;
			iy = iVisibleTop;
		}
		initPasteLayer(ix, iy);
		_moving = true;
	}
	/// TODO comment
	private void initPasteLayer(int ix, int iy) {
		enforce(_pasteLayer);
		_iSelRange.x = ix;
		_iSelRange.y = iy;
		_iSelRange.width = _pasteLayer.width;
		_iSelRange.height = _pasteLayer.height;
		redrawCursorArea();
		raiseSelectChangedEvent();

		clearCache();
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
		clearCache();
		redrawCursorArea();
	}

	/// Fixes paste.
	/// A pasted image is floating on current layer,
	/// When fix calls this method or clicks out of range.
	/// If when not after paste, this method no process. TODO comment
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
			auto pll = _pasteLayer.layer(l).image;
			foreach (ix; 0 .. _pasteLayer.width) {
				foreach (iy; 0 .. _pasteLayer.height) {
					int pixel = pll.getPixel(ix, iy);
					if (!enabledBackColor || pixel != backPixel) {
						iSetPixel(_iSelRange.x + ix, _iSelRange.y + iy, pixel, l);
					}
				}
			}
		}
		redrawCursorArea();
		resetPasteParams();
	}
	/// Cancels paste. TODO comment
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
		clearCache();
		raiseSelectChangedEvent();
		drawReceivers.raiseEvent();
	}

	/// Selects full image.
	/// Set rangeSelection is true.TODO comment
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
		clearCache();
		redrawCursorArea();
		raiseSelectChangedEvent();
	}

	/// Scrolls to coordinate (image coordinates)
	/// into view port. TODO comment
	void scroll(int x, int y) {
		checkWidget();
		checkInit();
		iScroll(x, y);
	}
	/// ditto
	private void iScroll(int ix, int iy) {
		checkWidget();
		checkInit();
		// TODO comment
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

	/// Central coordinate at viewport. TODO comment
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

	/// Utility methods for transform. TODO comment
	private int[] iPGetPixels(int ix, int iy) {
		enforce (_pasteLayer);
		if (_pastePixelsTemp.length != _pasteLayer.layerCount) {
			_pastePixelsTemp.length = _pasteLayer.layerCount;
		}
		foreach (i, ref p; _pastePixelsTemp) {
			p = _pasteLayer.layer(i).image.getPixel(ix, iy);
		}
		return _pastePixelsTemp;
	}
	/// ditto
	private void iPSetPixels(int ix, int iy, int[] pixels) {
		enforce (_pasteLayer);
		assert (pixels.length == _pasteLayer.layerCount);
		foreach (i, p; pixels) {
			_pasteLayer.layer(i).image.setPixel(ix, iy, p);
		}
	}
	/// ditto
	private int[] iGetPixels2(int ix, int iy) {
		return iGetPixels(ix, iy).dup;
	}
	/// ditto
	private void iSetPixels2(int ix, int iy, int[] pixels) {
		iSetPixels(ix, iy, pixels);
	}

	/// Transforms image. TODO comment
	private void transform(void function
			(int[] delegate(int x, int y) pget,
			void delegate(int x, int y, int[] pixels) pset,
			int sx, int sy, int w, int h) func) {
		checkWidget();
		checkInit();
		if (_image.empty) return;
		if (_pasteLayer) {
			func(&iPGetPixels, &iPSetPixels, 0, 0, _pasteLayer.width, _pasteLayer.height);
			clearCache();
			redrawCursorArea();
		} else if (_iSelRange.p_empty) {
			if (_um) _um.store(this);
			clearCache();
			func(&iGetPixels2, &iSetPixels2,
				0, 0, _image.width, _image.height);
		} else {
			if (_um) _um.store(this);
			clearCache();
			auto ir = iInImageRect(_iSelRange.x, _iSelRange.y, _iSelRange.width, _iSelRange.height);
			func(&iGetPixels2, &iSetPixels2, ir.x, ir.y, ir.width, ir.height);
		}
		clearCache();
		drawReceivers.raiseEvent();
	}

	/// TODO comment
	void mirrorHorizontal() {
		transform(&.mirrorHorizontal!(int[]));
	}
	/// ditto
	void mirrorVertical() {
		transform(&.mirrorVertical!(int[]));
	}
	/// ditto
	void rotateRight() {
		transform(&.rotateRight!(int[]));
	}
	/// ditto
	void rotateLeft() {
		transform(&.rotateLeft!(int[]));
	}
	/// ditto
	void rotateUp() {
		transform(&.rotateUp!(int[]));
	}
	/// ditto
	void rotateDown() {
		transform(&.rotateDown!(int[]));
	}

	/// Resize image. TODO comment
	void resize(int newW, int newH) {
		checkWidget();
		checkInit();
		if (_image.empty) return;
		int iNewW = newW;
		int iNewH = newH;
		int iw, ih;
		void fillRest(int ifx, int ify) {
			if (iNewW < iw && iNewH < ih) {
				iFillRect((int ix, int iy) {
					iSetPixels(ix, iy, _backPixel);
				}, ifx + iNewW, ify, iw - iNewW, iNewH + (ih - iNewH));
				iFillRect((int ix, int iy) {
					iSetPixels(ix, iy, _backPixel);
				}, ifx, ify + iNewH, iNewW, ih - iNewH);
				return;
			}
			if (iNewW < iw) {
				iFillRect((int ix, int iy) {
					iSetPixels(ix, iy, _backPixel);
				}, ifx + iNewW, ify, iw - iNewW , iNewH);
			}
			if (iNewH < ih) {
				iFillRect((int ix, int iy) {
					iSetPixels(ix, iy, _backPixel);
				}, ifx, ify + iNewH, iNewW, ih - iNewH);
			}
		}
		if (_pasteLayer) {
			redrawCursorArea();
			iw = _pasteLayer.width;
			ih = _pasteLayer.height;
			auto newLayer = _pasteLayer.createMLImage();
			.resize!(int[])(iNewW, iNewH, &iPGetPixels, (int ix, int iy, int[] pixels) {
				assert (pixels.length == newLayer.layerCount);
				foreach (i, p; pixels) {
					newLayer.layer(i).image.setPixel(ix, iy, p);
				}
			}, 0, 0, iw, ih);
			_iSelRange.width = iNewW;
			_iSelRange.height = iNewH;
			redrawCursorArea();
		} else if (_iSelRange.p_empty) {
			iw = _image.width;
			ih = _image.height;
			if (iw == iNewW && ih == iNewH) return;
			if (_um) _um.store(this);
			.resize!(int[])(iNewW, iNewH, &iGetPixels, &iSetPixels2, 0, 0, iw, ih);
			fillRest(0, 0);
		} else {
			redrawCursorArea();
			auto ir = iInImageRect(_iSelRange.x, _iSelRange.y, _iSelRange.width, _iSelRange.height);
			int ix = ir.x;
			int iy = ir.y;
			iw = ir.width;
			ih = ir.height;
			if (iw == iNewW && ih == iNewH) return;
			if (_um) _um.store(this);
			.resize!(int[])(iNewW, iNewH, &iGetPixels, &iSetPixels2, ix, iy, iw, ih);
			_iSelRange.x = ix;
			_iSelRange.y = iy;
			_iSelRange.width = iNewW;
			_iSelRange.height = iNewH;
			fillRest(ix, iy);
			redrawCursorArea();
		}
		clearCache();
		drawReceivers.raiseEvent();
	}

	private void onMouseEnter(Event e) {
		checkWidget();
		checkInit();
		_mouseEnter = true;
		clearCache();
		redrawCursorArea();
	}
	private void onMouseExit(Event e) {
		checkWidget();
		checkInit();
		_mouseEnter = false;
		clearCache();
		redrawCursorArea();
	}

	/// TODO comment
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
	/// TODO comment
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
			if (0 == _iCurSize) {
				return CRect(0, 0, 0, 0);
			}
			int ix, iy, iw, ih;
			int ics = _rangeSel ? 0 : _iCurSize - 1;
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
		clearCache();
		raiseSelectChangedEvent();
	}
	/// Reset catch frame parameters. TODO comment
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
		return c / cast(int) _zoom;
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
	/// Converts a image coordinate to a control coordinate.
	const
	private int itoc(int i) {
		checkInit();
		return i * cast(int) _zoom;
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
	/// Zooms values of rectangle.
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

	/// Is chacked frame of selected range. TODO comment
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

	/// If coordinates can draw, returns true. TODO comment
	private bool iCanDraw(int ix, int iy, size_t layer) {
		if (iMask(ix, iy, layer)) return false;
		if (_tone && 0 < _tone.length) {
			auto toneLn = _tone[iy % $];
			return 0 == toneLn.length || toneLn[ix % $];
		}
		return true;
	}

	/// If coordinates masked, returns true. TODO comment
	private bool iMask(int ix, int iy, size_t layer) {
		return _mask[iGetPixel(ix, iy, layer)];
	}

	/// Sets pixel of current layer.
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
			_image.layer(l).image.setPixel(ix, iy, pixel);
		}
		clearCache();
		redraw(ixtocx(ix), iytocy(iy), itoc(1), itoc(1), false);
	}
	/// ditto
	private void iSetPixels(int ix, int iy, in int[] pixels) {
		checkWidget();
		checkInit();
		enforce(pixels.length == _layers.length);
		if (_image.empty) return;
		if (!iInImage(ix, iy)) return;
		foreach (i, l; _layers) {
			if (!iCanDraw(ix, iy, l)) continue;
			if (-1 == pixels[i]) continue;
			_image.layer(l).image.setPixel(ix, iy, pixels[i]);
		}
		clearCache();
		redraw(ixtocx(ix), iytocy(iy), itoc(1), itoc(1), false);
	}
	/// ditto
	private void iSetPixel(int ix, int iy, int pixel, int layer) {
		checkWidget();
		checkInit();
		if (_image.empty) return;
		if (!iInImage(ix, iy)) return;
		if (!iCanDraw(ix, iy, layer)) return;
		_image.layer(layer).image.setPixel(ix, iy, pixel);
		clearCache();
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
	/// Calls dlg(X, Y) with fill of rectangle. TODO comment
	private void iFillRect(void delegate(int ix, int iy) dlg, Rectangle ia) {
		iFillRect(dlg, ia.x, ia.y, ia.width, ia.height);
	}
	/// ditto
	private void iFillRect(void delegate(int ix, int iy) dlg, int ix, int iy, int iw, int ih) {
		pointsOfPath(dlg, PaintMode.RectFill,
			ix, iy, ix + iw - 1, iy + ih - 1, _image.width, _image.height, 1);
	}

	/// Draws paste layer. TODO comment
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

	/// Deletes cache of showingIamge(). TODO comment
	private void clearCache() {
		foreach (ref c; _cache) {
			if (c) {
				c.dispose();
				c = null;
			}
		}
		_cache.length = _image.layerCount;
	}
	/// Creates showing image. TODO comment
	private Image showingImage(size_t layer, bool oneLayer) {
		checkWidget();
		checkInit();

		if (layer < _cache.length && _cache[layer] && !oneLayer) {
			return _cache[layer];
		}

		auto d = this.p_display;

		auto selLayer = selectedInfo;

		// Draws layer.
		auto data = new ImageData(_image.width, _image.height, 8, _image.palette);

		auto l = _image.layer(layer).image;
		if (0 == layer && !selLayer[layer]) {
			data.data[] = l.data;
		} else {
			int tPixel = (0 == layer) ? _backPixel : 0;
			foreach (ix; 0 .. _image.width) {
				foreach (iy; 0 .. _image.height) {
					// Fill background pixel to area before move. TODO comment
					if (selLayer[layer] && _iMoveRange.contains(ix, iy)) {
						data.setPixel(ix, iy, tPixel);
						continue;
					}
					int pixel = l.getPixel(ix, iy);
					// Pixel 0 in layer not first is transparent. TODO comment
					if (0 == layer || 0 != pixel) {
						data.setPixel(ix, iy, pixel);
					} else {
						data.setPixel(ix, iy, tPixel);
					}
				}
			}
			if (0 != layer && !oneLayer) {
				data.transparentPixel = tPixel;
			}
		}
		if (selLayer[layer] && _pasteLayer) {
			size_t pLayerIndex = 0;
			foreach (i; 0 .. layer) {
				if (selLayer[i]) pLayerIndex++;
			}
			pushPasteLayer(data, pLayerIndex, layer);
		} else if (!_rangeSel && _mouseDown) {
			/// Draws cursor in painting. TODO comment
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

		auto img = new Image(d, data);
		if (!oneLayer) {
			_cache[layer] = img;
		}
		return img;
	}

	private void onDispose(Event e) {
		clearCache();
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
		foreach (l; 0 .. _image.layerCount) {
			if (_image.layer(l).visible) {
				showImage = true;
				break;
			}
		}

		auto ib = CRect(0, 0, _image.width, _image.height);
		auto cb = itoc(ib);
		if (!showImage || ((cb.width < ca.width || cb.height < ca.height)
				&& !(cb.contains(e.x, e.y) && cb.contains(e.x + e.width, e.y + e.height)))) {
			drawShade(e.gc, ca);
		}

		bool showCursor = false;
		auto selInfo = selectedInfo;

		foreach (l; 0 .. _image.layerCount) {
			if (!_image.layer(l).visible) continue;
			auto img = showingImage(l, false);
			if (!img) continue;
			e.gc.drawImage(img, ib.x, ib.y, ib.width, ib.height,
				cb.x, cb.y, cb.width, cb.height);
			if (selInfo[l]) {
				showCursor = true;
			}
		}

		// Draws grid.
		if (_grid1 && 4 <= _zoom) {
			e.gc.p_lineStyle = SWT.LINE_DOT;
			scope (exit) e.gc.p_lineStyle = SWT.LINE_SOLID;
			foreach (ix; 0 .. ib.width) {
				e.gc.drawLine(ixtocx(ix), iytocy(0), ixtocx(ix), iytocy(ib.height));
			}
			foreach (iy; 0 .. ib.height) {
				e.gc.drawLine(ixtocx(0), iytocy(iy), ixtocx(ib.width), iytocy(iy));
			}
		}
		if (_grid2) {
			static const GRID_2_INTERVAL = 25;
			for (int ix; ix < ib.width; ix += GRID_2_INTERVAL) {
				e.gc.drawLine(ixtocx(ix), iytocy(0), ixtocx(ix), iytocy(ib.height));
			}
			for (int iy; iy < ib.height; iy += GRID_2_INTERVAL) {
				e.gc.drawLine(ixtocx(0), iytocy(iy), ixtocx(ib.width), iytocy(iy));
			}
		}
		if (0 != _canvasW && 0 != _canvasH) {
			e.gc.drawLine(ixtocx(_canvasW), iytocy(0), ixtocx(_canvasW), iytocy(_canvasH) + 1);
			e.gc.drawLine(ixtocx(0), iytocy(_canvasH), ixtocx(_canvasW), iytocy(_canvasH));
		}

		if ((_pasteLayer || _rangeSel) && !_iSelRange.p_empty) {
			// If selection area, draw focus line.
			auto cca = cCursorArea();
			e.gc.drawFocus(cca.x, cca.y, cca.width, cca.height);
		} else {
			// Draws cursor.
			if (showCursor && !_mouseDown && _mouseEnter && 0 != _layers.length) {
				// Draws only pixel under a mouse cursor.
				auto ia = iCursorArea;
				int ix1 = ia.x, ix2 = ia.x + ia.width - 1;
				int iy1 = ia.y, iy2 = ia.y + ia.height - 1;
				auto color = new Color(d, _image.palette.colors[_pixel]);
				scope (exit) color.dispose();
				e.gc.p_background = color;
				int ccs = itoc(1);
				pointsOfPath((int ix, int iy) {
					if (!iInImage(ix, iy)) return;
					if (ccs <= 4) {
						e.gc.fillRectangle(ixtocx(ix), iytocy(iy), ccs, ccs);
					} else {
						// TODO comment
						if (ix == ix1) {
							e.gc.fillRectangle(ixtocx(ix), iytocy(iy), 2, ccs);
						}
						if (ix == ix2) {
							e.gc.fillRectangle(ixtocx(ix) + ccs - 2, iytocy(iy), 2, ccs);
						}
						if (iy == iy1) {
							e.gc.fillRectangle(ixtocx(ix), iytocy(iy), ccs, 2);
						}
						if (iy == iy2) {
							e.gc.fillRectangle(ixtocx(ix), iytocy(iy) + ccs - 2, ccs, 2);
						}
					}
				}, PaintMode.RectLine, ix1, iy1, ix2, iy2, ib.width, ib.height, 1);
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
		if (_mouseDown) {
			if (_pasteLayer) {
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
					clearCache();
					redrawCursorArea();
					raiseSelectChangedEvent();
					drawReceivers.raiseEvent();
				}
				return;
			}
			if (_iCurTo.x == ix && _iCurTo.y == iy) {
				return;
			}
			clearCache();
			redrawCursorArea();
			int iOldX = _iCurTo.x;
			int iOldY = _iCurTo.y;
			_iCurTo.x = ix;
			_iCurTo.y = iy;
			if (_rangeSel) {
				// Resizes selected range. TODO comment
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
					// Selects range. TODO comment
					_iSelRange.x = min(_iCurFrom.x, _iCurTo.x);
					_iSelRange.y = min(_iCurFrom.y, _iCurTo.y);
					_iSelRange.width = max(_iCurFrom.x, _iCurTo.x) - _iSelRange.x;
					_iSelRange.height = max(_iCurFrom.y, _iCurTo.y) - _iSelRange.y;
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
			if (_pasteLayer) return;
			if (_rangeSel) {
				// TODO comment
				bool no, ea, so, we;
				cIsCatchedFocus(e.x, e.y, no, ea, so, we);
				auto d = this.p_display;
				if ((no && ea) || (so && we)) {
					this.p_cursor = d.getSystemCursor(SWT.CURSOR_SIZENESW);
				} else if ((no && we) || (ea && so)) {
					this.p_cursor = d.getSystemCursor(SWT.CURSOR_SIZENWSE);
				} else if (no || so) {
					this.p_cursor = d.getSystemCursor(SWT.CURSOR_SIZENS);
				} else if (ea || we) {
					this.p_cursor = d.getSystemCursor(SWT.CURSOR_SIZEWE);
				} else {
					this.p_cursor = cursor(mode);
				}
				return;
			}
			this.p_cursor = cursor(mode);
			if (_iCurFrom.x == ix && _iCurFrom.y == iy) {
				return;
			}
			clearCache();
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
			if (_mouseDown) return;
			_mouseDown = true;
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
					// Catching frame of selected range. TODO comment
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
					// Start move. TODO comment
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
				// Start draw. TODO comment
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
					// Fills area. TODO comment
					foreach (l; _layers) {
						int pixel = iGetPixel(_iCurFrom.x, _iCurFrom.y, l);
						if (pixel != _pixel) {
							bool first = true;
							pointsOfFill((int ix, int iy) {
								if (!iMask(ix, iy, l)) {
									if (first) {
										if (_um) _um.store(this);
										first = false;
									}
									iSetPixel(ix, iy, _pixel, l);
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
		switch (e.button) {
		case 1:
			_mouseDown = false;
			if (_pasteLayer) return;
			if (_rangeSel) {
				// No draws. TODO comment
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
		case 3:
			if (cInImage(e.x, e.y)) {
				auto pixels = iGetPixels(cxtoix(e.x), cytoiy(e.y));
				_pixel = pixels[0];
				foreach (i; 1 .. pixels.length) {
					if (0 != pixels[i]) {
						_pixel = pixels[i];
					}
				}
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

	/// Changes zoom parameter. TODO comment
	private void onMouseWheel(Event e) {
		checkWidget();
		if (0 == e.count) return;
		int count;
		auto old = zoom;
		if (e.count < 0) {
			count = min(e.count / 3, -1);
		} else {
			count = max(e.count / 3, 1);
		}
		zoom = max(1, min(cast(int) zoom + count, ZOOM_MAX));
		if (zoom != old) {
			statusChangedReceivers.raiseEvent();
		}
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

	/// Data object for undo. TODO comment
	private static class StoreData {
		/// Selected layers. TODO comment
		size_t[] layers;
		/// Store data of MLImage. TODO comment
		Object image = null;
		/// Paste layer. TODO comment
		MLImage pasteLayer = null;
		/// Paste coordinates. TODO comment
		int iPasteX = 0;
		/// ditto
		int iPasteY = 0;
		/// Move base coordinate. TODO comment
		int iMoveX = 0;
		/// ditto
		int iMoveY = 0;
		/// ditto
		int iMoveW = 0;
		/// ditto
		int iMoveH = 0;
		/// Background mode.
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
			data.pasteLayer = _pasteLayer;
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
		auto st = cast(StoreData) data;
		enforce(st);
		_image.restore(st.image, mode);
		if (st.pasteLayer) {
			auto layers = _layers;
			scope (exit) _layers = layers;
			_layers = st.layers;
			_pasteLayer = st.pasteLayer;
			initPasteLayer(st.iPasteX, st.iPasteY);
			_iMoveRange.x = st.iMoveX;
			_iMoveRange.y = st.iMoveY;
			_iMoveRange.width = st.iMoveW;
			_iMoveRange.height = st.iMoveH;
			fixPasteImpl(st.enabledBackColor, st.backPixel);
		}
		clearCache();
		redraw();
		drawReceivers.raiseEvent();
		restoreReceivers.raiseEvent();
	}
	@property
	override bool enabledUndo() {
		return !this.p_disposed && _image.enabledUndo;
	}
}

/// This class is previewer for image. TODO comment
class PaintPreview : Canvas {
	/// Preview paint area. TODO comment
	private PaintArea _paintArea = null;

	/// Coordinates of left and top of preview area. TODO comment
	private int _px = 0, _py = 0;

	/// Is mouse button downing?
	private bool _mouseDown = false;
	/// Mouse downed coordinates. TODO comment
	private int _mx = -1, _my = -1;
	/// When mouse downed preview area coordinates. TODO comment
	private int _mpx = 0, _mpy = 0;

	/// The only constructor.
	this (Composite parent, int style) {
		super (parent, style);

		auto d = parent.p_display;
		this.p_background = d.getSystemColor(SWT.COLOR_GRAY);
		this.p_foreground = d.getSystemColor(SWT.COLOR_DARK_GRAY);

		this.bindListeners();
	}

	/// Sets preview target image. TODO comment
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

	/// TODO comment
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

	/// Draws image. TODO comment
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

		int srcX = _px;
		int srcY = _py;
		int destX = iw < ca.width ? (ca.width - iw) / 2 : 0;
		int destY = ih < ca.height ? (ca.height - ih) / 2 : 0;
		int w = iw - _px;
		int h = ih - _py;

		foreach (l; 0 .. _paintArea.image.layerCount) {
			if (!_paintArea.image.layer(l).visible) continue;
			auto img = _paintArea.showingImage(l, false);
			if (!img) continue;
			e.gc.drawImage(img, srcX, srcY, w, h, destX, destY, w, h);
			painted = true;
		}

		if (!painted) {
			drawShade(e.gc, ca);
		}
	}

	/// Moves preview range. TODO comment
	private void onMouseMove(Event e) {
		if (!_paintArea || _paintArea.image.empty) {
			return;
		}
		checkWidget();
		auto ca = this.p_clientArea;
		int iw = _paintArea.image.width;
		int ih = _paintArea.image.height;
		if (iw <= ca.width || ih <= ca.height) return;
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

/// Layer list for PaintArea. TODO comment
class LayerList : Canvas {
	/// One layer height of view. TODO comment
	private static const LAYER_H = 60;

	/// Preview paint area. TODO comment
	private PaintArea _paintArea = null;

	/// Bounds of name area. TODO comment
	private PBounds[] _nameBounds;
	/// Bounds of check for visible. TODO comment
	private PBounds[] _vCheckBounds;

	/// Editor for layer name. TODO comment
	private Editor _editor;
	/// Index of layer editing name. TODO comment
	private size_t _editing = 0;

	/// Undo manager. TODO comment
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
		vs.listeners!(SWT.Selection) ~= &redraw;

		this.bindListeners();
	}

	/// Undo manager. TODO comment
	@property
	void undoManager(UndoManager um) { _um = um; }
	/// ditto
	@property
	const
	const(UndoManager) undoManager() { return _um; }

	/// Calculates parameters of scroll bars. TODO comment
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
		calcScrollParams();
	}

	/// Sets preview target image. TODO comment
	void init(PaintArea paintArea) {
		checkWidget();
		_editor.cancel();
		if (_paintArea) {
			_paintArea.drawReceivers.removeReceiver(&redraw);
			_paintArea.changedLayerReceivers.removeReceiver(&changedLayerReceiver);
			_paintArea.image.restoreReceivers.removeReceiver(&redraw);
		}
		if (paintArea) {
			paintArea.checkInit();
			paintArea.drawReceivers ~= &redraw;
			paintArea.changedLayerReceivers ~= &changedLayerReceiver;
			paintArea.image.restoreReceivers ~= &redraw;
		}
		_paintArea = paintArea;
		changedLayerReceiver();
	}

	/// Gets layer index from coordinates. TODO comment
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

	/// Edit layer name. TODO comment
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
			_paintArea.image.restoreReceivers.removeReceiver(&redraw);
		}
	}

	/// Draws layer list. TODO comment
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
			w = cast(int) (ib.width * (cast(real) LAYER_H / ib.height));
		} else {
			w = ib.width;
		}
		int th = e.gc.p_fontMetrics.p_height;
		foreach (l; 0 .. _paintArea.image.layerCount) {
			if (vss + ca.height <= y) break;
			if (0 <= y + LAYER_H + 2) {
				auto img = _paintArea.showingImage(l, true);
				auto layer = _paintArea.image.layer(l);
				scope (exit) img.dispose();

				if (selLayer[l]) {
					// Draws selection mark. TODO comment
					e.gc.p_background = d.getSystemColor(SWT.COLOR_DARK_BLUE);
					e.gc.fillRectangle(0, y, ca.width, LAYER_H + 2);
					// color of name text. TODO comment
					e.gc.p_foreground = d.getSystemColor(SWT.COLOR_WHITE);
				} else {
					// color of name text. TODO comment
					e.gc.p_foreground = d.getSystemColor(SWT.COLOR_BLACK);
				}

				// Draws name. TODO comment
				string name = layer.name;
				int tx = w + 2;
				int ty = y;
				if (!_editor.editing || _editing != l) {
					e.gc.drawText(name, tx, ty, true);
				}
				auto ts = e.gc.textExtent(name);
				_nameBounds[l] = PBounds(tx, ty, max(10, ts.x), th);

				// Draws check box of visible. TODO comment
				static const V_CHECK_W = 20;
				static const V_CHECK_H = 15;
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

				// Draws image preview. TODO comment
				if (LAYER_H < ib.height) {
					e.gc.drawImage(img, ib.x, ib.y, ib.width, ib.height, 1, y + 1, w, LAYER_H);
				} else {
					int iy = y;
					if (ib.height < LAYER_H) y += (LAYER_H - ib.height) / 2;
					e.gc.drawImage(img, ib.x + 1, iy + 1);
				}
				int ly = y + LAYER_H + 1;
				e.gc.p_lineStyle = SWT.LINE_DASH;
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
	/// Changes selected layers. TODO comment
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
	}

	/// Selects layer.
	private void onMouseDown(Event e) {
		if (!_paintArea || _paintArea.image.empty) {
			return;
		}
		checkWidget();
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
			// Require one layer select. TODO comment
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
	}

	override Point computeSize(int wHint, int hHint, bool changed) {
		checkWidget();
		int cbw = this.p_borderWidth * 2;
		int cw = (wHint == SWT.DEFAULT) ? LAYER_H + cbw : wHint;
		int ch = (hHint == SWT.DEFAULT) ? LAYER_H + cbw : hHint;
		return CPoint(cw, ch);
	}
}