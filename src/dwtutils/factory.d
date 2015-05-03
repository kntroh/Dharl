
/// This module includes functions for creating DWT widgets easily.
///
/// License: Public Domain
/// Authors: kntroh
module dwtutils.factory;

private import dwtutils.utils;
private import dwtutils.wrapper;

private import std.array;
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
Shell basicShell(string title, Image[] images = [], Layout layout = null, int style = SWT.SHELL_TRIM) {
	return basicShell(null, title, images, layout, style);
}
/// ditto
Shell basicShell(Shell parent, string title, Image[] images = [], Layout layout = null, int style = SWT.SHELL_TRIM) {
	auto sh = new Shell(parent, style);
	sh.p_text = title;
	sh.p_images = images;
	sh.p_layout = layout;
	return sh;
}
/// Creates tool window style shell.
Shell toolShell(Shell parent, string title, bool resize = true, bool close = true, Layout layout = null) {
	int style = SWT.TITLE | SWT.TOOL;
	if (resize) style |= SWT.RESIZE;
	if (close) style |= SWT.CLOSE;
	return basicShell(parent, title, [], layout, style);
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

/// Creates separator.
Label separator(Composite parent, int style = SWT.HORIZONTAL) {
	return new Label(parent, style | SWT.SEPARATOR);
}
/// ditto
MenuItem separator(Menu parent, int index = -1) {
	if (index < 0) {
		return new MenuItem(parent, SWT.SEPARATOR);
	} else {
		return new MenuItem(parent, SWT.SEPARATOR, index);
	}
}
/// ditto
ToolItem separator(ToolBar parent, int index = -1) {
	if (index < 0) {
		return new ToolItem(parent, SWT.SEPARATOR);
	} else {
		return new ToolItem(parent, SWT.SEPARATOR, index);
	}
}
/// ditto
MTItem separator(Menu menu, ToolBar tool, int menuIndex = -1, int toolIndex = -1) {
	typeof(return) result;
	result.menuItem = .separator(menu, menuIndex);
	result.toolItem = .separator(tool, toolIndex);
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
MenuItem basicMenuItem(Menu parent, string text, Image image, void delegate(Event e) listener, int style = SWT.PUSH, bool selection = false, int index = -1) {
	MenuItem menuItem;
	if (index < 0) {
		menuItem = new MenuItem(parent, style);
	} else {
		menuItem = new MenuItem(parent, style, index);
	}
	menuItem.p_text = text;
	menuItem.p_image = image;
	menuItem.p_accelerator = acceleratorKey(text);
	menuItem.p_selection = selection;
	if (listener) {
		menuItem.p_listeners!(SWT.Selection) ~= listener;
	}
	return menuItem;
}
/// ditto
MenuItem basicMenuItem(Menu parent, string text, void delegate(Event e) listener, int style = SWT.PUSH, bool selection = false, int index = -1) {
	return basicMenuItem(parent, text, null, listener, style, selection, index);
}
/// ditto
MenuItem basicMenuItem(Menu parent, string text, Image image, void delegate() listener, int style = SWT.PUSH, bool selection = false, int index = -1) {
	return basicMenuItem(parent, text, image, listener ? (Event) {
		listener();
	} : null, style, selection, index);
}
/// ditto
MenuItem basicMenuItem(Menu parent, string text, void delegate() listener, int style = SWT.PUSH, bool selection = false, int index = -1) {
	return basicMenuItem(parent, text, null, listener, style, selection, index);
}

/// Creates basic style tool bar.
ToolBar basicToolBar(Composite parent, int style = SWT.FLAT | SWT.HORIZONTAL) {
	return new ToolBar(parent, style);
}
/// Creates basic style tool item.
ToolItem basicToolItem(ToolBar parent, string text, Image image, void delegate(Event e) listener, int style = SWT.PUSH, bool selection = false, int index = -1) {
	ToolItem toolItem;
	if (index < 0) {
		toolItem = new ToolItem(parent, style);
	} else {
		toolItem = new ToolItem(parent, style, index);
	}
	initToolItem(toolItem, text, image);
	toolItem.p_selection = selection;
	if (listener) {
		toolItem.p_listeners!(SWT.Selection) ~= listener;
	}
	return toolItem;
}
/// ditto
ToolItem basicToolItem(ToolBar parent, string text, void delegate(Event e) listener, int style = SWT.PUSH, bool selection = false, int index = -1) {
	return basicToolItem(parent, text, null, listener, style, selection, index);
}
/// ditto
ToolItem basicToolItem(ToolBar parent, string text, Image image, void delegate() listener, int style = SWT.PUSH, bool selection = false, int index = -1) {
	return basicToolItem(parent, text, image, listener ? (Event) {
		listener();
	} : null, style, selection, index);
}
/// ditto
ToolItem basicToolItem(ToolBar parent, string text, void delegate() listener, int style = SWT.PUSH, bool selection = false, int index = -1) {
	return basicToolItem(parent, text, null, listener, style, selection, index);
}
/// ditto
ToolItem basicToolItem(ToolBar parent, Control control, int index = -1) {
	ToolItem toolItem;
	if (index < 0) {
		toolItem = new ToolItem(parent, SWT.SEPARATOR);
	} else {
		toolItem = new ToolItem(parent, SWT.SEPARATOR, index);
	}
	toolItem.control = control;
	auto cs = control.computeSize(SWT.DEFAULT, SWT.DEFAULT);
	toolItem.p_width = cs.x;
	return toolItem;
}

/// Creates drop down tool item.
Tuple!(ToolItem, "toolItem", Menu, "menu") dropDownToolItem(ToolBar parent, string text, Image image, void delegate() buttonListener, int index = -1) {
	return dropDownToolItem(parent, text, image, (Event) {
		buttonListener();
	}, index);
}
/// ditto
Tuple!(ToolItem, "toolItem", Menu, "menu") dropDownToolItem(ToolBar parent, string text, Image image, void delegate(Event e) buttonListener, int index = -1) {
	ToolItem toolItem;
	if (index < 0) {
		toolItem = new ToolItem(parent, SWT.DROP_DOWN);
	} else {
		toolItem = new ToolItem(parent, SWT.DROP_DOWN, index);
	}
	initToolItem(toolItem, text, image);
	auto menu = new Menu(parent.p_shell);
	toolItem.p_listeners!(SWT.Selection) ~= (Event e) {
		if (!buttonListener || SWT.ARROW == e.detail) {
			auto b = toolItem.p_bounds;
			menu.p_location = parent.toDisplay(b.x, b.y + b.height);
			menu.p_visible = true;
		} else if (buttonListener) {
			buttonListener(e);
		}
	};
	return typeof(return)(toolItem, menu);
}
/// ditto
Tuple!(ToolItem, "toolItem", Menu, "menu") dropDownToolItem(ToolBar parent, string text, void delegate(Event e) buttonListener, int index = -1) {
	return dropDownToolItem(parent, text, null, buttonListener, index);
}
/// ditto
Tuple!(ToolItem, "toolItem", Menu, "menu") dropDownToolItem(ToolBar parent, string text, void delegate() buttonListener, int index = -1) {
	return dropDownToolItem(parent, text, null, buttonListener, index);
}

/// Common function for tool item.
private void initToolItem(ToolItem toolItem, string text, Image image) {
	text = text.replace("\t", "\n");
	if (image) {
		toolItem.p_toolTipText = text;
		toolItem.p_image = image;
	} else {
		toolItem.p_text = text;
	}
}

/// Creates basic style a menu item and a tool item bound.
MTItem basicMenuItem(Menu menu, ToolBar tool, string text, Image image, void delegate(Event e) listener, int style = SWT.PUSH, bool selection = false, int menuIndex = -1, int toolIndex = -1) {
	typeof(return) result;
	void delegate(Event e) nl = null;
	result.menuItem = basicMenuItem(menu, text, image, nl, style, selection, menuIndex);
	result.toolItem = basicToolItem(tool, text, image, nl, style, selection, toolIndex);
	bindMenu(result.menuItem, result.toolItem);
	if (listener) {
		result.menuItem.p_listeners!(SWT.Selection) ~= listener;
		result.toolItem.p_listeners!(SWT.Selection) ~= listener;
	}
	return result;
}
/// ditto
MTItem basicMenuItem(Menu menu, ToolBar tool, string text, void delegate(Event e) listener, int style = SWT.PUSH, bool selection = false, int menuIndex = -1, int toolIndex = -1) {
	return basicMenuItem(menu, tool, text, null, listener, style, selection, menuIndex, toolIndex);
}
/// ditto
MTItem basicMenuItem(Menu menu, ToolBar tool, string text, Image image, void delegate() listener, int style = SWT.PUSH, bool selection = false, int menuIndex = -1, int toolIndex = -1) {
	return basicMenuItem(menu, tool, text, image, listener ? (Event) {
		listener();
	} : null, style, selection, menuIndex, toolIndex);
}
/// ditto
MTItem basicMenuItem(Menu menu, ToolBar tool, string text, void delegate() listener, int style = SWT.PUSH, bool selection = false, int menuIndex = -1, int toolIndex = -1) {
	return basicMenuItem(menu, tool, text, null, listener, style, selection, menuIndex, toolIndex);
}

/// Creates basic style Label.
Label basicLabel(Composite parent, string text, int style = SWT.NONE) {
	auto lb = new Label(parent, style);
	lb.p_text = text;
	return lb;
}
/// Creates basic style Image box.
Label basicImageBox(Composite parent, Image image, int style = SWT.NONE) {
	auto lb = new Label(parent, style);
	lb.p_image = image;
	return lb;
}

/// Creates basic style Text.
Text basicText(Composite parent, void delegate(Event) modify, string text = "", int style = SWT.BORDER) {
	auto tx = new Text(parent, style);
	tx.p_text = text;
	if (modify) {
		tx.p_listeners!(SWT.Modify) ~= modify;
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
	return basicText(parent, cast(void delegate(Event))null, text, style);
}

/// Creates multi line Text.
Text multiLineText(Composite parent, void delegate(Event) modify, string text = "", int style = SWT.BORDER) {
	return basicText(parent, modify, text, style | SWT.MULTI | SWT.V_SCROLL);
}
/// ditto
Text multiLineText(Composite parent, void delegate() modify, string text = "", int style = SWT.BORDER) {
	return basicText(parent, modify, text, style | SWT.MULTI | SWT.V_SCROLL);
}
/// ditto
Text multiLineText(Composite parent, string text = "", int style = SWT.BORDER) {
	return basicText(parent, text, style | SWT.MULTI | SWT.V_SCROLL);
}

/// Creates basic style button.
Button basicButton(Composite parent, string text, void delegate(Event) selection, int style = SWT.PUSH) {
	return basicButton(parent, text, null, selection, style);
}
/// ditto
Button basicButton(Composite parent, string text, void delegate() selection, int style = SWT.PUSH) {
	return basicButton(parent, text, null, selection, style);
}
/// ditto
Button basicButton(Composite parent, string text, Image image, void delegate(Event) selection, int style = SWT.PUSH) {
	auto bt = new Button(parent, style);
	bt.p_image = image;
	bt.p_text = text;
	if (selection) {
		bt.p_listeners!(SWT.Selection) ~= selection;
	}
	return bt;
}
/// ditto
Button basicButton(Composite parent, string text, Image image, void delegate() selection, int style = SWT.PUSH) {
	return basicButton(parent, text, image, selection ? (Event e) {
		selection();
	} : null, style);
}
/// Creates basic style checkbox.
Button basicCheck(Composite parent, string text, void delegate(Event) selection) {
	return basicButton(parent, text, null, selection, SWT.CHECK);
}
/// ditto
Button basicCheck(Composite parent, string text, void delegate() selection) {
	return basicButton(parent, text, null, selection, SWT.CHECK);
}
/// Creates basic style radiobutton.
Button basicRadio(Composite parent, string text, void delegate(Event) selection) {
	return basicButton(parent, text, null, selection, SWT.RADIO);
}
/// ditto
Button basicRadio(Composite parent, string text, void delegate() selection) {
	return basicButton(parent, text, null, selection, SWT.RADIO);
}

/// Creates no border style Text for number input.
/// When you received ModifyEvent,
/// a checked value is in ModifyEvent.text.
/// A decimal is not-correspond.
Text basicNumber(Composite parent, int min, int max, int style = SWT.BORDER | SWT.RIGHT) {
	auto tx = basicText(parent, to!string(min), style);
	tx.p_textLimit = cast(int)to!string(max).length;

	// When inputting invalid value, old restores it.
	string old = tx.p_text;

	tx.p_listeners!(SWT.FocusOut) ~= (Event e) {
		tx.p_text = old;
	};
	tx.p_listeners!(SWT.FocusIn) ~= (Event e) {
		old = tx.p_text;
	};

	tx.p_listeners!(SWT.Modify) ~= (Event e) {
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

	tx.p_listeners!(SWT.Verify) ~= (Event e) {
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
	combo.p_visibleItemCount = 20;
	if (items) {
		combo.p_items = items;
		if (0 != items.length) {
			combo.select(0);
		}
	}
	return combo;
}

/// Creates basic style Spinner.
Spinner basicSpinner(Composite parent, int min, int max, bool wheelUpDown = true) {
	enforce(min <= max);
	auto spn = new Spinner(parent, SWT.BORDER);
	spn.p_minimum = min;
	spn.p_maximum = max;
	if (wheelUpDown) {
		spn.p_listeners!(SWT.MouseWheel) ~= (Event e) {
			if (0 == e.count) return;
			if (e.count < 0) {
				spn.p_selection = spn.p_selection - spn.p_increment;
			} else {
				assert (0 < e.count);
				spn.p_selection = spn.p_selection + spn.p_increment;
			}
			auto se = new Event;
			se.time = e.time;
			se.stateMask = e.stateMask;
			se.doit = e.doit;
			spn.notifyListeners(SWT.Selection, se);
			e.doit = se.doit;
		};
	}
	return spn;
}

/// Creates basic style ToolTip.
ToolTip basicToolTip(Control parent, bool autoHide = true, string title = "", string message = "", int style = SWT.NONE) {
	auto toolTip = new ToolTip(parent.p_shell, style);
	toolTip.p_text = title;
	toolTip.p_message = message;
	return toolTip;
}

/// Creates basic style List.
List basicList(Composite parent, bool multi, bool check = false) {
	int style = SWT.BORDER | SWT.V_SCROLL;
	style |= multi ? SWT.MULTI : SWT.SINGLE;
	return new List(parent, style);
}

/// Creates basic style Table.
Table basicTable(Composite parent, bool multi, bool check) {
	int style = SWT.BORDER | SWT.V_SCROLL | SWT.FULL_SELECTION;
	style |= multi ? SWT.MULTI : SWT.SINGLE;
	if (check) style |= SWT.CHECK;
	return new Table(parent, style);
}
/// Creates basic style TableColumn.
TableColumn basicTableColumn(Table parent, string text, int index = -1) {
	TableColumn column;
	if (-1 == index) {
		column = new TableColumn(parent, SWT.NONE);
	} else {
		column = new TableColumn(parent, SWT.NONE, index);
	}
	column.p_text = text;
	return column;
}
/// Creates basic style TableItem.
TableItem basicTableItem(Table parent, string text, Image image = null, int index = -1) {
	TableItem item;
	if (-1 == index) {
		item = new TableItem(parent, SWT.NONE);
	} else {
		item = new TableItem(parent, SWT.NONE, index);
	}
	item.p_text = text;
	item.p_image = image;
	return item;
}
/// Creates a Table like list.
Table listTable(Composite parent, bool multi, bool check = false) {
	auto table = basicTable(parent, multi, check);

	// The only column.
	auto column = basicTableColumn(table, "");
	table.p_listeners!(SWT.Resize) ~= {
		column.p_width = table.p_clientArea.width;
	};
	return table;
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
	/// Default value for margin and spacing.
	static immutable WINDOW_MARGIN   = 2;
	static immutable WINDOW_SPACING  = 2; /// ditto
	static immutable MINIMUM_MARGIN  = 1; /// ditto
	static immutable MINIMUM_SPACING = 1; /// ditto

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

	/// Creates new GD.
	@property
	static GD opCall() {
		GD gd;
		gd.data = new GridData;
		return gd;
	}
	/// Creates new GD with style.
	@property
	static GD opCall(int style) {
		GD gd;
		gd.data = new GridData(style);
		return gd;
	}
	/// Creates new GD with fill style.
	@property
	static GD fill(bool horizontal, bool vertical) {
		GD gd;
		int style = SWT.NONE;
		if (horizontal) style |= GridData.FILL_HORIZONTAL;
		if (vertical)   style |= GridData.FILL_VERTICAL;
		gd.data = new GridData(style);
		return gd;
	}
	/// Creates new GD with center position.
	@property
	static GD center(bool horizontal, bool vertical) {
		GD gd;
		gd.data = new GridData;
		if (horizontal) gd.hAlign(SWT.CENTER).hGrabExcessSpace(true);
		if (vertical)   gd.vAlign(SWT.CENTER).vGrabExcessSpace(true);
		return gd;
	}
	/// Creates new GD with begininng position.
	@property
	static GD begin(bool horizontal, bool vertical) {
		GD gd;
		gd.data = new GridData;
		if (horizontal) gd.hAlign(SWT.BEGINNING).hGrabExcessSpace(true);
		if (vertical)   gd.vAlign(SWT.BEGINNING).vGrabExcessSpace(true);
		return gd;
	}
	/// Creates new GD with end position.
	@property
	static GD end(bool horizontal, bool vertical) {
		GD gd;
		gd.data = new GridData;
		if (horizontal) gd.hAlign(SWT.END).hGrabExcessSpace(true);
		if (vertical)   gd.vAlign(SWT.END).vGrabExcessSpace(true);
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

	/// Sets data.horizontalAlignment and data.verticalAlignment.
	GD alignment(int horizontalAlignment, int verticalAlignment) {
		return hAlign(horizontalAlignment).vAlign(verticalAlignment);
	}
	/// Sets data.horizontalSpan.
	GD hAlign(int alignment) {
		data.horizontalAlignment = alignment;
		return this;
	}
	/// Sets data.verticalSpan.
	GD vAlign(int alignment) {
		data.verticalAlignment = alignment;
		return this;
	}

	/// Sets data.grabExcessHorizontalSpace and data.grabExcessVerticalSpace.
	GD grabExcessSpace(bool grabExcessHorizontalSpace, bool grabExcessVerticalSpace) {
		return hGrabExcessSpace(grabExcessHorizontalSpace).vGrabExcessSpace(grabExcessVerticalSpace);
	}
	/// Sets data.horizontalSpan.
	GD hGrabExcessSpace(bool grab) {
		data.grabExcessHorizontalSpace = grab;
		return this;
	}
	/// Sets data.verticalSpan.
	GD vGrabExcessSpace(bool grab) {
		data.grabExcessVerticalSpace = grab;
		return this;
	}
}

/// A wrapper for settings to a FormLayout.
struct FL {
	/// FormLayout.
	FormLayout data = null;
	/// ditto
	alias data this;

	/// Create new FL with wMargin and hMargin.
	@property
	static FL opCall(int wMargin = SWT.DEFAULT, int hMargin = SWT.DEFAULT) {
		FL fl;
		if (SWT.DEFAULT != wMargin) fl.wMargin = wMargin;
		if (SWT.DEFAULT != hMargin) fl.hMargin = hMargin;
		return fl;
	}

	/// Sets data.marginWidth and data.marginHeight
	@property
	FL margin(int margin) {
		return wMargin(margin).hMargin(margin);
	}
	/// Sets data.marginWidth.
	@property
	FL wMargin(int margin) {
		data.marginWidth = margin;
		return this;
	}
	/// Sets data.marginHeight.
	@property
	FL hMargin(int margin) {
		data.marginHeight = margin;
		return this;
	}
}

/// A wrapper for settings to a FormData.
struct FD {
	/// FormData.
	FormData data = null;
	/// ditto
	alias data this;

	/// Creates new FD with size.
	static FD opCall(int width = SWT.DEFAULT, int height = SWT.DEFAULT) {
		FD fd;
		fd.data = new FormData;
		if (SWT.DEFAULT != width)  fd.width  = width;
		if (SWT.DEFAULT != height) fd.height = height;
		return fd;
	}
	/// Creates new FD with FormAttachment.
	/// Sets null to be not used direction.
	static FD opCall(FormAttachment top, FormAttachment right, FormAttachment bottom, FormAttachment left) {
		FD fd;
		fd.data = new FormData;

		fd.top    = top;
		fd.right  = right;
		fd.bottom = bottom;
		fd.left   = left;

		return fd;
	}

	/// Sets data.width and data.height.
	FD size(int width, int height) {
		return this.width(width).height(height);
	}
	/// ditto
	@property
	FD width(int width) {
		data.width = width;
		return this;
	}
	/// ditto
	@property
	FD height(int height) {
		data.height = height;
		return this;
	}

	/// Sets data.top and data.right and data.bottom and data.left.
	FD atachment(FormAttachment top, FormAttachment right, FormAttachment bottom, FormAttachment left) {
		return this.top(top).right(right).bottom(bottom).left(left);
	}
	/// ditto
	@property
	FD top(FormAttachment top) {
		data.top = top;
		return this;
	}
	/// ditto
	@property
	FD right(FormAttachment right) {
		data.right = right;
		return this;
	}
	/// ditto
	@property
	FD bottom(FormAttachment bottom) {
		data.bottom = bottom;
		return this;
	}
	/// ditto
	@property
	FD left(FormAttachment left) {
		data.left = left;
		return this;
	}
}


/// A wrapper for settings to a FormAttachment.
struct FA {
	/// FormAttachment.
	FormAttachment data = null;
	/// ditto
	alias data this;

	/// Creates new FA with parameters.
	static FA opCall(Control control) {
		FA fa;
		fa.data = new FormAttachment(control);
		return fa;
	}
	/// ditto
	static FA opCall(Control control, int offset) {
		auto fa = FA(control);
		fa.offset = offset;
		return fa;
	}
	/// ditto
	static FA opCall(Control control, int offset, int alignment) {
		auto fa = FA(control, offset);
		fa.alignment = alignment;
		return fa;
	}
	/// ditto
	static FA opCall(int numerator, int offset = 0) {
		FA fa;
		fa.data = new FormAttachment(numerator, offset);
		return fa;
	}
	/// ditto
	static FA opCall(int numerator, int denominator, int offset) {
		auto fa = FA(numerator, offset);
		fa.denominator = denominator;
		return fa;
	}

	/// Sets data.numerator.
	@property
	FA numerator(int numerator) {
		data.numerator = numerator;
		return this;
	}
	/// Sets data.denominator.
	@property
	FA denominator(int denominator) {
		data.denominator = denominator;
		return this;
	}
	/// Sets data.offset.
	@property
	FA offset(int offset) {
		data.offset = offset;
		return this;
	}
	/// Sets data.control.
	@property
	FA control(Control control) {
		data.control = control;
		return this;
	}
	/// Sets data.alignment.
	@property
	FA alignment(int alignment) {
		data.alignment = alignment;
		return this;
	}
}
