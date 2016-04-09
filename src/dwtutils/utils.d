
/// This module includes utilities for DWT.
///
/// License: Public Domain
/// Authors: kntroh
module dwtutils.utils;

public import dwtutils.factory;
public import dwtutils.wrapper;

private import core.thread;

private import std.algorithm;
private import std.ascii;
private import std.conv;
private import std.datetime;
private import std.exception;
private import std.math;
private import std.range;
private import std.string;
private import std.typecons;

private import org.eclipse.swt.all;

/// Starts event loop of the application.
/// If caught exception, it calls catchException.
/// If it returns false, quit the application.
/// If catchException is null,
/// quit the application is when someone thrown exception.
void startApplication(Shell mainShell, bool delegate(Throwable e) catchException = null) {
	.enforce(mainShell);
	mainShell.open();
	startApplication(mainShell.p_display, &mainShell.isDisposed, catchException);
}
/// ditto
void startApplication(Display display, bool delegate() isQuit, bool delegate(Throwable e) catchException = null) {
	.enforce(display);
	.enforce(isQuit);
	scope (exit) display.dispose();

	while (!isQuit()) {
		try {
			if (!display.readAndDispatch()) {
				display.sleep();
			}
		} catch (Throwable e) {
			if (catchException) {
				if (!catchException(e)) {
					throw e;
				}
			} else {
				throw e;
			}
			display.sleep();
		}
	}
}

/// Adds simple table item to table.
void add(Table table, string text, Image image = null) {
	basicTableItem(table, text, image);
}
/// ditto
void add(Table table, string text, int index) {
	basicTableItem(table, text, null, index);
}
/// ditto
void add(Table table, string text, Image image, int index) {
	basicTableItem(table, text, image, index);
}

/// Swap table items.
void swapItems(Table table, int index1, int index2) {
	auto itm1 = table.getItem(index1);
	auto itm2 = table.getItem(index2);
	foreach (col; 0 .. .max(1, table.p_columnCount)) {
		auto tmpBackground = itm1.getBackground(col);
		auto tmpForeground = itm1.getForeground(col);
		auto tmpFont = itm1.getFont(col);
		auto tmpImage = itm1.getImage(col);
		auto tmpText = itm1.getText(col);
		itm1.setBackground(col, itm2.getBackground(col));
		itm1.setForeground(col, itm2.getForeground(col));
		itm1.setFont(col, itm2.getFont(col));
		itm1.setImage(col, itm2.getImage(col));
		itm1.setText(col, itm2.getText(col));
		itm2.setBackground(col, tmpBackground);
		itm2.setForeground(col, tmpForeground);
		itm2.setFont(col, tmpFont);
		itm2.setImage(col, tmpImage);
		itm2.setText(col, tmpText);
	}
	auto tmpChecked = itm1.p_checked;
	auto tmpGrayed = itm1.p_grayed;
	auto tmpImageIndent = itm1.p_imageIndent;
	itm1.p_checked = itm2.p_checked;
	itm1.p_grayed = itm2.p_grayed;
	itm1.p_imageIndent = itm2.p_imageIndent;
	itm2.p_checked = tmpChecked;
	itm2.p_grayed = tmpGrayed;
	itm2.p_imageIndent = tmpImageIndent;
}

/// control is descendant of composite?
/// If composite is control, returns true.
bool descendant(Control composite, Control control) {
	while (composite !is control) {
		if (!control) return false;
		control = control.p_parent;
	}
	return true;
}

/// Converts from point size to pixel based on dpi.
int pointToPixel(real point, int dpi) {
	return roundTo!int(point * dpi / 72.0);
}
/// Converts from pixel to point size based on dpi.
real pixelToPoint(int pixel, int dpi) {
	return cast(real)pixel / dpi * 72.0;
}
unittest {
	assert (pointToPixel(7, 96) == 9);
	assert (pointToPixel(8, 96) == 11);
	assert (pointToPixel(9, 96) == 12);
	assert (pixelToPoint(9, 96).roundTo!int() == 7);
	assert (pixelToPoint(11, 96).roundTo!int() == 8);
	assert (pixelToPoint(12, 96).roundTo!int() == 9);
}

/// Computes text size on drawable.
Point computeTextSize(Drawable drawable, string text) {
	auto tgc = new GC(drawable);
	scope (exit) tgc.dispose();
	return tgc.textExtent(text);
}
/// Computes text size with font.
Point computeTextSize(Font font, string text) {
	auto d = Display.getCurrent();
	auto img = new Image(d, 1, 1);
	scope (exit) img.dispose();
	auto tgc = new GC(img);
	scope (exit) tgc.dispose();
	tgc.p_font = font;
	return tgc.textExtent(text);
}

/// A floating text box on a Composite.
class Editor {
	/// The parent of text box.
	private Composite _parent = null;
	/// If it is true, "" is same as canceled.
	private bool _emptyIsCancel = true;

	/// The text box.
	private Text _text = null;

	/// Callback function of cancel.
	private void delegate() _cancelCallback = null;

	/// The only constructor.
	this (Composite parent, bool emptyIsCancel, void delegate() cancelCallback = null) {
		.enforce(parent);
		.enforce(!parent.p_layout);
		_parent = parent;
		_emptyIsCancel = emptyIsCancel;
		_cancelCallback = cancelCallback;
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
		if (_cancelCallback) {
			_cancelCallback();
		}
	}

	/// Starts edit.
	void start(int editorX, int editorY, string text, void delegate(string) set, void delegate(string) modify = null) {
		.enforce(!_parent.p_layout);
		.enforce(set);
		if (_text) {
			cancel();
		}
		assert (!_text);
		_text = new Text(_parent, SWT.NONE);
		_text.p_text = text;
		_text.setSelection(0, cast(int)text.length);
		auto vBar = _parent.p_verticalBar;
		auto hBar = _parent.p_horizontalBar;
		if (vBar) {
			auto info = vBar.p_listeners!(SWT.Selection) ~= { cancel(); };
			_text.p_listeners!(SWT.Dispose) ~= { info.remove(); };
		}
		if (hBar) {
			auto info = hBar.p_listeners!(SWT.Selection) ~= { cancel(); };
			_text.p_listeners!(SWT.Dispose) ~= { info.remove(); };
		}
		void submit() {
			if (!_text) return;
			auto t = _text.p_text;
			if (t && (!_emptyIsCancel || t.length)) {
				_text.dispose();
				_text = null;
				set(t);
			} else {
				cancel();
			}
		}
		_text.p_listeners!(SWT.Modify) ~= (Event e) {
			if (modify) modify(_text.p_text);
			resize(e);
		};
		_text.p_listeners!(SWT.FocusOut) ~= &submit;
		_text.p_listeners!(SWT.KeyDown) ~= (Event e) {
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
		auto info = _parent.p_listeners!(SWT.Resize) ~= &resize;
		_text.p_listeners!(SWT.Dispose) ~= { info.remove(); };
		auto pBounds = _parent.p_clientArea;
		auto s = _text.computeSize(SWT.DEFAULT, SWT.DEFAULT);
		s.x += computeTextSize(_text, "##").x; // allow leeway
		auto maxWidth = pBounds.width - editorX;
		_text.p_bounds = CRect(editorX, editorY, .min(maxWidth, s.x), s.y);
		_text.setFocus();
	}

	/// Adjust text box size to match a input text.
	private void resize(Event e) {
		if (!_text) return;
		_text.p_redraw = false;
		scope (exit) _text.p_redraw = true;

		auto pBounds = _parent.p_clientArea;
		auto s = _text.p_bounds;
		auto ns = _text.computeSize(SWT.DEFAULT, SWT.DEFAULT);
		ns.x += computeTextSize(_text, "##").x; // allow leeway
		auto maxWidth = pBounds.width - s.x;
		if (ns.x <= maxWidth) {
			_text.p_size = ns;
			// Rectifies position gap.
			auto sel = _text.p_selection;
			_text.p_selection = 0;
			_text.showSelection();
			_text.p_selection = sel;
		} else {
			ns.x = maxWidth;
			_text.p_size = ns;
		}
	}
}

/// Start edit when be press F2 key or click selected item.
Editor createEditor(Table table, bool emptyIsCancel, void delegate(int index, string name) decision) {
	TableItem itm = null;
	string lastText = "";
	void cancelCallback() {
		// restore
		itm.p_text = lastText;
	}
	auto editor = new Editor(table, emptyIsCancel, &cancelCallback);
	void edit(int index) {
		itm = table.getItem(index);
		lastText = itm.p_text;

		auto bounds = itm.getTextBounds(0);
		auto th = table.computeTextSize("#").y;
		editor.start(bounds.x, bounds.y + (bounds.height - th) / 2, lastText, (string text) {
			if (decision) {
				itm.p_text = lastText;
				decision(table.indexOf(itm), text);
			} else {
				itm.p_text = text;
			}
		}, (string text) {
			// modify
			itm.p_text = text;
		});
	}

	// Start edit with keyboard operation.
	table.p_listeners!(SWT.KeyDown) ~= (Event e) {
		if (SWT.F2 != e.keyCode) return;
		int index = table.p_selectionIndex;
		if (-1 == index) return;
		edit(index);
	};

	// Start edit with mouse operation.
	auto d = table.p_display;
	TableItem selection = null; // Selection item, when focus is on the table.
	bool click = false; // If had valid mouse down operation, sets true to this flag.
	int count = 0; // Count of mouse down.
	table.focusLost ~= {
		// Clears selection.
		selection = null;
		click = false;
	};
	auto selected = {
		// Update selection (lazy).
		d.asyncExecWith({
			if (!selection) click = false;
			int index = table.p_selectionIndex;
			selection = index == -1 ? null : table.getItem(index);
		});
	};
	table.focusGained ~= selected;
	table.widgetSelected ~= selected;
	table.mouseDown ~= (MouseEvent e) {
		// If meet conditions, sets true to click.
		//  * Left button.
		//  * Single click.
		//  * Selected before click.
		click = false;
		count = e.count;
		if (1 == e.count && e.button == 1 && selection) {
			auto itm = table.getItem(CPoint(e.x, e.y));
			if (itm is selection) {
				click = true;
			}
		}
	};
	table.mouseUp ~= (MouseEvent e) {
		// If meet conditions, start edit after certain time.
		if (!click) return;
		click = false;
		if (1 < count || e.button != 1) return;
		auto itm = table.getItem(CPoint(e.x, e.y));
		if (!itm || itm !is selection) return;
		auto index = table.indexOf(itm);
		auto dTime = dur!"msecs"(d.p_doubleClickTime);
		(new Thread({
			// Wait certain time.
			auto limit = Clock.currTime() + dTime;
			while (Clock.currTime() < limit) {
				Thread.sleep(dur!"msecs"(1));
				if (itm !is selection) return;
			}
			// Start edit.
			d.asyncExecWith(&edit, index);
		})).start();
	};
	return editor;
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
	menu.p_listeners!(SWT.Selection) ~= {
		tool.p_selection = menu.p_selection;
	};
	tool.p_listeners!(SWT.Selection) ~= {
		menu.p_selection = tool.p_selection;
	};
}

/// Gets a accelerator key from text.
int acceleratorKey(string text) {
	auto i = std.string.indexOf(text, "\t");
	if (-1 == i || text.length <= i + 1) {
		return 0;
	}
	text = text[i + 1 .. $];

	int accelerator = 0;
	foreach (key; text.split("+")) {
		switch (key.toUpper()) {
		case "CTRL"        : accelerator += SWT.CTRL;        break;
		case "ALT"         : accelerator += SWT.ALT;         break;
		case "SHIFT"       : accelerator += SWT.SHIFT;       break;
		case "COMMAND"     : accelerator += SWT.COMMAND;     break;
		case "BACKSPACE"   : accelerator += SWT.BS;          break;
		case "TAB"         : accelerator += SWT.TAB;         break;
		case "RETURN"      : accelerator += SWT.CR;          break;
		case "ENTER"       : accelerator += SWT.CR;          break;
		case "ESCAPE"      : accelerator += SWT.ESC;         break;
		case "ESC"         : accelerator += SWT.ESC;         break;
		case "DELETE"      : accelerator += 127;             break;
		case "SPACE"       : accelerator += ' ';             break;
		case "ARROW_UP"    : accelerator += SWT.ARROW_UP;    break;
		case "ARROW_DOWN"  : accelerator += SWT.ARROW_DOWN;  break;
		case "ARROW_LEFT"  : accelerator += SWT.ARROW_LEFT;  break;
		case "ARROW_RIGHT" : accelerator += SWT.ARROW_RIGHT; break;
		case "PAGE_UP"     : accelerator += SWT.PAGE_UP;     break;
		case "PAGE_DOWN"   : accelerator += SWT.PAGE_DOWN;   break;
		case "HOME"        : accelerator += SWT.HOME;        break;
		case "END"         : accelerator += SWT.END;         break;
		case "INSERT"      : accelerator += SWT.INSERT;      break;
		case "F1"          : accelerator += SWT.F1;          break;
		case "F2"          : accelerator += SWT.F2;          break;
		case "F3"          : accelerator += SWT.F3;          break;
		case "F4"          : accelerator += SWT.F4;          break;
		case "F5"          : accelerator += SWT.F5;          break;
		case "F6"          : accelerator += SWT.F6;          break;
		case "F7"          : accelerator += SWT.F7;          break;
		case "F8"          : accelerator += SWT.F8;          break;
		case "F9"          : accelerator += SWT.F9;          break;
		case "F10"         : accelerator += SWT.F10;         break;
		case "F11"         : accelerator += SWT.F11;         break;
		case "F12"         : accelerator += SWT.F12;         break;
		default:
			accelerator += key.length ? cast(int)std.ascii.toUpper(key[0]) : 0;
			break;
		}
	}

	return accelerator;
} unittest {
	assert (acceleratorKey("&Save\tCtrl+S") == SWT.CTRL + 'S');
	assert (acceleratorKey("&Save\tCtrl+Shift+S") == SWT.CTRL + SWT.SHIFT + 'S');
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
/// 
/// 		mixin(BindListeners);
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
immutable BindListeners = `
{
	static class BindListeners_Listener : Listener {
		void delegate(Event)[int] _receivers;
		override void handleEvent(Event e) {
			auto p = e.type in _receivers;
			if (!p) return;
			(*p)(e);
		}
	}

	void BindListeners_bindListenersImpl(alias Names)(BindListeners_Listener l) {
		static const Name = Names[0];
		static if (is(typeof(mixin("&this.on" ~ Name)) == void delegate(Event))) {
			// A widget has onX(Event).
			auto type = mixin("SWT." ~ Name);
			l._receivers[type] = mixin("&this.on" ~ Name);
			this.addListener(type, l);
		}
		static if (Names.length > 1) {
			// recurse
			BindListeners_bindListenersImpl!(Names[1 .. $])(l);
		}
	}

	BindListeners_bindListenersImpl!([
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
	])(new BindListeners_Listener);
}
`;

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

/// This is used when change a processing of events
/// depending on the state of any key.
/// Example:
/// ---
/// // Switches target layers with shift key down.
/// void rotateLeft (bool allLayers) { /* ... */ }
/// void rotateDown (bool allLayers) { /* ... */ }
/// void rotateUp   (bool allLayers) { /* ... */ }
/// void rotateRight(bool allLayers) { /* ... */ }
/// auto s = new KeyObserver(trans, SWT.SHIFT);
/// basicToolItem(tools, "Rotate &Left",  s.withShift(&rotateLeft));
/// basicToolItem(tools, "Rotate &Down",  s.withShift(&rotateDown));
/// basicToolItem(tools, "Rotate &Up",    s.withShift(&rotateUp));
/// basicToolItem(tools, "Rotate &Right", s.withShift(&rotateRight));
///
/// void func() {
/// 	if (s.keyDown) {
/// 		// ...
/// 	} else {
/// 		// ...
/// 	}
/// }
/// ---
class KeyObserver {
	/// Is key down?
	private bool _keyDown = false;

	/// Creates instance and starts observation of key.
	/// When occurs dispose event of widget,
	/// run cleanup function for release all resources.
	this (Widget widget, int keyCode) {
		auto keyDownInfo = widget.p_display.p_filters!(SWT.KeyDown) ~= (Event e) { _keyDown |= e.keyCode == keyCode; };
		auto keyUpInfo = widget.p_display.p_filters!(SWT.KeyUp) ~= (Event e) { _keyDown ^= e.keyCode == keyCode; };
		widget.p_listeners!(SWT.Dispose) ~= {
			keyDownInfo.remove();
			keyUpInfo.remove();
		};
	}

	/// Is shift key down?
	@property
	const
	bool keyDown() { return _keyDown; }

	/// Creates event listener from delegate with shift parameter.
	const
	void delegate(Event e) withKey(void delegate(bool shift) listener) {
		return (Event e)  => listener(keyDown);
	}
}
