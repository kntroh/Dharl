
/// This module includes utilities for DWT.
module dwtutils.utils;

public import dwtutils.factory;
public import dwtutils.wrapper;

private import std.exception;
private import std.math;
private import std.range;
private import std.string;
private import std.typecons;

private import org.eclipse.swt.all;

/// A floating text box on a Composite.
class Editor {
	/// The parent of text box.
	private Composite _parent = null;
	/// If it is true, "" is same as canceled.
	private bool _emptyIsCancel = true;

	/// The text box.
	private Text _text = null;

	/// The only constructor.
	this (Composite parent, bool emptyIsCancel) {
		enforce(parent);
		enforce(!parent.p_layout);
		_parent = parent;
		_emptyIsCancel = emptyIsCancel;
	}

	/// On editing?
	@property
	const
	bool editing() {
		return _text !is null;
	}
	/// Cancels edit.
	void cancel() {
		if (!_text) return;
		_text.dispose();
		_text = null;
	}

	/// Starts edit.
	void start(int editorX, int editorY, string text, void delegate(string) set) {
		enforce(!_parent.p_layout);
		enforce(text);
		enforce(set);
		if (_text) {
			cancel();
		}
		assert (!_text);
		_text = new Text(_parent, SWT.NONE);
		_text.p_text = text;
		_text.setSelection(0, text.length);
		void submit() {
			if (!_text) return;
			auto t = _text.p_text;
			if (t && (!_emptyIsCancel || t.length)) {
				set(t);
			}
			cancel();
		}
		_text.listeners!(SWT.Modify) ~= &resize;
		_text.listeners!(SWT.FocusOut) ~= &submit;
		_text.listeners!(SWT.KeyDown) ~= (Event e) {
			switch (e.keyCode) {
			case SWT.CR:
				submit();
				break;
			case SWT.ESC:
				cancel();
				break;
			default:
				break;
			}
		};
		auto s = _text.computeSize(SWT.DEFAULT, SWT.DEFAULT);
		_text.p_bounds = CRect(editorX, editorY, s.x, s.y);
		_text.setFocus();
	}

	/// Adjust text box size to match a input text.
	private void resize(Event e) {
		if (!_text) return;
		_text.p_redraw = false;
		scope (exit) _text.p_redraw = true;

		auto s = _text.p_size;
		auto ns = _text.computeSize(SWT.DEFAULT, s.y);
		_text.p_size = ns;

		// Rectifies position gap.
		auto sel = _text.p_selection;
		_text.p_selection = 0;
		_text.showSelection();
		_text.p_selection = sel;
	}
}

/// MenuItem and ToolItem.
struct MTItem {
	MenuItem menuItem; /// MenuItem.
	ToolItem toolItem; /// ToolItem.

	/// Calls setSelection() of menuItem and toolItem.
	void setSelection(bool v) {
		menuItem.setSelection(v);
		toolItem.setSelection(v);
	}
	/// Calls getSelection() of menuItem.
	bool getSelection() {
		return menuItem.getSelection();
	}
	/// Calls setEnabled() of menuItem and toolItem.
	void setEnabled(bool v) {
		menuItem.setEnabled(v);
		toolItem.setEnabled(v);
	}
	/// Calls getEnabled() of menuItem.
	bool getEnabled() {
		return menuItem.getEnabled();
	}
}

/// Binds menu and tool.
void bindMenu(MenuItem menu, ToolItem tool) {
	menu.listeners!(SWT.Selection) ~= {
		tool.p_selection = menu.p_selection;
	};
	tool.listeners!(SWT.Selection) ~= {
		menu.p_selection = tool.p_selection;
	};
}

/// Gets a accelerator key from text.
int acceleratorKey(string text) {
	int i = text.indexOf("\t");
	if (-1 != i && i + 1 < text.length) {
		text = text[i + 1 .. $];
	}
	string key1;
	int key2 = 0;
	i = text.indexOf("+");
	if (-1 != i && i + 1 < text.length) {
		key1 = text[0 .. i];
		key2 = std.ascii.toUpper(text[i + 1]);
	} else {
		key1 = text;
	}
	switch (key1.toUpper()) {
	case "CTRL"        : return key2 + SWT.CTRL;
	case "ALT"         : return key2 + SWT.ALT;
	case "SHIFT"       : return key2 + SWT.SHIFT;
	case "COMMAND"     : return key2 + SWT.COMMAND;
	case "BACKSPACE"   : return key2 + SWT.BS;
	case "TAB"         : return key2 + SWT.TAB;
	case "RETURN"      : return key2 + SWT.CR;
	case "ENTER"       : return key2 + SWT.CR;
	case "ESCAPE"      : return key2 + SWT.ESC;
	case "ESC"         : return key2 + SWT.ESC;
	case "DELETE"      : return key2 + 127;
	case "SPACE"       : return key2 + ' ';
	case "ARROW_UP"    : return key2 + SWT.ARROW_UP;
	case "ARROW_DOWN"  : return key2 + SWT.ARROW_DOWN;
	case "ARROW_LEFT"  : return key2 + SWT.ARROW_LEFT;
	case "ARROW_RIGHT" : return key2 + SWT.ARROW_RIGHT;
	case "PAGE_UP"     : return key2 + SWT.PAGE_UP;
	case "PAGE_DOWN"   : return key2 + SWT.PAGE_DOWN;
	case "HOME"        : return key2 + SWT.HOME;
	case "END"         : return key2 + SWT.END;
	case "INSERT"      : return key2 + SWT.INSERT;
	case "F1"          : return key2 + SWT.F1;
	case "F2"          : return key2 + SWT.F2;
	case "F3"          : return key2 + SWT.F3;
	case "F4"          : return key2 + SWT.F4;
	case "F5"          : return key2 + SWT.F5;
	case "F6"          : return key2 + SWT.F6;
	case "F7"          : return key2 + SWT.F7;
	case "F8"          : return key2 + SWT.F8;
	case "F9"          : return key2 + SWT.F9;
	case "F10"         : return key2 + SWT.F10;
	case "F11"         : return key2 + SWT.F11;
	case "F12"         : return key2 + SWT.F12;
	default: return 0;
	}
} unittest {
	assert (acceleratorKey("&Save\tCtrl+S") == SWT.CTRL + 'S');
}

/// Adds drag functions to control.
void addDropFunctions(Control control,
		int dndStyle,
		Transfer[] transfers,
		void delegate(DropTargetEvent) doDrop) {
	addDropFunctions(control, dndStyle, transfers, doDrop, (DropTargetEvent e) {
		foreach (t; transfers) {
			if (t.isSupportedType(e.currentDataType)) {
				e.detail = dndStyle;
				break;
			}
		}
	});
}
/// ditto
void addDropFunctions(Control control,
		int dndStyle,
		Transfer[] transfers,
		void delegate(DropTargetEvent) doDrop,
		void delegate(DropTargetEvent) enter,
		void delegate(DropTargetEvent) leave = null,
		void delegate(DropTargetEvent) over = null,
		void delegate(DropTargetEvent) operationChanged = null,
		void delegate(DropTargetEvent) accept = null) {
	auto drop = new DropTarget(control, dndStyle);
	drop.p_transfer = transfers;
	drop.addDropListener(new class DropTargetListener {
		override void drop(DropTargetEvent event) {
			if (doDrop) doDrop(event);
		}
		override void dragEnter(DropTargetEvent event) {
			if (enter) enter(event);
		}
		override void dragLeave(DropTargetEvent event) {
			if (leave) leave(event);
		}
		override void dragOver(DropTargetEvent event) {
			if (over) over(event);
		}
		override void dragOperationChanged(DropTargetEvent event) {
			if (operationChanged) operationChanged(event);
		}
		override void dropAccept(DropTargetEvent event) {
			if (accept) accept(event);
		}
	});
}

/// Adds drop functions to control.
void addDragFunctions(Control control,
		int dndStyle,
		Transfer[] transfers,
		void delegate(DragSourceEvent) start,
		void delegate(DragSourceEvent) setData,
		void delegate(DragSourceEvent) finished = null) {
	auto drag = new DragSource(control, dndStyle);
	drag.setTransfer(transfers);
	drag.addDragListener(new class DragSourceListener {
		override void dragStart(DragSourceEvent event) {
			if (start) start(event);
		}
		override void dragSetData(DragSourceEvent event) {
			if (setData) setData(event);
		}
		override void dragFinished(DragSourceEvent event) {
			if (finished) finished(event);
		}
	});
}

/// Adds event listeners according as existing methods.
/// For example, void onKeyDown(Event) is called for SWT.KeyDown.
/// Example:
/// ---
/// class MyCanvas : Canvas {
/// 	/// A background image for this canvas.
/// 	private Image _image;
/// 
/// 	this (Composite parent, int style) {
/// 		super (parent, style);
/// 		_image = new Image(getDisplay(), "ocean.jpg");
/// 		bindListeners(this);
/// 	}
/// 
/// 	/// Processes event (SWT.Paint).
/// 	private void onPaint(Event e) {
/// 		e.gc.drawImage(_image, 0, 0);
/// 	}
/// 
/// 	/// Processes event (SWT.Dispose).
/// 	private void onDispose(Event e) {
/// 		_image.dispose();
/// 	}
/// }
/// ---
void bindListeners(W)(W widget) {
	bindListenersImpl!([
		"None",
		"KeyDown",
		"KeyUp",
		"MouseDown",
		"MouseUp",
		"MouseMove",
		"MouseEnter",
		"MouseExit",
		"MouseDoubleClick",
		"Paint",
		"Move",
		"Resize",
		"Dispose",
		"Selection",
		"DefaultSelection",
		"FocusIn",
		"FocusOut",
		"Expand",
		"Collapse",
		"Iconify",
		"Deiconify",
		"Close",
		"Show",
		"Hide",
		"Modify",
		"Verify",
		"Activate",
		"Deactivate",
		"Help",
		"DragDetect",
		"Arm",
		"Traverse",
		"MouseHover",
		"HardKeyDown",
		"HardKeyUp",
		"MenuDetect",
		"SetData",
		"MouseWheel",
		"Settings",
		"EraseItem",
		"MeasureItem",
		"PaintItem",
		"ImeComposition",
	])(widget, new BindListeners);
}
private class BindListeners : Listener {
	void delegate(Event)[int] _receivers;
	override void handleEvent(Event e) {
		auto p = e.type in _receivers;
		if (!p) return;
		(*p)(e);
	}
}
private void bindListenersImpl(alias Names, W)(W widget, BindListeners l) {
	static const Name = Names[0];
	static if (is(typeof(mixin("&widget.on" ~ Name)) == void delegate(Event))) {
		// widget has onX(Event).
		auto type = mixin("SWT." ~ Name);
		l._receivers[type] = mixin("&widget.on" ~ Name);
		widget.addListener(type, l);
	}
	static if (Names.length > 1) {
		// recurse
		bindListenersImpl!(Names[1 .. $])(widget, l);
	}
}

/**
Converts a SWT event type to event listener class.
Example:
---
static assert (is(ListenerClass!(SWT.KeyDown) == KeyListener));
static assert (is(ListenerClass!(SWT.MouseWheel) == MouseWheelListener));
---
*/
template ListenerClass(int EventType) {
	static if (EventType == SWT.None) {
		alias Listener ListenerClass;
	} else static if (EventType == SWT.KeyDown) {
		alias KeyListener ListenerClass;
	} else static if (EventType == SWT.KeyUp) {
		alias KeyListener ListenerClass;
	} else static if (EventType == SWT.MouseDown) {
		alias MouseListener ListenerClass;
	} else static if (EventType == SWT.MouseUp) {
		alias MouseListener ListenerClass;
	} else static if (EventType == SWT.MouseMove) {
		alias MouseMoveListener ListenerClass;
	} else static if (EventType == SWT.MouseEnter) {
		alias MouseTrackListener ListenerClass;
	} else static if (EventType == SWT.MouseExit) {
		alias MouseTrackListener ListenerClass;
	} else static if (EventType == SWT.MouseDoubleClick) {
		alias MouseListener ListenerClass;
	} else static if (EventType == SWT.Paint) {
		alias PaintListener ListenerClass;
	} else static if (EventType == SWT.Move) {
		alias ControlListener ListenerClass;
	} else static if (EventType == SWT.Resize) {
		alias ControlListener ListenerClass;
	} else static if (EventType == SWT.Dispose) {
		alias DisposeListener ListenerClass;
	} else static if (EventType == SWT.Selection) {
		alias SelectionListener ListenerClass;
	} else static if (EventType == SWT.DefaultSelection) {
		alias SelectionListener ListenerClass;
	} else static if (EventType == SWT.FocusIn) {
		alias FocusListener ListenerClass;
	} else static if (EventType == SWT.FocusOut) {
		alias FocusListener ListenerClass;
	} else static if (EventType == SWT.Expand) {
		alias TreeListener ListenerClass;
	} else static if (EventType == SWT.Collapse) {
		alias TreeListener ListenerClass;
	} else static if (EventType == SWT.Iconify) {
		alias ShellListener ListenerClass;
	} else static if (EventType == SWT.Deiconify) {
		alias ShellListener ListenerClass;
	} else static if (EventType == SWT.Close) {
		alias ShellListener ListenerClass;
	} else static if (EventType == SWT.Show) {
		alias MenuListener ListenerClass;
	} else static if (EventType == SWT.Hide) {
		alias MenuListener ListenerClass;
	} else static if (EventType == SWT.Modify) {
		alias ModifyListener ListenerClass;
	} else static if (EventType == SWT.Verify) {
		alias VerifyListener ListenerClass;
	} else static if (EventType == SWT.Activate) {
		alias ShellListener ListenerClass;
	} else static if (EventType == SWT.Deactivate) {
		alias ShellListener ListenerClass;
	} else static if (EventType == SWT.Help) {
		alias HelpListener ListenerClass;
	} else static if (EventType == SWT.DragDetect) {
		alias DragDetectListener ListenerClass;
	} else static if (EventType == SWT.Arm) {
		alias ArmListener ListenerClass;
	} else static if (EventType == SWT.Traverse) {
		alias TraverseListener ListenerClass;
	} else static if (EventType == SWT.MouseHover) {
		alias MouseTrackListener ListenerClass;
	} else static if (EventType == SWT.HardKeyDown) {
		alias Listener ListenerClass;
	} else static if (EventType == SWT.HardKeyUp) {
		alias Listener ListenerClass;
	} else static if (EventType == SWT.MenuDetect) {
		alias MenuDetectListener ListenerClass;
	} else static if (EventType == SWT.SetData) {
		alias Listener ListenerClass;
	} else static if (EventType == SWT.MouseWheel) {
		alias MouseWheelListener ListenerClass;
	} else static if (EventType == SWT.Settings) {
		alias Listener ListenerClass;
	} else static if (EventType == SWT.EraseItem) {
		alias Listener ListenerClass;
	} else static if (EventType == SWT.MeasureItem) {
		alias Listener ListenerClass;
	} else static if (EventType == SWT.PaintItem) {
		alias Listener ListenerClass;
	} else static if (EventType == SWT.ImeComposition) {
		alias Listener ListenerClass;
	} else static assert (0, "Invaild EventType");
}
static assert (is(ListenerClass!(SWT.KeyDown) == KeyListener));
static assert (is(ListenerClass!(SWT.MouseWheel) == MouseWheelListener));

/**
Converts a SWT event type to method name of event handler.
Example:
---
static assert (EventName!(SWT.KeyDown) == "keyPressed");
static assert (EventName!(SWT.Dispose) == "widgetDisposed()");
---
*/
template EventName(int EventType) {
	static if (EventType == SWT.None) {
		immutable EventName = "handleEvent";
	} else static if (EventType == SWT.KeyDown) {
		immutable EventName = "keyPressed";
	} else static if (EventType == SWT.KeyUp) {
		immutable EventName = "keyReleased";
	} else static if (EventType == SWT.MouseDown) {
		immutable EventName = "mouseDown";
	} else static if (EventType == SWT.MouseUp) {
		immutable EventName = "mouseUp";
	} else static if (EventType == SWT.MouseMove) {
		immutable EventName = "mouseMove";
	} else static if (EventType == SWT.MouseEnter) {
		immutable EventName = "mouseEnter";
	} else static if (EventType == SWT.MouseExit) {
		immutable EventName = "mouseExit";
	} else static if (EventType == SWT.MouseDoubleClick) {
		immutable EventName = "mouseDoubleClick";
	} else static if (EventType == SWT.Paint) {
		immutable EventName = "paintControl";
	} else static if (EventType == SWT.Move) {
		immutable EventName = "controlMoved";
	} else static if (EventType == SWT.Resize) {
		immutable EventName = "controlResized";
	} else static if (EventType == SWT.Dispose) {
		immutable EventName = "widgetDisposed()";
	} else static if (EventType == SWT.Selection) {
		immutable EventName = "widgetSelected()";
	} else static if (EventType == SWT.DefaultSelection) {
		immutable EventName = "widgetDefaultSelected()";
	} else static if (EventType == SWT.FocusIn) {
		immutable EventName = "focusGained";
	} else static if (EventType == SWT.FocusOut) {
		immutable EventName = "focusLost";
	} else static if (EventType == SWT.Expand) {
		immutable EventName = "treeExpanded";
	} else static if (EventType == SWT.Collapse) {
		immutable EventName = "treeCollapsed";
	} else static if (EventType == SWT.Iconify) {
		immutable EventName = "shellIconified";
	} else static if (EventType == SWT.Deiconify) {
		immutable EventName = "shellDeconified";
	} else static if (EventType == SWT.Close) {
		immutable EventName = "shellClosed";
	} else static if (EventType == SWT.Show) {
		immutable EventName = "menuHidden";
	} else static if (EventType == SWT.Hide) {
		immutable EventName = "menuShown";
	} else static if (EventType == SWT.Modify) {
		immutable EventName = "modifyText";
	} else static if (EventType == SWT.Verify) {
		immutable EventName = "verifyText";
	} else static if (EventType == SWT.Activate) {
		immutable EventName = "shellActivated";
	} else static if (EventType == SWT.Deactivate) {
		immutable EventName = "shellDeactivated";
	} else static if (EventType == SWT.Help) {
		immutable EventName = "helpRequested";
	} else static if (EventType == SWT.DragDetect) {
		immutable EventName = "dragDetected";
	} else static if (EventType == SWT.Arm) {
		immutable EventName = "widgetArmed()";
	} else static if (EventType == SWT.Traverse) {
		immutable EventName = "keyTraversed";
	} else static if (EventType == SWT.MouseHover) {
		immutable EventName = "mouseHover";
	} else static if (EventType == SWT.HardKeyDown) {
		immutable EventName = "handleEvent";
	} else static if (EventType == SWT.HardKeyUp) {
		immutable EventName = "handleEvent";
	} else static if (EventType == SWT.MenuDetect) {
		immutable EventName = "menuDetected";
	} else static if (EventType == SWT.SetData) {
		immutable EventName = "handleEvent";
	} else static if (EventType == SWT.MouseWheel) {
		immutable EventName = "mouseScrolled";
	} else static if (EventType == SWT.Settings) {
		immutable EventName = "handleEvent";
	} else static if (EventType == SWT.EraseItem) {
		immutable EventName = "handleEvent";
	} else static if (EventType == SWT.MeasureItem) {
		immutable EventName = "handleEvent";
	} else static if (EventType == SWT.PaintItem) {
		immutable EventName = "handleEvent";
	} else static if (EventType == SWT.ImeComposition) {
		immutable EventName = "handleEvent";
	} else static assert (0, "Invaild EventType");
}
static assert (EventName!(SWT.KeyDown) == "keyPressed");
static assert (EventName!(SWT.Dispose) == "widgetDisposed()");
