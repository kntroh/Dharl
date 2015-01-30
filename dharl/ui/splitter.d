
/// This module includes Splitter and members related to it. 
///
/// License: Public Domain
/// Authors: kntroh
module dharl.ui.splitter;

private import dwtutils.utils;

private import std.algorithm;

private import org.eclipse.swt.all;

/// Creates basic style splitter.
Splitter basicSplitter(Composite parent, bool maximizable, int style = SWT.HORIZONTAL) {
	if (maximizable) style |= SWT.MAX;
	auto splitter = new Splitter(parent, style);
	return splitter;
}
/// ditto
Splitter basicHSplitter(Composite parent, bool maximizable) {
	return basicSplitter(parent, maximizable, SWT.HORIZONTAL);
}
/// ditto
Splitter basicVSplitter(Composite parent, bool maximizable) {
	return basicSplitter(parent, maximizable, SWT.VERTICAL);
}

/// This control is show two child controls, and show sash between there.
class Splitter : Composite {

	/// This sash splits area with left and right or top and bottom.
	private Sash _sash;

	/// Style value of split direction.
	private int _splitStyle;

	/// The split position.
	private int _selection = SWT.DEFAULT;

	/// Minimum width of splitted one area.
	private int _dragMinimum = 20;

	/// Width of sash.
	private int _sashWidth = 5;

	/// When resized this splitter, this control will be resized.
	private Control _resizable = null;

	/// The only constructor.
	/// The default splitting style is SWT.HORIZONTAL.
	this (Composite parent, int style) {
		_splitStyle = (style & SWT.VERTICAL) ? SWT.VERTICAL : SWT.HORIZONTAL;
		super (parent, style & ~(SWT.HORIZONTAL | SWT.VERTICAL));

		super.setLayout(new SplitterLayout);
		_sash = new Sash(this, SWT.VERTICAL == splitStyle ? SWT.HORIZONTAL : SWT.VERTICAL);

		// Handle sash moved event.
		_sash.p_listeners!(SWT.Selection) ~= (Event e) {
			checkWidget();
			auto children = this.p_children;
			if (2 > children.length) return;
			auto ca = this.p_clientArea;

			auto a = children[0];

			auto bw = this.p_borderWidth;
			if (SWT.VERTICAL == splitStyle) {
				if (_resizable is a) {
					this.p_selection = adjustSelection(ca.height - bw - e.y);
					e.y = ca.height - bw - this.p_selection; // overwrite with adjusted value
				} else {
					this.p_selection = adjustSelection(e.y);
					e.y = this.p_selection; // overwrite with adjusted value
				}
			} else {
				if (_resizable is a) {
					this.p_selection = adjustSelection(ca.width - bw - e.x);
					e.x = ca.width - bw - this.p_selection; // overwrite with adjusted value
				} else {
					this.p_selection = adjustSelection(e.x);
					e.x = this.p_selection; // overwrite with adjusted value
				}
			}

			raiseSelectionEvent(e);
		};
	}

	override Control[] getChildren() {
		checkWidget();
		return super.getChildren()[1 .. $];
	}
	/// Doesn't work.
	override void setLayout(Layout layout) {
		checkWidget();
	}

	override Point computeSize(int wHint, int hHint, bool changed) {
		checkWidget();
		auto children = this.p_children;
		if (2 > children.length) return CPoint(0, 0);

		int w = 0, h = 0;
		if (SWT.DEFAULT == wHint || SWT.DEFAULT == hHint) {
			foreach (c; children) {
				auto size = c.computeSize(SWT.DEFAULT, SWT.DEFAULT);
				if (SWT.VERTICAL == splitStyle) {
					w = .max(size.x, w);
					h += size.y;
				} else {
					w += size.x;
					h = .max(size.y, h);
				}
			}
			if (SWT.VERTICAL == splitStyle) {
				h += sashWidth;
			} else {
				w += sashWidth;
			}
		}

		int cbw = this.p_borderWidth * 2;
		int cw = (wHint == SWT.DEFAULT) ? w + cbw : wHint;
		int ch = (hHint == SWT.DEFAULT) ? h + cbw : hHint;
		return CPoint(cw, ch);
	}

	/// returns SWT.HORIZONTAL or SWT.VERTICAL.
	@property
	const
	private int splitStyle() { return _splitStyle; }

	/// The split position.
	/// A value is equals width (or height) of the resizable.
	/// If value is less 0, value goes to half client area size.
	void setSelection(int value) {
		checkWidget();

		_selection = value;

		if (SWT.MAX & this.p_style) {
			auto ca = this.p_clientArea;
			if (0 == ca.width || 0 == ca.height) return;

			auto children = this.p_children;
			if (2 > children.length) return;

			auto bw = this.p_borderWidth;

			// maximize when space is small
			Control a, b;
			if (_resizable is children[0]) {
				a = children[1];
				b = children[0];
			} else {
				a = children[0];
				b = children[1];
			}
			auto selection = adjustSelection(value);
			a.p_visible = dragMinimum <= selection - bw;
			b.p_visible = dragMinimum <= rightOrBottom - bw - selection;
		}

		layout(true);
	}
	/// ditto
	int getSelection() {
		checkWidget();
		return _selection;
	}

	/// Adjusts split position to fit in the client area.
	int adjustSelection(int value) {
		checkWidget();
		auto ca = this.p_clientArea;
		if (0 == ca.width || 0 == ca.height) return value;

		if (value < 0) {
			if (SWT.VERTICAL == splitStyle) {
				value = ca.height / 2 - sashWidth / 2;
			} else {
				value = ca.width / 2 - sashWidth / 2;
			}
		}

		auto children = this.p_children;
		if (2 > children.length) return value;

		auto bw = this.p_borderWidth;

		if (SWT.MAX & this.p_style) {
			// maximize when space is small
			if (value - bw < dragMinimum) {
				value = bw;
			}
			if (rightOrBottom - bw - value < dragMinimum) {
				value = rightOrBottom - bw;
			}
		} else {
			// ensure minimal space
			if (value - bw < dragMinimum) {
				value = bw + dragMinimum;
			}
			if (rightOrBottom - bw - value < dragMinimum) {
				value = rightOrBottom - bw - dragMinimum;
			}
		}

		return value;
	}

	/// Client size of split direction.
	@property
	private int rightOrBottom() {
		checkWidget();
		auto ca = this.p_clientArea;

		if (SWT.VERTICAL == splitStyle) {
			return ca.height;
		} else {
			return ca.width;
		}
	}

	/// When resized this splitter, c will be resized.
	/// Default value is null.
	@property
	void resizable(Control c) {
		checkWidget();
		if (c && this !is c.p_parent) {
			SWT.error(__FILE__, __LINE__, SWT.ERROR_INVALID_ARGUMENT);
		}
		bool resizeRight1 = false, resizeRight2 = false;
		auto children = this.p_children;
		if (2 <= children.length) {
			auto a = children[0];
			resizeRight1 = _resizable is a;
			resizeRight2 = c is a;
		}

		_resizable = c;

		if (resizeRight1 != resizeRight2) {
			// adjusts sash position
			auto ca = this.p_clientArea;
			auto size = SWT.VERTICAL == splitStyle ? ca.height : ca.width;
			size -= this.p_borderWidth * 2;
			this.p_selection = size - sashWidth - this.p_selection;
		}
	}
	/// ditto
	@property
	Control resizable() {
		checkWidget();
		return _resizable;
	}

	/// Minimum width of splitted one area.
	@property
	void dragMinimum(int value) {
		checkWidget();
		_dragMinimum = value;
		// recalculate for layout
		this.p_selection = this.p_selection;
	}
	/// ditto
	@property
	const
	int dragMinimum() { return _dragMinimum; }

	/// Minimum width of splitted one area.
	@property
	void sashWidth(int value) {
		checkWidget();
		if (value < 1) {
			SWT.error(__FILE__, __LINE__, SWT.ERROR_INVALID_ARGUMENT);
		}

		_sashWidth = value;
		// recalculate for layout
		this.p_selection = this.p_selection;
	}
	/// ditto
	@property
	const
	int sashWidth() { return _sashWidth; }

	/// Raises selection event.
	private void raiseSelectionEvent(Event e) {
		auto se = new Event;
		se.widget = this;
		se.time = e.time;
		se.stateMask = e.stateMask;
		se.doit = e.doit;

		auto size = _sash.p_size;
		se.width = size.x;
		se.height = size.y;
		if (SWT.VERTICAL == splitStyle) {
			se.y = this.p_selection;
		} else {
			se.x = this.p_selection;
		}

		notifyListeners(SWT.Selection, se);
		e.doit = se.doit;
	}

	/// Adds or removes a listener for sash moved event.
	void addSelectionListener(SelectionListener listener) {
		checkWidget();
		if (!listener) {
			SWT.error(__FILE__, __LINE__, SWT.ERROR_NULL_ARGUMENT);
		}
		auto tl = new TypedListener(listener);
		addListener(SWT.Selection, tl);
		addListener(SWT.DefaultSelection, tl);
	}
	/// ditto
	void removeSelectionListener(SelectionListener listener) {
		checkWidget();
		if (!listener) {
			SWT.error(__FILE__, __LINE__, SWT.ERROR_NULL_ARGUMENT);
		}
		removeListener(SWT.Selection, listener);
		removeListener(SWT.DefaultSelection, listener);
	}

	/// Layout of splitter.
	private class SplitterLayout : Layout {

		protected override Point computeSize(Composite composite, int wHint, int hHint, bool flushCache) {
			return composite.computeSize(wHint, hHint);
		}

		protected override void layout(Composite composite, bool flushCache) {
			auto ca = composite.p_clientArea;
			auto children = composite.p_children;
			if (2 > children.length) return;

			auto a = children[0];
			auto b = children[1];

			auto bw = composite.p_borderWidth;
			auto selection = adjustSelection(this.outer.p_selection);
			if (SWT.VERTICAL == splitStyle) {
				if (_resizable is a) {
					selection = ca.height - bw - selection;
				}

				int y = bw;
				if (a.p_visible) {
					a.setBounds(0, y, ca.width, selection);
					y += selection;
				}
				if (b.p_visible) {
					_sash.setBounds(0, y, ca.width, sashWidth);
					y += sashWidth;
					b.setBounds(0, y, ca.width, ca.height - bw - y);
				} else {
					y = ca.height - bw - sashWidth;
					_sash.setBounds(0, y, ca.width, sashWidth);
				}
			} else {
				if (_resizable is a) {
					selection = ca.width - bw - selection;
				}

				int x = bw;
				if (a.p_visible) {
					a.setBounds(x, 0, selection, ca.height);
					x += selection;
				}
				if (b.p_visible) {
					_sash.setBounds(x, 0, sashWidth, ca.height);
					x += sashWidth;
					b.setBounds(x, 0, ca.width - bw - x, ca.height);
				} else {
					x = ca.width - bw - sashWidth;
					_sash.setBounds(x, 0, sashWidth, ca.height);
				}
			}
		}
	}
}
