
/// This module includes PImageList and members related to it. 
module dharl.ui.pimagelist;

private import dharl.util.utils;
private import dharl.ui.mlimage;
private import dharl.ui.dwtutils;
private import dharl.ui.dwtfactory;

private import std.algorithm;
private import std.conv;

private import org.eclipse.swt.all;

/// Image list.
/// This class displays image listing.
/// And user can select piece of image in list.
class PImageList : Canvas {
	/// Remove event receivers. TODO comment
	bool delegate(size_t index)[] removeReceivers;
	/// Removed event receivers. TODO comment
	void delegate()[] removedReceivers;

	/// Image spacing.
	private const SPACING = 5;

	/// Size of a selectable piece.
	private Point _pieceSize = null;
	/// Index of image selected.
	private int _selected = -1;
	/// Images.
	private PImageItem[] _images;

	/// Old coordinates of mouse cursor.
	private int _oldX = -1, _oldY = -1;

	/// The only constructor.
	this (Composite parent, int style) {
		super (parent, style | SWT.H_SCROLL | SWT.V_SCROLL);

		_pieceSize = CPoint(100, 100);

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

		int x = SPACING;
		int y = SPACING;
		int maxW = 0; // Maximum width in the list. TODO comment
		int maxH = 0; // Maximum height in a row. TODO comment.
		foreach (i, img; _images) {
			img._bounds.x = x;
			img._bounds.y = y;

			x += img._bounds.width + SPACING;
			maxW = max(maxW, x);
			maxH = max(maxH, img._bounds.height);

			if (i + 1 < _images.length) {
				if (ca.width < x + _images[i + 1]._bounds.width + SPACING) {
					x = SPACING;
					y += SPACING + maxH;
					maxH = 0;
				}
			}
		}
		// list size
		int w = maxW;
		int h = y + maxH + SPACING;

		auto hs = this.p_horizontalBar;
		assert (hs);
		auto vs = this.p_verticalBar;
		assert (vs);

		vs.setValues(vs.p_selection, 0, h, ca.height, ca.height / 10, ca.height / 2);
		bool vsv = vs.p_visible;
		vs.p_visible = ca.height < h;
		if (vsv != vs.p_visible) {
			ca = this.p_clientArea;
		}
		hs.setValues(hs.p_selection, 0, w, ca.width, ca.width / 10, ca.width / 2);
		hs.p_visible = ca.width < w;
	}

	/// Gets image count.
	@property
	const
	size_t imageCount() { return _images.length; }

	/// Index of image selected.
	/// -1 is no selected. TODO comment
	@property
	const
	int selectedIndex() { return _selected; }
	/// ditto
	@property
	void selectedIndex(int index) {
		if (index < -1) {
			SWT.error(__FILE__, __LINE__, SWT.ERROR_INVALID_ARGUMENT);
		}
		if (-1 != index && _images.length <= index) {
			SWT.error(__FILE__, __LINE__, SWT.ERROR_INVALID_ARGUMENT);
		}
		checkWidget();
		if (-1 != _selected) {
			_images[_selected].deselect();
		}
		_selected = index;
		if (-1 != index) {
			_images[index].redrawFocus();
		}
	}
	/// Index of image from location.
	/// If a location out of image _bounds, returns -1.
	/// A name area is -1. TODO comment
	int indexOf(int x, int y) {
		checkWidget();

		auto rect = CRect(0, 0, 0, 0);
		foreach (i, img; _images) {
			rect.x = img._bounds.x + img._iBounds.x;
			rect.y = img._bounds.y + img._iBounds.y;
			rect.width = img._iBounds.width;
			rect.height = img._iBounds.height;
			if (rect.contains(x, y)) {
				return i;
			}
		}
		return -1;
	}
	/// Index of image from location. TODO comment
	size_t indexOfName(int x, int y) {
		checkWidget();

		auto rect = CRect(0, 0, 0, 0);
		foreach (i, img; _images) {
			rect.x = img._bounds.x + img._tBounds.x;
			rect.y = img._bounds.y + img._tBounds.y;
			rect.width = img._tBounds.width;
			rect.height = img._tBounds.height;
			if (rect.contains(x, y)) {
				return i;
			}
		}
		return -1;
	}
	/// Index of image from location. TODO comment
	size_t indexOfLose(int x, int y) {
		checkWidget();

		auto rect = CRect(0, 0, 0, 0);

		size_t rowStart = 0;
		size_t maxH = 0;
		foreach (i, img; _images) {
			maxH = max(maxH, img._bounds.height);
			if (i + 1 == _images.length || img._bounds.y != _images[i + 1]._bounds.y) {
				foreach (j; rowStart .. i + 1) {
					auto img2 = _images[j];
					rect.x = img2._bounds.x - SPACING;
					rect.y = img2._bounds.y - SPACING;
					rect.width = j == i ? int.max : (img2._bounds.width + SPACING);
					rect.height = maxH + SPACING;
					if (rect.contains(x, y)) {
						return j;
					}
				}
				rowStart = i;
				maxH = 0;
			}
		}
		return _images.length;
	}

	/// Shows selected item. TODO comment
	void showSelection() {
		checkWidget();
		if (-1 == _selected) return;
		auto ca = this.p_clientArea;
		auto hs = this.p_horizontalBar;
		assert (hs);
		int hss = hs.p_selection;
		auto vs = this.p_verticalBar;
		assert (vs);
		int vss = vs.p_selection;

		auto ib = _images[_selected]._bounds;

		// TODO comment
		int scroll(int selH, int imgX, int imgW, int caX, int caW) {
			if (imgX < SPACING) {
				redraw();
				return selH - (SPACING - imgX);
			} else {
				int cw = caX + caW;
				int iw = imgX + imgW / 2; // TODO comment
				if (cw < iw) {
					redraw();
					return min(imgX - SPACING, selH + ((imgX + imgW + SPACING) - cw));
				}
			}
			return selH;
		}

		hs.p_selection = scroll(hss, ib.x, ib.width, ca.x, ca.width);
		vs.p_selection = scroll(vss, ib.y, ib.height, ca.y, ca.height);
	}

	/// Gets item. TODO comment
	PImageItem item(size_t index) {
		if (_images.length <= index) {
			SWT.error(__FILE__, __LINE__, SWT.ERROR_INVALID_ARGUMENT);
		}
		checkWidget();
		return _images[index];
	}

	/// Size of a selectable piece.
	@property
	const
	const(Point) pieceSize() { return _pieceSize; }
	/// ditto
	@property
	void pieceSize(in Point v) {
		checkWidget();
		if (!v) {
			SWT.error(__FILE__, __LINE__, SWT.ERROR_NULL_ARGUMENT);
		}
		setPieceSize(v.x, v.y);
	}
	/// ditto
	void setPieceSize(int w, int h) {
		checkWidget();
		if (w == _pieceSize.x && h == _pieceSize.y) {
			return;
		}
		_pieceSize = CPoint(w, h);

		if (-1 != _selected) {
			auto selImg = _images[_selected];
			selImg.redrawPieceFrame();
			selImg._selectedPiece.x = -1;
			selImg._selectedPiece.y = -1;
			selImg._selectedPiece.width = w;
			selImg._selectedPiece.height = h;
		}
	}

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

	private void onDispose(Event e) {
		checkWidget();
	}

	private void onResize(Event e) {
		checkWidget();
		calcScrollParams();
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

	/// Selects image. TODO comment
	private void onKeyDown(Event e) {
		checkWidget();
		if (!_images.length) return;
		switch (e.keyCode) {
		case SWT.ARROW_UP:
		case SWT.ARROW_LEFT:
			if (-1 == selectedIndex) {
				selectedIndex = 0;
			} else if (0 == selectedIndex) {
				selectedIndex = _images.length - 1;
			} else {
				selectedIndex = selectedIndex - 1;
			}
			showSelection();
			break;
		case SWT.ARROW_DOWN:
		case SWT.ARROW_RIGHT:
			if (-1 == _selected) {
				_selected = 0;
			} else if (_images.length <= selectedIndex + 1) {
				selectedIndex = 0;
			} else {
				selectedIndex = selectedIndex + 1;
			}
			showSelection();
			break;
		default:
		}
	}

	/// Draws image list. TODO comment
	private void onPaint(Event e) {
		checkWidget();
		auto ca = this.p_clientArea;
		auto d = this.p_display;

		auto hs = this.p_horizontalBar;
		assert (hs);
		int hss = hs.p_selection;
		auto vs = this.p_verticalBar;
		assert (this.p_verticalBar);
		int vss = vs.p_selection;

		drawShade(e.gc, ca);

		if (!_images.length) return;

		auto cRect = CRectangle(e.x, e.y, e.width, e.height);
		int x = SPACING - hss;
		int y = SPACING - vss;
		int maxH = 0; // Maximum height in a row. TODO comment.
		foreach (i, img; _images) {
			img._bounds.x = x;
			img._bounds.y = y;

			if (cRect.intersects(img._bounds)) {
				img.drawImage(e.gc, _selected == i);
			}

			if (i + 1 < _images.length) {
				x += img._bounds.width + SPACING;
				maxH = max(maxH, img._bounds.height);

				if (ca.width < x + _images[i + 1]._bounds.width + SPACING) {
					x = SPACING - hss;
					y += SPACING + maxH;
					maxH = 0;
				}
			}
		}
	}

	/// Selects image.
	private void onMouseDown(Event e) {
		checkWidget();
		setFocus();

		auto rect = CRectangle(0, 0, 0, 0);
		foreach (index, img; _images) {
			if (1 == e.button) {
				rect.x = img._bounds.x + img._cBounds.x;
				rect.y = img._bounds.y + img._cBounds.y;
				rect.width = img._cBounds.width;
				rect.height = img._cBounds.height;
				if (rect.contains(e.x, e.y)) {
					bool doit = removeReceivers.raiseEvent(index);
					if (doit) {
						size_t selected = _selected;
						img.dispose();
						removedReceivers.raiseEvent();
						if (selected == index) {
							raiseSelectionEvent(e);
						}
					}
					break;
				}
			}
			if (img._bounds.contains(e.x, e.y)) {
				if (_selected != index) {
					selectedIndex = index;

					raiseSelectionEvent(e);
				}
				break;
			}
		}
	}

	/// Moves rectangle of select piece.
	private void onMouseMove(Event e) {
		checkWidget();
		scope (exit) {
			_oldX = e.x;
			_oldY = e.y;
		}
	
		auto iRect = CRectangle(0, 0, 0, 0);
		void initRect(in PImageItem img, in Rectangle rect) {
			iRect.x = img._bounds.x + rect.x;
			iRect.y = img._bounds.y + rect.y;
			iRect.width = rect.width;
			iRect.height = rect.height;
		}
		string toolTip = null;
		foreach (img; _images) {
			initRect(img, img._iBounds);
			void set(int x, int y) {
				if (img._selectedPiece.x != x || img._selectedPiece.y != y) {
					img.redrawPieceFrame();
					img._selectedPiece.x = x;
					img._selectedPiece.y = y;
					img.redrawPieceFrame();
				}
			}
			if (iRect.contains(e.x, e.y)) {
				int pw = _pieceSize.x;
				int ph = _pieceSize.y;
				int psx = (e.x - iRect.x) / pw * pw;
				int psy = (e.y - iRect.y) / ph * ph;
				set(psx, psy);
			} else if (-1 != img._selectedPiece.x) {
				// Mouse exit on img. TODO comment
				set(-1, -1);
			}
			initRect(img, img._tBounds);
			if (iRect.contains(e.x, e.y)) {
				toolTip = img.toolTip;
			}
			initRect(img, img._cBounds);
			if (iRect.contains(e.x, e.y) || iRect.contains(_oldX, _oldY)) {
				img.redrawCloseButton();
			}
		}
		this.p_toolTipText = toolTip;
	}
	/// ditto
	private void onMouseEnter(Event e) {
		checkWidget();
		onMouseMove(e);
	}
	/// ditto
	private void onMouseExit(Event e) {
		checkWidget();
		onMouseMove(e);
	}

	override Point computeSize(int wHint, int hHint, bool changed) {
		checkWidget();
		int cbw = this.p_borderWidth * 2;
		int cw, ch;
		if (wHint == SWT.DEFAULT) {
			cw = SPACING;
			foreach (img; _images) {
				cw += img._bounds.width + SPACING;
			}
			cw += cbw;
		} else {
			cw = wHint;
		}
		if (hHint == SWT.DEFAULT) {
			ch = 0;
			foreach (img; _images) {
				ch = max(ch, img._bounds.height);
			}
			ch += SPACING * 2;
		} else {
			ch = hHint;
		}
		return CPoint(cw, ch);
	}
}

/// One image.
private class PImageItem : Item {
	private PImageList _parent; /// Parent of this. TODO comment

	private string _name; /// Name of this image.
	private MLImage _image; /// Data of this image (multi layer). TODO comment
	private string _toolTip = null; /// Tool tip text. TODO comment

	private Rectangle _bounds; /// Bounds of this image (including name). TODO comment
	private Rectangle _iBounds; /// Bounds of this image (excluding name). TODO comment
	private Rectangle _tBounds; /// Bounds of name area. TODO comment
	private Rectangle _cBounds; /// Bounds of close button. TODO comment
	private Rectangle _selectedPiece; /// Range of selected piece.

	/// Creates PImageItem. TODO comment
	this (PImageList parent, int style) {
		this (parent, style, -1);
	}
	/// Creates PImageItem with index. TODO comment
	this (PImageList parent, int style, int index) {
		if (!parent) {
			SWT.error(__FILE__, __LINE__, SWT.ERROR_NULL_ARGUMENT);
		}
		if (index != -1 && (index < 0 || parent.imageCount < index)) {
			SWT.error(__FILE__, __LINE__, SWT.ERROR_INVALID_ARGUMENT);
		}
		super (parent, style);
		_parent = parent;
		_cBounds = CRectangle(0, 0, 0, 0);
		_tBounds = CRectangle(0, 0, 0, 0);
		_iBounds = CRectangle(0, 0, 0, 0);
		_bounds = CRectangle(0, 0, 0, 0);
		_selectedPiece = CRectangle(-1, -1, parent._pieceSize.x - 1, parent._pieceSize.y - 1);

		if (-1 == index) {
			index = parent.imageCount;
		}
		parent._images.length += 1;
		foreach_reverse (i; index .. parent._images.length - 1) {
			parent._images[i + 1] = parent._images[i];
		}
		parent._images[index] = this;

		this.bindListeners();
	}

	/// Calculates _bounds. TODO comment
	private void calcBounds() {
		checkWidget();
		if (!_image || _image.empty) return;

		auto gc = new GC(_parent);
		scope (exit) gc.dispose();
		auto ds = gc.textExtent("#");
		int tsq = 2 * 2 + ds.y;

		_cBounds.x = image.width - tsq;
		_cBounds.width = tsq;
		_cBounds.height = tsq;
		_tBounds.width = image.width - _cBounds.width;
		_tBounds.height = tsq;
		_iBounds.y = _tBounds.height;
		_iBounds.width = image.width;
		_iBounds.height = image.height;
		_bounds.width = image.width;
		_bounds.height = _iBounds.height + _tBounds.height;

		_parent.calcScrollParams();
		_parent.redraw();
	}

	/// Image. TODO comment
	@property
	void image(MLImage v) {
		if (!v) {
			SWT.error(__FILE__, __LINE__, SWT.ERROR_NULL_ARGUMENT);
		}
		checkWidget();
		if (_image) {
			_image.resizeReceivers.removeReceiver(&calcBounds);
			_image.restoreReceivers.removeReceiver(&calcBounds);
		}
		_image = v;
		v.resizeReceivers ~= &calcBounds;
		v.restoreReceivers ~= &calcBounds;
		calcBounds();
	}
	/// ditto
	@property
	const
	const(MLImage) image() { return _image; }
	/// ditto
	@property
	MLImage image() { return _image; }

	/// Tool tip text. TODO comment
	@property
	void toolTip(string v) {
		checkWidget();
		_toolTip = v;
	}
	/// ditto
	@property
	const
	string toolTip() { return _toolTip; }

	/// Gets palette of first layer. TODO comment
	@property
	const
	const(PaletteData) palette() {
		return _image.palette;
	}
	/// Gets _bounds of selected piece. TODO comment
	@property
	Rectangle selectedPiece() {
		checkWidget();
		auto pb = _selectedPiece;
		return CRect(pb.x, pb.y, pb.width, pb.height);
	}

	/// TODO comment
	bool pushImage(MLImage src) {
		checkWidget();
		redrawPiece();
		auto cip = _selectedPiece;
		return _image.pushImage(src, cip.x, cip.y);
	}

	/// Color of palette. TODO comment
	void color(size_t pixel, in RGB rgb) {
		checkWidget();
		_image.color(pixel, rgb);
		redrawImage();
	}
	/// ditto
	const
	RGB color(size_t pixel) {
		return _image.color(pixel);
	}
	/// Sets colors. TODO comment
	@property
	void colors(in RGB[] colors) {
		_image.colors = colors;
		redrawImage();
	}

	/// Resizes image. TODO comment
	void resize(uint w, uint h, size_t backgroundPixel) {
		checkWidget();
		_image.resize(w, h, backgroundPixel);
		calcBounds();
	}
	/// Change image scale. TODO comment
	void scaledTo(uint w, uint h) {
		checkWidget();
		_image.scaledTo(w, h);
		calcBounds();
	}

	/// Deselects this.
	void deselect() {
		checkWidget();
		_parent._selected = -1;
		redrawFocus();
	}

	/// Redraws area of image. TODO comment
	private void redrawImage() {
		if (!_image || _image.empty) return;
		checkWidget();
		auto ib = _bounds;
		auto iib = _iBounds;
		_parent.redraw(ib.x + iib.x, ib.y + iib.y, iib.width, iib.height, true);
	}
	/// Redraws area of text. TODO comment
	private void redrawText() {
		if (!_image || _image.empty) return;
		checkWidget();
		auto ib = _bounds;
		auto itb = _tBounds;
		_parent.redraw(ib.x + itb.x, ib.y + itb.y, itb.width, itb.height, true);
	}
	/// Redraws close button. TODO comment;
	private void redrawCloseButton() {
		if (!_image || _image.empty) return;
		checkWidget();
		auto ib = _bounds;
		auto icb = _cBounds;
		_parent.redraw(ib.x + icb.x, ib.y + icb.y, icb.width, icb.height, true);
	}
	/// Redraws area of focus. TODO comment
	private void redrawFocus() {
		if (!_image || _image.empty) return;
		checkWidget();
		int x = _bounds.x - 1;
		int y = _bounds.y - 1;
		int w = _bounds.width + 2;
		int h = _bounds.height + 2;
		_parent.redraw(x, y, w, 1, true); // top
		_parent.redraw(x, y, 1, h, true); // left
		_parent.redraw(x + w - 1, y, 1, h, true); // right
		_parent.redraw(x, y + h - 1, w, 1, true); // bottom
		int tx = _bounds.x + _tBounds.x;
		int ty = _bounds.y + _tBounds.y;
		int tw = _tBounds.width;
		int th = _tBounds.height;
		_parent.redraw(tx, ty, tw, th, true);
		int cx = _bounds.x + _cBounds.x;
		int cy = _bounds.y + _cBounds.y;
		int cw = _cBounds.width;
		int ch = _cBounds.height;
		_parent.redraw(cx, cy, cw, ch, true);
	}
	/// Redraws area of selected piece. TODO comment
	private void redrawPiece() {
		if (!_image || _image.empty) return;
		checkWidget();
		if (-1 == _selectedPiece.x) return;
		auto ip = _selectedPiece;
		int x = _bounds.x + _iBounds.x + ip.x;
		int y = _bounds.y + _iBounds.y + ip.y;
		int w = min(ip.width + 1, _iBounds.width - ip.x);
		int h = min(ip.height + 1, _iBounds.height - ip.y);
		_parent.redraw(x, y, w, h, true);
	}
	/// Redraws area of selected piece frame. TODO comment
	private void redrawPieceFrame() {
		if (!_image || _image.empty) return;
		checkWidget();
		if (-1 == _selectedPiece.x) return;
		auto ip = _selectedPiece;
		int x = _bounds.x + _iBounds.x + ip.x;
		int y = _bounds.y + _iBounds.y + ip.y;
		int w = min(ip.width, _iBounds.width - ip.x);
		int h = min(ip.height, _iBounds.height - ip.y);
		_parent.redraw(x, y, w, 1, true); // top
		_parent.redraw(x, y, 1, h, true); // left
		if (w == ip.width) {
			_parent.redraw(x + w, y, 1, h, true); // right
		}
		if (h == ip.height) {
			_parent.redraw(x, y + h, w, 1, true); // bottom
		}
	}

	/// Draws image.
	private void drawImage(GC egc, bool selected) {
		if (!_image || _image.empty) return;
		checkWidget();

		auto canvas = createImage(selected);
		scope (exit) canvas.dispose();
		egc.drawImage(canvas, _bounds.x, _bounds.y);

		/// focus
		if (selected) {
			egc.drawFocus(_bounds.x - 1, _bounds.y - 1, _bounds.width + 2, _bounds.height + 2);
		}
	}

	/// Creates image of this. TODO comment
	Image createImage(bool selected) {
		checkWidget();
		if (!_image || _image.empty) return null;
		auto d = this.p_display;

		auto canvas = new Image(d, _bounds.width, _bounds.height);
		auto gc = new GC(canvas);
		scope (exit) gc.dispose();

		// Draws image.
		foreach (i; 0 .. image.layerCount) {
			auto img = new Image(d, image.layer(i).image);
			scope (exit) img.dispose();
			gc.drawImage(img, _iBounds.x, _iBounds.y);
		}

		/// Draws selected area. TODO comment
		if (-1 != _selectedPiece.x) {
			auto color1 = d.getSystemColor(SWT.COLOR_WHITE);
			auto color2 = d.getSystemColor(SWT.COLOR_RED);
			auto psp = _selectedPiece;
			auto piece = CRect(_iBounds.x + psp.x, _iBounds.y + psp.y, psp.width, psp.height);
			drawColorfulFocus(gc, color1, color2, piece);
		}

		// Draws name.
		if (selected) {
			gc.p_foreground = d.getSystemColor(SWT.COLOR_WHITE);
			gc.p_background = d.getSystemColor(SWT.COLOR_DARK_BLUE);
		} else {
			gc.p_foreground = d.getSystemColor(SWT.COLOR_BLACK);
			gc.p_background = d.getSystemColor(SWT.COLOR_WHITE);
		}
		string t = this.p_text;
		auto ts = gc.textExtent(t);
		if (ts.x > _tBounds.width) {
			// Cuts longer name. TODO comment
			auto ds = gc.textExtent("...");
			auto dst = to!dstring(t);
			while (t.length) {
				dst.length -= 1;
				t = to!string(dst);
				ts = gc.textExtent(t);
				if (ts.x + ds.x <= _tBounds.width) {
					t ~= "...";
					break;
				}
			}
		}
		// background of text
		gc.fillRectangle(_tBounds.x, _tBounds.y, _tBounds.width, _tBounds.height);
		// text
		int tx = _tBounds.x + (_tBounds.width - ts.x) / 2;
		int ty = _tBounds.y + 2;
		gc.drawText(t, tx, ty);

		// Draws close button.
		gc.fillRectangle(_cBounds.x, _cBounds.y, _cBounds.width, _cBounds.height);
		auto cRect = CRect(_bounds.x + _cBounds.x, _bounds.y + _cBounds.y, _cBounds.width, _cBounds.height);
		int cs = 5;
		if (cRect.contains(_parent._oldX, _parent._oldY)) {
			cs = 4;
			gc.p_lineWidth = 3;
		} else {
			gc.p_lineWidth = 2;
		}
		scope (exit) gc.p_lineWidth = 1;
		int cx1 = _cBounds.x + cs;
		int cy1 = _cBounds.y + cs;
		int cx2 = _cBounds.x + _cBounds.width - cs;
		int cy2 = _cBounds.y + _cBounds.height - cs;
		gc.p_antialias = true;
		gc.drawLine(cx1, cy1, cx2, cy2);
		gc.drawLine(cx2, cy1, cx1, cy2);
		gc.p_antialias = false;

		return canvas;
	}

	/// Removes image at list. TODO comment
	private void onDispose(Event e) {
		checkWidget();
		int index = _parent._images.countUntil(this);
		assert (-1 != index);
		_parent._images = _parent._images.remove(index);
		if (_parent._selected == index) {
			_parent._selected = -1;
		}
		_parent.calcScrollParams();
		_parent.redraw();
	}

	override void setText(string text) {
		super.setText(text);
		redrawText();
	}
}