
/// This module includes property related functions and templates.
///
/// License: Public Domain
/// Authors: kntroh
module util.properties;

private import util.types;

private import std.conv;
private import std.exception;
private import std.string;

/// Creates simple properties data by mixin.
mixin template Prop(string Name, Type, Type DefaultValue, bool ReadOnly = false, string ElementName = "") {
	/// A property.
	mixin("auto " ~ Name ~ " = PropValue!(Type, ReadOnly)(Name, DefaultValue, ElementName);");
}
///
unittest {
	import std.string;

	/// Window bounds.
	struct WindowBounds {
		/// Window name.
		mixin Prop!("name", string, "name");
		mixin Prop!("name2", string, "name2"); /// ditto
		mixin Prop!("name3", string, "name3"); /// ditto
		/// Values of bounds.
		mixin Prop!("x", int, 0);
		mixin Prop!("y", int, 0); /// ditto
		mixin Prop!("width", int, 100); /// ditto
		mixin Prop!("height", int, 100); /// ditto

		/// Windows status.
		mixin Prop!("statuses", PArray!("status", string), PArray!("status", string)([]));
		mixin Prop!("statuses2", PArray!("status", string), PArray!("status", string)([""])); /// ditto

		mixin PropIO!("windowBounds");
	}
	WindowBounds wb;
	wb.readXML(`<windowBounds><name2>Name&amp;Bounds</name2><name/><x>1</x><y>2</y><width>3</width><height>4</height><statuses><status>maximized</status><status/><status>fullscreen</status></statuses><statuses2/></windowBounds>`);
	assert (wb.name == "", .text(wb));
	assert (wb.name2 == "Name&Bounds", .text(wb));
	assert (wb.name3 == "name3", .text(wb));
	assert (wb.x == 1, .text(wb));
	assert (wb.y == 2, .text(wb));
	assert (wb.width == 3, .text(wb));
	assert (wb.height == 4, .text(wb));
	assert (wb.statuses == ["maximized", "", "fullscreen"], .text(wb));
	assert (wb.statuses2 == [], .text(wb));

	auto xml = wb.writeXML();
	assert (xml == join([
		`<?xml version="1.0" encoding="UTF-8"?>`,
		`<windowBounds>`,
		` <name/>`,
		` <name2>Name&amp;Bounds</name2>`,
		` <x>1</x>`,
		` <y>2</y>`,
		` <width>3</width>`,
		` <height>4</height>`,
		` <statuses>`,
		`  <status>maximized</status>`,
		`  <status/>`,
		`  <status>fullscreen</status>`,
		` </statuses>`,
		` <statuses2/>`,
		`</windowBounds>`,
	], "\n"), xml);

	WindowBounds wb2;
	wb2.readXML(xml);
	assert (wb == wb2);
}
/// ditto
mixin template Prop(string Name, Type, string ElementName = "") {
	/// A property.
	mixin Prop!(Name, Type, Type.init, false, ElementName);
}
/// ditto
mixin template MsgProp(string Name, string Value, string ElementName = "") {
	/// A property.
	mixin Prop!(Name, string, Value, true, ElementName);
}
/// ditto
mixin template PropIO(string RootName) {
	/// Reads all properties from file.
	void readXMLFile(string file) {
		import std.file;
		import util.utils;
		char[] s = cast(char[])readText(file);
		s = normalizeLineEndings(s);
		readXML(std.exception.assumeUnique(s));
	}
	/// Reads all properties from xml.
	void readXML(string xml) {
		import dxml.parser;
		auto range = parseXML!(makeConfig(SkipComments.yes))(xml);
		if (RootName != range.front.name) return;
		range.popFront();
		readElement(range);
	}
	private void putDelegate(T, EntityRange)(ref T fld, ref void delegate(ref EntityRange range)[string] put) {
		put[fld.ELEMENT_NAME] = (ref EntityRange range) {
			fld = .fromElementFunc!(typeof(fld.value))(range);
		};
	}
	/// Reads all properties from range.
	void readElement(EntityRange)(ref EntityRange range) {
		import dxml.parser;
		void delegate(ref EntityRange range)[string] put;
		foreach (ref fld; this.tupleof) {
			// is(typeof(...)) will silently ignore it when a compile error occurs,
			// so have to use __traits to generate a call for putDelegate.
			static if (is(typeof(.fromElementFunc!(typeof(fld.value))(range))) || __traits(hasMember, typeof(fld), "fromElement")) {
				putDelegate(fld, put);
			}
		}
		while (!range.empty()) {
			if (range.front.type == EntityType.elementStart || range.front.type == EntityType.elementEmpty) {
				if (auto p = range.front.name in put) {
					if (range.front.type == EntityType.elementStart) {
						range.popFront();
						auto range2 = range.save();
						(*p)(range);
						if (range2.front.type == EntityType.elementEnd) {
							range = range2;
						} else {
							range = range2.skipToParentEndTag();
						}
					} else {
						assert (range.front.type == EntityType.elementEmpty);
						auto range2 = range.save();
						(*p)(range);
						range = range2;
					}
				}
			}
			range.popFront();
		}
	}
	/// Creates new instance from range.
	static typeof(this) fromElement(EntityRange)(ref EntityRange range) {
		typeof(this) r;
		static if (is(typeof(r is null))) {
			r = new typeof(this);
		}
		r.readElement(range);
		return r;
	}

	/// Writes all properties to file.
	const
	void writeXMLFile(string file) {
		import std.file;
		write(file, writeXML());
	}
	/// Creates XML string include all properties data.
	const
	string writeXML() {
		import std.array;
		import dxml.writer;
		auto app = appender!string();
		writeXMLDecl!string(app);
		auto writer = xmlWriter(app, " ");
		toElement(writer, RootName);
		return writer.output.data;
	}
	/// Creates XML element include all properties data.
	const
	void toElement(XMLWriter)(ref XMLWriter writer, string tagName) {
		import dxml.writer;
		writer.writeStartTag(tagName);
		foreach (fld; this.tupleof) {
			// is(typeof(...)) will silently ignore it when a compile error occurs,
			// so have to use __traits to generate a call for toElementFunc.
			static if (is(typeof(.toElementFunc(writer, fld.ELEMENT_NAME, fld.value))) || __traits(hasMember, typeof(fld), "toElement")) {
				if (fld.READ_ONLY || fld.INIT == fld.value) {
					// If fld is read only or fld value isn't changed,
					// no creates element.
					continue;
				} else {
					.toElementFunc(writer, fld.ELEMENT_NAME, fld.value);
				}
			}
		}
		writer.writeEndTag(tagName);
	}
}
/// ditto
struct PropValue(Type, bool ReadOnly) {
	/// Is property read only?
	static immutable READ_ONLY = ReadOnly;
	/// Property name.
	string NAME;
	/// XML element name.
	string ELEMENT_NAME;
	/// Initializing value of property.
	Type INIT;

	/// Value of property.
	Type value;
	/// ditto
	alias value this;

	/// Creates instance.
	this (string name, Type defaultValue, string elementName = "") {
		NAME = name;
		INIT = defaultValue;
		value = defaultValue;
		if (elementName == "") {
			ELEMENT_NAME = name;
		} else {
			ELEMENT_NAME = elementName;
		}
	}

	void opAssign(Type rhs) {
		value = rhs;
	}

	static if (is(typeof(.text(Type.init)))) {
		const
		string toString() { return .text(value); }
	}
}

/// Creates T from range.
/// T.fromElement(range) or T.fromString(string) or to!T(string) is required.
T fromElementFunc(T, EntityRange)(ref EntityRange range) {
	import dxml.parser;
	import dxml.util;

	// is(typeof(...)) will silently ignore it when a compile error occurs,
	// so have to use __traits to generate a call for fromElement.
	static if (is(typeof(T.fromElement(range))) || __traits(hasMember, T, "fromElement")) {
		return T.fromElement(range);
	} else static if (is(typeof(T.fromString("")))) {
		T t = T.init;
		if (range.front.type == EntityType.text) {
			t = T.fromString(decodeXML(range.front.text));
		} else if (range.front.type == EntityType.elementEmpty) {
			t = T.fromString("");
		}
		return t;
	} else static if (is(typeof(to!T("")))) {
		T t = T.init;
		if (range.front.type == EntityType.text) {
			t = to!T(decodeXML(range.front.text));
		} else if (range.front.type == EntityType.elementEmpty) {
			t = to!T("");
		}
		return t;
	} else static assert (0, T.stringof);
}

/// Creates XML element from value.
/// value.toElement(writer, tagName) or text(value) is required.
void toElementFunc(T, XMLWriter)(ref XMLWriter writer, string tagName, in T value) {
	import std.conv;
	import dxml.util;
	import dxml.writer;

	// is(typeof(...)) will silently ignore it when a compile error occurs,
	// so have to use __traits to generate a call for toElement.
	static if (is(typeof(value.toElement(writer, tagName))) || __traits(hasMember, T, "toElement")) {
		value.toElement(writer, tagName);
	} else static if (is(typeof(text(value)))) {
		auto valueText = text(value);
		if (valueText == "") {
			writer.writeStartTag(tagName, EmptyTag.yes);
		} else {
			writer.writeStartTag(tagName);
			writer.writeText(encodeText(valueText), Newline.no);
			writer.writeEndTag(tagName, Newline.no);
		}
	} else static assert (0, T.stringof);
}

/// Array property.
struct PArray(string ValueName, ValueType) {
	/// Array.
	ValueType[] array;
	/// ditto
	alias array this;

	/// Creates instance from range.
	static PArray fromElement(EntityRange)(ref EntityRange range) {
		import dxml.parser;

		PArray r;
		if (range.front.type == EntityType.elementEmpty) {
			return r;
		}
		while (!range.empty()) {
			if (range.front.type == EntityType.elementStart && range.front.name == ValueName) {
				range.popFront();
				auto range2 = range.save();
				r.array ~= .fromElementFunc!ValueType(range);
				range = range2;
				if (range.front.type != EntityType.elementEnd) {
					range = range.skipToParentEndTag();
				}
				range.popFront();
			} else if (range.front.type == EntityType.elementEmpty && range.front.name == ValueName) {
				r.array ~= .fromElementFunc!ValueType(range);
				range.popFront();
			} else if (range.front.type == EntityType.elementStart) {
				range.popFront();
				if (range.front.type != EntityType.elementEnd) {
					range = range.skipToParentEndTag();
				}
				range.popFront();
			} else {
				range.popFront();
			}
			if (range.front.type == EntityType.elementEnd) {
				range.popFront();
				break;
			}
		}
		return r;
	}
	/// Creates XML element from this instance.
	const
	void toElement(XMLWriter)(ref XMLWriter writer, string tagName) {
		import dxml.writer;

		if (array.length) {
			writer.writeStartTag(tagName, EmptyTag.no);
			foreach (value; array) {
				.toElementFunc!ValueType(writer, ValueName, value);
			}
			writer.writeEndTag(tagName);
		} else {
			writer.writeStartTag(tagName, EmptyTag.yes);
		}
	}
}
