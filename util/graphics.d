
/// This module include common member for graphics.
module util.graphics;

private import util.types;
private import util.utils;

private import std.algorithm;
private import std.conv;
private import std.exception;
private import std.math;

/// Path mode for paint.
enum PaintMode {
	FreePath, /// Free path.
	Straight, /// Straight path.
	OvalLine, /// Oval (line).
	RectLine, /// Rectangle (line).
	OvalFill, /// Oval (fill).
	RectFill, /// Rectangle (fill).
	Fill, /// Fill same color area.
}

/// If pointsOfPath() is using size parameter by mode, returns true.
bool isEnabledSize(PaintMode mode) {
	return PaintMode.Fill != mode;
}

/// Distance of 1 to 2.
real distance(real x1, real y1, real x2, real y2) {
	real d1 = x1 - x2;
	real d2 = y1 - y2;
	return sqrt(d1 * d1 + d2 * d2);
}

/// Calls dlg(X, Y) or dlg(X, Y, Width, Height) with points of path.
/// If mode is PaintMode.Fill, please use pointsOfFill().
void pointsOfPath(void delegate(int x, int y) dlg, PaintMode mode, int x1, int y1, int x2, int y2, size_t w, size_t h, uint size = 1) {
	pointsOfPath((int x, int y, int w, int h) {
		foreach (ix; x .. w + x) {
			foreach (iy; y .. h + y) {
				dlg(ix, iy);
			}
		}
	}, mode, x1, y1, x2, y2, w, h, size);
}
/// ditto
void pointsOfPath(void delegate(int x, int y, int w, int h) dlg, PaintMode mode, int x1, int y1, int x2, int y2, size_t w, size_t h, uint size = 1) {
	if (0 == size) return;

	int s = size - 1;

	// Calls dlg on around x, y.
	void around(int x, int y, int xw, int yh) {
		assert (isEnabledSize(mode));
		if (1 == size && 1 == xw && 1 == yh) {
			if (0 <= x && x < w && 0 <= y && y < h) {
				dlg(x, y, xw, yh);
			}
		} else {
			int xFrom = x - s;
			int xTo = x + xw + s;
			if (xTo < 0 || cast(int) w <= xFrom) return;
			int yFrom = y - s;
			int yTo = y + yh + s;
			if (yTo < 0 || cast(int) h <= yFrom) return;
			xTo = min(cast(int) w, xTo);
			xFrom = max(0, xFrom);
			yTo = min(cast(int) h, yTo);
			yFrom = max(0, yFrom);
			dlg(xFrom, yFrom, xTo - xFrom, yTo - yFrom);
		}
	}

	if (x1 == x2 && y1 == y2) {
		if (isEnabledSize(mode)) {
			around(x1, y1, 1, 1);
		} else {
			dlg(x1, y1, 1, 1);
		}
		return;
	}

	int mxx = max(x1, x2);
	int mnx = min(x1, x2);
	int mxy = max(y1, y2);
	int mny = min(y1, y2);

	// Common function for oval.
	void oval(void delegate(int cx, int cy, int x, int y) dlg2) {
		// Bresenham
		int a = (mxx - mnx) / 2;
		int b = (mxy - mny) / 2;
		int aa = a * a;
		int bb = b * b;
		int aa2 = aa * 2;
		int bb2 = bb * 2;
		int aa4 = aa * 4;
		int bb4 = bb * 4;
		int r = a * b;
		int d = b * r;
		// central
		int cx = mnx + a;
		int cy = mny + b;
		int f = (-2 * d + bb) + aa2;
		int h = (-4 * d) + bb2 + aa;
		int x = a;
		int y = 0;
		// Only 1/4 is calculated.
		while (x >= 0) {
			dlg2(cx, cy, x, y);
			if (f >= 0) {
				x--;
				f -= bb4 * x;
				h -= bb4 * x - bb2;
			}
			if (h < 0) {
				y++;
				f += aa4 * y + aa2;
				h += aa4 * y;
			}
		}
	}
	final switch (mode) {
	case PaintMode.FreePath, PaintMode.Straight:
		if (y1 == y2) {
			// horizontal
			int ss = size * 2 - 1;
			assert (ss >= 1);
			int to = min(cast(int) (w - (size - 1)), mxx);
			int x = max(cast(int) (size - 1), mnx);
			around(x, y1, to + 1 - x, 1);
		} else if (x1 == x2) {
			// vertical
			int ss = size * 2 - 1;
			assert (ss >= 1);
			int to = min(cast(int) (h - (size - 1)), mxy);
			int y = max(cast(int) (size - 1), mny);
			around(x1, y, 1, to + 1 - y);
		} else {
			// diagonal line
			size_t len = max(mxx - mnx, mxy - mny);
			// from
			// TODO
			around(x1, y1, 1, 1);
			foreach (i; 1 .. len) {
				// among
				real dt = cast(real) i / len;
				int x = roundTo!(int)((x2 - x1) * dt);
				int y = roundTo!(int)((y2 - y1) * dt);
				around(x1 + x, y1 + y, 1, 1);
			}
			// to
			around(x2, y2, 1, 1);
		}
		break;
	case PaintMode.OvalLine:
		oval((int cx, int cy, int x, int y) {
			around(cx + x, cy + y, 1, 1);
			around(cx + x, cy - y, 1, 1);
			around(cx - x, cy + y, 1, 1);
			around(cx - x, cy - y, 1, 1);
		});
		break;
	case PaintMode.RectLine:
		if (mxx < 0 || cast(int) w <= mnx) return;
		if (mxy < 0 || cast(int) h <= mny) return;
		mnx = min(x1, x2);
		mxx = max(x1, x2);
		mny = min(y1, y2);
		mxy = max(y1, y2);
		around(mnx, mny, mxx + 1 - mnx, 1);
		around(mnx, mxy, mxx + 1 - mnx, 1);
		around(mnx, mny + s * 2, 1, mxy + 1 - mny - s * 4);
		around(mxx, mny + s * 2, 1, mxy + 1 - mny - s * 4);
		break;
	case PaintMode.OvalFill:
		int i = 0;
		oval((int cx, int cy, int x, int y) {
			int ix1 = cx - x;
			int ix2 = cx + x;
			if (ix2 < 0 || cast(int) w <= ix1) return;
			int x1 = max(cast(int) (size - 1), ix1);
			int x2 = min(cast(int) (w - (size - 1)), ix2);

			// Draws line from top left to top right.
			int ya = cy + y;
			if (0 <= ya && ya < h) {
				pointsOfPath(dlg, PaintMode.Straight, x1, ya, x2, ya, w, h, size);
			}

			// Draws line from bottom left to bottom right.
			int yb = cy - y;
			if (0 <= yb && yb < h) {
				pointsOfPath(dlg, PaintMode.Straight, x1, yb, x2, yb, w, h, size);
			}
		});
		break;
	case PaintMode.RectFill:
		if (mxx < 0 || cast(int) w <= mnx) return;
		if (mxy < 0 || cast(int) h <= mny) return;
		mnx = max(cast(int) (size - 1), mnx);
		mxx = min(cast(int) (w - (size - 1)), mxx);
		mny = max(cast(int) (size - 1), mny);
		mxy = min(cast(int) (h - (size - 1)), mxy);
		foreach (y; mny .. mxy + 1) {
			pointsOfPath(dlg, PaintMode.Straight, mnx, y, mxx, y, w, h, size);
		}
		break;
	case PaintMode.Fill:
		// Please use pointsOfFill().
		break;
	}
}
unittest {
	import std.string;

	char[][] img = [
		"      ".dup,
		"      ".dup,
		"      ".dup,
		"      ".dup
	];
	// Straight line (vertical) with '#'.
	pointsOfPath((int x, int y) {
		img[y][x] = '#';
	}, PaintMode.Straight, 0, 0, 0, 3, 6, 4, 1);
	assert (img == [
		"#     ",
		"#     ",
		"#     ",
		"#     "
	], "\n" ~ std.string.join(img, "\n"));

	// Straight line (horizontal) with '@'.
	pointsOfPath((int x, int y) {
		img[y][x] = '@';
	}, PaintMode.Straight, 1, 1, 3, 1, 6, 4, 2);
	assert (img == [
		"@@@@@ ",
		"@@@@@ ",
		"@@@@@ ",
		"#     "
	], "\n" ~ std.string.join(img, "\n"));

	// Rectangle with '?'.
	pointsOfPath((int x, int y) {
		img[y][x] = '?';
	}, PaintMode.RectLine, 0, -1, 5, 3, 6, 4, 2);
	assert (img == [
		"??????",
		"??@@??",
		"??????",
		"??????"
	], "\n" ~ std.string.join(img, "\n"));
}

/// Calls dlg(X, Y) or dlg(X, Y, Width, Height) with points of fill area.
/// Params:
///  onFillArea = This function receives X, Y
///               and returns true if it is fill area.
void pointsOfFill(void delegate(int x, int y) dlg, bool delegate(int x, int y) onFillArea, int sx, int sy, size_t w, size_t h) {
	pointsOfFill((int x, int y, int w, int h) {
		foreach (ix; x .. w + x) {
			foreach (iy; y .. h + y) {
				dlg(ix, iy);
			}
		}
	}, onFillArea, sx, sy, w, h);
}
/// ditto
void pointsOfFill(void delegate(int x, int y, int w, int h) dlg, bool delegate(int x, int y) onFillArea, int sx, int sy, size_t w, size_t h) {
	if (!onFillArea(sx, sy)) return;
	if (sx < 0 || w <= sx) return;
	if (sy < 0 || h <= sy) return;

	// Scanline seed fill algorithm.

	auto comp = new bool[w * h]; // Information of completed.

	bool canFill(int x, int y) {
		return (0 <= x && x < w)
			&& (0 <= y && y < h)
			&& onFillArea(x, y)
			&& !comp[w * y + x];
	}

	void procSeed(int sx, int sy) {
		int wy = w * sy;
		int xl = sx;
		int xr = sx;
		while (canFill(xl - 1, sy)) xl--;
		while (canFill(xr + 1, sy)) xr++;
		pointsOfPath(dlg, PaintMode.Straight, xl, sy, xr, sy, w, h);
		comp[wy + xl .. wy + xr + 1] = true;

		int upX = -1;
		int downX = -1;
		int upY = sy - 1;
		int downY = sy + 1;
		foreach (nx; xl .. xr + 1) {
			if (canFill(nx, upY)) {
				upX = nx;
			} else {
				if (-1 != upX) {
					procSeed(upX, upY);
				}
				upX = -1;
			}
			if (canFill(nx, downY)) {
				downX = nx;
			} else {
				if (-1 != downX) {
					procSeed(downX, downY);
				}
				downX = -1;
			}
		}
		if (-1 != upX) {
			procSeed(upX, upY);
		}
		if (-1 != downX) {
			procSeed(downX, downY);
		}
	}
	procSeed(sx, sy);
}
unittest {
	import std.string;

	char[][] img = [
		"    # ".dup,
		"#     ".dup,
		" #  # ".dup,
		"  #   ".dup
	];
	// Paints with '@'.
	pointsOfFill((int x, int y) {
		img[y][x] = '@';
	}, (int x, int y) {
		return img[y][x] == ' ';
	}, 2, 1, img[0].length, img.length);
	assert (img == [
		"@@@@#@",
		"#@@@@@",
		" #@@#@",
		"  #@@@"
	], "\n" ~ std.string.join(img, "\n"));
	// Paints with '#'.
	pointsOfFill((int x, int y) {
		img[y][x] = '#';
	}, (int x, int y) {
		return img[y][x] == ' ';
	}, 0, 2, img[0].length, img.length);
	assert (img == [
		"@@@@#@",
		"#@@@@@",
		"##@@#@",
		"###@@@"
	], "\n" ~ std.string.join(img, "\n"));
	// Paints with '&'.
	pointsOfFill((int x, int y) {
		img[y][x] = '&';
	}, (int x, int y) {
		return img[y][x] == '#';
	}, 1, 2, img[0].length, img.length);
	assert (img == [
		"@@@@#@",
		"&@@@@@",
		"&&@@#@",
		"&&&@@@"
	], "\n" ~ std.string.join(img, "\n"));
	// Paints with ' '.
	pointsOfFill((int x, int y) {
		img[y][x] = ' ';
	}, (int x, int y) {
		return true;
	}, 3, 2, img[0].length, img.length);
	assert (img == [
		"      ",
		"      ",
		"      ",
		"      "
	], "\n" ~ std.string.join(img, "\n"));
	img = [
		"#########".dup,
		"###   ###".dup,
		"###   ###".dup,
		"#       #".dup,
		"#   #   #".dup,
		"#       #".dup,
		"###   ###".dup,
		"###   ###".dup,
		"#########".dup
	];
	// Paints with '@'.
	pointsOfFill((int x, int y) {
		img[y][x] = '@';
	}, (int x, int y) {
		return img[y][x] == ' ';
	}, 4, 2, img[0].length, img.length);
	assert (img == [
		"#########",
		"###@@@###",
		"###@@@###",
		"#@@@@@@@#",
		"#@@@#@@@#",
		"#@@@@@@@#",
		"###@@@###",
		"###@@@###",
		"#########"
	], "\n" ~ std.string.join(img, "\n"));
	img = [
		"#########".dup,
		"        #".dup,
		" # #  # #".dup,
		"#### ####".dup,
		"###   # #".dup,
		"####    #".dup,
		"##  #   #".dup,
		"#       #".dup,
		"#########".dup
	];
	// Paints with '@'.
	pointsOfFill((int x, int y) {
		img[y][x] = '@';
	}, (int x, int y) {
		return img[y][x] == ' ';
	}, 4, 2, img[0].length, img.length);
	assert (img == [
		"#########".dup,
		"@@@@@@@@#".dup,
		"@#@#@@#@#".dup,
		"####@####".dup,
		"###@@@#@#".dup,
		"####@@@@#".dup,
		"##@@#@@@#".dup,
		"#@@@@@@@#".dup,
		"#########".dup
	], "\n" ~ std.string.join(img, "\n"));
}

// Does `Median Cut' in-place.
// Colors count is decreased to countOfTarget.
// If result count is less countOfTarget,
// fill remaining area by RGB(0, 0, 0).
void medianCut(ref CRGB[] colors, size_t countOfTarget) {
	if (colors.length == countOfTarget) return;
	if (colors.length < countOfTarget) {
		size_t len = colors.length;
		colors.length = countOfTarget;
		colors[len .. $] = CRGB(0, 0, 0);
		return;
	}
	// Information for median cut.
	static struct MCBox {
		/// Range.
		size_t from;
		/// ditto
		size_t to;
		/// Target of divide (RGB index).
		ubyte targ;
		/// Median of target value.
		ubyte med;
		/// Length from minimum value to maximum value in targ.
		size_t len;
		/// Typical value, maximum value and minimum value.
		/// [0] = R, [1] = B, [2] = G
		ubyte[3] typVal;
	}
	auto boxes = new MCBox[countOfTarget];
	boxes[0].from = 0;
	boxes[0].to = colors.length;
	// Array of RGB values to calculate median.
	auto cArr = new ubyte[colors.length];
	void createBox(ref MCBox box) {
		box.len = 0;
		if (box.to <= box.from) {
			box.med = colors[box.from].r;
			box.targ = 0;
			return;
		}
		foreach (ubyte rgb; 0 .. 3) {
			ubyte max = ubyte.min;
			ubyte min = ubyte.max;
			uint sum = 0;
			size_t cALen = 0;
			foreach (xy; box.from .. box.to) {
				ubyte cv;
				final switch (rgb) {
				case 0: cv = colors[xy].r; break;
				case 1: cv = colors[xy].g; break;
				case 2: cv = colors[xy].b; break;
				}
				max = .max(cv, max);
				min = .min(cv, min);
				sum += cv;
				cArr[cALen] = cv;
				cALen++;
			}
			// average
			box.typVal[rgb] = cast(ubyte) (sum / (box.to - box.from));

			int len = max - min;
			if (box.len < len) {
				// Select divide target.
				box.len = len;
				box.med = cArr[cALen / 2];
				box.targ = rgb;
			}
		}
	}
	createBox(boxes[0]);
	size_t bLen = 1;
	while (bLen < countOfTarget) {
		size_t sel;
		size_t len = size_t.min;
		// Select maximum length box.
		foreach (i; 0 .. bLen) {
			if (len < boxes[i].len) {
				len = boxes[i].len;
				sel = i;
			}
		}
		if (len < 2) break;

		// Does sort and divide,
		// f becomes a division index as a result.
		size_t f = boxes[sel].from;
		size_t t = boxes[sel].to - 1;
		while (f < t) {
			ubyte cv;
			final switch (boxes[sel].targ) {
			case 0: cv = colors[f].r; break;
			case 1: cv = colors[f].g; break;
			case 2: cv = colors[f].b; break;
			}
			if (boxes[sel].med < cv) {
				swap(colors[f], colors[t]);
				t--;
			} else {
				f++;
			}
		}
		size_t divLine = f;

		// Create new box.
		boxes[bLen].from = divLine;
		boxes[bLen].to = boxes[sel].to;
		createBox(boxes[bLen]);
		bLen++;

		// Recalculate.
		boxes[sel].to = divLine;
		createBox(boxes[sel]);
	}

	colors.length = countOfTarget;
	foreach (i, ref box; boxes) {
		colors[i].r = box.typVal[0];
		colors[i].g = box.typVal[1];
		colors[i].b = box.typVal[2];
	}
	if (boxes.length < countOfTarget) {
		colors[boxes.length .. $] = CRGB(0, 0, 0);
	}
}

// Sorted collection of color. Implemented by octree.
class ColorTree {
	/// Index of return value of sortedColors().
	private size_t _index;
	/// Level of node.
	private ubyte _level;
	/// Color of this node.
	private CRGB _color;
	/// Sub nodes.
	private ColorTree[8] _node;
	/// Sorted colors.
	private CRGB[] _sorted = null;

	/// Creates color tree.
	this (const(CRGB[]) colors, bool sort) {
		enforce(colors.length);
		_index = 0;
		_level = 0;
		foreach (i, ref c; colors) {
			add(c, i);
		}
		size_t index = 0;
		if (sort) {
			size_t len = createIndices(index);
			_sorted = new CRGB[len];
			index = 0;
			sortedColorsImpl(_sorted, index);
		}
	}
	/// Creates node of color tree.
	private this (ubyte level, ref const(CRGB) color, size_t index) {
		_level = level;
		_color = color;
		_index = index;
	}

	/// Calculates index of _node.
	private size_t nodeIndex(ref const(CRGB) color)
	out (result) {
		assert (result < 8);
	} body {
		auto mask = 0x80 >> _level;
		auto shift = 7 - _level;
		auto r = (color.r & mask) >> (shift - 2);
		auto g = (color.g & mask) >> (shift - 1);
		auto b = (color.b & mask) >> (shift - 0);
		assert (r <= 4 && g <= 2 && b <= 1);
		return r | g | b;
	}

	/// Adds node of color.
	private bool add(ref const(CRGB) color, size_t index) {
		if (0 != _level && _color == color) {
			return false;
		}
		size_t i = nodeIndex(color);
		if (!_node[i]) {
			_node[i] = new ColorTree(cast(ubyte) (_level + 1), color, index);
			return true;
		}
		return _node[i].add(color, index);
	}

	/// Creates index of result of sortedColors().
	private size_t createIndices(ref size_t index) {
		if (0 != _level) {
			_index = index;
			index++;
		}
		foreach (n; _node) {
			if (n) {
				n.createIndices(index);
			}
		}
		return index;
	}

	/// Gets sorted array of colors.
	@property
	CRGB[] sortedColors() {
		return _sorted;
	}
	private void sortedColorsImpl(ref CRGB[] result, ref size_t index) {
		if (0 != _level) {
			result[index] = _color;
			index++;
		}
		foreach (n; _node) {
			if (n) {
				n.sortedColorsImpl(result, index);
			}
		}
	}
	/// Finds and returns index of color.
	/// If not found, returns index of closest matching color.
	size_t searchLose(ref const(CRGB) color) {
		if (0 != _level && _color == color) {
			return _index;
		}
		size_t ni = nodeIndex(color);
		if (_node[ni]) {
			return _node[ni].searchLose(color);
		}
		if (0 == _level) {
			uint cd = uint.max; // Distance of two colors.
			size_t index = 0;
			foreach (i, c; _sorted) {
				// Calculates Manhattan distance.
				uint icd = abs(c.r - color.r) + abs(c.g - color.g) + abs(c.b - color.b);
				if (icd < cd) {
					index = i;
					cd = icd;
				}
			}
			return index;
		}
		return _index;
	}
}

/// Transforms image data to mirror horizontally or vertically.
void mirrorHorizontal(T)(T delegate(int x, int y) pget, void delegate(int x, int y, T pixel) pset,
		int sx, int sy, int w, int h) {
	enforce(0 <= w);
	enforce(0 <= h);
	if (0 == w || 0 == h) return;
	foreach (x; 0 .. w / 2) {
		foreach (y; 0 .. h) {
			pset(sx + w - x - 1, sy + y, pget(sx + x, sy + y));
		}
	}
}
/// ditto
void mirrorVertical(T)(T delegate(int x, int y) pget, void delegate(int x, int y, T pixel) pset,
		int sx, int sy, int w, int h) {
	enforce(0 <= w);
	enforce(0 <= h);
	if (0 == w || 0 == h) return;
	foreach (x; 0 .. w) {
		foreach (y; 0 .. h / 2) {
			pset(sx + x, sy + h - y - 1, pget(sx + x, sy + y));
		}
	}
}

/// ditto
void flipHorizontal(T)(T delegate(int x, int y) pget, void delegate(int x, int y, T pixel) pset,
		int sx, int sy, int w, int h) {
	enforce(0 <= w);
	enforce(0 <= h);
	if (0 == w || 0 == h) return;
	foreach (x; 0 .. w / 2) {
		foreach (y; 0 .. h) {
			int x1 = sx + x, y1 = sy + y;
			int x2 = sx + w - x - 1, y2 = y1;
			auto temp = pget(x1, y1);
			pset(x1, y1, pget(x2, y2));
			pset(x2, y2, temp);
		}
	}
}
/// ditto
void flipVertical(T)(T delegate(int x, int y) pget, void delegate(int x, int y, T pixel) pset,
		int sx, int sy, int w, int h) {
	enforce(0 <= w);
	enforce(0 <= h);
	if (0 == w || 0 == h) return;
	foreach (x; 0 .. w) {
		foreach (y; 0 .. h / 2) {
			int x1 = sx + x, y1 = sy + y;
			int x2 = x1, y2 = sy + h - y - 1;
			auto temp = pget(x1, y1);
			pset(x1, y1, pget(x2, y2));
			pset(x2, y2, temp);
		}
	}
}

/// Moves image data in each direction.
/// Rotates a pixel of bounds.
void rotateRight(T)(T delegate(int x, int y) pget, void delegate(int x, int y, T pixel) pset,
		int sx, int sy, int w, int h) {
	enforce(0 <= w);
	enforce(0 <= h);
	if (0 == w || 0 == h) return;
	foreach (y; 0 .. h) {
		auto tmp = pget(sx + w - 1, sy + y);
		foreach_reverse (x; 1 .. w) {
			pset(sx + x, sy + y, pget(sx + x - 1, sy + y));
		}
		pset(sx, sy + y, tmp);
	}
}
/// ditto
void rotateLeft(T)(T delegate(int x, int y) pget, void delegate(int x, int y, T pixel) pset,
		int sx, int sy, int w, int h) {
	enforce(0 <= w);
	enforce(0 <= h);
	if (0 == w || 0 == h) return;
	foreach (y; 0 .. h) {
		auto tmp = pget(sx, sy + y);
		foreach (x; 1 .. w) {
			pset(sx + x - 1, sy + y, pget(sx + x, sy + y));
		}
		pset(sx + w - 1, sy + y, tmp);
	}
}
/// ditto
void rotateUp(T)(T delegate(int x, int y) pget, void delegate(int x, int y, T pixel) pset,
		int sx, int sy, int w, int h) {
	enforce(0 <= w);
	enforce(0 <= h);
	if (0 == w || 0 == h) return;
	foreach (x; 0 .. w) {
		auto tmp = pget(sx + x, sy);
		foreach (y; 1 .. h) {
			pset(sx + x, sy + y - 1, pget(sx + x, sy + y));
		}
		pset(sx + x, sy + h - 1, tmp);
	}
}
/// ditto
void rotateDown(T)(T delegate(int x, int y) pget, void delegate(int x, int y, T pixel) pset,
		int sx, int sy, int w, int h) {
	enforce(0 <= w);
	enforce(0 <= h);
	if (0 == w || 0 == h) return;
	foreach (x; 0 .. w) {
		auto tmp = pget(sx + x, sy + h - 1);
		foreach_reverse (y; 1 .. h) {
			pset(sx + x, sy + y, pget(sx + x, sy + y - 1));
		}
		pset(sx + x, sy, tmp);
	}
}

/// Resizes image data.
void resize(T)(int rw, int rh, T delegate(int x, int y) pget, void delegate(int x, int y, T pixel) pset,
		int sx, int sy, int w, int h) {
	enforce(0 <= w);
	enforce(0 <= h);
	enforce(0 <= rw);
	enforce(0 <= rh);
	if (w == rw && h == rh) return;
	if (0 == rw || 0 == w || 0 == rh || 0 == h) {
		return;
	}
	real gw = cast(real) rw / w;
	real gh = cast(real) rh / h;
	real gwr = cast(real) w / rw;
	real ghr = cast(real) h / rh;
	void yProc(int xBase, int xNew) {
		if (rh < h) {
			foreach (y; 0 .. h) {
				int yBase = sy + y;
				int yNew = sy + cast(int) (y * gh);
				pset(xNew, yNew, pget(xBase, yBase));
			}
		} else if (h < rh) {
			foreach_reverse (y; 0 .. rh) {
				int yBase = sy + cast(int) (y * ghr);
				int yNew = sy + y;
				pset(xNew, yNew, pget(xBase, yBase));
			}
		} else {
			foreach (y; 0 .. h) {
				int yBase = sy + y;
				pset(xNew, yBase, pget(xBase, yBase));
			}
		}
	}
	if (rw < w) {
		foreach (x; 0 .. w) {
			yProc(sx + x, sx + cast(int) (x * gw));
		}
	} else if (w < rw) {
		foreach_reverse (x; 0 .. rw) {
			yProc(sx + cast(int) (x * gwr), sx + x);
		}
	} else {
		foreach (x; 0 .. w) {
			yProc(sx + x, sx + x);
		}
	}
}

/// Turns image data.
void turn(T)(real deg, T delegate(int x, int y) pget, void delegate(int x, int y, T pixel) pset,
		int sx, int sy, int w, int h, T backgroundPixel) {
	enforce(0 <= w);
	enforce(0 <= h);
	if (isNaN(deg) || isInfinity(deg) || 0 == w || 0 == h) return;
	auto rad = radian(deg);
	if (0 == deg) return;
	int dcos = cast(int) (rad.cos() * (1 << 10)); 
	int dsin = cast(int) (rad.sin() * (1 << 10)); 
	auto base = new T[w * h];
	foreach (x; 0 .. w) {
		foreach (y; 0 .. h) {
			base[y * w + x] = pget(sx + x, sy + y);
			pset(sx + x, sy + y, backgroundPixel);
		}
	}
	int cx = w / 2;
	int cy = h / 2;
	foreach (x; 0 .. w) {
		foreach (y; 0 .. h) {
			int xmcx = x - cx;
			int ymcy = y - cy;
			int ax = ((xmcx * dcos - ymcy * dsin) >> 10) + cx;
			int ay = ((xmcx * dsin + ymcy * dcos) >> 10) + cy;
			int xx = sx + ax;
			int yy = sy + ay;
			if (sx <= xx && ax < w && sy <= yy && ay < h) {
				pset(xx, yy, base[y * w + x]);
			}
		}
	}
}
