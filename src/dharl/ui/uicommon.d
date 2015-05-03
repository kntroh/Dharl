
/// This module includes functions related to user interface.
///
/// License: Public Domain
/// Authors: kntroh
module dharl.ui.uicommon;

private import util.utils;

private import dharl.common;

private import std.exception;

private import java.lang.Runnable;
private import java.io.ByteArrayInputStream;

private import org.eclipse.swt.all;

/// Creates image from dimg.
Image cimg(in DImage dimg) {
	return cimgImpl!Image(dimg, CursorSpot.init);
}

/// Creates multiple images from dimg.
Image[] cmimg(in DImage dimg) {
	return cimgImpl!(Image[])(dimg, CursorSpot.init);
}

/// Creates cursor from dimg.
Cursor ccur(in DImage dimg, CursorSpot hotspot) {
	return cimgImpl!Cursor(dimg, hotspot);
}

/// Hotspot of cursor.
enum CursorSpot {
	TopLeft, // Top left.
	Center, // Center.
}

/// Common function for cimg and ccur.
private T cimgImpl(T)(in DImage dimg, CursorSpot hotspot) {
	if (!dimg.id) return null;
	if (!dimg.data) return null;

	auto d2 = Display.getCurrent();
	if (!d2) {
		d2 = new Display;
	}

	static Display d = null; // The display.
	static T[string] table = null; // Table of image in each display.

	// Disposes all images and clears table.
	void clear() {
		if (!table) return;
		static if (is(T:Image[])) {
			foreach (id, imgs; table) {
				foreach (img; imgs) {
					img.dispose();
				}
			}
		} else {
			foreach (id, img; table) {
				img.dispose();
			}
		}
		table = null;
	}

	if (d2 !is d) {
		// A new display created.
		d = d2;
		typeof(table) newTable;
		table = newTable;
		d.disposeExec(new class Runnable {
			override void run() {
				clear();
			}
		});
	}

	auto p = dimg.id in table;
	if (p) return *p;
	// Creates image from bytes.
	auto inp = new ByteArrayInputStream(cast(byte[])dimg.data);
	static if (is(T:Image[])) {
		T img;
		foreach (data; (new ImageLoader).load(inp)) {
			img ~= new Image(d, data);
		}
	} else {
		auto data = new ImageData(inp);
		data.transparentPixel = 0;
		static if (is(T:Image)) {
			auto img = new T(d, data);
		} else static if (is(T:Cursor)) {
			T img;
			final switch (hotspot) {
			case CursorSpot.TopLeft:
				img = new T(d, data, 0, 0);
				break;
			case CursorSpot.Center:
				img = new T(d, data, data.width / 2, data.height / 2);
				break;
			}
		}
	}
	table[dimg.id] = img;
	return img;
}

/// Creates tone icon.
ImageData toneIcon(in bool[][] tone, uint w, uint h) {
	enforce(0 < w);
	enforce(0 < h);
	auto colors = [new RGB(255, 255, 255), new RGB(0, 0, 0)];
	auto palette = new PaletteData(colors);
	auto image = new ImageData(w, h, 1, palette);
	if (!tone || 0 == tone.length) {
		return image;
	}
	// border of icon
	foreach (y; 0 .. h) {
		if (0 == y || h - 1 == y) {
			foreach (x; 0 .. w) {
				image.setPixel(x, y, 1);
			}
		} else {
			image.setPixel(0, y, 1);
			image.setPixel(w - 1, y, 1);
		}
	}
	// tone
	foreach (y; 2 .. h - 2) {
		auto ln = tone[(y - 2) % $];
		if (!ln || !ln.length) continue;
		foreach (x; 2 .. w - 2) {
			image.setPixel(x, y, ln[(x - 2) % $] ? 1 : 0);
		}
	}
	return image;
}
