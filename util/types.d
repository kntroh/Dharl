
/// This module includes common types and structures.
module util.types;

private import util.utils : safeParse;

private import std.algorithm;
private import std.conv;
private import std.exception;
private import std.math;
private import std.string;
private import std.xml;

/// Value of RGB color model.
struct CRGB {
	ubyte r; /// Red.
	ubyte g; /// Green.
	ubyte b; /// Blue.

	/// Converts to value of HSV color model.
	CHSV toHSV() {
		CHSV hsv;
		real rr = r / 255.0;
		real rg = g / 255.0;
		real rb = b / 255.0;
		real mx = max(rr, rg, rb);
		real mn = min(rr, rg, rb);
		real h;
		if (mx == rr) {
			h = 60 * ((rg - rb) / (mx - mn)) + 0;
		} else if (mx == rg) {
			h = 60 * ((rb - rr) / (mx - mn)) + 120;
		} else {
			assert (mx == rb);
			h = 60 * ((rr - rg) / (mx - mn)) + 240;
		}
		if (h < 0) h += 360;
		hsv.h = cast(ushort) h;
		hsv.s = (mx - mn) / mx;
		hsv.v = mx;
		return hsv;
	}

	/// Creates instance from ep.
	static CRGB fromElement(ElementParser ep) {
		CRGB r;
		auto p = "r" in ep.tag.attr;
		if (p) r.r = safeParse!ubyte(*p, r.r);
		p = "g" in ep.tag.attr;
		if (p) r.g = safeParse!ubyte(*p, r.g);
		p = "b" in ep.tag.attr;
		if (p) r.b = safeParse!ubyte(*p, r.b);
		return r;
	}
	/// Creates XML element from this instance.
	const
	Element toElement(string tagName) {
		auto e = new Element(tagName);
		e.tag.attr["r"] = text(r);
		e.tag.attr["g"] = text(g);
		e.tag.attr["b"] = text(b);
		return e;
	}

	/// Returns a string representing of RGB color.
	const
	string toString() {
		return std.string.format("CRGB {%d, %d, %d}", r, g, b);
	}

	/// Returns true if this equals o.
	const
	bool opEquals(ref const(CRGB) o) {
		return r == o.r && g == o.g && b == o.b;
	}

	/// This compare to o.
	const
	int opCmp(ref const(CRGB) o) {
		foreach (i; 0 .. ubyte.sizeof) {
			auto s = 0x80 >> i;
			if ((r & s) < (o.r & s)) return -1;
			if ((r & s) > (o.r & s)) return 1;
			if ((g & s) < (o.g & s)) return -1;
			if ((g & s) > (o.g & s)) return 1;
			if ((b & s) < (o.b & s)) return -1;
			if ((b & s) > (o.b & s)) return 1;
		}
		return 0;
	}

	/// Gets hash code of this.
	const
	hash_t toHash() {
		hash_t hash = r;
		hash += hash * 31 + g;
		hash += hash * 31 + b;
		return hash;
	}
}
/// Value of HSV color model.
struct CHSV {
	ushort h; /// Hue.
	real s; /// Saturation.
	real v; /// Value.

	/// Converts to value of RGB color model.
	CRGB toRGB() {
		if (s == 0) {
			return CRGB(255, 255, 255);
		}
		int hi = cast(int) floor(h / 60.0);
		real f = h / 60.0 - hi;
		real p = v * (1 - s);
		real q = v * (1 - f * s);
		real t = v * (1 - (1 - f) * s);
		ubyte v255 = cast(ubyte) (v * 255);
		ubyte t255 = cast(ubyte) (t * 255);
		ubyte p255 = cast(ubyte) (p * 255);
		ubyte q255 = cast(ubyte) (q * 255);
		switch (hi) {
		case 0: return CRGB(v255, t255, p255);
		case 1: return CRGB(q255, v255, p255);
		case 2: return CRGB(p255, v255, t255);
		case 3: return CRGB(p255, q255, v255);
		case 4: return CRGB(t255, p255, v255);
		case 5: return CRGB(v255, p255, q255);
		default: throw new Exception("Invalid HSV color");
		}
	}

	/// Creates instance from ep.
	static CHSV fromElement(ElementParser ep) {
		CHSV r;
		auto p = "h" in ep.tag.attr;
		if (p) r.h = safeParse!ushort(*p, r.h);
		p = "s" in ep.tag.attr;
		if (p) r.s = safeParse!real(*p, r.s);
		p = "v" in ep.tag.attr;
		if (p) r.v = safeParse!real(*p, r.v);
		return r;
	}
	/// Creates XML element from this instance.
	const
	Element toElement(string tagName) {
		auto e = new Element(tagName);
		e.tag.attr["h"] = text(h);
		e.tag.attr["s"] = text(s);
		e.tag.attr["v"] = text(v);
		return e;
	}

	/// Returns a string representing of HSV color.
	const
	string toString() {
		return std.string.format("CHSV {%d, %0.2f, %0.2f}", h, s, v);
	}

	/// Returns true if this equals o.
	const
	bool opEquals(ref const(CHSV) o) {
		return h == o.h && s == o.s && v == o.v;
	}

	/// This compare to o.
	const
	int opCmp(ref const(CHSV) o) {
		if (h < o.h) return -1;
		if (h > o.h) return 1;
		if (s < o.s) return -1;
		if (s > o.s) return 1;
		if (v < o.v) return -1;
		if (v > o.v) return 1;
		return 0;
	}

	/// Gets hash code of this.
	const
	hash_t toHash() {
		hash_t hash = h;
		hash += hash * 31 + s;
		hash += hash * 31 + v;
		return hash;
	}
}
unittest {
	assert (CRGB(128, 64, 0).toHSV().toRGB() == CRGB(128, 64, 0));
	assert (CRGB(255, 255, 255).toHSV().toRGB() == CRGB(255, 255, 255));
	assert (CRGB(0, 0, 0).toHSV().toRGB() == CRGB(0, 0, 0));
}

/// Bounds.
struct PBounds {
	/// Coordinate of bounds.
	int x;
	/// ditto
	int y;
	/// ditto
	uint width;
	/// ditto
	uint height;

	/// This contains coordinates of x, y?
	const
	bool contains(int x, int y) {
		return this.x <= x && x < this.x + width && this.y <= y && y < this.y + height;
	}

	/// Creates instance from ep.
	static PBounds fromElement(ElementParser ep) {
		PBounds r;
		auto p = "x" in ep.tag.attr;
		if (p) r.x = safeParse!int(*p, r.x);
		p = "y" in ep.tag.attr;
		if (p) r.y = safeParse!int(*p, r.y);
		p = "width" in ep.tag.attr;
		if (p) r.width = safeParse!int(*p, r.width);
		p = "height" in ep.tag.attr;
		if (p) r.height = safeParse!int(*p, r.height);
		return r;
	}
	/// Creates XML element from this instance.
	const
	Element toElement(string tagName) {
		auto e = new Element(tagName);
		e.tag.attr["x"] = text(x);
		e.tag.attr["y"] = text(y);
		e.tag.attr["width"] = text(width);
		e.tag.attr["height"] = text(height);
		return e;
	}
}

/// Coordinate.
struct PPoint {
	/// Value of coordinate.
	int x;
	/// ditto
	int y;

	/// Creates instance from ep.
	static PPoint fromElement(ElementParser ep) {
		PPoint r;
		auto p = "x" in ep.tag.attr;
		if (p) r.x = safeParse!int(*p, r.x);
		p = "y" in ep.tag.attr;
		if (p) r.y = safeParse!int(*p, r.y);
		return r;
	}
	/// Creates XML element from this instance.
	const
	Element toElement(string tagName) {
		auto e = new Element(tagName);
		e.tag.attr["x"] = text(x);
		e.tag.attr["y"] = text(y);
		return e;
	}
}

/// Size.
struct PSize {
	/// Value of size.
	uint width;
	/// ditto
	uint height;

	/// Creates instance from ep.
	static PSize fromElement(ElementParser ep) {
		PSize r;
		auto p = "width" in ep.tag.attr;
		if (p) r.width = safeParse!int(*p, r.width);
		p = "height" in ep.tag.attr;
		if (p) r.height = safeParse!int(*p, r.height);
		return r;
	}
	/// Creates XML element from this instance.
	const
	Element toElement(string tagName) {
		auto e = new Element(tagName);
		e.tag.attr["width"] = text(width);
		e.tag.attr["height"] = text(height);
		return e;
	}
}

/// Weights of split area.
struct Weights {
	uint l; /// Weight of left area.
	uint r; /// Weight of right area.

	/// Creates instance from ep.
	static Weights fromElement(ElementParser ep) {
		Weights w;
		auto p = "l" in ep.tag.attr;
		if (p) w.l = safeParse!uint(*p, w.l);
		p = "r" in ep.tag.attr;
		if (p) w.r = safeParse!uint(*p, w.r);
		return w;
	}
	/// Creates string from this instance.
	const
	Element toElement(string tagName) {
		auto e = new Element(tagName);
		e.tag.attr["l"] = text(l);
		e.tag.attr["r"] = text(r);
		return e;
	}
}

/// Tone.
struct Tone {
	string name;
	/// Data of tone.
	bool[][] value;

	/// Creates instance from ep.
	static Tone fromElement(ElementParser ep) {
		Tone r;
		r.name = ep.tag.attr.get("name", "(No name)");
		ep.onText = (string s) {
			auto lines = s.split(" ");
			foreach (line; lines) {
				bool[] lv;
				foreach (j, c; line) {
					lv ~= '1' == c;
				}
				r.value ~= lv;
			}
		};
		ep.parse();
		return r;
	}
	/// Creates string from this instance.
	const
	Element toElement(string tagName) {
		char[] buf;
		foreach (i, line; value) {
			foreach (c; line) {
				buf ~= c ? '1' : '0';
			}
			if (i + 1 < value.length) {
				buf ~= ' ';
			}
		}
		auto e = new Element(tagName, assumeUnique(buf));
		e.tag.attr["name"] = name;
		return e;
	}
}
