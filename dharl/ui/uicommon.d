
/// This module includes functions related to user interface.
module dharl.ui.uicommon;

private import dharl.common;
private import dharl.util.utils;

private import std.exception;

private import java.lang.Runnable;
private import java.io.ByteArrayInputStream;

private import org.eclipse.swt.all;

/// Creates image from dimg.
Image cimg(in DImage dimg) {
	return cimgImpl!Image(dimg, 0, 0);
}

/// Creates cursor from dimg.
Cursor ccur(in DImage dimg, int hotspotX, int hotspotY) {
	return cimgImpl!Cursor(dimg, hotspotX, hotspotY);
}

/// Common function for cimg and ccur.
private T cimgImpl(T)(in DImage dimg, int hotspotX, int hotspotY) {
	enforce(dimg.id);
	enforce(dimg.data);

	auto d2 = Display.getCurrent();
	if (!d2) return null;

	static Display d = null; // The display.
	static T[string] table = null; // Table of image in each display.

	// Disposes all images and clears table.
	void clear() {
		if (!table) return;
		foreach (id, img; table) {
			img.dispose();
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
	auto inp = new ByteArrayInputStream(cast(byte[]) dimg.data);
	auto data = new ImageData(inp);
	data.transparentPixel = 0;
	static if (is(T:Image)) {
		auto img = new T(d, data);
	} else static if (is(T:Cursor)) {
		auto img = new T(d, data, hotspotX, hotspotY);
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
