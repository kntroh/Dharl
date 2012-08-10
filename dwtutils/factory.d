
/// This module includes functions for creating DWT widgets easily.
module dwtutils.factory;

private import dwtutils.utils;
private import dwtutils.wrapper;

private import std.exception;
private import std.conv;
private import std.ascii;
private import std.string;
private import std.typecons;

private import org.eclipse.swt.all;

/// Creates a instance of Rectangle.
Rectangle CRect(int x, int y, int w, int h) {
	return new Rectangle(x, y, w, h);
}
alias CRect CRectangle;
/// Creates a instance of Point.
Point CPoint(int x, int y) {
	return new Point(x, y);
}

/// Creates basic style shell.
Shell basicShell(string title, Image image = null, Layout layout = null, int style = SWT.SHELL_TRIM) {
	return basicShell(null, title, image, layout, style);
}
/// ditto
Shell basicShell(Shell parent, string title, Image image = null, Layout layout = null, int style = SWT.SHELL_TRIM) {
	auto sh = new Shell(parent, style);
	sh.p_text = title;
	sh.p_image = image;
	sh.p_layout = layout;
	return sh;
}

/// Creates basic style composite.
Composite basicComposite(Composite parent, Layout layout = null, int style = SWT.NONE) {
	auto co = new Composite(parent, style);
	co.p_layout = layout;
	return co;
}

/// Creates basic style group.
Group basicGroup(Composite parent, string text, Layout layout = null, int style = SWT.NONE) {
	auto gr = new Group(parent, style);
	gr.p_text = text;
	gr.p_layout = layout;
	return gr;
}

/// Creates basic style sash form.
SashForm basicSashForm(Composite parent, int style = SWT.HORIZONTAL) {
	auto sa = new SashForm(parent, style);
	return sa;
}

/// Creates separator. TODO comment
Label separator(Composite parent, int style = SWT.HORIZONTAL) {
	return new Label(parent, style | SWT.SEPARATOR);
}
/// ditto
ToolItem separator(ToolBar parent) {
	return new ToolItem(parent, SWT.SEPARATOR);
}
/// ditto
MenuItem separator(Menu parent) {
	return new MenuItem(parent, SWT.SEPARATOR);
}
/// ditto
MTItem separator(Menu menu, ToolBar tool) {
	typeof(return) result;
	result.menuItem = new MenuItem(menu, SWT.SEPARATOR);
	result.toolItem = new ToolItem(tool, SWT.SEPARATOR);
	return result;
}

/// Creates basic style menu bar.
Menu basicMenuBar(Shell parent) {
	auto menuBar = new Menu(parent, SWT.BAR);
	parent.p_menuBar = menuBar;
	return menuBar;
}
/// Creates basic style drop down menu.
Menu basicDropDownMenu(Menu parent, string text) {
	auto menuItem = new MenuItem(parent, SWT.CASCADE);
	menuItem.p_text = text;
	auto menu = new Menu(parent.parent, SWT.DROP_DOWN);
	menuItem.p_menu = menu;
	return menu;
}
/// ditto
Menu basicDropDownMenu(Shell parent, string text) {
	if (!parent.p_menuBar) {
		basicMenuBar(parent);
	}
	return basicDropDownMenu(parent.p_menuBar, text);
}
/// Creates basic style menu item.
MenuItem basicMenuItem(Menu parent, string text, Image image, void delegate(Event e) listener, int style = SWT.PUSH, bool selection = false) {
	auto menuItem = new MenuItem(parent, style);
	menuItem.p_text = text;
	menuItem.p_image = image;
	menuItem.p_accelerator = acceleratorKey(text);
	menuItem.p_selection = selection;
	if (listener) {
		menuItem.listeners!(SWT.Selection) ~= listener;
	}
	return menuItem;
}
/// ditto
MenuItem basicMenuItem(Menu parent, string text, void delegate(Event e) listener, int style = SWT.PUSH, bool selection = false) {
	return basicMenuItem(parent, text, null, listener, style, selection);
}
/// ditto
MenuItem basicMenuItem(Menu parent, string text, Image image, void delegate() listener, int style = SWT.PUSH, bool selection = false) {
	return basicMenuItem(parent, text, image, listener ? (Event) {
		listener();
	} : null, style, selection);
}
/// ditto
MenuItem basicMenuItem(Menu parent, string text, void delegate() listener, int style = SWT.PUSH, bool selection = false) {
	return basicMenuItem(parent, text, null, listener, style, selection);
}

/// Creates basic style tool bar.
ToolBar basicToolBar(Composite parent, int style = SWT.FLAT | SWT.HORIZONTAL) {
	return new ToolBar(parent, style);
}
/// Creates basic style tool item.
ToolItem basicToolItem(ToolBar parent, string text, Image image, void delegate(Event e) listener, int style = SWT.PUSH, bool selection = false) {
	auto toolItem = new ToolItem(parent, style);
	int tab = text.indexOf("\t");
	if (-1 != tab) text = text[0 .. tab];
	if (image) {
		toolItem.toolTipText = text;
		toolItem.p_image = image;
	} else {
		toolItem.p_text = text;
	}
	toolItem.p_selection = selection;
	if (listener) {
		toolItem.listeners!(SWT.Selection) ~= listener;
	}
	return toolItem;
}
/// ditto
ToolItem basicToolItem(ToolBar parent, string text, void delegate(Event e) listener, int style = SWT.PUSH, bool selection = false) {
	return basicToolItem(parent, text, null, listener, style, selection);
}
/// ditto
ToolItem basicToolItem(ToolBar parent, string text, Image image, void delegate() listener, int style = SWT.PUSH, bool selection = false) {
	return basicToolItem(parent, text, image, listener ? (Event) {
		listener();
	} : null, style, selection);
}
/// ditto
ToolItem basicToolItem(ToolBar parent, string text, void delegate() listener, int style = SWT.PUSH, bool selection = false) {
	return basicToolItem(parent, text, null, listener, style, selection);
}
/// ditto
ToolItem basicToolItem(ToolBar parent, Control control) {
	auto toolItem = new ToolItem(parent, SWT.SEPARATOR);
	toolItem.control = control;
	auto cs = control.computeSize(SWT.DEFAULT, SWT.DEFAULT);
	toolItem.p_width = cs.x;
	return toolItem;
}

/// Creates basic style menu item and tool item (binding). TODO comment
MTItem basicMenuItem(Menu menu, ToolBar tool, string text, Image image, void delegate(Event e) listener, int style = SWT.PUSH, bool selection = false) {
	typeof(return) result;
	void delegate(Event e) nl = null;
	result.menuItem = basicMenuItem(menu, text, image, nl, style, selection);
	result.toolItem = basicToolItem(tool, text, image, nl, style, selection);
	bindMenu(result.menuItem, result.toolItem);
	if (listener) {
		result.menuItem.listeners!(SWT.Selection) ~= listener;
		result.toolItem.listeners!(SWT.Selection) ~= listener;
	}
	return result;
}
/// ditto
MTItem basicMenuItem(Menu menu, ToolBar tool, string text, void delegate(Event e) listener, int style = SWT.PUSH, bool selection = false) {
	return basicMenuItem(menu, tool, text, null, listener, style, selection);
}
/// ditto
MTItem basicMenuItem(Menu menu, ToolBar tool, string text, Image image, void delegate() listener, int style = SWT.PUSH, bool selection = false) {
	return basicMenuItem(menu, tool, text, image, listener ? (Event) {
		listener();
	} : null, style, selection);
}
/// ditto
MTItem basicMenuItem(Menu menu, ToolBar tool, string text, void delegate() listener, int style = SWT.PUSH, bool selection = false) {
	return basicMenuItem(menu, tool, text, null, listener, style, selection);
}

/// Creates basic style Label.
Label basicLabel(Composite parent, string text, int style = SWT.NONE) {
	auto lb = new Label(parent, style);
	lb.p_text = text;
	return lb;
}

/// Creates basic style Text.
Text basicText(Composite parent, void delegate(Event) modify, string text = "", int style = SWT.BORDER) {
	auto tx = new Text(parent, style);
	tx.p_text = text;
	if (modify) {
		tx.listeners!(SWT.Modify) ~= modify;
	}
	return tx;
}
/// ditto
Text basicText(Composite parent, void delegate() modify, string text = "", int style = SWT.BORDER) {
	return basicText(parent, modify ? (Event e) {
		modify();
	} : null, text, style);
}
/// ditto
Text basicText(Composite parent, string text = "", int style = SWT.BORDER) {
	return basicText(parent, cast(void delegate(Event)) null, text, style);
}

/// Creates basic style button.
Button basicButton(Composite parent, string text, void delegate(Event) selection, int style = SWT.PUSH) {
	auto bt = new Button(parent, style);
	bt.p_text = text;
	if (selection) {
		bt.listeners!(SWT.Selection) ~= selection;
	}
	return bt;
}
/// ditto
Button basicButton(Composite parent, string text, void delegate() selection, int style = SWT.PUSH) {
	return basicButton(parent, text, selection ? (Event e) {
		selection();
	} : null, style);
}

/// Creates no border style Text for number input.
/// When you received ModifyEvent,
/// a checked value is in ModifyEvent.text.
/// A decimal is not-correspond.
Text basicNumber(Composite parent, int min, int max, int style = SWT.BORDER | SWT.RIGHT) {
	auto tx = basicText(parent, to!string(min), style);
	tx.p_textLimit = to!string(max).length;

	// When inputting invalid value, old restores it.
	string old = tx.p_text;

	tx.listeners!(SWT.FocusOut) ~= (Event e) {
		tx.p_text = old;
	};
	tx.listeners!(SWT.FocusIn) ~= (Event e) {
		old = tx.p_text;
	};

	tx.listeners!(SWT.Modify) ~= (Event e) {
		string text = tx.p_text;
		if (text.length && old != text) {
			auto t = strip(text);
			try {
				int num = parse!int(t);
				if (!t.length) {
					old = text;
				}
			} catch (ConvException e) {
				// For example, exception is
				// thrown out in parsed of "-". 
			}
		}
		// At this point, old has new value.
		e.text = old;
	};

	tx.listeners!(SWT.Verify) ~= (Event e) {
		if (!e.text.length) return;
		// Checks a input character.
		auto buf = new char[e.text.length];
		size_t len = 0;
		foreach (i, char c; e.text) {
			// A decimal is not-correspond.
			if (isDigit(c) || c == '-') {
				buf[len] = c;
				len++;
			}
		}
		buf = buf[0 .. len];
		e.text = assumeUnique(buf);
	};
	return tx;
}

/// Creates basic style Combo.
Combo basicCombo(Composite parent, bool readOnly = true, string[] items = null) {
	int style = SWT.BORDER;
	if (readOnly) style |= SWT.READ_ONLY;
	auto combo = new Combo(parent, style);
	if (items) {
		combo.p_items = items;
		if (0 != items.length) {
			combo.select(0);
		}
	}
	return combo;
}

/// Creates basic style Spinner.
Spinner basicSpinner(Composite parent, int min, int max) {
	enforce(min <= max);
	auto spn = new Spinner(parent, SWT.BORDER);
	spn.p_minimum = min;
	spn.p_maximum = max;
	return spn;
}

/// A wrapper for settings to a RowLayout.
struct RL {
	/// RowLayout
	RowLayout data = null;
	/// ditto
	alias data this;

	/// Create new RL with style.
	@property
	static RL opCall(int style) {
		RL rl;
		rl.data = new RowLayout(style);
		return rl;
	}
	/// Create new RL with SWT.VERTICAL or SWT.HORIZONTAL style.
	@property
	static RL vertical() {
		RL rl;
		rl.data = new RowLayout(SWT.VERTICAL);
		return rl;
	}
	/// ditto
	@property
	static RL horizontal() {
		RL rl;
		rl.data = new RowLayout(SWT.HORIZONTAL);
		return rl;
	}
	/// Sets data.wrap.
	RL wrap(bool wrap) {
		data.wrap = wrap;
		return this;
	}
	/// Sets data.pack.
	RL pack(bool pack) {
		data.pack = pack;
		return this;
	}
	/// Sets data.justify.
	RL justify(bool justify) {
		data.justify = justify;
		return this;
	}
	/// Sets all margin.
	RL margin(int left, int top, int right, int bottom) {
		return lMargin(left).tMargin(top).rMargin(right).bMargin(bottom);
	}
	/// Sets data.marginLeft.
	RL lMargin(int margin) {
		data.marginLeft = margin;
		return this;
	}
	/// Sets data.marginTop.
	RL tMargin(int margin) {
		data.marginTop = margin;
		return this;
	}
	/// Sets data.marginRight.
	RL rMargin(int margin) {
		data.marginRight = margin;
		return this;
	}
	/// Sets data.marginBottom.
	RL bMargin(int margin) {
		data.marginBottom = margin;
		return this;
	}
	/// Sets data.spacing.
	RL spacing(int spacing) {
		data.spacing = spacing;
		return this;
	}
}

/// A wrapper for settings to a RowData.
struct RD {
	/// RowData.
	RowData data = null;
	/// ditto
	alias data this;
	/// Create new RD with width and height.
	@property
	static RD opCall(int width, int height) {
		RD rd;
		rd.data = new RowData(width, height);
		return rd;
	}
}

/// A wrapper for settings to a GridLayout.
struct GL {
	/// GridLayout.
	GridLayout data = null;
	/// ditto
	alias data this;

	/// Create new GL with numColumns and makeColumnsEqualWidth.
	@property
	static GL opCall(int numColumns = 1, bool makeColumnsEqualWidth = false) {
		GL gl;
		gl.data = new GridLayout(numColumns, makeColumnsEqualWidth);
		return gl;
	}
	/// Creates new GL with style.
	/// And sets 0 to all margin.
	@property
	static GL noMargin(int numColumns = 1, bool makeColumnsEqualWidth = false) {
		return GL(numColumns, makeColumnsEqualWidth).margin(0);
	}
	/// Creates new GL with style.
	/// And sets 2 to all margin and spacing.
	@property
	static GL window(int numColumns = 1, bool makeColumnsEqualWidth = false) {
		return GL(numColumns, makeColumnsEqualWidth).margin(2).spacing(2);
	}
	/// Creates new GL with style.
	/// And sets 1 to all margin and spacing.
	@property
	static GL minimum(int numColumns = 1, bool makeColumnsEqualWidth = false) {
		return GL(numColumns, makeColumnsEqualWidth).margin(1).spacing(1);
	}
	/// Creates new GL with style.
	/// And sets 0 to all margin and spacing.
	@property
	static GL zero(int numColumns = 1, bool makeColumnsEqualWidth = false) {
		return GL(numColumns, makeColumnsEqualWidth).margin(0).spacing(0);
	}

	/// Sets data.marginWidth and data.marginHeight
	GL margin(int margin) {
		return wMargin(margin).hMargin(margin);
	}
	/// Sets data.marginWidth.
	GL wMargin(int margin) {
		data.marginWidth = margin;
		return this;
	}
	/// Sets data.marginHeight.
	GL hMargin(int margin) {
		data.marginHeight = margin;
		return this;
	}
	/// Sets data.horizontalSpacing and data.verticalSpacing
	GL spacing(int spacing) {
		return hSpacing(spacing).vSpacing(spacing);
	}
	/// Sets data.horizontalSpacing.
	GL hSpacing(int spacing) {
		data.horizontalSpacing = spacing;
		return this;
	}
	/// Sets data.verticalSpacing.
	GL vSpacing(int spacing) {
		data.verticalSpacing = spacing;
		return this;
	}
}

/// A wrapper for settings to a GridData.
struct GD {
	/// GridData.
	GridData data = null;
	/// ditto
	alias data this;

	/// Creates new GD with style.
	@property
	static GD opCall(int style) {
		GD gd;
		gd.data = new GridData(style);
		return gd;
	}
	/// Creates new GD with fill style. TODO comment
	@property
	static GD fill(bool horizontal, bool vertical) {
		GD gd;
		int style = SWT.NONE;
		if (horizontal) style |= GridData.FILL_HORIZONTAL;
		if (vertical) style |= GridData.FILL_VERTICAL;
		gd.data = new GridData(style);
		return gd;
	}

	/// Sets data.horizontalSpan and data.verticalSpan.
	GD span(int horizontalSpan, int verticalSpan) {
		return hSpan(horizontalSpan).vSpan(verticalSpan);
	}
	/// Sets data.horizontalSpan.
	GD hSpan(int span) {
		data.horizontalSpan = span;
		return this;
	}
	/// Sets data.verticalSpan.
	GD vSpan(int span) {
		data.verticalSpan = span;
		return this;
	}

	/// Sets data.widthHint and data.heightHint.
	GD sizeHint(int widthHint, int heightHint) {
		return wHint(widthHint).hHint(heightHint);
	}
	/// Sets data.widthHint.
	GD wHint(int hint) {
		data.widthHint = hint;
		return this;
	}
	/// Sets data.heightHint.
	GD hHint(int hint) {
		data.heightHint = hint;
		return this;
	}
}