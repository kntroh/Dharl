
/// This module includes functions to handle EDGE file (*.edg).
///
/// License: Public Domain
/// Authors: kntroh
module dharl.image.edg;

private import util.convertendian;
private import util.sjis;

private import dharl.image.mlimage;

private import std.conv;
private import std.stream;
private import std.string;

private import org.eclipse.swt.all : ImageData, PaletteData, RGB;

/// Loads EDGE file (*.edg).
MLImage loadEDG(string file) {
	auto s = new BufferedFile(file, FileMode.In);
	scope (exit) s.close();
	return loadEDG(s);
}

/// Loads EDGE image from s.
MLImage loadEDG(InputStream s) {
	if ('E' != s.readL!ubyte() || 'D' != s.readL!ubyte() || 'G' != s.readL!ubyte() || 'E' != s.readL!ubyte()) {
		throw new Exception("Data isn't EDGE image.");
	}

	s.readL!uint(); // reserved
	s.readL!ushort(); // reserved

	auto w = s.readL!uint(); // Image width.
	auto h = s.readL!uint(); // Image height.
	auto lCount = s.readL!ushort(); // Count of layers.
	auto tPixel = s.readL!ubyte(); // Transparent pixel.

	// Palette.
	auto rgbs = new RGB[256];
	foreach (ref rgb; rgbs) {
		rgb = new RGB(s.readL!ubyte(), s.readL!ubyte(), s.readL!ubyte());
	}
	auto palette = new PaletteData(rgbs);

	// Creates instance.
	auto img = new MLImage(w, h, palette);

	// Layers.
	foreach (li; 0 .. lCount) {
		// Layer name.
		auto nameBuf = new char[80];
		s.read(cast(ubyte[])nameBuf);
		auto name = .text(nameBuf.ptr);
		// Visibility.
		auto visible = s.readL!ubyte();

		// Pixels.
		auto data = new ImageData(w, h, 8, palette);
		data.transparentPixel = tPixel;

		/// Complressed pixels of EDGE image.
		static struct CompData {
			uint pos; /// Start position of data block.
			uint len; /// Length of data block.
			ubyte val; /// Value of data.
		}
		// Count of compressed data.
		auto cCount = s.readL!uint();
		// Compressed data.
		auto cData = new CompData[cCount];
		foreach (ref d; cData) {
			d.pos = s.readL!uint(); // start position
			d.len = s.readL!uint(); // length
			d.val = s.readL!ubyte(); // value
		}

		// Count of uncompressed data.
		auto uCount = s.readL!uint();
		// Uncompressed data.
		auto uData = new ubyte[uCount];
		s.read(uData);

		uint x = 0, y = 0; // Position.
		// Puts pixel.
		void put(int pixel) {
			data.setPixel(x, y, pixel);
			x++;
			if (w <= x) {
				x = 0;
				y++;
			}
		}
		// Decompress.
		// A not compressed data has exist between a uncompressed data.
		// EDGE image data doesn't have a line padding.
		size_t ui = 0;
		foreach (ref d; cData) {
			while (ui < d.pos) {
				put(uData[ui]);
				ui++;
			}
			foreach (p; 0 .. d.len) {
				put(d.val);
			}
		}
		// Remaining uncompressed data.
		foreach (i; ui .. uData.length) {
			put(uData[i]);
		}

		// Adds layer.
		img.addLayer(li, Layer(data, .touni(name), 0 != visible));
	}

	return img;
}
