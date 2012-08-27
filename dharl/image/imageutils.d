
/// This module includes utilities for image.
///
/// License: Public Domain
/// Authors: kntroh
module dharl.image.imageutils;

private import util.graphics;
private import util.types;
private import util.utils;

private import std.exception;

private import org.eclipse.swt.all;

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

/// Reductions polygon by divisor.
int[] smallerPolygon(in int[] polygon, int divisor) {
	.enforce(0 == (polygon.length & 0x1));

	if (!polygon.length) return [];
	if (!divisor) return [];
	if (1 == divisor) return polygon.dup;

	int[] result;
	for (size_t i = 0; i < polygon.length; i += 2) {
		int x = polygon[i];
		int y = polygon[i + 1];

		x = x / divisor;
		y = y / divisor;

		if (result.length) {
			// Removes a extra point.
			int ox = result[$ - 2];
			int oy = result[$ - 1];
			if (x == ox && y == oy) continue;
		}

		result ~= [x, y];
	}
	if (result.length <= 4) {
		// Polygon size doesn't exist.
		result.length = 0;
	}
	return result;
}

/// Magnifies polygon by multiplier.
int[][] zoomPolygon(in int[] polygon, int multiplier) {
	static immutable N = 0;
	static immutable E = 1;
	static immutable S = 2;
	static immutable W = 3;

	if (!polygon.length) return [];
	if (!multiplier) return [];
	if (1 == multiplier) return [polygon.dup];

	.enforce(0 == (polygon.length & 0x1));
	int z = multiplier;
	int[][] result;

	auto region = new Region;
	scope (exit) region.dispose();
	region.add(polygon.dup);

	// Gets frame of polygon in magnified region.
	int[] getFrame(int sx, int sy) {
		int prevDir = S; // Always start from top left.
		int x = sx, y = sy;
		int[] pts;

		do {
			assert (region.contains(x, y));

			// Each direction is in the region?
			bool n = region.contains(x, y - 1);
			bool e = region.contains(x + 1, y);
			bool s = region.contains(x, y + 1);
			bool w = region.contains(x - 1, y);

			// Coordinates of the four corners on magnified point (x, y).
			int[2] ne = [x * z + z, y * z];
			int[2] es = [x * z + z, y * z + z];
			int[2] sw = [x * z,     y * z + z];
			int[2] wn = [x * z,     y * z];

			int[2][4] putPoint = [ne, es, sw, wn];
			bool[4] block = [e, s, w, n];
			int[4] nDir = [W, N, E, S];
			int[2][4] xyMove = [[1, 0], [0, 1], [-1, 0], [0, -1]];

			// Determine add coordinates of corners by clockwise.
			// Start direction is determine by prevDir.
			foreach (d; 0 .. 4) {
				auto i = (d + prevDir) % 4;
				pts ~= putPoint[i];
				if (block[i]) {
					prevDir = nDir[i];
					// next point.
					x += xyMove[i][0];
					y += xyMove[i][1];
					break;
				}
			}
		} while (x != sx || y != sy);

		if (pts.length <= 4) {
			// Polygon size doesn't exist.
			pts.length = 0;
		}
		return pts;
	}

	auto bounds = region.getBounds();

	// Processed point is true.
	bool[] fix = new bool[bounds.width * bounds.height];

	// Starts from left top.
	foreach (y; 0 .. bounds.height) {
		foreach (x; 0 .. bounds.width) {
			if (fix[y * bounds.width + x]) continue;

			int bx = bounds.x + x;
			int by = bounds.y + y;
			if (!region.contains(bx, by)) continue;

			result ~= getFrame(bx, by);

			// Sets true to processed region.
			pointsOfFill((int x, int y, int w, int h) {
				foreach (yy; y .. y + h) {
					int xx = yy * bounds.width + x;
					fix[xx .. xx + w] = true;
				}
			}, (int x, int y) {
				int bx = bounds.x + x;
				int by = bounds.y + y;
				return region.contains(bx, by);
			}, x, y, bounds.width, bounds.height);
		}
	}

	return result;
}
