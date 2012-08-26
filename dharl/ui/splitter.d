
/// This module includes Splitter and members related to it. 
///
/// License: Public Domain
/// Authors: kntroh
module dharl.ui.splitter;

private import dwtutils.utils;

private import std.algorithm;

private import org.eclipse.swt.all;

/// Creates basic style splitter.
Splitter basicSplitter(Composite parent, int style = SWT.HORIZONTAL) {
	auto splitter = new Splitter(parent, style);
	return splitter;
}
/// ditto
Splitter basicHSplitter(Composite parent) {
	return basicSplitter(parent, SWT.HORIZONTAL);
}
/// ditto
Splitter basicVSplitter(Composite parent) {
	return basicSplitter(parent, SWT.VERTICAL);
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
	/// Width or height of before resizing.
	private int _oldSize = -1;

	/// The only constructor.
	/// The default splitting style is SWT.HORIZONTAL.
	this (Composite parent, int style) {
		_splitStyle = (style & SWT.VERTICAL) ? SWT.VERTICAL : SWT.HORIZONTAL;
		super (parent, style & !SWT.HORIZONTAL & !SWT.VERTICAL);

		super.setLayout(new SplitterLayout);
		_sash = new Sash(this, SWT.VERTICAL == splitStyle ? SWT.HORIZONTAL : SWT.VERTICAL);

		// Handle sash moved event.
		_sash.listeners!(SWT.Selection) ~= (Event e) {
			checkWidget();

			if (SWT.VERTICAL == splitStyle) {
				this.p_selection = e.y;
			} else {
				this.p_selection = e.x;
			}

			if (SWT.VERTICAL == splitStyle) {
				e.y = this.p_selection;
			} else {
				e.x = this.p_selection;
			}

			raiseSelectionEvent(e);
		};

		// Sash follows bottom or right line
		// when maximized top or left control.
		this.listeners!(SWT.Resize) ~= (Event e) {
			checkWidget();
			auto children = this.p_children;
			if (2 > children.length) return;
			auto ca = this.p_clientArea;

			int oldSize = _oldSize;
			int newSize;
			if (SWT.VERTICAL == splitStyle) {
				newSize = ca.height;
			} else {
				newSize = ca.width;
			}
			_oldSize = newSize;

			auto a = children[0];
			auto b = children[1];

			if (_selection < 0) {
				// initialize
				this.p_selection = SWT.DEFAULT;
			}

			scope (exit) raiseSelectionEvent(e);

			if (_resizable is a) {
				if (-1 == oldSize) return;
				if (!a.p_visible) return;

				// Resizes top or left control.
				this.p_selection = this.p_selection + (newSize - oldSize);
			} else {
				// Only if B is minimized.
				if (b.p_visible) return;

				auto bw = this.p_borderWidth;
				if (SWT.VERTICAL == splitStyle) {
					this.p_selection = ca.height - bw;
				} else {
					this.p_selection = ca.width - bw;
				}
			}
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
	/// If value is less 0, value goes to half client area size.
	void setSelection(int value) {
		checkWidget();
		auto ca = this.p_clientArea;

		if (value < 0) {
			if (SWT.VERTICAL == splitStyle) {
				if (0 < ca.height) {
					value = ca.height / 2 - sashWidth / 2;
				}
			} else {
				if (0 < ca.width) {
					value = ca.width / 2 - sashWidth / 2;
				}
			}
		}
		_selection = value;

		if (0 == ca.width || 0 == ca.height) return;

		// maximize when space is small
		auto children = this.p_children;
		if (2 > children.length) return;

		auto a = children[0];
		auto b = children[1];

		int rightOrBottom;
		if (SWT.VERTICAL == splitStyle) {
			rightOrBottom = ca.height;
		} else {
			rightOrBottom = ca.width;
		}
		auto bw = this.p_borderWidth;
		if (_selection - bw < dragMinimum) {
			_selection = bw;
			a.p_visible = false;
		} else {
			a.p_visible = true;
		}
		if (rightOrBottom - bw - _selection < dragMinimum) {
			_selection = rightOrBottom - bw;
			b.p_visible = false;
		} else {
			b.p_visible = true;
		}

		layout(true);
	}
	/// ditto
	int getSelection() {
		checkWidget();
		return _selection;
	}

	/// When resized this splitter, c will be resized.
	/// Default value is null.
	@property
	void resizable(Control c) {
		checkWidget();
		if (this !is c.p_parent) {
			SWT.error(__FILE__, __LINE__, SWT.ERROR_INVALID_ARGUMENT);
		}
		_resizable = c;
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
			if (SWT.VERTICAL == splitStyle) {
				_oldSize = ca.height;

				int y = bw;
				if (a.p_visible) {
					a.setBounds(0, y, ca.width, _selection);
					y += this.outer.p_selection;
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
				_oldSize = ca.width;

				int x = bw;
				if (a.p_visible) {
					a.setBounds(x, 0, _selection, ca.height);
					x += this.outer.p_selection;
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
