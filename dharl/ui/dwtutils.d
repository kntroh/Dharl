
/// This module includes utilities for DWT.
module dharl.ui.dwtutils;

public import dwtutils.utils;
public import dwtutils.wrapper;

private import util.graphics;
private import util.types;
private import util.utils;

private import dharl.ui.splitter;

private import std.exception;
private import std.math;
private import std.range;
private import std.string;
private import std.typecons;

private import org.eclipse.swt.all;

/// A MouseWheel event send to a control under the cursor always.
void initMouseWheel(Shell shell) {
	auto d = shell.p_display;
	bool inProc = false;
	d.p_filters!(SWT.MouseWheel) ~= (Event e) {
		.enforce(SWT.MouseWheel == e.type);

		if (inProc) return;
		inProc = true;
		scope (exit) inProc = false;

		auto c = d.getCursorControl();
		if (!c) return;
		auto w = cast(Control) e.widget;
		if (!w) return;
		if (c.p_shell !is shell) return;
		if (c is w) {
			e.doit = false;
			return;
		}

		auto se = new Event;
		se.type = e.type;
		se.widget = c;
		se.time = e.time;
		se.stateMask = e.stateMask;
		se.doit = e.doit;

		auto p = c.toControl(w.toDisplay(e.x, e.y));
		se.button = e.button;
		se.x = p.x;
		se.y = p.y;
		se.count = e.count;

		c.notifyListeners(se.type, se);
		e.doit = false;
	};
}

/// Sets parameters to shell from param.
/// And save parameters when disposed shell.
void refWindow(ref WindowParameter param, Shell shell) {
	shell.p_bounds = CRect(param.x, param.y, param.width, param.height);
	shell.p_maximized = param.maximized;
	shell.p_minimized = param.minimized;
	shell.listeners!(SWT.Dispose) ~= (Event e) {
		auto b = shell.p_bounds;
		param.x      = b.x;
		param.y      = b.y;
		param.width  = b.width;
		param.height = b.height;
		param.maximized = shell.p_maximized;
		param.minimized = shell.p_minimized;
	};
}

/// Sets width and height to two spinners.
/// And save value when disposed spinners.
void refSize(ref PSize size, Spinner width, Spinner height) {
	width.p_selection  = size.width;
	height.p_selection = size.height;
	width.listeners!(SWT.Dispose) ~= (Event e) {
		size.width  = width.p_selection;
	};
	height.listeners!(SWT.Dispose) ~= (Event e) {
		size.height = height.p_selection;
	};
}

/// Sets value to control.
/// And save value when disposed control.
void refSelection(C, V)(ref V value, C control) {
	control.p_selection = value;
	control.listeners!(SWT.Dispose) ~= (Event e) {
		value = control.p_selection;
	};
}

// Draws alternately different color lines,
// to raise the visibility.
void drawColorfulFocus(GC gc, Color color1, Color color2, int x, int y, int w, int h) {
	auto fore = gc.p_foreground;
	scope (exit) gc.p_foreground = fore;
	int oldStyle = gc.p_lineStyle;
	scope (exit) gc.p_lineStyle = oldStyle;
	int[] oldDash = gc.p_lineDash;
	scope (exit) gc.p_lineDash = oldDash;

	gc.p_lineStyle = SWT.LINE_SOLID;
	gc.p_foreground = color1;
	gc.drawRectangle(x, y, w, h);

	gc.p_lineStyle = SWT.LINE_DASH;
	int[] cLineDash = [2, 3];
	gc.p_lineDash = cLineDash;
	gc.p_foreground = color2;
	gc.drawRectangle(x, y, w, h);
}
/// ditto
void drawColorfulFocus(GC gc, Color color1, Color color2, Rectangle rect) {
	drawColorfulFocus(gc, color1, color2, rect.x, rect.y, rect.width, rect.height);
}

// Shading to client area.
void drawShade(GC gc, in Rectangle clientArea) {
	static const cSHADE_INTERVAL = 8;
	int cwh = clientArea.width + clientArea.height;
	for (size_t c = 0; c < cwh; c += cSHADE_INTERVAL) {
		gc.drawLine(c, 0, 0, c);
		gc.drawLine(c - clientArea.height, 0, c, clientArea.height);
	}
}

/// Converts image to 8-bit indexed color.
ImageData colorReduction(ImageData image, bool errorDiffusion = true) {
	if (image.depth == 8 && !image.palette.isDirect && image.palette.colors.length == 256) {
		/// result == image
		return image;
	}
	if (image.depth <= 8 && !image.palette.isDirect) {
		/// image is less than 8-bit indexed color.
		auto rgbs = new RGB[256];
		foreach (i, ref rgb; rgbs) {
			if (i < image.palette.colors.length) {
				auto c = image.palette.colors[i];
				rgb = new RGB(c.red, c.green, c.blue);
			} else {
				rgb = new RGB(0, 0, 0);
			}
		}
		auto result = new ImageData(image.width, image.height, 8, new PaletteData(rgbs));
		auto pixels = new int[image.width * image.height];
		image.getPixels(0, 0, pixels.length, pixels, 0);
		result.setPixels(0, 0, pixels.length, pixels, 0);
		return result;
	}
	auto d = Display.getCurrent();

	// All colors used.
	auto colors = new CRGB[image.width * image.height];
	auto colors2 = new CRGB[image.width * image.height];
	size_t ci = 0;
	foreach(y; 0 .. image.height) {
		foreach(x; 0 .. image.width) {
			auto rgb = image.palette.getRGB(image.getPixel(x, y));
			ubyte r = cast(ubyte) rgb.red;
			ubyte g = cast(ubyte) rgb.green;
			ubyte b = cast(ubyte) rgb.blue;
			colors[ci] = CRGB(r, g, b);
			colors2[ci] = CRGB(r, g, b);
			ci++;
		}
	}

	// Creates 256-colors palette.
	RGB[] createPalette() {
		auto rgbs = new RGB[256];
		foreach (i, ref rgb; rgbs) {
			if (i < colors.length) {
				rgb = new RGB(colors[i].r, colors[i].g, colors[i].b);
			} else {
				rgb = new RGB(0, 0, 0);
			}
		}
		return rgbs;
	}
	if (colors.length <= 256) {
		auto rgbs = createPalette();

		// Creates result image.
		auto result = new ImageData(image.width, image.height, 8, new PaletteData(rgbs));
		assert (!result.palette.isDirect);
		ci = 0;
		foreach(y; 0 .. image.height) {
			foreach(x; 0 .. image.width) {
				result.setPixel(x, y, ci);
				ci++;
			}
		}
		return result;
	} else {
		// Color reduction.
		medianCut(colors, 256);
		assert (colors.length == 256);
		auto tree = new ColorTree(colors, true);
		colors = tree.sortedColors;

		// Creates 256-colors palette.
		auto rgbs = createPalette();

		// Creates result image.
		auto result = new ImageData(image.width, image.height, 8, new PaletteData(rgbs));
		assert (!result.palette.isDirect);
		ci = 0;
		foreach(y; 0 .. image.height) {
			foreach(x; 0 .. image.width) {
				auto rgb = colors2[ci];
				size_t sel = tree.searchLose(rgb);
				result.setPixel(x, y, sel);

				if (errorDiffusion) {
					// Error diffusion.
					auto c = result.palette.colors[sel];
					// errors
					int er = cast(int) rgb.r - c.red;
					int eg = cast(int) rgb.g - c.green;
					int eb = cast(int) rgb.b - c.blue;
					void diffusion(size_t x, size_t y, real rate) {
						if (image.width <= x || image.height <= y) return;
						size_t ci = y * image.width + x;
						auto trgb = colors2[ci];
						trgb.r = roundCast!(ubyte)(trgb.r + cast(int) (er * rate));
						trgb.g = roundCast!(ubyte)(trgb.g + cast(int) (eg * rate));
						trgb.b = roundCast!(ubyte)(trgb.b + cast(int) (eb * rate));
						colors2[ci] = trgb;
					}
					diffusion(x + 1, y, 0.375);
					diffusion(x, y + 1, 0.375);
					diffusion(x + 1, y + 1, 0.25);
				}
				ci++;
			}
		}
		return result;
	}
}
