
/// This module includes functions to handle D-Pixed file (*.dpx).
///
/// License: Public Domain
/// Authors: kntroh
module dharl.image.dpx;

private import util.convertendian;
private import util.sjis;
private import util.utils;

private import dharl.image.mlimage;

private import std.exception;
private import std.stream;
private import std.string;

private import org.eclipse.swt.all : ImageData, PaletteData, RGB;

/// Loads D-Pixed file (*.dpx).
MLImage loadDPX(string file) {
	auto s = new BufferedFile(file, FileMode.In);
	scope (exit) s.close();
	return loadDPX(s);
}

/// Loads D-Pixed image from s.
MLImage loadDPX(InputStream s) {
	ubyte[128] desc;
	s.read(desc); // Description.
	if ('D' != desc[0] || 'P' != desc[1] || 'X' != desc[2]) {
		throw new Exception("Data isn't D-Pixed image.");
	}
	auto ver = s.readL!uint(); // Data version.
	auto fileFlags = s.readL!uint(); // File flags.

	auto w = s.readL!uint(); // Image width.
	auto h = s.readL!uint(); // Image height.
	auto lCount = s.readL!uint(); // Count of layers.

	s.readL!uint(); // reserved
	s.readL!uint(); // reserved
	s.readL!uint(); // reserved

	// Palette.
	auto rgbs = new RGB[256];
	foreach (ref rgb; rgbs) {
		auto i = s.readL!uint();
		rgb = new RGB(
			(i >>> 16) & 0xFF, // red
			(i >>> 8)  & 0xFF, // green
			(i >>> 0)  & 0xFF  // blue
		);
	}
	auto palette = new PaletteData(rgbs);

	// Creates instance.
	auto img = new MLImage(w, h, palette);

	// Layers.
	foreach (i; 0 .. lCount) {
		static immutable HAS_MASK       = 0x00000001;
		static immutable LAYER_PALETTE  = 0x00000002;
		static immutable COMP_MASK      = 0x00000010;
		static immutable COMP_IMAGE     = 0x00000020;
		static immutable VISIBLE        = 0x00010000;
		static immutable USE_MASK       = 0x00020000;
		static immutable HAS_COLOR_MASK = 0x00100000;

		auto headerSize = s.readL!uint(); // Size of layer header.
		auto layerFlags = s.readL!uint(); // Flags.
		auto transparentPixel = s.readL!uint(); // Transparent pixel (index).
		auto alpha = s.readL!uint() * 16; // Alpha of layer.
		auto maskDataSize = s.readL!uint(); // Size of mask data on each pixel.
		auto backgroundPixel = s.readL!uint(); // Background pixel (index).
		auto dataSize = s.readL!uint(); // Size of image data.
		s.readL!uint(); // reserved

		// Layer name.
		char[] name;
		foreach (n; 0 .. 64) {
			char c;
			s.read(c);
			if (c) name ~= c;
		}
		if (0x00002100 <= ver) {
			// Animation-related data. (Ignore)
			auto aLeft   = s.readL!uint();
			auto aTop    = s.readL!uint();
			auto aRight  = s.readL!uint();
			auto aBottom = s.readL!uint();
			auto aDelay  = s.readL!uint();
			auto aMode   = s.readL!uint();
			auto aInput  = s.readL!uint();
			auto aTransparent = s.readL!uint();
		}

		if (0x00002110 <= ver) {
			// Color mask. (Ignore)
			if (HAS_COLOR_MASK & layerFlags) {
				ubyte[256] colorMask;
				s.read(colorMask);
			}
		}

		// Pixels.
		auto data = new ImageData(w, h, 8, palette);
		data.transparentPixel = transparentPixel;
		int x = 0, y = h - 1;

		auto pad = .padding(w, 4);

		auto padCount = 0;
		void put(int b) {
			if (padCount) {
				// ignore line padding
				padCount--;
				return;
			}
			data.setPixel(x, y, b);
			x++;
			if (w <= x) {
				x = 0;
				y--;
				padCount = pad; // ignores line padding
			}
		}

		if (COMP_IMAGE & layerFlags) {
			// Compressed data.
			// If there is a same pixel twice, next byte is run length of it pixel.
			// Actual data is compressed confuse with a line padding.
			short old = -1;
			for (size_t p = 0; p < dataSize;) {
				auto b = s.readL!ubyte();
				p++;
				if (b == old) {
					// run length
					auto len = s.readL!ubyte();
					p++;
					foreach (l; 0 .. len) {
						put(b);
					}
					old = -1;
				} else {
					if (-1 != old) {
						put(old);
					}
					old = b;
				}
			}
		} else {
			// uncompressed
			for (size_t p = 0; p < dataSize; p++) {
				put(s.readL!ubyte());
			}
		}

		auto maskData = new ubyte[maskDataSize];
		s.read(maskData); // Mask data. (Ignore)

		// Adds layer.
		img.addLayer(0, Layer(data, .touni(name), 0 != (layerFlags & VISIBLE)));
	}

	return img;
}
