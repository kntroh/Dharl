
/// This module includes property related functions and templates.
module util.properties;

private import util.types;
private import util.utils : parseS;

private import std.conv;
private import std.exception;
private import std.file;
private import std.string;
private import std.xml;

/// Creates simple properties data by mixin.
/// Example:
/// ---
/// Window bounds.
/// struct WindowBounds {
///    /// Values of bounds.
///    mixin Prop!("x", int, 0);
///    mixin Prop!("y", int, 0); /// ditto
///    mixin Prop!("width", int, 100); /// ditto
///    mixin Prop!("height", int, 100); /// ditto
/// 
///    mixin PropIO!("windowBounds");
/// }
/// ---
mixin template Prop(string Name, Type, Type DefaultValue = Type.init, bool ReadOnly = false) {
	/// A property.
	mixin("PropValue!(Name, Type, DefaultValue, ReadOnly) " ~ Name ~ ";");
}
/// ditto
mixin template MsgProp(string Name, string Value) {
	/// A property.
	mixin Prop!(Name, string, Value);
}
/// ditto
mixin template PropIO(string RootName) {
	/// Reads all properties from file.
	void readXMLFile(string file) {
		char[] s = cast(char[]) std.file.read(file);
		readXML(std.exception.assumeUnique(s));
	}
	/// Reads all properties from xml.
	void readXML(string xml) {
		auto parser = new std.xml.DocumentParser(xml);
		parser.onStartTag[RootName] = (std.xml.ElementParser ep) {
			readElement(ep);
		};
		parser.parse();
	}
	/// Reads all properties from ep.
	void readElement(std.xml.ElementParser ep) {
		foreach (fld; this.tupleof) {
			ep.onStartTag[fld.NAME] = (std.xml.ElementParser ep) {
				fld = .fromElement!(typeof(fld.value))(ep);
			};
		}
		ep.parse();
	}
	/// Creates new instance from ep.
	static typeof(this) fromElement(std.xml.ElementParser ep) {
		typeof(this) r;
		static if (is(typeof(r is null))) {
			r = new typeof(this);
		}
		r.readElement(ep);
		return r;
	}

	/// Writes all properties to file.
	const
	void writeXMLFile(string file) {
		std.file.write(file, writeXML());
	}
	/// Creates XML string include all properties data.
	const
	string writeXML() {
		auto doc = toElement(RootName);
		return std.string.join(doc.pretty(1), "\n");
	}
	/// Creates XML element include all properties data.
	const
	std.xml.Element toElement(string tagName) {
		auto r = new std.xml.Element(tagName);
		foreach (fld; this.tupleof) {
			if (fld.READ_ONLY && fld.INIT == fld.value) {
				// If fld is read only or fld value isn't changed,
				// no creates element.
				continue;
			}
			r ~= .toElement(fld.NAME, fld.value);
		}
		return r;
	}
}
/// ditto
struct PropValue(string Name, Type, Type DefaultValue, bool ReadOnly) {
	/// Property name.
	static const NAME = Name;
	/// Is property read only?
	static const READ_ONLY = ReadOnly;
	/// Initializing value of property.
	static const INIT = DefaultValue;

	/// Value of property.
	Type value = DefaultValue;
	/// ditto
	alias value this;
}

/// Creates T from ep.
/// T.fromElement(ep) or T.fromString(string) or to!T(string) is required.
T fromElement(T)(ElementParser ep) {
	static if (is(typeof(T.fromElement(ep)))) {
		return T.fromElement(ep);
	} else static if (is(typeof(T.fromString("")))) {
		T t = T.init;
		ep.onText = (string text) {
			t = T.fromString(text);
		};
		ep.parse();
		return t;
	} else static if (is(typeof(to!T("")))) {
		T t = T.init;
		ep.onText = (string text) {
			t = to!T(text);
		};
		ep.parse();
		return t;
	} else static assert (0);
}

/// Creates XML element from value.
/// value.toElement(tagName) or to!string(value) is required.
Element toElement(T)(string tagName, in T value) {
	static if (is(typeof(value.toElement(tagName)))) {
		return value.toElement(tagName);
	} else static if (is(typeof(to!string(value)))) {
		return new Element(tagName, to!string(value));
	} else static assert (0);
}

/// Array property.
struct PArray(string ValueName, ValueType) {
	/// Array.
	ValueType[] array;
	/// ditto
	alias array this;

	/// Creates instance from ep.
	static PArray fromElement(ElementParser ep) {
		PArray r;
		ep.onStartTag[ValueName] = (ElementParser ep) {
			r.array ~= .fromElement!ValueType(ep);
		};
		ep.parse();
		return r;
	}
	/// Creates XML element from this instance.
	const
	Element toElement(string tagName) {
		auto e = new Element(tagName);
		foreach (value; array) {
			e ~= .toElement!ValueType(ValueName, value);
		}
		return e;
	}
}
