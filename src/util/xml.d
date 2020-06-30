
/// This module includes structures and functions for easy handling for the dxml.
///
/// License: Public Domain
/// Authors: kntroh
module util.xml;

private import dxml.parser;
private import dxml.util;

/// A structure for recursive processing in readXML.
struct XMLReader {
	/// Called when the element opened.
	void delegate(const(char)[] name) startElement = null;
	/// Processes attributes of the element.
	void delegate(const(char)[] name, const(char)[] value) attribute = null;
	/// Processes text in the element.
	void delegate(const(char)[] text) text = null;
	/// Processes CDATA in the element.
	void delegate(const(char)[] cdata) cdata = null;
	/// Processes PI in the element.
	void delegate(const(char)[] pi) pi = null;
	/// Processes subelements in the elements.
	XMLReader[string] children = null;
	/// Called when the element closed.
	void delegate() endElement = null;
}

/// Recursive processes for XML elements.
/// Decoding of text is done automatically.
void readElement(EntityRange)(ref EntityRange range, ref const(XMLReader) reader) {
	while (!range.empty() && range.front.type != EntityType.elementStart && range.front.type != EntityType.elementEmpty) {
		range.popFront();
	}
	if (range.empty()) return;

	if (reader.startElement) {
		reader.startElement(range.front.name);
	}
	scope (success) {
		if (reader.endElement) {
			reader.endElement();
		}
	}
	if (reader.attribute) {
		foreach (attr; range.front.attributes) {
			reader.attribute(attr.name, attr.value.decodeXML());
		}
	}
	if (range.front.type == EntityType.elementStart) {
		// Process all a child elements and data.
		while (!range.empty()) {
			range.popFront();
			final switch (range.front.type) {
			case EntityType.elementStart:
			case EntityType.elementEmpty:
				auto p = range.front.name in reader.children;
				if (!p) {
					p = null in reader.children;
				}
				if (p) {
					.readElement(range, *p);
				} else if (range.front.type == EntityType.elementStart) {
					range.popFront();
					if (range.front.type != EntityType.elementEnd) {
						range = range.skipToParentEndTag();
					}
					assert (range.front.type == EntityType.elementEnd);
				} else {
					assert (range.front.type == EntityType.elementEmpty);
				}
				break;
			case EntityType.text:
				if (reader.text) {
					reader.text(range.front.text.decodeXML());
				}
				break;
			case EntityType.cdata:
				if (reader.cdata) {
					reader.cdata(range.front.text);
				}
				break;
			case EntityType.pi:
				if (reader.pi) {
					reader.pi(range.front.name);
				}
				break;
			case EntityType.comment:
				break;
			case EntityType.elementEnd:
				return;
			}
		}
	}
}
///
unittest {
	import std.ascii;
	import std.conv;
	import std.string;

	auto xml = join([
		`<root attr="42">`,
		`  <element1 attr1="42" attr2="true"/>`,
		`  <!-- comment -->`,
		`  &quot;text1&quot;`,
		`  <![CDATA[cdata value 1]]>`,
		`  <?processing_instruction_1?>`,
		`  <element2 attr="&amp;">`,
		`    <child1 attr="cattr1">`,
		`      <tail name="tail">`,
		`        <skip1>`,
		`        </skip1>`,
		`        <skip2/>`,
		`        <skip3>text</skip3>`,
		`      </tail>`,
		`    </child1>`,
		`    &quot;text3&quot;`,
		`    <child2 attr="cattr2"/>`,
		`    <![CDATA[cdata value 3]]>`,
		`    <child3 attr="cattr3"/>`,
		`    <?processing_instruction_3?>`,
		`  </element2>`,
		`  <![CDATA[cdata value 2]]>`,
		`  <?processing_instruction_2?>`,
		`  <element3/>`,
		`  &quot;text2&quot;`,
		`</root>`,
	], newline);

	struct E {
		const(char)[] name;
		const(char)[][const(char)[]] attrs;
		const(char)[][] text;
		const(char)[][] cdata;
		const(char)[][] pi;
		E[] children;
	}
	E root;
	E e1;
	E e2;
	E e3;
	auto end = false;
	auto reader = XMLReader(
		(name) { root.name = name; },
		(name, value) { root.attrs[name] = value; },
		(text) { root.text ~= strip(text); },
		(cdata) { root.cdata ~= cdata; },
		(pi) { root.pi ~= pi; },
		[
			"element1": XMLReader(
				(name) { e1 = E(name); },
				(name, value) { e1.attrs[name] = value; },
				(text) { assert (false, text); },
				(cdata) { assert (false, cdata); },
				(pi) { assert (false, pi); },
				null,
				{ root.children ~= e1; }
			),
			"element2": XMLReader(
				(name) { e1 = E(name); },
				(name, value) { e1.attrs[name] = value; },
				(text) { e1.text ~= strip(text); },
				(cdata) { e1.cdata ~= cdata; },
				(pi) { e1.pi ~= pi; },
				[
					null: XMLReader(
						(name) { e2 = E(name); },
						(name, value) { e2.attrs[name] = value; },
						(text) { assert (false, text); },
						(cdata) { assert (false, cdata); },
						(pi) { assert (false, pi); },
						[
							null: XMLReader(
								(name) { e3 = E(name); },
								(name, value) { e3.attrs[name] = value; },
								(text) { assert (false, text); },
								(cdata) { assert (false, cdata); },
								(pi) { assert (false, pi); },
								null,
								{ e2.children ~= e3; }
							),
						],
						{ e1.children ~= e2; }
					),
				],
				{ root.children ~= e1; }
			),
			null: XMLReader(
				(name) { e1 = E(name); },
				(name, value) { assert (false, name ~ ": " ~ value); },
				(text) { assert (false, text); },
				(cdata) { assert (false, cdata); },
				(pi) { assert (false, pi); },
				null,
				{ root.children ~= e1; }
			),
		],
		{ end = true; }
	);

	auto range = .parseXML(xml);
	.readElement(range, reader);

	assert (end);
	assert (root == E("root", ["attr": "42"], ["\"text1\"", "\"text2\""], ["cdata value 1", "cdata value 2"], ["processing_instruction_1", "processing_instruction_2"], [
		E("element1", ["attr1": "42", "attr2": "true"]),
		E("element2", ["attr": "&"], ["\"text3\""], ["cdata value 3"], ["processing_instruction_3"], [
			E("child1", ["attr": "cattr1"], [ ], [ ], [ ], [
				E("tail", ["name": "tail"]),
			]),
			E("child2", ["attr": "cattr2"]),
			E("child3", ["attr": "cattr3"]),
		]),
		E("element3"),
	]), text(root));
}
