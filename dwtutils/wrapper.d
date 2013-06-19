
/// This module includes D-style wrapper for DWT widgets and events.
///
/// License: Public Domain
/// Authors: kntroh
module dwtutils.wrapper;

private import std.algorithm;
private import std.array;
private import std.ascii;
private import std.exception;
private import std.string;
private import std.traits;

private import org.eclipse.swt.all;

private import java.lang.all : Runnable;

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

/**
Wraps a getter and a setter.

This templates add prefix 'p_' to a property name,
in order to avoid conflicts with existing member.

Example:
---
auto shell = new Shell;
shell.p_text = "The Application";
shell.p_layout = new FillLayout;

auto label = new Label(shell, SWT.NONE);
label.p_text = "a label";

shell.p_bounds = new Rectangle(50, 50, 100, 100);
shell.p_visible = true;
---
*/
mixin GetSetWrapper!("Accelerator"); /// ditto
mixin GetSetWrapper!("Active"); /// ditto
mixin GetSetWrapper!("Alpha"); /// ditto
mixin GetSetWrapper!("Antialias"); /// ditto
mixin GetSetWrapper!("AutoHide"); /// ditto
mixin GetSetWrapper!("AvailableTypeNames"); /// ditto
mixin GetSetWrapper!("AvailableTypes"); /// ditto
mixin GetSetWrapper!("Background"); /// ditto
mixin GetSetWrapper!("BorderWidth"); /// ditto
mixin GetSetWrapper!("Bounds"); /// ditto
mixin GetSetWrapper!("Checked"); /// ditto
mixin GetSetWrapper!("Children"); /// ditto
mixin GetSetWrapper!("ClientArea"); /// ditto
mixin GetSetWrapper!("ColumnCount"); /// ditto
mixin GetSetWrapper!("ColumnOrder"); /// ditto
mixin GetSetWrapper!("Columns"); /// ditto
mixin GetSetWrapper!("Control"); /// ditto
mixin GetSetWrapper!("Cursor"); /// ditto
mixin GetSetWrapper!("CursorControl"); /// ditto
mixin GetSetWrapper!("CursorLocation"); /// ditto
mixin GetSetWrapper!("Data"); /// ditto
mixin GetSetWrapper!("DefaultButton"); /// ditto
mixin GetSetWrapper!("Display"); /// ditto
mixin GetSetWrapper!("Disposed"); /// ditto
mixin GetSetWrapper!("DoubleClickTime"); /// ditto
mixin GetSetWrapper!("DPI"); /// ditto
mixin GetSetWrapper!("Empty"); /// ditto
mixin GetSetWrapper!("Enabled"); /// ditto
mixin GetSetWrapper!("FileName"); /// ditto
mixin GetSetWrapper!("FileNames"); /// ditto
mixin GetSetWrapper!("FilterExtensions"); /// ditto
mixin GetSetWrapper!("FilterIndex"); /// ditto
mixin GetSetWrapper!("FilterNames"); /// ditto
mixin GetSetWrapper!("FilterPath"); /// ditto
mixin GetSetWrapper!("FocusControl"); /// ditto
mixin GetSetWrapper!("Font"); /// ditto
mixin GetSetWrapper!("FontData"); /// ditto
mixin GetSetWrapper!("FontMetrics"); /// ditto
mixin GetSetWrapper!("Foreground"); /// ditto
mixin GetSetWrapper!("Grayed"); /// ditto
mixin GetSetWrapper!("HeaderVisible"); /// ditto
mixin GetSetWrapper!("Height"); /// ditto
mixin GetSetWrapper!("HorizontalBar"); /// ditto
mixin GetSetWrapper!("Image"); /// ditto
mixin GetSetWrapper!("ImageData"); /// ditto
mixin GetSetWrapper!("ImageIndent"); /// ditto
mixin GetSetWrapper!("Increment"); /// ditto
mixin GetSetWrapper!("ItemCount"); /// ditto
mixin GetSetWrapper!("Items"); /// ditto
mixin GetSetWrapper!("Layout"); /// ditto
mixin GetSetWrapper!("LayoutData"); /// ditto
mixin GetSetWrapper!("LineAttributes"); /// ditto
mixin GetSetWrapper!("LineDash"); /// ditto
mixin GetSetWrapper!("LineStyle"); /// ditto
mixin GetSetWrapper!("LineWidth"); /// ditto
mixin GetSetWrapper!("Location"); /// ditto
mixin GetSetWrapper!("Maximized"); /// ditto
mixin GetSetWrapper!("Maximum"); /// ditto
mixin GetSetWrapper!("Menu"); /// ditto
mixin GetSetWrapper!("MenuBar"); /// ditto
mixin GetSetWrapper!("Message", systemReturnCodeToN, nToSystemReturnCode); /// ditto
mixin GetSetWrapper!("Minimized"); /// ditto
mixin GetSetWrapper!("Minimum"); /// ditto
mixin GetSetWrapper!("Name"); /// ditto
mixin GetSetWrapper!("Selection"); /// ditto
mixin GetSetWrapper!("SelectionIndex"); /// ditto
mixin GetSetWrapper!("SelectionIndices"); /// ditto
mixin GetSetWrapper!("Shell"); /// ditto
mixin GetSetWrapper!("Size"); /// ditto
mixin GetSetWrapper!("Style"); /// ditto
mixin GetSetWrapper!("SupportedTypes"); /// ditto
mixin GetSetWrapper!("Text", systemReturnCodeToN, nToSystemReturnCode);
mixin GetSetWrapper!("TextAntialias"); /// ditto
mixin GetSetWrapper!("TextLimit"); /// ditto
mixin GetSetWrapper!("Thumb"); /// ditto
mixin GetSetWrapper!("ToolTipText", systemReturnCodeToN, nToSystemReturnCode); /// ditto
mixin GetSetWrapper!("Transfer"); /// ditto
mixin GetSetWrapper!("TypeIds"); /// ditto
mixin GetSetWrapper!("TypeNames"); /// ditto
mixin GetSetWrapper!("Overwrite"); /// ditto
mixin GetSetWrapper!("PageIncrement"); /// ditto
mixin GetSetWrapper!("Parent"); /// ditto
mixin GetSetWrapper!("Redraw"); /// ditto
mixin GetSetWrapper!("RGB"); /// ditto
mixin GetSetWrapper!("VerticalBar"); /// ditto
mixin GetSetWrapper!("Visible"); /// ditto
mixin GetSetWrapper!("VisibleItemCount"); /// ditto
mixin GetSetWrapper!("Weights"); /// ditto
mixin GetSetWrapper!("Width"); /// ditto

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
Wraps Widget#addListener() and Display.addFilter().

Example:
---
auto shell = new Shell;
shell.p_listeners!(SWT.Active) ~= {
	writeln("shell activated!");
};
auto info = shell.p_listeners!(SWT.Dispose) ~= (Event e) {
	writeln("shell disposed.");
};
info.remove(); // remove the dispose listener.
---
*/
@property
auto p_listeners(int Type, W)(W widget) {
	return new ListenerWrapper!(Type, W, false)(widget);
}
/// ditto
@property
auto p_filters(int Type)(Display display) {
	return new ListenerWrapper!(Type, Display, true)(display);
}


/* ---- utilities ------------------------------------------------- */

/// Casts return value of widget#getData().
@property
D dataTo(D)(Widget widget) {
	return cast(D)widget.data;
}

/// Calls display.syncExec() or display.asyncExec() with dlg.
void syncExecWith(T...)(Display display, void delegate(T args) dlg, T args) {
	display.syncExec(new class Runnable {
		override void run() {
			dlg(args);
		}
	});
}
/// ditto
void asyncExecWith(T...)(Display display, void delegate(T args) dlg, T args) {
	display.asyncExec(new class Runnable {
		override void run() {
			dlg(args);
		}
	});
}

/// A information of added listeners.
/// BUG: If struct use, when call remove(),
///      occur Privileged Instruction exception.
class ListenerInfo(W, L) {
	W widget; // A widget which registered a listener.
	L listener; // A registered listener.

	private void delegate() _remove;

	/// The only constructor.
	this (W widget, L listener, void delegate() remove) {
		this.widget = widget;
		this.listener = listener;
		this._remove = remove;
	}

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
			static immutable MethodWrapper = `@property auto ` ~ lccName(Method["get".length .. $]) ~ `()() {
				return bean.` ~ Method ~ `();
			}`;
		} else static if (Method.startsWith("is")) {
			// Avoids conflict of get*** and is***.
			static if (-1 == Methods.countUntil("get" ~ Method["is".length .. $])) {
				static immutable MethodWrapper = `@property auto ` ~ lccName(Method["is".length .. $]) ~ `()() {
					return bean.` ~ Method ~ `();
				}`;
			} else {
				static immutable MethodWrapper = ``;
			}
		} else static if (Method.startsWith("set")) {
			static immutable MethodWrapper = `@property void ` ~ lccName(Method["set".length .. $]) ~ `(Type)(Type value) {
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

/// Creates a lower camel case string.
@property
pure
private string lccName(string name) {
	if (!name.length) return name;
	if (name[0].isLower()) return name;
	size_t lowerRange = name.length;
	foreach (i, char c; name) {
		if (!c.isUpper()) {
			lowerRange = i;
			break;
		}
	}
	if (name.length == lowerRange) {
		// All chars is uppercase.
		return name.toLower();
	}
	if (1 < lowerRange) {
		// A camel case string is followed by a uppercase string.
		lowerRange--;
	}
	return name[0 .. lowerRange].toLower() ~ name[lowerRange .. $];
} unittest {
	assert (lccName("AbcDefg") == "abcDefg", lccName("AbcDefg"));
	assert (lccName("ABCDefg") == "abcDefg", lccName("ABCDefg"));
	assert (lccName("Abcdefg") == "abcdefg", lccName("Abcdefg"));
	assert (lccName("ABCD")    == "abcd",    lccName("ABCD"));
	assert (lccName("ABCDe")   == "abcDe",   lccName("ABCDe"));
}

/// Creates a property name, and add prefix 'p_'.
private template PName(string Name) {
	immutable PName = "p_" ~ lccName(Name);
}

/// Creates wrap property for a getter and a setter.
template GetSetWrapper(string Name, alias getterFunc = Object, alias setterFunc = Object) {
	private import std.string;
	private import std.traits;
	private static immutable LName = PName!(Name);
	mixin(`
	@property void ` ~ LName ~ `(W, Type)(W widget, Type value) {
		` ~ (is(setterFunc==Object) ? `` : `static if (is(typeof(setterFunc(value)))) {
			value = setterFunc(value);
		}`) ~ `
		widget.set` ~ Name ~ `(value);
	}`);
	mixin(`
	@property auto ` ~ LName ~ `(W)(W widget) {
		` ~ (is(getterFunc==Object) ? `` : `static if (is(typeof(getterFunc(value)))) {
			value = getterFunc(value);
		}`) ~ `
		static if (is(typeof(widget.get` ~ Name ~ `()))) {
			return widget.get` ~ Name ~ `();
		} else static if (is(typeof(widget.is` ~ Name ~ `()))) {
			return widget.is` ~ Name ~ `();
		} else static assert (0, W.stringof ~ "." ~ LName ~ " <- " ~ Name);
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
		return new AddRemove!(W, Name, ParameterTypeTuple!(widget.add` ~ Name ~ `)[0])(widget);
	}`);
}
/// BUG: If struct use, when call remove(),
///      occur Privileged Instruction exception.
private class AddRemove(T, string Name, Type) {
	T t;
	auto opOpAssign(string s)(Type value) if (s == "~") {
		mixin(`t.add` ~ Name ~ `(value);`);
		return new ListenerInfo!(T, Type)(t, value, {
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
		return new TypedListenerWrapperImpl!(W, ListenerType, MethodName)(widget);
	}`);
}
/// BUG: If struct use, when call remove(),
///      occur Privileged Instruction exception.
private class TypedListenerWrapperImpl(W, ListenerType, string MethodName) {
	private import std.traits;
	private import std.typecons;
	alias ParameterTypeTuple!(mixin(ListenerType.stringof ~ "." ~ MethodName))[0] EventType;

	W widget;
	this (W widget) { this.widget = widget; }
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
		return new ListenerInfo!(W, ListenerType)(widget, l, {
			mixin(`widget.remove` ~ ListenerType.stringof ~ `(l);`);
		});
	}
}

/// Creates wrapper for org.eclipse.swt.widget.Listener#handleEvent().
/// BUG: If struct use, when call remove(),
///      occur Privileged Instruction exception.
private class ListenerWrapper(int Type, W, bool Filter) {
	W widget;
	this (W widget) { this.widget = widget; }
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
		static if (Filter) {
			widget.addFilter(Type, l);
			return new ListenerInfo!(W, Listener)(widget, l, {
				widget.removeFilter(Type, l);
			});
		} else {
			widget.addListener(Type, l);
			return new ListenerInfo!(W, Listener)(widget, l, {
				widget.removeListener(Type, l);
			});
		}
	}
}
