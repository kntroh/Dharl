
module dwtutils.wrapper;

private import std.algorithm;
private import std.array;
private import std.string;
private import std.traits;

private import org.eclipse.swt.all;

/**
Wraps a getter and a setter.

This templates add suffix '_' to a property name,
in order to avoid conflicts with existing member.

Example:
---
auto shell = new Shell;
shell.widgetText = "The Application";
shell.layoutManager = new FillLayout;

auto label = new Label(shell, SWT.NONE);
label.widgetText = "a label";

shell.bounds = CRect(50, 50, 100, 100);
shell.visible = true;
---
*/
mixin GetSetWrapper!("Text", systemReturnCodeToN, nToSystemReturnCode);
mixin GetSetWrapper!("Data"); /// ditto
mixin GetSetWrapper!("Visible"); /// ditto
mixin GetSetWrapper!("Layout"); /// ditto
mixin GetSetWrapper!("LayoutData"); /// ditto
mixin GetSetWrapper!("Style"); /// ditto
mixin GetSetWrapper!("Control"); /// ditto
mixin GetSetWrapper!("Items"); /// ditto
mixin GetSetWrapper!("Disposed"); /// ditto
mixin GetSetWrapper!("Size"); /// ditto
mixin GetSetWrapper!("Bounds"); /// ditto
mixin GetSetWrapper!("Selection"); /// ditto
mixin GetSetWrapper!("SelectionIndex"); /// ditto
mixin GetSetWrapper!("SelectionIndices"); /// ditto
mixin GetSetWrapper!("Menu"); /// ditto
mixin GetSetWrapper!("MenuBar"); /// ditto
mixin GetSetWrapper!("Parent"); /// ditto
mixin GetSetWrapper!("Image"); /// ditto
mixin GetSetWrapper!("Accelerator"); /// ditto
mixin GetSetWrapper!("ToolTipText", systemReturnCodeToN, nToSystemReturnCode); /// ditto
mixin GetSetWrapper!("Width"); /// ditto
mixin GetSetWrapper!("TextLimit"); /// ditto
mixin GetSetWrapper!("Maximum"); /// ditto
mixin GetSetWrapper!("Minimum"); /// ditto
mixin GetSetWrapper!("PageIncrement"); /// ditto
mixin GetSetWrapper!("Redraw"); /// ditto
mixin GetSetWrapper!("Foreground"); /// ditto
mixin GetSetWrapper!("Background"); /// ditto
mixin GetSetWrapper!("Enabled"); /// ditto
mixin GetSetWrapper!("HorizontalBar"); /// ditto
mixin GetSetWrapper!("VerticalBar"); /// ditto
mixin GetSetWrapper!("ClientArea"); /// ditto
mixin GetSetWrapper!("BorderWidth"); /// ditto
mixin GetSetWrapper!("LineWidth"); /// ditto
mixin GetSetWrapper!("Display"); /// ditto
mixin GetSetWrapper!("Antialias"); /// ditto
mixin GetSetWrapper!("DoubleClickTime"); /// ditto
mixin GetSetWrapper!("Weights"); /// ditto
mixin GetSetWrapper!("LineStyle"); /// ditto
mixin GetSetWrapper!("LineDash"); /// ditto
mixin GetSetWrapper!("FileName"); /// ditto
mixin GetSetWrapper!("FileNames"); /// ditto
mixin GetSetWrapper!("FilterNames"); /// ditto
mixin GetSetWrapper!("FilterPath"); /// ditto
mixin GetSetWrapper!("FilterExtensions"); /// ditto
mixin GetSetWrapper!("FilterIndex"); /// ditto
mixin GetSetWrapper!("Overwrite"); /// ditto
mixin GetSetWrapper!("Thumb"); /// ditto
mixin GetSetWrapper!("Empty"); /// ditto
mixin GetSetWrapper!("FontMetrics"); /// ditto
mixin GetSetWrapper!("Height"); /// ditto
mixin GetSetWrapper!("Cursor"); /// ditto
mixin GetSetWrapper!("FocusControl"); /// ditto
mixin GetSetWrapper!("ItemCount"); /// ditto
mixin GetSetWrapper!("Shell"); /// ditto
mixin GetSetWrapper!("Transfer"); /// ditto

/**
Creates small wrapper for methods of widget.

Example:
---
auto shell = new Shell;
shell.p.text = "The Application";
shell.p.bounds = Rect(100, 100, 200, 200);
---
*/
@property
BeanWrapper!W p(W)(W widget) { return BeanWrapper!W(widget); }

/**
Wraps add*Listener methods.

Example:
---
auto shell = new Shell;
shell.shellClosed ~= (ShellEvent e) {
	writeln("don't close.");
	e.doit = false;
};
auto info = shell.shellActivated ~= {
	writeln("shell activated!");
};
info.remove(); // remove the dispose listener.
---
*/
// org.eclipse.swt.event
mixin CreateTypedListenerWrapper!(ArmListener);
mixin CreateTypedListenerWrapper!(ControlListener); /// ditto
mixin CreateTypedListenerWrapper!(DisposeListener); /// ditto
mixin CreateTypedListenerWrapper!(DragDetectListener); /// ditto
mixin CreateTypedListenerWrapper!(FocusListener); /// ditto
mixin CreateTypedListenerWrapper!(HelpListener); /// ditto
mixin CreateTypedListenerWrapper!(KeyListener); /// ditto
mixin CreateTypedListenerWrapper!(MenuListener); /// ditto
mixin CreateTypedListenerWrapper!(MenuDetectListener); /// ditto
mixin CreateTypedListenerWrapper!(MouseListener); /// ditto
mixin CreateTypedListenerWrapper!(MouseMoveListener); /// ditto
mixin CreateTypedListenerWrapper!(MouseTrackListener); /// ditto
mixin CreateTypedListenerWrapper!(MouseWheelListener); /// ditto
mixin CreateTypedListenerWrapper!(ModifyListener); /// ditto
mixin CreateTypedListenerWrapper!(PaintListener); /// ditto
mixin CreateTypedListenerWrapper!(SelectionListener); /// ditto
mixin CreateTypedListenerWrapper!(ShellListener); /// ditto
mixin CreateTypedListenerWrapper!(TraverseListener); /// ditto
mixin CreateTypedListenerWrapper!(TreeListener); /// ditto
mixin CreateTypedListenerWrapper!(VerifyListener); /// ditto
// org.eclipse.swt.custom
mixin CreateTypedListenerWrapper!(BidiSegmentListener); /// ditto
mixin CreateTypedListenerWrapper!(CTabFolder2Listener); /// ditto
mixin CreateTypedListenerWrapper!(CTabFolderListener); /// ditto
mixin CreateTypedListenerWrapper!(ExtendedModifyListener); /// ditto
mixin CreateTypedListenerWrapper!(LineBackgroundListener); /// ditto
mixin CreateTypedListenerWrapper!(LineStyleListener); /// ditto
mixin CreateTypedListenerWrapper!(MovementListener); /// ditto
mixin CreateTypedListenerWrapper!(PaintObjectListener); /// ditto
mixin CreateTypedListenerWrapper!(StyledTextContent); /// ditto
mixin CreateTypedListenerWrapper!(TextChangeListener); /// ditto
mixin CreateTypedListenerWrapper!(VerifyKeyListener); /// ditto

/**
Wraps Widget#addListener().

Example:
---
auto shell = new Shell;
shell.listeners!(SWT.Active) ~= {
	writeln("shell activated!");
};
auto info = shell.listeners!(SWT.Dispose) ~= (Event e) {
	writeln("shell disposed.");
};
info.remove(); // remove the dispose listener.
---
*/
@property
auto listeners(int Type, W)(W widget) {
	return ListenerWrapper!(Type, W)(widget);
}


/* ---- utilities ------------------------------------------------- */

/// Casts return value of widget#getData().
@property
D dataTo(D : Object)(Widget widget) {
	return cast(D) widget.data;
}

/// Converts from std.string.newline to "\n".
string systemReturnCodeToN(string text) {
	static if (.newline == "\n") {
		return text;
	} else {
		return text.replace(.newline, "\n");
	}
}
/// Converts from "\n" to std.string.newline.
string nToSystemReturnCode(string text) {
	static if (.newline == "\n") {
		return text;
	} else {
		return text.replace("\n", .newline);
	}
}

/// A information of added listeners.
struct ListenerInfo(W, L) {
	W widget; // A widget which registered a listener.
	L listener; // A registered listener.

	private void delegate() _remove;

	/// Removes listener.
	void remove() {
		_remove();
	}
}

/* ---- templates for wrappers ------------------------------------ */

/// A small wrapper for methods of JavaBeans.
/// See_Also: p
struct BeanWrapper(B) {
	B bean; /// A wrapped bean.

	private static immutable Methods = beansMember(__traits(allMembers, B));
	mixin(Wrapper!0);

	private static template Wrapper(int Index) {
		static if (Index + 1 < Methods.length) {
			static immutable Wrapper = MethodWrapper!(Methods[Index]) ~ Wrapper!(Index + 1);
		} else static if (Index < Methods.length) {
			static immutable Wrapper = MethodWrapper!(Methods[Index]);
		} else {
			static immutable Wrapper = "";
		}
	}
	private static template MethodWrapper(string Method) {
		static if (Method.startsWith("get")) {
			static immutable MethodWrapper = `@property auto ` ~ LName!(Method["get".length .. $]) ~ `()() {
				return bean.` ~ Method ~ `();
			}`;
		} else static if (Method.startsWith("is")) {
			// Avoids conflict of get*** and is***.
			static if (-1 == Methods.countUntil("get" ~ Method["is".length .. $])) {
				static immutable MethodWrapper = `@property auto ` ~ LName!(Method["is".length .. $]) ~ `()() {
					return bean.` ~ Method ~ `();
				}`;
			} else {
				static immutable MethodWrapper = ``;
			}
		} else static if (Method.startsWith("set")) {
			static immutable MethodWrapper = `@property void ` ~ LName!(Method["set".length .. $]) ~ `(Type)(Type value) {
				bean.` ~ Method ~ `(value);
			}`;
		} else {
			static immutable MethodWrapper = ``;
		}
	}
} unittest {
	class BeanParent1 {
		bool getStatus1() { return true; }
	}
	class BeanParent2 : BeanParent1 {
		bool getStatus2() { return true; }
	}
	class Bean : BeanParent2 {
		string s = null;
		string getString() { return s; }
		void setString(string s) { this.s = s; }
		bool isNullValue() { return s is null; }
		bool getNullValue() { return s is null; }
	}
	auto b = new Bean;
	assert (b.p.status1);
	assert (b.p.status2);
	assert (b.p.nullValue);
	b.p.string = "test";
	assert (b.p.string == "test");
	assert (!b.p.nullValue);
}

/// Narrows to bean member from members.
string[] beansMember(in string[] members...) {
	string[] result;
	foreach (member; members) {
		if (member.startsWith("get") && "get".length < member.length) {
			result ~= member;
		}
		if (member.startsWith("is") && "is".length < member.length) {
			result ~= member;
		}
		if (member.startsWith("set") && "set".length < member.length) {
			result ~= member;
		}
	}
	return result;
}

/// Creates a property name.
private template LName(string Name) {
	immutable LName = Name[0 .. 1].toLower() ~ Name[1 .. $];
}

/// Creates a property name, and add prefix 'p_'.
private template PName(string Name) {
	immutable PName = "p_" ~ LName!Name;
}

private void dummy() {}

/// Creates wrap property for a getter and a setter.
template GetSetWrapper(string Name, alias getterFunc = dummy, alias setterFunc = dummy) {
	private import std.string;
	private import std.traits;
	private static immutable LName = PName!(Name);
	mixin(`@property void ` ~ LName ~ `(W, Type)(W widget, Type value) {
		static if (is(typeof(setterFunc(value)))) {
			value = setterFunc(value);
		}
		widget.set` ~ Name ~ `(value);
	}`);
	mixin(`@property auto ` ~ LName ~ `(W)(W widget) {
		static if (is(typeof(getterFunc(value)))) {
			value = getterFunc(value);
		}
		static if (is(typeof(widget.get` ~ Name ~ `()))) {
			return widget.get` ~ Name ~ `();
		} else static if (is(typeof(widget.is` ~ Name ~ `()))) {
			return widget.is` ~ Name ~ `();
		} else static assert (0);
	}`);
} unittest {
	class BeanParent1 {
		bool getData() { return true; }
	}
	class BeanParent2 : BeanParent1 {
		bool getLineWidth() { return true; }
	}
	class Bean : BeanParent2 {
		string s = null;
		string getText() { return s; }
		void setText(string s) { this.s = s; }
	}
	auto b = new Bean;
	assert (b.p_data);
	assert (b.p_lineWidth);
	b.p_text = "test";
	assert (b.p_text == "test");
}

/// Creates wrap property for a add method and a remove method.
template AddRemoveWrapper(string Name) {
	private import std.string;
	private static immutable LName = PName!(Name);
	mixin(`@property auto ` ~ LName ~ `(W)(W widget) {
		import std.traits;
		return AddRemove!(W, Name, ParameterTypeTuple!(widget.add` ~ Name ~ `)[0])(widget);
	}`);
}
private struct AddRemove(T, string Name, Type) {
	T t;
	auto opOpAssign(string s)(Type value) if (s == "~") {
		mixin(`t.add` ~ Name ~ `(value);`);
		return ListenerInfo!(T, Type)(t, value, {
			mixin(`t.remove` ~ Name ~ `(value);`);
		});
	}
	void remove(Type value) {
		mixin(`t.remove` ~ Name ~ `(value);`);
	}
}

/// Creates wrapper for methods of ListenerType.
template CreateTypedListenerWrapper(ListenerType) {
	mixin CreateTypedListenerWrapperImpl!(ListenerType, 0);
}
private template CreateTypedListenerWrapperImpl(ListenerType, int Index) {
	private static immutable string[] Methods = [__traits(derivedMembers, ListenerType)];
	static if (Index < Methods.length) {
		mixin TypedListenerWrapper!(ListenerType, Methods[Index]);
		static if (Index + 1 < Methods.length) {
			// recurse
			mixin CreateTypedListenerWrapperImpl!(ListenerType, Index + 1);
		}
	}
}

/// Creates wrapper for ListenerType#MethodName().
template TypedListenerWrapper(ListenerType, string MethodName) {
	@property
	mixin(`auto ` ~ MethodName ~ `(W)(W widget) {
		return TypedListenerWrapperImpl!(W, ListenerType, MethodName)(widget);
	}`);
}
private struct TypedListenerWrapperImpl(W, ListenerType, string MethodName) {
	private import std.traits;
	private import std.typecons;
	alias ParameterTypeTuple!(mixin(ListenerType.stringof ~ "." ~ MethodName))[0] EventType;

	W widget;
	auto opOpAssign(string s)(void delegate() dlg) if (s == "~") {
		return opOpAssign!s((EventType e) {dlg();});
	}
	auto opOpAssign(string s)(void delegate(EventType e) dlg) if (s == "~") {
		return opOpAssign!s(new class BlackHole!ListenerType {
			mixin(`override void ` ~ MethodName ~ `(EventType e) {
				dlg(e);
			}`);
		});
	}
	auto opOpAssign(string s)(ListenerType l) if (s == "~") {
		mixin(`widget.add` ~ ListenerType.stringof ~ `(l);`);
		return ListenerInfo!(W, ListenerType)(widget, l, {
			mixin(`widget.remove` ~ ListenerType.stringof ~ `(l);`);
		});
	}
}

/// Creates wrapper for org.eclipse.swt.widget.Listener#handleEvent().
private struct ListenerWrapper(int Type, W) {
	W widget;
	auto opOpAssign(string s)(void delegate() dlg) if (s == "~") {
		return opOpAssign!s((Event e) {dlg();});
	}
	auto opOpAssign(string s)(void delegate(Event e) dlg) if (s == "~") {
		return opOpAssign!s(new class Listener {
			override void handleEvent(Event e) {
				dlg(e);
			}
		});
	}
	auto opOpAssign(string s)(Listener l) if (s == "~") {
		widget.addListener(Type, l);
		return ListenerInfo!(W, Listener)(widget, l, {
			widget.removeListener(Type, l);
		});
	}
}
