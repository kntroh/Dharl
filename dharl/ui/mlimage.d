
/// This module includes MLImage and members related to it. 
module dharl.ui.mlimage;

private import dharl.util.undomanager;
private import dharl.util.graphics;
private import dharl.util.types;
private import dharl.util.utils;
private import dharl.ui.dwtutils;

private import std.algorithm;
private import std.exception;

private import org.eclipse.swt.all;

/// Layer data. TODO comment
struct Layer {
	ImageData image = null;
	string name = "";
	bool visible = true;
}

/// Multi layer image. TODO comment
class MLImage : Undoable {
	/// Restore event receivers. TODO comment
	void delegate()[] restoreReceivers;
	/// Resize event receivers. TODO comment
	void delegate()[] resizeReceivers;
	/// Initialize event receivers. TODO comment
	void delegate()[] initializeReceivers;

	/// Layers.
	private Layer[] _layers;
	/// The palette. It is common in all layers.
	private PaletteData _palette = null;
	/// Image size. It is common in all layers.
	private uint _iw = 0, _ih = 0;

	/// If doesn't initialized throws exception.
	const
	private void checkInit() {
		enforce(_palette, new Exception("MLImage is no initialized.", __FILE__, __LINE__));
	}

	/// Initializes this image.
	/// If call a other methods before didn't called this,
	/// It throws exception.
	/// When raised resize event returns true.
	/// TODO comment
	void init(ImageData image, string name) {
		if (!image || !name) {
			SWT.error(__FILE__, __LINE__, SWT.ERROR_NULL_ARGUMENT);
		}
		int ow = _iw, oh = _ih;
		auto layer = colorReduction(image, false);
		assert (layer.palette.colors.length == 256);
		_layers.length = 1;
		_layers[0].image = image;
		_layers[0].name = name;
		_layers[0].visible = true;
		_iw = layer.width;
		_ih = layer.height;
		_palette = layer.palette;
		if (ow != _iw || oh != _ih) {
			resizeReceivers.raiseEvent();
		}
		initializeReceivers.raiseEvent();
	}
	/// ditto
	void init(uint w, uint h, PaletteData palette) {
		if (!palette) {
			SWT.error(__FILE__, __LINE__, SWT.ERROR_NULL_ARGUMENT);
		}
		if (palette.colors.length != 256) {
			SWT.error(__FILE__, __LINE__, SWT.ERROR_INVALID_ARGUMENT);
		}
		if (w == 0 || h == 0) {
			SWT.error(__FILE__, __LINE__, SWT.ERROR_INVALID_ARGUMENT);
		}
		int ow = _iw, oh = _ih;
		_layers.length = 0;
		_iw = w;
		_ih = h;
		_palette = palette;
		if (ow != _iw || oh != _ih) {
			resizeReceivers.raiseEvent();
		}
		initializeReceivers.raiseEvent();
	}

	/// Disposes this image. TODO comment
	void dispose() {
		removeLayers(0, _layers.length);
		restoreReceivers.length = 0;
		resizeReceivers.length = 0;
	}

	/// Image size. It is common in all layers.
	@property
	const
	uint width() {
		checkInit();
		return _iw;
	}
	/// ditto
	@property
	const
	uint height() {
		checkInit();
		return _ih;
	}

	/// Resizes this image. TODO comment
	void resize(uint w, uint h, size_t backgroundPixel) {
		if (w == 0 || h == 0) {
			SWT.error(__FILE__, __LINE__, SWT.ERROR_INVALID_ARGUMENT);
		}
		if (_palette.colors.length <= backgroundPixel) {
			SWT.error(__FILE__, __LINE__, SWT.ERROR_INVALID_ARGUMENT);
		}
		checkInit();
		if (w == _iw && h == _ih) return;

		foreach (ref l; _layers) {
			auto nl = new ImageData(w, h, l.image.depth, l.image.palette);
			foreach (x; 0 .. w) {
				foreach (y; 0 .. h) {
					if (x < l.image.width && y < l.image.height) {
						nl.setPixel(x, y, l.image.getPixel(x, y));
					} else {
						nl.setPixel(x, y, backgroundPixel);
					}
				}
			}
			l.image = nl;
		}

		_iw = w;
		_ih = h;
		resizeReceivers.raiseEvent();
	}
	/// Change image scale. TODO comment
	void scaledTo(uint w, uint h) {
		if (w == 0 || h == 0) {
			SWT.error(__FILE__, __LINE__, SWT.ERROR_INVALID_ARGUMENT);
		}
		checkInit();
		if (w == _iw && h == _ih) return;

		foreach (ref l; _layers) {
			auto nl = new ImageData(w, h, l.image.depth, l.image.palette);
			.resize!int(w, h, &l.image.getPixel, &nl.setPixel, 0, 0, _iw, _ih);
			l.image = nl;
		}

		_iw = w;
		_ih = h;
		resizeReceivers.raiseEvent();
	}

	/// Gets count of layer. TODO comment
	@property
	const
	size_t layerCount() {
		checkInit();
		return _layers.length;
	}

	/// Gets layer from index.
	ref Layer layer(size_t index) {
		if (_layers.length <= index) {
			SWT.error(__FILE__, __LINE__, SWT.ERROR_INVALID_ARGUMENT);
		}
		checkInit();
		return _layers[index];
	}
	/// ditto
	const
	ref const(Layer) layer(size_t index) {
		if (_layers.length <= index) {
			SWT.error(__FILE__, __LINE__, SWT.ERROR_INVALID_ARGUMENT);
		}
		checkInit();
		return _layers[index];
	}

	/// TODO comment
	bool pushImage(MLImage src, int srcX, int srcY, int backgroundPixel) {
		if (!src) {
			SWT.error(__FILE__, __LINE__, SWT.ERROR_NULL_ARGUMENT);
		}
		if (src.empty) {
			SWT.error(__FILE__, __LINE__, SWT.ERROR_INVALID_ARGUMENT);
		}
		if (palette.colors.length <= backgroundPixel) {
			SWT.error(__FILE__, __LINE__, SWT.ERROR_INVALID_ARGUMENT);
		}
		checkInit();

		bool changed = false;
		/// TODO comment
		if (src.layerCount < _layers.length) {
			removeLayers(src.layerCount, _layers.length);
			changed = true;
		} else if (src.layerCount > _layers.length) {
			auto names = new string[src.layerCount - _layers.length];
			names[] = "";
			addLayers(names);
			changed = true;
		}
		foreach (li; 0 .. src.layerCount) {
			auto sl = src.layer(li);
			_layers[li].name = sl.name;
			auto l = sl.image;
			auto tl = _layers[li].image;
			foreach (ix; 0 .. _iw) {
				foreach (iy; 0 .. _ih) {
					int ilx = srcX + ix;
					int ily = srcY + iy;
					int pixel = tl.getPixel(ix, iy);
					int sPixel;
					if (0 <= ilx && ilx < l.width && 0 <= ily && ily < l.height) {
						sPixel = l.getPixel(ilx, ily);
					} else {
						// Out of source image. TODO comment
						sPixel = backgroundPixel;
					}
					if (pixel != sPixel) {
						tl.setPixel(ix, iy, sPixel);
						changed = true;
					}
				}
			}
		}
		return changed;
	}
	/// ditto
	bool pushImage(MLImage src, int destX, int destY) {
		if (!src) {
			SWT.error(__FILE__, __LINE__, SWT.ERROR_NULL_ARGUMENT);
		}
		if (src.empty) {
			SWT.error(__FILE__, __LINE__, SWT.ERROR_INVALID_ARGUMENT);
		}
		checkInit();

		/// TODO comment
		bool changed = false;
		if (src.layerCount > _layers.length) {
			auto names = new string[src.layerCount - _layers.length];
			names[] = "";
			addLayers(names);
			changed = true;
		}
		foreach (li; 0 .. src.layerCount) {
			auto sl = src.layer(li);
			_layers[li].name = sl.name;
			auto l = sl.image;
			auto tl = _layers[li].image;
			foreach (ix; 0 .. src.width) {
				foreach (iy; 0 .. src.height) {
					int idx = destX + ix;
					int idy = destY + iy;
					if (0 <= idx && idx < width && 0 <= idy && idy < height) {
						int pixel = tl.getPixel(idx, idy);
						int sPixel = l.getPixel(ix, iy);
						if (pixel != sPixel) {
							tl.setPixel(idx, idy, sPixel);
							changed = true;
						}
					}
				}
			}
		}
		return changed;
	}

	/// Creates MLImage from this. TODO comment
	MLImage createMLImage(in size_t[] layer = null) {
		return createMLImage(0, 0, _iw, _ih, layer);
	}
	/// ditto
	MLImage createMLImage(in Rectangle iRange, in size_t[] layer = null) {
		return createMLImage(iRange.x, iRange.y, iRange.width, iRange.height, layer);
	}
	/// ditto
	MLImage createMLImage(int ix, int iy, int iw, int ih, in size_t[] layer = null) {
		if (layer) {
			foreach (i; layer) {
				if (_layers.length <= i) {
					SWT.error(__FILE__, __LINE__, SWT.ERROR_INVALID_ARGUMENT);
				}
			}
		}
		checkInit();
		size_t[] ls = null;
		if (layer) {
			ls = layer.dup;
			ls = ls.sort;
			ls = ls.unify;
		}
		auto palette = copyPalette();
		auto data = new ImageData[ls ? ls.length : _layers.length];
		auto name = new string[data.length];

		if (0 == ix && 0 == iy && _iw == iw && _ih == ih) {
			foreach (i, ref d; data) {
				auto l = _layers[ls ? ls[i] : i];
				d = new ImageData(_iw, _ih, 8, palette);
				d.data = l.image.data.dup;
				name[i] = l.name;
			}
		} else {
			foreach (i, ref d; data) {
				d = new ImageData(iw, ih, 8, palette);
				auto l = _layers[ls ? ls[i] : i];
				foreach (x; 0 .. iw) {
					foreach (y; 0 .. ih) {
						int pixel = l.image.getPixel(x + ix, y + iy);
						d.setPixel(x, y, pixel);
					}
				}
				name[i] = l.name;
			}
		}

		auto r = new MLImage;
		r.init(iw, ih, palette);
		foreach (i, d; data) {
			r._layers ~= Layer(d, name[i], true);
		}
		return r;
	}

	/// Creates one image from all layers. TODO comment
	ImageData createImageData(ubyte depth, in size_t[] layer = null) {
		return createImageData(0, 0, _iw, _ih, depth, layer);
	}
	/// ditto
	ImageData createImageData(Rectangle iRange, ubyte depth, in size_t[] layer = null) {
		return createImageData(iRange.x, iRange.y, iRange.width, iRange.height, depth, layer);
	}
	/// ditto
	ImageData createImageData(int ix, int iy, int iw, int ih, ubyte depth, in size_t[] layer = null) {
		if (1 != depth && 2 != depth && 4 != depth && 8 != depth
				&& 16 != depth && 24 != depth && 32 != depth) {
			SWT.error(__FILE__, __LINE__, SWT.ERROR_INVALID_ARGUMENT);
		}
		if (ix < 0 || iy < 0 || _iw <= ix || _ih <= iy) {
			SWT.error(__FILE__, __LINE__, SWT.ERROR_INVALID_ARGUMENT);
		}
		if (iw < 1 || ih < 1 || _iw < ix + iw || _ih < iy + ih) {
			SWT.error(__FILE__, __LINE__, SWT.ERROR_INVALID_ARGUMENT);
		}
		if (layer) {
			foreach (i; layer) {
				if (_layers.length <= i) {
					SWT.error(__FILE__, __LINE__, SWT.ERROR_INVALID_ARGUMENT);
				}
			}
		}
		checkInit();

		size_t[] ls = null;
		if (layer) {
			ls = layer.dup;
			ls = ls.sort;
			ls = ls.unify;
		}
		/// Creates new palette.
		size_t colors = 0x1 << depth;
		auto rgbs = new RGB[colors];
		foreach (i, ref rgb; rgbs) {
			if (i < 256) {
				rgb = color(i);
			} else {
				rgb = new RGB(0, 0, 0);
			}
		}
		auto palette = new PaletteData(rgbs);

		if (1 == _layers.length && 8 == depth
				&& 0 == ix && 0 == iy && _iw == iw && _ih == ih) {
			/// Only base layer.
			auto data = new ImageData(_iw, _ih, 8, palette);
			data.data = _layers[0].image.data.dup;
			return data;
		}

		auto data = new ImageData(iw, ih, depth, palette);
		void put(size_t i, ImageData layer) {
			foreach (x; 0 .. iw) {
				foreach (y; 0 .. ih) {
					int pixel = layer.getPixel(x + ix, y + iy);
					if (pixel < colors && (0 == i || pixel != layer.transparentPixel)) {
						data.setPixel(x, y, pixel);
					}
				}
			}
		}
		if (ls) {
			foreach (i, l; ls) {
				put(i, _layers[l].image);
			}
		} else {
			foreach (i, l; _layers) {
				put(i, l.image);
			}
		}
		return data;
	}

	/// If this hasn't layer, returns true. TODO comment
	@property
	const
	bool empty() {
		checkInit();
		return !_layers.length;
	}

	/// Adds layer.
	/// A layer after second,
	/// is a first color treats as transparent pixel.
	void addLayer(string name) {
		if (!name) {
			SWT.error(__FILE__, __LINE__, SWT.ERROR_NULL_ARGUMENT);
		}
		checkInit();
		addLayerImpl(name);
	}
	/// ditto
	void addLayers(string[] names) {
		if (!names) {
			SWT.error(__FILE__, __LINE__, SWT.ERROR_NULL_ARGUMENT);
		}
		foreach (name; names) {
			if (!name) {
				SWT.error(__FILE__, __LINE__, SWT.ERROR_NULL_ARGUMENT);
			}
		}
		checkInit();
		foreach (name; names) {
			addLayerImpl(name);
		}
	}
	/// ditto
	private void addLayerImpl(string name) {
		checkInit();
		enforce(name);
		auto data = new ImageData(_iw, _ih, 8, _palette);
		if (_layers.length >= 1) {
			data.transparentPixel = 0;
		}
		_layers ~= Layer(data, name, true);
	}
	/// Removes layer.
	/// TODO comment
	void removeLayer(size_t index) {
		if (_layers.length <= index) {
			SWT.error(__FILE__, __LINE__, SWT.ERROR_INVALID_ARGUMENT);
		}
		checkInit();
		_layers = _layers.remove(index);
		if (0 == index && _layers.length) {
			_layers[0].image.transparentPixel = -1;
		}
	}
	/// ditto
	void removeLayers(size_t from, size_t to) {
		if (from >= to) {
			SWT.error(__FILE__, __LINE__, SWT.ERROR_INVALID_ARGUMENT);
		}
		if (_layers.length < to) {
			SWT.error(__FILE__, __LINE__, SWT.ERROR_INVALID_ARGUMENT);
		}
		assert (from < _layers.length);
		checkInit();
		size_t range = to - from;
		foreach (index; from .. to) {
			if (index + range < _layers.length) {
				_layers[index] = _layers[index + range];
			}
		}
		_layers.length -= range;
		if (0 == from && _layers.length) {
			_layers[0].image.transparentPixel = -1;
		}
	}

	/// Gets palette.
	@property
	const
	const(PaletteData) palette() {
		checkInit();
		return _palette;
	}
	/// ditto
	@property
	PaletteData palette() {
		checkInit();
		return _palette;
	}
	/// Gets copy palette. TODO comment
	PaletteData copyPalette() {
		checkInit();
		auto rgbs = new RGB[_palette.colors.length];
		foreach (i, ref rgb; rgbs) {
			rgb = color(i);
		}
		return new PaletteData(rgbs);
	}

	/// Gets color of palette.
	const
	RGB color(size_t index) {
		if (_palette.colors.length <= index) {
			SWT.error(__FILE__, __LINE__, SWT.ERROR_INVALID_ARGUMENT);
		}
		checkInit();
		auto rgb = _palette.colors[index];
		return new RGB(rgb.red, rgb.green, rgb.blue);
	}
	/// Sets color of palette.
	void color(size_t index, int r, int g, int b) {
		if (_palette.colors.length <= index) {
			SWT.error(__FILE__, __LINE__, SWT.ERROR_INVALID_ARGUMENT);
		}
		checkInit();
		auto rgb = _palette.colors[index];
		rgb.red   = r;
		rgb.green = g;
		rgb.blue  = b;
	}
	/// Sets color of palette.
	void color(size_t index, in RGB rgb) {
		checkInit();
		color(index, rgb.red, rgb.green, rgb.blue);
	}
	/// Sets all colors. TODO comment
	@property
	void colors(in RGB[] rgbs) {
		checkInit();
		if (_palette.colors.length != rgbs.length) {
			SWT.error(__FILE__, __LINE__, SWT.ERROR_INVALID_ARGUMENT);
		}
		foreach (i, ref rgb; _palette.colors) {
			auto v = rgbs[i];
			rgb.red   = v.red;
			rgb.green = v.green;
			rgb.blue  = v.blue;
		}
	}
	/// Swap pixel colors.
	void swapColor(int pixel1, int pixel2) {
		checkInit();
		if (pixel1 < 0 || _palette.colors.length <= pixel1) {
			SWT.error(__FILE__, __LINE__, SWT.ERROR_INVALID_ARGUMENT);
		}
		if (pixel2 < 0 || _palette.colors.length <= pixel2) {
			SWT.error(__FILE__, __LINE__, SWT.ERROR_INVALID_ARGUMENT);
		}

		// Swap colors.
		auto temp = color(pixel1);
		color(pixel1, color(pixel2));
		color(pixel2, temp);

		// Sets pixels of target color.
		foreach (layer; _layers) {
			foreach (ix; 0 .. layer.image.width) {
				foreach (iy; 0 .. layer.image.height) {
					int pi = layer.image.getPixel(ix, iy);
					if (pi == pixel1) {
						layer.image.setPixel(ix, iy, pixel2);
					} else if (pi == pixel2) {
						layer.image.setPixel(ix, iy, pixel1);
					}
				}
			}
		}
	}

	/// Data object for undo. TODO comment
	private static class StoreData {
		/// Size of image. TODO comment
		uint width, height;
		/// Palette data. TODO comment
		CRGB[256] palette;
		/// Layer data. TODO comment
		byte[][] layers = null;
		/// Layer name. TODO comment
		string[] name = null;
		/// Layer visible. TODO comment
		bool[] visible = null;
	}

	/// Equals this and o. Require o is return value at storeData(). TODO comment
	const
	bool equalsTo(ref const(Object) o) {
		auto data = cast(const(StoreData)) o;
		if (!data) return false;
		if (_iw != data.width || _ih != data.height) return false;
		if (_layers.length != data.layers.length) return false;
		foreach (i, ref rgb; data.palette) {
			auto c = _palette.colors[i];
			if (c.red != rgb.r || c.green != rgb.g || c.blue != rgb.b) return false;
		}
		foreach (i, ref l; _layers) {
			if (l.image.data != data.layers[i]) return false;
			if (l.name != data.name[i]) return false;
			if (l.visible != data.visible[i]) return false;
		}
		return true;
	}

	@property
	override Object storeData() {
		auto data = new StoreData;
		data.width = _iw;
		data.height = _ih;
		foreach (i, ref rgb; data.palette) {
			auto c = _palette.colors[i];
			rgb.r = cast(ubyte) c.red;
			rgb.g = cast(ubyte) c.green;
			rgb.b = cast(ubyte) c.blue;
		}
		data.layers = new byte[][_layers.length];
		data.name = new string[_layers.length];
		data.visible = new bool[_layers.length];
		foreach (i, ref l; _layers) {
			data.layers[i] = l.image.data.dup;
			data.name[i] = l.name;
			data.visible[i] = l.visible;
		}
		return data;
	}
	override void restore(Object data, UndoMode mode) {
		auto st = cast(StoreData) data;
		enforce(st);
		foreach (i, ref rgb; _palette.colors) {
			auto c = st.palette[i];
			rgb.red   = c.r;
			rgb.green = c.g;
			rgb.blue  = c.b;
		}
		_layers.length = st.layers.length;
		foreach (i, ref l; _layers) {
			if (_iw != st.width || _ih != st.height) {
				l.image = new ImageData(st.width, st.height, 8, _palette);
			} else if (!l.image) {
				l.image = new ImageData(st.width, st.height, 8, _palette);
			}
			l.image.data = st.layers[i].dup;
			l.name = st.name[i];
			l.visible = st.visible[i];
		}
		_iw = st.width;
		_ih = st.height;
		restoreReceivers.raiseEvent();
	}
	@property
	override bool enabledUndo() {
		return !empty;
	}
}
