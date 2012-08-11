
/// This module include UndoManager and members related to it. 
module dharl.util.undomanager;

private import dharl.util.utils;

private import std.exception;

/// Mode of undo or redo.
enum UndoMode {
	Undo, /// Undo.
	Redo /// Redo.
}

/// Manager class for undo and redo.
class UndoManager {
	/// Receivers of status changed event.
	void delegate()[] statusChangedReceivers;

	/// Maximum capacity of _stack.
	private size_t _capacity;

	/// Stack of Undoable classes.
	private Undoable[][] _stack;
	/// Stack of store data from Undoable classes.
	private Object[][] _dataStack;
	/// Pointer of _stack.
	private size_t _pointer = 0;

	/// Last retry-word.
	/// If this received continue same retry-word,
	/// undo operation will return to a first one.
	private string _retryWord = null;

	/// The only constructor.
	this (size_t capacity) {
		_capacity = capacity;
	}

	/// Clears undo stack.
	void clear() {
		_stack.length = 0;
		_dataStack.length = 0;
		_pointer = 0;
		_retryWord = null;
		statusChangedReceivers.raiseEvent();
	}

	/// Gets stack size now.
	@property
	const
	size_t stackSize() { return _stack.length; }

	/// Executes undo.
	void undo() {
		undoRedoImpl(&canUndo, UndoMode.Undo);
	}
	/// Executes redo.
	void redo() {
		undoRedoImpl(&canRedo, UndoMode.Redo);
	}
	/// Executes undo or redo.
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

	/// If can undo or redo, returns true.
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

	/// Stores undo data.
	/// If this received continue same retry-word,
	/// undo operation will return to a first one.
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

	/// Clears retry-word.
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

/// Undoable class implements this.
interface Undoable {
	/// Creates data of undo operation.
	@property
	Object storeData();
	/// Executes undo operation.
	/// Implement class must restore own state from data.
	void restore(Object data, UndoMode mode);
	/// If enable undo operation, returns true.
	@property
	bool enabledUndo();
}
