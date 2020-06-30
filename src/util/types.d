
/// This module includes common types and structures.
///
/// License: Public Domain
/// Authors: kntroh
module util.types;

private import util.utils : safeParse;

private import std.algorithm;
private import std.conv;
private import std.exception;
private import std.math;
private import std.string;

private import dxml.parser;
private import dxml.util;
private import dxml.writer;

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
		hsv.h = cast(ushort)h;
		hsv.s = (mx - mn) / mx;
		hsv.v = mx;
		return hsv;
	}

	/// Creates instance from range.
	static CRGB fromElement(EntityRange)(ref EntityRange range) {
		CRGB r;
		foreach (attr; range.front.attributes.save) {
			switch (attr.name) {
			case "r":
				r.r = safeParse!ubyte(attr.value.decodeXML(), r.r);
				break;
			case "g":
				r.g = safeParse!ubyte(attr.value.decodeXML(), r.g);
				break;
			case "b":
				r.b = safeParse!ubyte(attr.value.decodeXML(), r.b);
				break;
			default:
				break;
			}
		}
		return r;
	}
	/// Creates XML element from this instance.
	const
	void toElement(XMLWriter)(ref XMLWriter writer, string tagName) {
		writer.openStartTag(tagName);
		writer.writeAttr("r", .text(r));
		writer.writeAttr("g", .text(g));
		writer.writeAttr("b", .text(b));
		writer.closeStartTag(EmptyTag.yes);
	}

	/// Returns a string representing of RGB color.
	const
	string toString() {
		return std.string.format("CRGB {%d, %d, %d}", r, g, b);
	}

	/// Returns true if this equals o.
	const
	bool opEquals(const(CRGB) o) {
		return r == o.r && g == o.g && b == o.b;
	}

	/// This compare to o.
	const
	int opCmp(const(CRGB) o) {
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
	nothrow
	@safe
	hash_t toHash() {
		hash_t hash = r;
		hash += hash * 31 + g;
		hash += hash * 31 + b;
		return hash;
	}
}
unittest {
	import std.array;

	auto xml = `<rgb r="101" g="102" b="103"/>`;
	auto range = .parseXML(xml);
	auto s = CRGB.fromElement(range);
	assert (s.r == 101, .text(s));
	assert (s.g == 102, .text(s));
	assert (s.b == 103, .text(s));

	auto writer = .xmlWriter(appender!string());
	s.toElement(writer, "rgb");

	xml = writer.output.data;
	assert (xml == "\n" ~ `<rgb r="101" g="102" b="103"/>`, xml);
	range = .parseXML(xml);
	assert (s == CRGB.fromElement(range));
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
		int hi = cast(int)floor(h / 60.0);
		real f = h / 60.0 - hi;
		real p = v * (1 - s);
		real q = v * (1 - f * s);
		real t = v * (1 - (1 - f) * s);
		ubyte v255 = cast(ubyte)(v * 255);
		ubyte t255 = cast(ubyte)(t * 255);
		ubyte p255 = cast(ubyte)(p * 255);
		ubyte q255 = cast(ubyte)(q * 255);
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

	/// Creates instance from range.
	static CHSV fromElement(EntityRange)(ref EntityRange range) {
		CHSV r;
		foreach (attr; range.front.attributes.save) {
			switch (attr.name) {
			case "h":
				r.h = safeParse!ushort(attr.value.decodeXML(), r.h);
				break;
			case "s":
				r.s = safeParse!real(attr.value.decodeXML(), r.s);
				break;
			case "v":
				r.v = safeParse!real(attr.value.decodeXML(), r.v);
				break;
			default:
				break;
			}
		}
		return r;
	}
	/// Creates XML element from this instance.
	const
	void toElement(XMLWriter)(ref XMLWriter writer, string tagName) {
		writer.openStartTag(tagName);
		writer.writeAttr("h", .text(h));
		writer.writeAttr("s", .text(s));
		writer.writeAttr("v", .text(v));
		writer.closeStartTag(EmptyTag.yes);
	}

	/// Returns a string representing of HSV color.
	const
	string toString() {
		return std.string.format("CHSV {%d, %0.2f, %0.2f}", h, s, v);
	}

	/// Returns true if this equals o.
	const
	bool opEquals(const(CHSV) o) {
		return h == o.h && s == o.s && v == o.v;
	}

	/// This compare to o.
	const
	int opCmp(const(CHSV) o) {
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
	nothrow
	@safe
	hash_t toHash() {
		hash_t hash = h;
		hash += hash * 31 + cast(hash_t)s;
		hash += hash * 31 + cast(hash_t)v;
		return hash;
	}
}
unittest {
	import std.array;

	assert (CRGB(128, 64, 0).toHSV().toRGB() == CRGB(128, 64, 0));
	assert (CRGB(255, 255, 255).toHSV().toRGB() == CRGB(255, 255, 255));
	assert (CRGB(0, 0, 0).toHSV().toRGB() == CRGB(0, 0, 0));

	auto xml = `<hsv h="101" s="102" v="103"/>`;
	auto range = .parseXML(xml);
	auto s = CHSV.fromElement(range);
	assert (s.h == 101, .text(s));
	assert (s.s == 102, .text(s));
	assert (s.v == 103, .text(s));

	auto writer = .xmlWriter(appender!string());
	s.toElement(writer, "hsv");

	xml = writer.output.data;
	assert (xml == "\n" ~ `<hsv h="101" s="102" v="103"/>`, xml);
	range = .parseXML(xml);
	assert (s == CHSV.fromElement(range));
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

	/// Creates instance from range.
	static PBounds fromElement(EntityRange)(ref EntityRange range) {
		PBounds r;
		foreach (attr; range.front.attributes.save) {
			switch (attr.name) {
			case "x":
				r.x = safeParse!int(attr.value.decodeXML(), r.x);
				break;
			case "y":
				r.y = safeParse!int(attr.value.decodeXML(), r.y);
				break;
			case "width":
				r.width = safeParse!int(attr.value.decodeXML(), r.width);
				break;
			case "height":
				r.height = safeParse!int(attr.value.decodeXML(), r.height);
				break;
			default:
				break;
			}
		}
		return r;
	}
	/// Creates XML element from this instance.
	const
	void toElement(XMLWriter)(ref XMLWriter writer, string tagName) {
		writer.openStartTag(tagName);
		writer.writeAttr("x", .text(x));
		writer.writeAttr("y", .text(y));
		writer.writeAttr("width", .text(width));
		writer.writeAttr("height", .text(height));
		writer.closeStartTag(EmptyTag.yes);
	}
}
unittest {
	import std.array;

	auto xml = `<bounds x="101" y="102" width="103" height="104"/>`;
	auto range = .parseXML(xml);
	auto s = PBounds.fromElement(range);
	assert (s.x == 101, .text(s));
	assert (s.y == 102, .text(s));
	assert (s.width == 103, .text(s));
	assert (s.height == 104, .text(s));

	auto writer = .xmlWriter(appender!string());
	s.toElement(writer, "bounds");

	xml = writer.output.data;
	assert (xml == "\n" ~ `<bounds x="101" y="102" width="103" height="104"/>`, xml);
	range = .parseXML(xml);
	assert (s == PBounds.fromElement(range));
}

/// Parameters of window.
struct WindowParameter {
	/// Bounds.
	PBounds bounds;
	alias bounds this;

	/// Maximized and minimized.
	bool maximized = false;
	/// ditto
	bool minimized = false;

	/// Creates instance.
	static WindowParameter opCall(in PBounds bounds, bool maximized = false, bool minimized = false) {
		WindowParameter wp;
		wp.bounds = bounds;
		wp.maximized = maximized;
		wp.minimized = minimized;
		return wp;
	}
	/// ditto
	static WindowParameter opCall(int x = int.min, int y = int.min, uint w = 0, uint h = 0, bool maximized = false, bool minimized = false) {
		return WindowParameter(PBounds(x, y, w, h), maximized, minimized);
	}

	/// Creates instance from range.
	static WindowParameter fromElement(EntityRange)(ref EntityRange range) {
		auto r = WindowParameter(PBounds.fromElement(range));
		foreach (attr; range.front.attributes.save) {
			switch (attr.name) {
			case "maximized":
				r.maximized = safeParse!bool(attr.value.decodeXML(), r.maximized);
				break;
			case "minimized":
				r.minimized = safeParse!bool(attr.value.decodeXML(), r.minimized);
				break;
			default:
				break;
			}
		}
		return r;
	}
	/// Creates XML element from this instance.
	const
	void toElement(XMLWriter)(ref XMLWriter writer, string tagName) {
		writer.openStartTag(tagName);
		writer.writeAttr("x", .text(x));
		writer.writeAttr("y", .text(y));
		writer.writeAttr("width", .text(width));
		writer.writeAttr("height", .text(height));
		if (maximized) writer.writeAttr("maximized", .text(maximized));
		if (minimized) writer.writeAttr("minimized", .text(minimized));
		writer.closeStartTag(EmptyTag.yes);
	}
}
unittest {
	import std.array;

	auto xml = `<windowParameter x="101" y="102" width="103" height="104" maximized="true" minimized="true"/>`;
	auto range = .parseXML(xml);
	auto s = WindowParameter.fromElement(range);
	assert (s.x == 101, .text(s));
	assert (s.y == 102, .text(s));
	assert (s.width == 103, .text(s));
	assert (s.height == 104, .text(s));

	auto writer = .xmlWriter(appender!string());
	s.toElement(writer, "windowParameter");

	xml = writer.output.data;
	assert (xml == "\n" ~ `<windowParameter x="101" y="102" width="103" height="104" maximized="true" minimized="true"/>`, xml);
	range = .parseXML(xml);
	assert (s == WindowParameter.fromElement(range));

	s.maximized = false;
	s.minimized = true;
	auto writer2 = .xmlWriter(appender!string());
	s.toElement(writer2, "windowParameter");

	xml = writer2.output.data;
	assert (xml == "\n" ~ `<windowParameter x="101" y="102" width="103" height="104" minimized="true"/>`, xml);
	range = .parseXML(xml);
	assert (s == WindowParameter.fromElement(range));

	s.maximized = true;
	s.minimized = false;
	auto writer3 = .xmlWriter(appender!string());
	s.toElement(writer3, "windowParameter");

	xml = writer3.output.data;
	assert (xml == "\n" ~ `<windowParameter x="101" y="102" width="103" height="104" maximized="true"/>`, xml);
	range = .parseXML(xml);
	assert (s == WindowParameter.fromElement(range));
}

/// Coordinate.
struct PPoint {
	/// Value of coordinate.
	int x;
	/// ditto
	int y;

	/// Creates instance from range.
	static PPoint fromElement(EntityRange)(ref EntityRange range) {
		PPoint r;
		foreach (attr; range.front.attributes.save) {
			switch (attr.name) {
			case "x":
				r.x = safeParse!int(attr.value.decodeXML(), r.x);
				break;
			case "y":
				r.y = safeParse!int(attr.value.decodeXML(), r.y);
				break;
			default:
				break;
			}
		}
		return r;
	}
	/// Creates XML element from this instance.
	const
	void toElement(XMLWriter)(ref XMLWriter writer, string tagName) {
		writer.openStartTag(tagName);
		writer.writeAttr("x", .text(x));
		writer.writeAttr("y", .text(y));
		writer.closeStartTag(EmptyTag.yes);
	}
}
unittest {
	import std.array;

	auto xml = `<point x="101" y="102"/>`;
	auto range = .parseXML(xml);
	auto s = PPoint.fromElement(range);
	assert (s.x == 101, .text(s));
	assert (s.y == 102, .text(s));

	auto writer = .xmlWriter(appender!string());
	s.toElement(writer, "point");

	xml = writer.output.data;
	assert (xml == "\n" ~ `<point x="101" y="102"/>`, xml);
	range = .parseXML(xml);
	assert (s == PPoint.fromElement(range));
}

/// Size.
struct PSize {
	/// Value of size.
	uint width;
	/// ditto
	uint height;

	/// Creates instance from range.
	static PSize fromElement(EntityRange)(ref EntityRange range) {
		PSize r;
		foreach (attr; range.front.attributes.save) {
			switch (attr.name) {
			case "width":
				r.width = safeParse!int(attr.value.decodeXML(), r.width);
				break;
			case "height":
				r.height = safeParse!int(attr.value.decodeXML(), r.height);
				break;
			default:
				break;
			}
		}
		return r;
	}
	/// Creates XML element from this instance.
	const
	void toElement(XMLWriter)(ref XMLWriter writer, string tagName) {
		writer.openStartTag(tagName);
		writer.writeAttr("width", .text(width));
		writer.writeAttr("height", .text(height));
		writer.closeStartTag(EmptyTag.yes);
	}
}
unittest {
	import std.array;

	auto xml = `<size width="101" height="102"/>`;
	auto range = .parseXML(xml);
	auto s = PSize.fromElement(range);
	assert (s.width == 101, .text(s));
	assert (s.height == 102, .text(s));

	auto writer = .xmlWriter(appender!string());
	s.toElement(writer, "size");

	xml = writer.output.data;
	assert (xml == "\n" ~ `<size width="101" height="102"/>`, xml);
	range = .parseXML(xml);
	assert (s == PSize.fromElement(range));
}

/// Weights of split area.
struct Weights {
	uint l; /// Weight of left area.
	uint r; /// Weight of right area.

	/// Creates instance from range.
	static Weights fromElement(EntityRange)(ref EntityRange range) {
		Weights w;
		foreach (attr; range.front.attributes.save) {
			switch (attr.name) {
			case "l":
				w.l = safeParse!uint(attr.value.decodeXML(), w.l);
				break;
			case "r":
				w.r = safeParse!uint(attr.value.decodeXML(), w.r);
				break;
			default:
				break;
			}
		}
		return w;
	}
	/// Creates string from this instance.
	const
	void toElement(XMLWriter)(ref XMLWriter writer, string tagName) {
		writer.openStartTag(tagName);
		writer.writeAttr("l", .text(l));
		writer.writeAttr("r", .text(r));
		writer.closeStartTag(EmptyTag.yes);
	}
}
unittest {
	import std.array;

	auto xml = `<weights l="101" r="102"/>`;
	auto range = .parseXML(xml);
	auto s = Weights.fromElement(range);
	assert (s.l == 101, .text(s));
	assert (s.r == 102, .text(s));

	auto writer = .xmlWriter(appender!string());
	s.toElement(writer, "weights");

	xml = writer.output.data;
	assert (xml == "\n" ~ `<weights l="101" r="102"/>`, xml);
	range = .parseXML(xml);
	assert (s == Weights.fromElement(range));
}

/// Tone.
struct Tone {
	string name;
	/// Data of tone.
	bool[][] value;

	/// Creates instance from range.
	static Tone fromElement(EntityRange)(ref EntityRange range) {
		Tone r;
		r.name = "(No Name)";
		foreach (attr; range.front.attributes.save) {
			switch (attr.name) {
			case "name":
				r.name = attr.value.decodeXML();
				break;
			default:
				break;
			}
		}
		range.popFront();
		if (range.front.type == EntityType.text) {
			auto lines = range.front.text.decodeXML().split(" ");
			foreach (line; lines) {
				bool[] lv;
				foreach (c; line) {
					lv ~= '1' == c;
				}
				r.value ~= lv;
			}
		}
		return r;
	}
	/// Creates string from this instance.
	const
	void toElement(XMLWriter)(ref XMLWriter writer, string tagName) {
		char[] buf;
		foreach (i, line; value) {
			foreach (c; line) {
				buf ~= c ? '1' : '0';
			}
			if (i + 1 < value.length) {
				buf ~= ' ';
			}
		}
		writer.openStartTag(tagName);
		writer.writeAttr("name", name.encodeAttr());
		writer.closeStartTag(EmptyTag.no);
		writer.writeText(buf.encodeText(), Newline.no, InsertIndent.no);
		writer.writeEndTag(tagName, Newline.no);
	}
}
unittest {
	import std.array;

	auto xml = `<tone name="&quot;Tone&quot;">010 101 110</tone>`;
	auto range = .parseXML(xml);
	auto s = Tone.fromElement(range);
	assert (s.name == `"Tone"`, .text(s));
	assert (s.value == [[false, true, false], [true, false, true], [true, true, false]], .text(s));

	auto writer = .xmlWriter(appender!string());
	s.toElement(writer, "tone");

	xml = writer.output.data;
	assert (xml == "\n" ~ `<tone name="&quot;Tone&quot;">010 101 110</tone>`, xml);
	range = .parseXML(xml);
	assert (s == Tone.fromElement(range));
}
