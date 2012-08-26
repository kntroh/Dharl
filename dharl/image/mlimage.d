
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
	string name; /// Combination name.
	bool[] visible; /// Visibility of layers.
	size_t selectedPalette = 0; /// Index of selection palette.

	/// Clone combination.
	@property
	const
	Combination clone() {
		Combination combi;
		combi.name = name;
		combi.visible = visible.dup;
		combi.selectedPalette = selectedPalette;
		return combi;
	}
}

/// Multi layer image.
class MLImage : Undoable {
	/// Receivers of restore event.
	void delegate(UndoMode mode)[] restoreReceivers;
	/// Receivers of resize event.
	void delegate()[] resizeReceivers;
	/// Receivers of initialize event.
	void delegate()[] initializeReceivers;

	/// Layers.
	private Layer[] _layers;
	/// Palettes. There is at least one. It is common in all layers.
	private PaletteData[] _palette;
	/// Index of selection palette.
	private size_t _selPalette = 0;

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

		// palettes
		PaletteData[] palettes;
		size_t selPalette = 0;
		parser.onStartTag["palettes"] = (ElementParser ep) {
			selPalette = to!size_t(ep.tag.attr["selected"]);
			ep.onStartTag["palette"] = (ElementParser ep) {
				RGB[] colors;
				ep.onStartTag["color"] = (ElementParser ep) {
					if (256 <= colors.length) return;
					int r = to!int(ep.tag.attr["r"]);
					int g = to!int(ep.tag.attr["g"]);
					int b = to!int(ep.tag.attr["b"]);
					colors ~= new RGB(r, g, b);
				};
				ep.parse();
				foreach (i; colors.length .. 256) {
					colors ~= new RGB(0, 0, 0);
				}
				assert (256 == colors.length);
				palettes ~= new PaletteData(colors);
			};
			ep.parse();
		};

		// layers
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
		// combinations
		Combination[] combis;
		parser.onStartTag["combinations"] = (ElementParser ep) {
			ep.onStartTag["combination"] = (ElementParser ep) {
				Combination combi;
				combi.name = ep.tag.attr["name"];
				combi.selectedPalette = .to!size_t(ep.tag.attr.get("palette", "0"));
				if (palettes.length <= combi.selectedPalette) {
					combi.selectedPalette = 0;
				}
				ep.onStartTag["visible"] = (ElementParser ep) {
					ep.onText = (string text) {
						combi.visible ~= .to!bool(text);
					};
					ep.parse();
				};
				ep.parse();
				combis ~= combi;
			};
			ep.parse();
		};
		parser.parse();

		// Initialize instance.
		.enforce(layers.length);
		if (!baseImage) baseImage = layers[$ - 1].image;

		init(baseImage.width, baseImage.height, baseImage.palette);
		if (palettes.length) {
			if (palettes.length <= selPalette) selPalette = 0;
			setPalettes(palettes, selPalette);
		}
		foreach (i, l; layers) {
			addLayer(i, l);
		}
		foreach (ref combi; combis) {
			// Ignore invalid combination.
			if (layers.length == combi.visible.length) {
				_combi ~= combi;
			}
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
		auto palettes = new Element("palettes");
		doc ~= palettes;
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

		// Palettes.
		palettes.tag.attr["selected"] = .text(_selPalette);
		foreach (palette; _palette) {
			auto pe = new Element("palette");
			palettes ~= pe;
			foreach (rgb; palette.colors) {
				auto ce = new Element("color");
				pe ~= ce;
				ce.tag.attr["r"] = .text(rgb.red);
				ce.tag.attr["g"] = .text(rgb.green);
				ce.tag.attr["b"] = .text(rgb.blue);
			}
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
		// Combinations.
		Element combis = null;
		foreach (ref combi; _combi) {
			if (!combis) {
				combis = new Element("combinations");
				doc ~= combis;
			}
			auto ce = new Element("combination");
			combis ~= ce;
			ce.tag.attr["name"] = combi.name;
			ce.tag.attr["palette"] = .text(combi.selectedPalette);
			foreach (v; combi.visible) {
				ce ~= new Element("visible", .text(v));
			}
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
		const(Combination)[][string] nameTable;
		string[] exists;
		string[] notExists;
		foreach (combi; combis) {
			string filename = dir.buildPath(combinationFilename(imageType, combi));
			nameTable[filename] = [combi];
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
			auto loader = writeCombinationImpl(depth, nameTable[filename][0]);
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
			auto loader = writeCombinationImpl(depth, combi);
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
		case SWT.IMAGE_BMP:     ext = ".bmp"; break;
		case SWT.IMAGE_BMP_RLE: ext = ".bmp"; break;
		case SWT.IMAGE_GIF:     ext = ".gif"; break;
		case SWT.IMAGE_ICO:     ext = ".ico"; break;
		case SWT.IMAGE_JPEG:    ext = ".jpg"; break;
		case SWT.IMAGE_PNG:     ext = ".png"; break;
		default: SWT.error(__FILE__, __LINE__, SWT.ERROR_INVALID_ARGUMENT);
		}
		return combi.name.validFilename ~ ext;
	}
	/// ditto
	private ImageLoader writeCombinationImpl(ubyte depth, in Combination combi) {
		checkInit();
		if (combi.visible.length != layerCount) {
			SWT.error(__FILE__, __LINE__, SWT.ERROR_INVALID_ARGUMENT);
		}
		if (_palette.length <= combi.selectedPalette) {
			SWT.error(__FILE__, __LINE__, SWT.ERROR_INVALID_ARGUMENT);
		}

		auto loader = new ImageLoader;
		size_t[] ls;
		foreach (l, v; combi.visible) {
			if (v) ls ~= l;
		}
		loader.data ~= createImageData(0, 0, width, height, depth, ls, combi.selectedPalette);
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
		_palette.length = 1;
		_palette[0] = layer.palette;
		_selPalette = 0;
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
		_palette.length = 1;
		_palette[0] = palette;
		_selPalette = 0;
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
		return 0 < _palette.length;
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
		if (palette.colors.length <= backgroundPixel) {
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
			nl.transparentPixel = l.image.transparentPixel;
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
		changed |= pushPalette(src);
		foreach (li; 0 .. src.layerCount) {
			auto sl = src.layer(li);
			auto tl = _layers[li].image;
			if (!changed && (_layers[li].name != sl.name || _layers[li].visible != sl.visible || tl.transparentPixel != sl.image.transparentPixel)) {
				changed = true;
			}
			_layers[li].name = sl.name;
			_layers[li].visible = sl.visible;
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
		changed |= pushPalette(src);
		foreach (li; 0 .. src.layerCount) {
			auto sl = src.layer(li);
			auto tl = _layers[li].image;
			if (!changed && (_layers[li].name != sl.name || _layers[li].visible != sl.visible || tl.transparentPixel != sl.image.transparentPixel)) {
				changed = true;
			}
			_layers[li].name = sl.name;
			_layers[li].visible = sl.visible;
			auto l = sl.image;
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
	/// Push palettes data.
	private bool pushPalette(in MLImage src) {
		bool changed = false;
		if (_palette.length != src._palette.length) {
			_palette.length = src._palette.length;
			changed = true;
		}
		foreach (pi, ref palette; _palette) {
			if (palette) {
				foreach (i, ref rgb; palette.colors) {
					auto base = src._palette[pi].colors[i];
					if (rgb != base) {
						rgb.red   = base.red;
						rgb.green = base.green;
						rgb.blue  = base.blue;
						changed = true;
					}
				}
			} else {
				// new palette
				palette = src.copyPalette(pi);
				changed = true;
			}
		}
		if (selectedPalette != src.selectedPalette) {
			selectedPalette = src.selectedPalette;
			changed = true;
		}
		foreach (ref combi; _combi) {
			if(_palette.length <= combi.selectedPalette) {
				combi.selectedPalette = 0;
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
		auto palette = copyPalette(_selPalette);
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

	/// Gets visible layer indexes.
	@property
	const
	private size_t[] visibleIndices() {
		checkInit();
		size_t[] r;
		foreach (i, l; _layers) {
			if (l.visible) r ~= i;
		}
		return r;
	}

	/// Creates one image from all layers.
	/// ditto
	ImageData createImageData(ubyte depth) {
		return createImageData(depth, visibleIndices);
	}
	ImageData createImageData(ubyte depth, in size_t[] layer, int selectedPalette = -1) {
		return createImageData(0, 0, _iw, _ih, depth, layer, selectedPalette);
	}
	/// ditto
	ImageData createImageData(Rectangle iRange, ubyte depth) {
		return createImageData(iRange, depth, visibleIndices);
	}
	/// ditto
	ImageData createImageData(Rectangle iRange, ubyte depth, in size_t[] layer, int selectedPalette = -1) {
		return createImageData(iRange.x, iRange.y, iRange.width, iRange.height, depth, layer, selectedPalette);
	}
	/// ditto
	ImageData createImageData(int ix, int iy, int iw, int ih, ubyte depth) {
		return createImageData(ix, iy, iw, ih, depth, visibleIndices);
	}
	/// ditto
	ImageData createImageData(int ix, int iy, int iw, int ih, ubyte depth, in size_t[] layer, int selectedPalette = -1) {
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
		if (-1 != selectedPalette && _palette.length <= selectedPalette) {
			SWT.error(__FILE__, __LINE__, SWT.ERROR_INVALID_ARGUMENT);
		}
		foreach (i; layer) {
			if (_layers.length <= i) {
				SWT.error(__FILE__, __LINE__, SWT.ERROR_INVALID_ARGUMENT);
			}
		}
		checkInit();

		auto basePalette = -1 == selectedPalette ? this.palette : _palette[selectedPalette];
		size_t[] ls = layer.dup.sort().uniq().array();

		/// Creates new palette.
		size_t colors = 0x1 << depth;
		auto rgbs = new RGB[colors];
		foreach (i, ref rgb; rgbs) {
			if (i < 256) {
				rgb = basePalette.colors[i];
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
		if (!ls.length) return data;
		data.transparentPixel = _layers[ls[$ - 1]].image.transparentPixel;
		void put(size_t i, ImageData layer) {
			foreach (x; 0 .. iw) {
				foreach (y; 0 .. ih) {
					int pixel = layer.getPixel(x + ix, y + iy);
					if (pixel < colors && (ls.length - 1 == i || pixel != layer.transparentPixel)) {
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
		layer.image.palette = palette;
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
		auto data = new ImageData(_iw, _ih, 8, palette);
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

	/// Index of selection palette.
	@property
	const
	size_t selectedPalette() {
		checkInit();
		return _selPalette;
	}
	/// ditto
	@property
	void selectedPalette(size_t index) {
		checkInit();
		if (_palette.length <= index) {
			SWT.error(__FILE__, __LINE__, SWT.ERROR_INVALID_ARGUMENT);
		}
		foreach (ref l; _layers) {
			l.image.palette = _palette[index];
		}
		_selPalette = index;
	}

	/// Gets palette.
	@property
	const
	const(PaletteData)[] palettes() {
		checkInit();
		return _palette;
	}
	/// ditto
	@property
	PaletteData[] palettes() {
		checkInit();
		return _palette.dup;
	}
	/// ditto
	@property
	const
	const(PaletteData) palette() {
		checkInit();
		return _palette[_selPalette];
	}
	/// ditto
	@property
	PaletteData palette() {
		checkInit();
		return _palette[_selPalette];
	}

	/// ditto
	@property
	const
	const(PaletteData) getPalette(size_t paletteIndex) {
		if (_palette.length <= paletteIndex) {
			SWT.error(__FILE__, __LINE__, SWT.ERROR_INVALID_ARGUMENT);
		}
		checkInit();
		return _palette[paletteIndex];
	}
	/// ditto
	@property
	PaletteData getPalette(size_t paletteIndex) {
		if (_palette.length <= paletteIndex) {
			SWT.error(__FILE__, __LINE__, SWT.ERROR_INVALID_ARGUMENT);
		}
		checkInit();
		return _palette[paletteIndex];
	}

	/// Add or remove palette.
	void setPalettes(in PaletteData[] palettes, size_t selectIndex) {
		if (!palettes) {
			SWT.error(__FILE__, __LINE__, SWT.ERROR_NULL_ARGUMENT);
		}
		if (0 == palettes.length) {
			SWT.error(__FILE__, __LINE__, SWT.ERROR_INVALID_ARGUMENT);
		}
		if (palettes.length <= selectIndex) {
			SWT.error(__FILE__, __LINE__, SWT.ERROR_INVALID_ARGUMENT);
		}
		foreach (palette; palettes) {
			if (!palette) {
				SWT.error(__FILE__, __LINE__, SWT.ERROR_NULL_ARGUMENT);
			}
			if (palette.isDirect) {
				SWT.error(__FILE__, __LINE__, SWT.ERROR_INVALID_ARGUMENT);
			}
			if (256 != palette.colors.length) {
				SWT.error(__FILE__, __LINE__, SWT.ERROR_INVALID_ARGUMENT);
			}
		}
		checkInit();

		_palette.length = palettes.length;
		foreach (i, ref palette; _palette) {
			palette = copyPalette(palettes[i]);
		}
		selectedPalette = selectIndex;
	}
	/// ditto
	void addPalette(PaletteData palette) {
		checkInit();
		addPalette(_palette.length, palette);
	}
	/// ditto
	void addPalette(size_t index, PaletteData palette) {
		if (_palette.length < index) {
			SWT.error(__FILE__, __LINE__, SWT.ERROR_INVALID_ARGUMENT);
		}
		foreach (p; _palette) {
			if (p is palette) {
				SWT.error(__FILE__, __LINE__, SWT.ERROR_INVALID_ARGUMENT);
			}
		}
		_palette.insertInPlace(index, palette);
		if (index <= selectedPalette) {
			selectedPalette = selectedPalette + 1;
		}
	}
	/// ditto
	void removePalette(size_t index) {
		if (_palette.length <= index) {
			SWT.error(__FILE__, __LINE__, SWT.ERROR_INVALID_ARGUMENT);
		}
		if (1 == _palette.length) {
			SWT.error(__FILE__, __LINE__, SWT.ERROR_INVALID_ARGUMENT);
		}
		_palette = _palette.remove(index);
		auto sel = selectedPalette;
		if (index == sel) {
			selectedPalette = sel;
		} else if (index < sel) {
			selectedPalette = sel - 1;
		}
	}

	/// Gets copy of this palette of image.
	const
	PaletteData copyPalette() {
		return copyPalette(selectedPalette);
	}
	/// ditto
	const
	PaletteData copyPalette(size_t paletteIndex) {
		if (_palette.length <= paletteIndex) {
			SWT.error(__FILE__, __LINE__, SWT.ERROR_INVALID_ARGUMENT);
		}
		checkInit();
		auto palette = _palette[paletteIndex];
		auto rgbs = new RGB[palette.colors.length];
		foreach (i, ref rgb; rgbs) {
			auto base = palette.colors[i];
			rgb = new RGB(base.red, base.green, base.blue);
		}
		return new PaletteData(rgbs);
	}
	/// ditto
	static PaletteData copyPalette(in PaletteData palette) {
		auto rgbs = new RGB[palette.colors.length];
		foreach (i, ref rgb; rgbs) {
			auto base = palette.colors[i];
			rgb = new RGB(base.red, base.green, base.blue);
		}
		return new PaletteData(rgbs);
	}

	/// Gets color of palette.
	const
	RGB color(size_t index) {
		if (this.palette.colors.length <= index) {
			SWT.error(__FILE__, __LINE__, SWT.ERROR_INVALID_ARGUMENT);
		}
		checkInit();
		auto rgb = this.palette.colors[index];
		return new RGB(rgb.red, rgb.green, rgb.blue);
	}
	/// Sets color of palette.
	void color(size_t index, int r, int g, int b) {
		if (palette.colors.length <= index) {
			SWT.error(__FILE__, __LINE__, SWT.ERROR_INVALID_ARGUMENT);
		}
		checkInit();
		auto rgb = palette.colors[index];
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
		if (palette.colors.length != rgbs.length) {
			SWT.error(__FILE__, __LINE__, SWT.ERROR_INVALID_ARGUMENT);
		}
		foreach (i, ref rgb; palette.colors) {
			auto v = rgbs[i];
			rgb.red   = v.red;
			rgb.green = v.green;
			rgb.blue  = v.blue;
		}
	}
	/// Swap pixel colors.
	void swapColor(int pixel1, int pixel2) {
		checkInit();
		if (pixel1 < 0 || palette.colors.length <= pixel1) {
			SWT.error(__FILE__, __LINE__, SWT.ERROR_INVALID_ARGUMENT);
		}
		if (pixel2 < 0 || palette.colors.length <= pixel2) {
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
			SWT.error(__FILE__, __LINE__, SWT.ERROR_NULL_ARGUMENT);
		}
		foreach (c; combi) {
			if (c.visible.length != _layers.length) {
				SWT.error(__FILE__, __LINE__, SWT.ERROR_INVALID_ARGUMENT);
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
			dest[i].selectedPalette = c.selectedPalette;
		}
	}

	/// A data object for undo.
	private static class StoreData {
		/// Size of image.
		uint width, height;
		/// Data of palettes.
		CRGB[256][] palettes;
		/// Index of selection index.
		size_t selectedPalette;
		/// Transparent pixel of layers.
		int[] transparentPixel;
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
		if (_selPalette != data.selectedPalette) return false;
		if (_palette.length != data.palettes.length) return false;
		if (data.includePalette) {
			foreach (pi, palette; data.palettes) {
				foreach (i, ref rgb; palette) {
					auto c = _palette[pi].colors[i];
					if (c.red != rgb.r || c.green != rgb.g || c.blue != rgb.b) return false;
				}
			}
		}
		foreach (i, ref l; _layers) {
			if (l.image.data != data.layers[i]) return false;
			if (l.image.transparentPixel != data.transparentPixel[i]) return false;
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
		data.selectedPalette = selectedPalette;
		data.palettes.length = _palette.length;
		if (includePalette) {
			foreach (pi, ref palette; data.palettes) {
				foreach (i, ref rgb; palette) {
					auto c = _palette[pi].colors[i];
					rgb.r = cast(ubyte) c.red;
					rgb.g = cast(ubyte) c.green;
					rgb.b = cast(ubyte) c.blue;
				}
			}
		}
		data.layers = new byte[][_layers.length];
		data.transparentPixel = new int[_layers.length];
		data.name = new string[_layers.length];
		data.visible = new bool[_layers.length];
		foreach (i, ref l; _layers) {
			data.layers[i] = l.image.data.dup;
			data.transparentPixel[i] = l.image.transparentPixel;
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
		_palette.length = st.palettes.length;
		foreach (pi, ref palette; _palette) {
			palette = new PaletteData(new RGB[st.palettes[pi].length]);
			foreach (i, ref rgb; palette.colors) {
				auto c = st.palettes[pi][i];
				rgb = new RGB(c.r, c.g, c.b);
			}
		}
		selectedPalette = st.selectedPalette;
		_layers.length = st.layers.length;
		foreach (i, ref l; _layers) {
			if (_iw != st.width || _ih != st.height) {
				l.image = new ImageData(st.width, st.height, 8, _palette[selectedPalette]);
			} else if (!l.image) {
				l.image = new ImageData(st.width, st.height, 8, _palette[selectedPalette]);
			}
			l.image.data = st.layers[i].dup;
			l.image.transparentPixel = st.transparentPixel[i];
			l.name = st.name[i];
			l.visible = st.visible[i];
		}
		_iw = st.width;
		_ih = st.height;
		cloneCombi(_combi, st.combi);
		restoreReceivers.raiseEvent(mode);
	}
	@property
	override bool enabledUndo() {
		return !empty;
	}
}
