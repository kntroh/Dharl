
/// This module include UndoManager and members related to it. 
module dharl.util.undomanager;

private import dharl.util.utils;

private import std.exception;

/// Undo / Redo mode. TODO comment
enum UndoMode {
	Undo, /// Undo.
	Redo /// Redo.
}

/// Undo / Redo manager class. TODO comment
class UndoManager {
	/// Status changed event receivers. TODO comment
	void delegate()[] statusChangedReceivers;

	/// Maximum capacity of _stack. TODO comment
	private size_t _capacity;

	/// Stack for Undoable classes. TODO comment
	private Undoable[][] _stack;
	/// Stack for store data from Undoable classes. TODO comment
	private Object[][] _dataStack;
	/// Pointer of _stack. TODO comment
	private size_t _pointer = 0;

	/// TODO comment
	private string _retryWord = null;

	/// The only constructor.
	this (size_t capacity) {
		_capacity = capacity;
	}

	/// Clears undo stack. TODO comment
	void clear() {
		_stack.length = 0;
		_dataStack.length = 0;
		_pointer = 0;
		_retryWord = null;
		statusChangedReceivers.raiseEvent();
	}

	/// Gets stack size now. TODO comment
	@property
	const
	size_t stackSize() { return _stack.length; }

	/// Executes undo. TODO comment
	void undo() {
		undoRedoImpl(&canUndo, UndoMode.Undo);
	}
	/// Executes redo. TODO comment
	void redo() {
		undoRedoImpl(&canRedo, UndoMode.Redo);
	}
	/// Executes undo or redo. TODO comment
	private void undoRedoImpl(bool delegate() can, UndoMode mode) {
		if (!can()) return;
		resetRetryWord();
		while (can()) {
			if (UndoMode.Undo == mode) {
				_pointer--;
			}
			auto us = _stack[_pointer];
			auto data = new Object[us.length];
			foreach (i, u; us) {
				if (!u.enabledUndo) continue;
				data[i] = u.storeData;
			}
			bool enbl = false;
			foreach (i, u; us) {
				if (!u.enabledUndo) continue;
				enbl = true;
				u.restore(_dataStack[_pointer][i], mode);
				_dataStack[_pointer][i] = data[i];
			}
			if (UndoMode.Redo == mode) {
				_pointer++;
			}
			if (enbl) {
				raiseEvent(statusChangedReceivers);
				break;
			}
		}
	}

	/// If can undo or redo returns true. TODO comment
	@property
	bool canUndo() {
		if (0 == _pointer) return false;
		foreach (i; 0 .. _pointer) {
			foreach (u; _stack[i]) {
				if (u.enabledUndo) return true;
			}
		}
		return false;
	}
	/// ditto
	@property
	bool canRedo() {
		if (_pointer >= _stack.length) return false;
		foreach (i; _pointer .. _stack.length) {
			foreach (u; _stack[i]) {
				if (u.enabledUndo) return true;
			}
		}
		return false;
	}

	/// Stores undoable class. TODO comment
	bool store(Undoable u, bool delegate() func = null, string retryWord = null) {
		auto us = [u];
		return store(us, func, retryWord);
	}
	/// ditto
	bool store(Undoable[] us, bool delegate() func = null, string retryWord = null) {
		enforce(us);
		if (retryWord && _retryWord && retryWord == _retryWord) {
			return false;
		}
		if (0 == _capacity) return false;
		bool enbl = false;
		foreach (u; us) {
			enforce(u);
			if (u.enabledUndo) {
				enbl = true;
				break;
			}
		}
		if (!enbl) return false;
		_retryWord = retryWord;

		auto data = new Object[us.length];
		foreach (i, ref d; data) {
			d = us[i].storeData;
		}
		if (func && !func()) {
			return false;
		}
		if (_pointer < _stack.length) {
			_stack[_pointer] = us.dup;
			_dataStack[_pointer] = data;
			_pointer++;
			if (_stack.length != _pointer) {
				_stack.length = _pointer;
				_dataStack.length = _pointer;
			}
		} else if (_capacity <= _stack.length) {
			foreach (i; 0 .. _capacity - 1) {
				_stack[i] = _stack[i + 1];
				_dataStack[i] = _dataStack[i + 1];
			}
			_stack[$ - 1] = us.dup;
			_dataStack[$ - 1] = data;
		} else {
			_stack ~= us.dup;
			_dataStack ~= data;
			_pointer = _stack.length;
		}
		statusChangedReceivers.raiseEvent();
		return true;
	}

	/// TODO comment
	void resetRetryWord() {
		_retryWord = null;
	}
} unittest {
	auto um = new UndoManager(3);
	class Text : Undoable {
		string s;
		@property
		void text(string s) {
			um.store(this);
			this.s = s;
		}
		@property
		override Object storeData() {
			auto t = new Text;
			t.s = s;
			return t;
		}
		override void restore(Object data, UndoMode mode) {
			auto t = cast(Text) data;
			s = t.s;
		}
		@property
		override bool enabledUndo() { return true; }
	}
	auto text = new Text;
	text.text = "a";
	text.text = "b";

	assert (text.s == "b");
	assert (um.canUndo);
	um.undo();
	assert (text.s == "a");
	assert (um.canUndo);
	um.undo();
	assert (text.s == "");
	assert (!um.canUndo);

	assert (um.canRedo);
	um.redo();
	assert (text.s == "a");
	assert (um.canRedo);
	um.redo();
	assert (text.s == "b");
	assert (!um.canRedo);

	um.undo();
	um.undo();
	assert (text.s == "");

	text.text = "a";
	text.text = "b";
	text.text = "c";
	text.text = "d";
	assert (text.s == "d");
	assert (um.canUndo);
	um.undo();
	assert (text.s == "c");
	assert (um.canUndo);
	um.undo();
	assert (text.s == "b");
	assert (um.canUndo);
	um.undo();
	assert (text.s == "a");
	assert (!um.canUndo);
}

/// Can undo class implements this. TODO comment.
interface Undoable {
	/// TODO comment
	@property
	Object storeData();
	/// TODO comment
	void restore(Object data, UndoMode mode);
	/// TODO comment
	@property
	bool enabledUndo();
}
