
/// This module includes utilities for DWT.
module dharl.ui.dwtutils;

public import dwtutils.utils;
public import dwtutils.wrapper;

private import util.graphics;
private import util.types;
private import util.utils;

private import dharl.ui.splitter;

private import std.algorithm;
private import std.conv;
private import std.exception;
private import std.math;
private import std.path;
private import std.range;
private import std.string;
private import std.typecons;

private import org.eclipse.swt.all;

/// A MouseWheel event send to a control under the cursor always.
void initMouseWheel(Shell shell) {
	auto d = shell.p_display;
	d.p_filters!(SWT.MouseWheel) ~= (Event e) {
		.enforce(SWT.MouseWheel == e.type);

		auto c = d.p_cursorControl();
		if (!c) return; // no cursor control
		auto w = cast(Control) e.widget;
		if (!w) return; // sender isn't control
		if (w is c) return; // focus control is cursor control

		if (c.p_shell !is shell) return; // out of shell

		// All parent controls of c receive a wheel event.
		if (w.descendant(c)) return;

		auto se = new Event;
		se.type = e.type;
		se.widget = c;
		se.time = e.time;
		se.stateMask = e.stateMask;
		se.doit = e.doit;

		auto p = c.toControl(w.toDisplay(e.x, e.y));
		se.button = e.button;
		se.x = p.x;
		se.y = p.y;
		se.count = e.count;

		c.notifyListeners(se.type, se);

		// smother
		e.doit = false;
		e.count = 0;
		e.button = 0;
	};
}

/// Sets parameters to shell from param.
/// And save parameters when disposed shell.
void refWindow(ref WindowParameter param, Shell shell) {
	int x = param.x;
	int y = param.y;
	int w = param.width;
	int h = param.height;
	if (x == int.min) x = SWT.DEFAULT;
	if (y == int.min) y = SWT.DEFAULT;
	if (w <= 0 || h <= 0) {
		auto size = shell.computeSize(SWT.DEFAULT, SWT.DEFAULT);
		if (w <= 0) w = size.x;
		if (h <= 0) h = size.y;
	}

	Rectangle pBounds = null;
	auto parent = shell.p_parent;
	if (parent) {
		// relative position
		pBounds = parent.p_bounds;
		int px = pBounds.x;
		int py = pBounds.y;
		int pw = pBounds.width;
		int ph = pBounds.height;
		x = (SWT.DEFAULT == x) ? (x + (pw - w) / 2) : (px + x);
		y = (SWT.DEFAULT == y) ? (y + (ph - h) / 2) : (py + y);
	}

	shell.p_bounds = CRect(x, y, w, h);
	shell.p_maximized = param.maximized;
	shell.p_minimized = param.minimized;

	shell.listeners!(SWT.Dispose) ~= (Event e) {
		auto b = shell.p_bounds;
		auto parent = shell.p_parent;
		if (parent) {
			// relative position
			pBounds = parent.p_bounds;
			param.x = b.x - pBounds.x;
			param.y = b.y - pBounds.y;
		} else {
			param.x = b.x;
			param.y = b.y;
		}
		param.width  = b.width;
		param.height = b.height;
		param.maximized = shell.p_maximized;
		param.minimized = shell.p_minimized;
	};
}

/// Sets width and height to two spinners.
/// And save value when disposed spinners.
void refSize(ref PSize size, Spinner width, Spinner height) {
	width.p_selection  = size.width;
	height.p_selection = size.height;
	width.listeners!(SWT.Dispose) ~= (Event e) {
		size.width  = width.p_selection;
	};
	height.listeners!(SWT.Dispose) ~= (Event e) {
		size.height = height.p_selection;
	};
}

/// Sets value to control.
/// And save value when disposed control.
void refSelection(C, V)(ref V value, C control) {
	control.p_selection = value;
	control.listeners!(SWT.Dispose) ~= (Event e) {
		value = control.p_selection;
	};
}

/// Sets selection index to radios.
/// And save index when disposed radios.
void refRadioSelection(C, V)(ref V index, C[] radios) {
	.enforce(radios.length);
	int index2 = index.roundCast!int(0, radios.length - 1);
	foreach (i, radio; radios) {
		radio.p_selection = (i == index2);
	}
	radios[0].listeners!(SWT.Dispose) ~= (Event e) {
		foreach (i, radio; radios) {
			if (radio.p_selection) {
				index = i;
				break;
			}
		}
	};
}

/// Sets index to control.
/// And save index when disposed control.
void refSelectionIndex(C, V)(ref V index, C control, bool canNoSelection = false) {
	int min = canNoSelection ? -1 : 0;
	control.select(index.roundCast(min, control.p_itemCount - 1));
	control.listeners!(SWT.Dispose) ~= (Event e) {
		index = control.p_selectionIndex;
	};
}

/// Sets text to control.
/// And save text when disposed control.
void refText(C, V)(ref V text, C control) {
	control.p_text = text;
	control.listeners!(SWT.Dispose) ~= (Event e) {
		text = control.p_text;
	};
}

/// Show message dialog.
int showMessage(Shell parent, string msg, string title, int style = SWT.OK | SWT.ICON_INFORMATION) {
	if (!parent) {
		SWT.error(__FILE__, __LINE__, SWT.ERROR_NULL_ARGUMENT);
	}
	auto dialog = new MessageBox(parent, style);
	dialog.p_text = title;
	dialog.p_message = msg;
	return dialog.open();
}
/// Show yes / no dialog.
int showYesNoDialog(Shell parent, string msg, string title) {
	return showMessage(parent, msg, title, SWT.YES | SWT.NO | SWT.ICON_QUESTION);
}
/// Show yes / no / cancel dialog.
int showYesNoCancelDialog(Shell parent, string msg, string title) {
	return showMessage(parent, msg, title, SWT.YES | SWT.NO | SWT.CANCEL | SWT.ICON_QUESTION);
}
/// Show warning dialog.
int showWarningDialog(Shell parent, string msg, string title) {
	return showMessage(parent, msg, title, SWT.OK | SWT.ICON_WARNING);
}
/// Show error dialog.
int showErrorDialog(Shell parent, string msg, string title) {
	return showMessage(parent, msg, title, SWT.OK | SWT.ICON_ERROR);
}

/// Creates select folder field.
Tuple!(Text, "text", Composite, "pane") folderField(Composite parent, string dialogTitle, string dialogMessage, string selectButton = "...") {
	auto area = basicComposite(parent);
	area.p_layout = GL.noMargin(2, false);
	auto field = basicText(area, "");
	field.p_layoutData = GD.fill(true, false);
	basicButton(area, selectButton, {
		auto dialog = new DirectoryDialog(field.p_shell);
		dialog.p_text = dialogTitle;
		dialog.p_message = dialogMessage;
		dialog.p_filterPath = field.p_text;
		auto result = dialog.open();
		if (result !is null) {
			field.p_text = dialog.p_filterPath.absolutePath().buildNormalizedPath();
		}
	});
	return typeof(return)(field, area);
}

/// Creates font for pixel number text in box.
Font pixelTextFont(Display d, Font base, int boxWidth, int boxHeight) {
	auto fontName = base ? base.p_fontData[0].p_name : "";
	auto dpi = d.p_dpi;
	auto fontWidth  = cast(int) pixelToPoint(boxWidth  - 2 * 2, dpi.x);
	auto fontHeight = cast(int) pixelToPoint(boxHeight - 2 * 2, dpi.y);
	return new Font(d, fontName, .min(fontWidth, fontHeight), SWT.NONE);
}
/// Selects system color for pixel number text in box.
Color pixelTextColor(Display d, in RGB rgb) {
	if (rgb.red + rgb.green + rgb.blue < 128 * 3) {
		return d.getSystemColor(SWT.COLOR_WHITE);
	} else {
		return d.getSystemColor(SWT.COLOR_BLACK);
	}
}

/// Draws alternately different color lines,
/// to raise the visibility.
void drawColorfulFocus(GC gc, Color color1, Color color2, int x, int y, int w, int h) {
	auto fore = gc.p_foreground;
	scope (exit) gc.p_foreground = fore;
	int oldStyle = gc.p_lineStyle;
	scope (exit) gc.p_lineStyle = oldStyle;
	int[] oldDash = gc.p_lineDash;
	scope (exit) gc.p_lineDash = oldDash;

	gc.p_lineStyle = SWT.LINE_SOLID;
	gc.p_foreground = color1;
	gc.drawRectangle(x, y, w, h);

	gc.p_lineStyle = SWT.LINE_DASH;
	int[] cLineDash = [2, 3];
	gc.p_lineDash = cLineDash;
	gc.p_foreground = color2;
	gc.drawRectangle(x, y, w, h);
}
/// ditto
void drawColorfulFocus(GC gc, Color color1, Color color2, Rectangle rect) {
	drawColorfulFocus(gc, color1, color2, rect.x, rect.y, rect.width, rect.height);
}

/// Shading to client area.
void drawShade(GC gc, in Rectangle clientArea) {
	static const cSHADE_INTERVAL = 8;
	int cwh = clientArea.width + clientArea.height;
	for (size_t c = 0; c < cwh; c += cSHADE_INTERVAL) {
		gc.drawLine(c, 0, 0, c);
		gc.drawLine(c - clientArea.height, 0, c, clientArea.height);
	}
}
