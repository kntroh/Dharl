
/// This module includes MLImage and members related to it.
module dharl.image.mlimage;

private import util.environment;
private import util.graphics;
private import util.types;
private import util.undomanager;
private import util.utils;

private import dharl.image.imageutils;

private import std.algorithm;
private import std.array;
private import std.conv;
private import std.datetime;
private import std.exception;
private import std.file;
private import std.path;
private import std.range;
private import std.string;
private import std.xml;
private import std.zip;

private import org.eclipse.swt.all;

private import java.io.ByteArrayInputStream;
private import java.io.ByteArrayOutputStream;

/// Layer data.
struct Layer {
	ImageData image = null; /// Image data of layer.
	string name = ""; /// Name of layer.
	bool visible = true; /// Visibility of layer.
}

/// Information of layers combination.
struct Combination {
	string name;
	bool[] visible;
}

/// Multi layer image.
class MLImage : Undoable {
	/// Receivers of restore event.
	void delegate()[] restoreReceivers;
	/// Receivers of resize event.
	void delegate()[] resizeReceivers;
	/// Receivers of initialize event.
	void delegate()[] initializeReceivers;

	/// Layers.
	private Layer[] _layers;
	/// The palette. It is common in all layers.
	private PaletteData _palette = null;
	/// Image size. It is common in all layers.
	private uint _iw = 0, _ih = 0;

	/// Combination info.
	private Combination[] _combi;
	invariant () {
		foreach (combi; _combi) {
			assert (combi.visible.length == _layers.length);
		}
	}

	/// Creates instance that hasn't initialized.
	this () {
		// No processing.
	}
	/// Creates instance and initialize it.
	this (ImageData image, string name) {
		init(image, name);
	}
	/// ditto
	this (uint w, uint h, PaletteData palette) {
		init(w, h, palette);
	}
	/// Creates from Dharl file (*.dhr).
	this (string file) {
		this (file.read());
	}
	/// Creates from Dharl file data.
	this (void[] fileData) {
		// Gets files information in archive.
		auto archive = new ZipArchive(fileData);
		ArchiveMember info = null;
		ArchiveMember[string] images;
		foreach (name, member; archive.directory) {
			if (0 == name.filenameCmp("dharl.xml")) {
				info = member;
			} else if (0 == name.extension().filenameCmp(".png")) {
				images[name] = member;
			}
		}
		.enforce(info);

		// Parses image information.
		auto xml = cast(char[]) archive.expand(info);
		auto parser = new DocumentParser(.assumeUnique(xml));
		.enforce("dharl" == parser.tag.name);

		ImageData baseImage = null;
		Layer[] layers;
		parser.onStartTag["layers"] = (ElementParser ep) {
			ep.onStartTag["layer"] = (ElementParser ep) {
				Layer layer;

				// Image data.
				auto bytes = archive.expand(images[ep.tag.attr["file"]]);
				auto buf = new ByteArrayInputStream(cast(byte[]) bytes);
				layer.image = .colorReduction(new ImageData(buf), false);
				assert (layer.image.palette.colors.length == 256);

				// Visibility.
				layer.visible = .to!bool(ep.tag.attr["visible"]);

				// Name.
				ep.onText = (string text) {
					layer.name = text;
				};
				ep.parse();

				layers ~= layer;
				if ("base" in ep.tag.attr) {
					baseImage = layer.image;
				}
			};
			ep.parse();
		};
		parser.parse();

		.enforce(layers.length);
		if (!baseImage) baseImage = layers[$ - 1].image;

		// Initialize instance.
		init(baseImage.width, baseImage.height, baseImage.palette);
		foreach (i, l; layers) {
			addLayer(i, l);
		}
	}

	/// Creates Dharl image data.
	@property
	void[] dharlImageData() {
		static immutable UNICODE_FILENAME = 0x0800;
		static immutable MEMBER_IS_FILE   = 0x0020;

		checkInit();
		auto time = Clock.currTime().SysTimeToDosFileTime();
		auto archive = new ZipArchive();

		auto doc = new Document(new Tag("dharl"));
		auto layers = new Element("layers");
		doc ~= layers;

		// Creates archive member.
		ArchiveMember createMember(string name, ubyte[] data) {
			auto member = new ArchiveMember;
			member.name = name;
			member.time = time;
			member.compressionMethod = 8;
			member.externalAttributes = MEMBER_IS_FILE;
			member.internalAttributes = 1;
			member.flags |= UNICODE_FILENAME;
			member.expandedData = data;
			return member;
		}

		// Layers.
		foreach (i, l; _layers) {
			auto le = new Element("layer", l.name);
			layers ~= le;

			le.tag.attr["visible"] = .text(l.visible);
			string file = "layer_%d.png".format(i);
			le.tag.attr["file"] = file;

			// Creates image data.
			auto loader = new ImageLoader;
			auto stream = new ByteArrayOutputStream(1024);
			loader.data ~= l.image;
			loader.save(stream, SWT.IMAGE_PNG);

			if (i + 1 == layerCount) {
				le.tag.attr["base"] = .text(true);
			}

			auto bytes = cast(ubyte[]) stream.toByteArray();
			archive.addMember(createMember(file, bytes));
		}

		// Image information.
		auto xml = doc.prolog ~ "\n" ~ doc.pretty(2).join("\n") ~ "\n";
		archive.addMember(createMember("dharl.xml", cast(ubyte[]) xml));

		return archive.build();
	}
	/// Save Dharl image file.
	void write(string file) {
		checkInit();
		file.write(dharlImageData);
	}

	/// Writes combination to file.
	/// The following values can be specified to imageType:
	/// SWT.IMAGE_BMP, SWT.IMAGE_BMP_RLE, SWT.IMAGE_GIF,
	/// SWT.IMAGE_ICO, SWT.IMAGE_JPEG, SWT.IMAGE_PNG.
	void writeCombination(int imageType, ubyte depth, string dir, void delegate(ref string[] filenames, out bool cancel) checkOverwrite = null, in Combination[] combinations = null) {
		checkInit();
		auto combis = combinations !is null ? combinations : this.combinations;
		const(bool)[][string] nameTable;
		string[] exists;
		string[] notExists;
		foreach (combi; combis) {
			string filename = dir.buildPath(combinationFilename(imageType, combi));
			nameTable[filename] = combi.visible;
			if (filename.exists()) {
				exists ~= filename;
			} else {
				notExists ~= filename;
			}
		}
		if (exists.length && checkOverwrite) {
			bool cancel;
			checkOverwrite(exists, cancel);
			if (cancel) return;
		}
		foreach (filename; exists ~ notExists) {
			auto loader = writeCombinationImpl(depth, nameTable[filename]);
			loader.save(filename, imageType);
		}
	}
	/// Creates file data table from combination.
	/// See_Also: writeCombination
	ubyte[][string] combinationFileTable(int imageType, ubyte depth, in Combination[] combinations = null) {
		checkInit();
		ubyte[][string] r;
		auto combis = combinations !is null ? combinations : this.combinations;
		foreach (combi; combis) {
			auto loader = writeCombinationImpl(depth, combi.visible);
			auto buf = new ByteArrayOutputStream;
			loader.save(buf, imageType);
			r[combinationFilename(imageType, combi)] = cast(ubyte[]) buf.toByteArray();
		}
		return r;
	}
	/// Common function for writeCombination() and combinationFileTable().
	private static string combinationFilename(int imageType, in Combination combi) {
		string ext;
		switch (imageType) {
		case SWT.IMAGE_BMP:     ext = "bmp"; break;
		case SWT.IMAGE_BMP_RLE: ext = "bmp"; break;
		case SWT.IMAGE_GIF:     ext = "gif"; break;
		case SWT.IMAGE_ICO:     ext = "ico"; break;
		case SWT.IMAGE_JPEG:    ext = "jpg"; break;
		case SWT.IMAGE_PNG:     ext = "png"; break;
		default: SWT.error(SWT.ERROR_INVALID_ARGUMENT);
		}
		return combi.name.validFilename.setExtension(ext);
	}
	/// ditto
	private ImageLoader writeCombinationImpl(ubyte depth, in bool[] layerVisible) {
		checkInit();
		if (layerVisible.length != layerCount) {
			SWT.error(SWT.ERROR_INVALID_ARGUMENT);
		}

		auto loader = new ImageLoader;
		size_t[] ls;
		foreach (l, v; layerVisible) {
			if (v) ls ~= l;
		}
		loader.data ~= createImageData(0, 0, width, height, depth, ls);
		return loader;
	}

	/// Initializes this image.
	/// If call a other methods before called this,
	/// it throws exception.
	void init(ImageData image, string name) {
		if (!image || !name) {
			SWT.error(__FILE__, __LINE__, SWT.ERROR_NULL_ARGUMENT);
		}
		int ow = _iw, oh = _ih;
		auto layer = .colorReduction(image, false);
		assert (layer.palette.colors.length == 256);
		_layers.length = 1;
		_layers[0].image = layer;
		_layers[0].name = name;
		_layers[0].visible = true;
		_iw = layer.width;
		_ih = layer.height;
		_palette = layer.palette;
		_combi.length  = 0;
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
		_combi.length  = 0;
		if (ow != _iw || oh != _ih) {
			resizeReceivers.raiseEvent();
		}
		initializeReceivers.raiseEvent();
	}

	/// If doesn't initialized instance, throws exception.
	const
	private void checkInit() {
		enforce(isInitialized, new Exception("MLImage is no initialized.", __FILE__, __LINE__));
	}
	/// Is initialized?
	@property
	const
	bool isInitialized() {
		return _palette !is null;
	}

	/// Disposes this image.
	void dispose() {
		_combi.length  = 0;
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

	/// Resizes this image.
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
	/// Change image scale.
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

	/// Gets count of layer.
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

	/// Push src to this image starting from srcX and srcY.
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

		/// If number of layers don't match, adjust layers number.
		if (src.layerCount < _layers.length) {
			removeLayers(0, _layers.length - src.layerCount);
			changed = true;
		} else if (src.layerCount > _layers.length) {
			auto names = new string[src.layerCount - _layers.length];
			names[] = "";
			addLayers(0, names);
			changed = true;
		}
		foreach (li; 0 .. src.layerCount) {
			auto sl = src.layer(li);
			_layers[li].name = sl.name;
			_layers[li].visible = sl.visible;
			auto tl = _layers[li].image;
			tl.transparentPixel = sl.image.transparentPixel;
			foreach (ix; 0 .. _iw) {
				foreach (iy; 0 .. _ih) {
					int ilx = srcX + ix;
					int ily = srcY + iy;
					int pixel = tl.getPixel(ix, iy);
					int sPixel;
					if (0 <= ilx && ilx < src.width && 0 <= ily && ily < src.height) {
						sPixel = sl.image.getPixel(ilx, ily);
					} else {
						// Out of source image.
						sPixel = backgroundPixel;
					}
					if (pixel != sPixel) {
						tl.setPixel(ix, iy, sPixel);
						changed = true;
					}
				}
			}
		}

		cloneCombi(_combi, src._combi);

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

		bool changed = false;

		/// If number of layers don't match, adjust layers number.
		if (src.layerCount > _layers.length) {
			auto names = new string[src.layerCount - _layers.length];
			names[] = "";
			addLayers(0, names);
			changed = true;
		}
		foreach (li; 0 .. src.layerCount) {
			auto sl = src.layer(li);
			_layers[li].name = sl.name;
			_layers[li].visible = sl.visible;
			auto l = sl.image;
			auto tl = _layers[li].image;
			tl.transparentPixel = l.transparentPixel;
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

	/// Creates MLImage based this instance.
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
			ls = layer.dup.sort().uniq().array();
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

		auto r = new MLImage(iw, ih, palette);
		foreach (i, d; data) {
			r._layers ~= Layer(d, name[i], true);
		}
		return r;
	}

	/// Creates one image from all layers.
	/// ditto
	ImageData createImageData(ubyte depth) {
		return createImageData(depth, .iota(0, _layers.length).array());
	}
	ImageData createImageData(ubyte depth, in size_t[] layer) {
		return createImageData(0, 0, _iw, _ih, depth, layer);
	}
	/// ditto
	ImageData createImageData(Rectangle iRange, ubyte depth) {
		return createImageData(iRange, depth, .iota(0, _layers.length).array());
	}
	/// ditto
	ImageData createImageData(Rectangle iRange, ubyte depth, in size_t[] layer) {
		return createImageData(iRange.x, iRange.y, iRange.width, iRange.height, depth, layer);
	}
	/// ditto
	ImageData createImageData(int ix, int iy, int iw, int ih, ubyte depth) {
		return createImageData(ix, iy, iw, ih, depth, .iota(0, _layers.length).array());
	}
	/// ditto
	ImageData createImageData(int ix, int iy, int iw, int ih, ubyte depth, in size_t[] layer) {
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
		foreach (i; layer) {
			if (_layers.length <= i) {
				SWT.error(__FILE__, __LINE__, SWT.ERROR_INVALID_ARGUMENT);
			}
		}
		checkInit();

		size_t[] ls = layer.dup.sort().uniq().array();
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

		if (1 == ls.length && 1 == _layers.length && 8 == depth
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
					if (pixel < colors && pixel != layer.transparentPixel) {
						data.setPixel(x, y, pixel);
					}
				}
			}
		}

		foreach_reverse (i, l; ls) {
			put(i, _layers[l].image);
		}
		return data;
	}

	/// If haven't layer, returns true.
	@property
	const
	bool empty() {
		checkInit();
		return !_layers.length;
	}

	/// Adds layer.
	/// A layer after second,
	/// is a first color treats as transparent pixel.
	void addLayer(size_t index, Layer layer) {
		if (!layer.image) {
			SWT.error(__FILE__, __LINE__, SWT.ERROR_INVALID_ARGUMENT);
		}
		if (!layer.name) {
			SWT.error(__FILE__, __LINE__, SWT.ERROR_INVALID_ARGUMENT);
		}
		if (layer.image.width != _iw) {
			SWT.error(__FILE__, __LINE__, SWT.ERROR_INVALID_ARGUMENT);
		}
		if (layer.image.height != _ih) {
			SWT.error(__FILE__, __LINE__, SWT.ERROR_INVALID_ARGUMENT);
		}
		if (layer.image.depth != 8) {
			SWT.error(__FILE__, __LINE__, SWT.ERROR_INVALID_ARGUMENT);
		}
		if (layerCount < index) {
			SWT.error(__FILE__, __LINE__, SWT.ERROR_INVALID_ARGUMENT);
		}
		checkInit();
		layer.image.palette = _palette;
		if (index < layerCount) {
			_layers.insertInPlace(index, layer);
			foreach (ref combi; _combi) {
				combi.visible.insertInPlace(index, layer.visible);
			}
		} else {
			_layers ~= layer;
			foreach (ref combi; _combi) {
				combi.visible ~= layer.visible;
			}
		}
	}
	void addLayer(size_t index, string name) {
		if (!name) {
			SWT.error(__FILE__, __LINE__, SWT.ERROR_NULL_ARGUMENT);
		}
		if (layerCount < index) {
			SWT.error(__FILE__, __LINE__, SWT.ERROR_INVALID_ARGUMENT);
		}
		checkInit();
		addLayerImpl(index, name);
	}
	/// ditto
	void addLayers(size_t index, string[] names) {
		if (!names) {
			SWT.error(__FILE__, __LINE__, SWT.ERROR_NULL_ARGUMENT);
		}
		if (layerCount < index) {
			SWT.error(__FILE__, __LINE__, SWT.ERROR_INVALID_ARGUMENT);
		}
		foreach (name; names) {
			if (!name) {
				SWT.error(__FILE__, __LINE__, SWT.ERROR_NULL_ARGUMENT);
			}
		}
		checkInit();
		foreach (i, name; names) {
			addLayerImpl(index + 1, name);
		}
	}
	/// ditto
	private void addLayerImpl(size_t index, string name) {
		checkInit();
		.enforce(name);
		.enforce(index <= layerCount);
		auto data = new ImageData(_iw, _ih, 8, _palette);
		if (index < layerCount) {
			data.transparentPixel = 0;
			_layers.insertInPlace(index, Layer(data, name, true));
			foreach (ref combi; _combi) {
				combi.visible.insertInPlace(index, true);
			}
		} else {
			data.transparentPixel = -1;
			_layers ~= Layer(data, name, true);
			foreach (ref combi; _combi) {
				combi.visible ~= true;
			}
		}
	}
	/// Removes layer.
	void removeLayer(size_t index) {
		if (_layers.length <= index) {
			SWT.error(__FILE__, __LINE__, SWT.ERROR_INVALID_ARGUMENT);
		}
		checkInit();
		_layers = _layers.remove(index);
		foreach (ref combi; _combi) {
			combi.visible = combi.visible.remove(index);
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
			_layers[index] = _layers[from + index];
		}
		_layers.length -= range;
		foreach (ref combi; _combi) {
			foreach (index; from .. to) {
				combi.visible[index] = combi.visible[from + index];
			}
			combi.visible.length -= range;
		}
	}
	/// Swap layer index.
	void swapLayers(size_t index1, size_t index2) {
		if (_layers.length <= index1) {
			SWT.error(__FILE__, __LINE__, SWT.ERROR_INVALID_ARGUMENT);
		}
		if (_layers.length <= index2) {
			SWT.error(__FILE__, __LINE__, SWT.ERROR_INVALID_ARGUMENT);
		}
		checkInit();
		if (index1 == index2) return;
		.swap(_layers[index1], _layers[index2]);
		if (layerCount - 1 == index1 || layerCount - 1 == index2) {
			.swap(_layers[index1].image.transparentPixel, _layers[index2].image.transparentPixel);
		}
		foreach (ref combi; _combi) {
			.swap(combi.visible[index1], combi.visible[index2]);
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
	/// Gets copy of this palette of image.
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
	/// Sets all colors.
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

	/// Combinations of layers.
	@property
	const
	const(Combination)[] combinations() {
		checkInit();
		return _combi;
	}
	/// ditto
	@property
	void combinations(in Combination[] combi) {
		checkInit();
		if (!combi) {
			SWT.error(SWT.ERROR_NULL_ARGUMENT);
		}
		foreach (c; combi) {
			if (c.visible.length != _layers.length) {
				SWT.error(SWT.ERROR_INVALID_ARGUMENT);
			}
		}
		cloneCombi(_combi, combi);
	}

	/// Creates clone of combi to dest.
	private void cloneCombi(ref Combination[] dest, in Combination[] combi) {
		if (dest is null) {
			dest = new Combination[combi.length];
		} else {
			dest.length = combi.length;
		}
		foreach (i, c; combi) {
			dest[i].name = c.name;
			dest[i].visible = c.visible.dup;
		}
	}

	/// A data object for undo.
	private static class StoreData {
		/// Size of image.
		uint width, height;
		/// Data of palette.
		CRGB[256] palette;
		/// Data of layers.
		byte[][] layers = null;
		/// Name of layers.
		string[] name = null;
		/// Visibility of layers.
		bool[] visible = null;
		/// Combination info.
		Combination[] combi;
		/// Is this include palette data?
		bool includePalette = true;
		/// Is this include combination info?
		bool includeCombination = true;
	}

	/// Checks this is equal to o.
	/// Require o is return value at storeData().
	const
	bool equalsTo(ref const(Object) o) {
		auto data = cast(const(StoreData)) o;
		if (!data) return false;
		if (_iw != data.width || _ih != data.height) return false;
		if (_layers.length != data.layers.length) return false;
		if (data.includePalette) {
			foreach (i, ref rgb; data.palette) {
				auto c = _palette.colors[i];
				if (c.red != rgb.r || c.green != rgb.g || c.blue != rgb.b) return false;
			}
		}
		foreach (i, ref l; _layers) {
			if (l.image.data != data.layers[i]) return false;
			if (l.name != data.name[i]) return false;
			if (l.visible != data.visible[i]) return false;
		}
		if (data.includeCombination) {
			if (_combi != data.combi) return false;
		}
		return true;
	}

	/// Creates now state data.
	@property
	Object storeData(bool includePalette, bool includeCombination) {
		auto data = new StoreData;
		data.width = _iw;
		data.height = _ih;
		if (includePalette) {
			foreach (i, ref rgb; data.palette) {
				auto c = _palette.colors[i];
				rgb.r = cast(ubyte) c.red;
				rgb.g = cast(ubyte) c.green;
				rgb.b = cast(ubyte) c.blue;
			}
		}
		data.layers = new byte[][_layers.length];
		data.name = new string[_layers.length];
		data.visible = new bool[_layers.length];
		foreach (i, ref l; _layers) {
			data.layers[i] = l.image.data.dup;
			data.name[i] = l.name;
			data.visible[i] = l.visible;
		}
		if (includeCombination) {
			cloneCombi(data.combi, _combi);
		}
		data.includePalette = includePalette;
		data.includeCombination = includeCombination;
		return data;
	}
	@property
	override Object storeData() {
		return storeData(true, true);
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
		cloneCombi(_combi, st.combi);
		restoreReceivers.raiseEvent();
	}
	@property
	override bool enabledUndo() {
		return !empty;
	}
}