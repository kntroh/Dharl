
module dharl.util.utils;

private import std.algorithm;
private import std.functional;
private import std.traits;
private import std.conv;

/// Prints debug message. TODO comment
alias std.stdio.writeln debugln;

debug private import std.datetime;

debug TickDuration performance[128];
debug size_t performanceCount[128];
debug {
	const BPerfS = `debug auto performanceCounter = std.datetime.StopWatch(std.datetime.AutoStart.yes);`;
} else {
	const BPerfS = ``;
}
template BPerf(size_t I) {
	const BPerf =
		`debug performanceCounter.stop();`
		`debug performance[` ~ .text(I) ~ `] += performanceCounter.peek();`
		`debug performanceCount[` ~ .text(I) ~ `]++;`
		`debug performanceCounter.reset();`
		`debug performanceCounter.start();`;
}
template FPerf(size_t I) {
	const FPerf =
		`debug auto performanceCounter = std.datetime.StopWatch(std.datetime.AutoStart.yes);`
		`debug scope (exit) performanceCount[` ~ .text(I) ~ `]++;`
		`debug scope (exit) performance[` ~ .text(I) ~ `] += performanceCounter.peek();`;
}
debug static ~this() {
	foreach (i, time; performance) {
		if (time.usecs) {
			auto c = performanceCount[i];
			auto t = time.usecs;
			std.stdio.writefln("performance[%d], %d: %d(%d)", i, c, t, t / c);
		}
	}
}

/// Raises event to receivers. TODO comment
RetType raiseEvent(RetType, Args ...)(RetType delegate(Args)[] receivers, Args args) {
	static if (!is(RetType == void)) {
		RetType ret;
		if (!receivers) return ret;
	} else {
		if (!receivers) return;
	}
	foreach (receiver; receivers) {
		if (!receiver) continue;
		static if (!is(RetType == void)) {
			ret = receiver(args);
			static if (is(typeof(!ret))) {
				if (!ret) {
					return ret;
				}
			}
		} else {
			receiver(args);
		}
	}
	static if (!is(RetType == void)) {
		return ret;
	}
} unittest {
	void delegate(int)[] dlgs;
	int r = 0;
	dlgs ~= (int v) { r += v; };
	dlgs ~= (int v) { r *= v; };
	dlgs ~= (int v) { r -= v; };
	dlgs.raiseEvent(3);
	assert (r == 6);

	bool delegate(int)[] dlgs2;
	r = 0;
	dlgs2 ~= (int v) { r += v; return true; };
	dlgs2 ~= (int v) { r *= v; return false; };
	dlgs2 ~= (int v) { r -= v; return true; };
	dlgs2.raiseEvent(3);
	assert (r == 9);
}

/// Remove receiver in receivers.
bool removeReceiver(T)(ref T[] receivers, in T receiver) {
	foreach (i; 0 .. receivers.length) {
		if (receiver is cast(const) receivers[i]) {
			foreach (j; i .. receivers.length - 1) {
				receivers[j + 1] = receivers[j];
			}
			receivers.length -= 1;
			return true;
		}
	}
	return false;
}

/// Rounds value at range from T.min to T.max.
T roundCast(T, N)(in N value) {
	return cast(T) min(T.max, max(T.min, value));
}

/// Parse string no throws exception. TODO comment
T parseS(T)(string s, lazy T defaultValue) {
	try {
		return parse!T(s);
	} catch (ConvException e) {
		return defaultValue;
	}
}

/// Unifies continued same element in-place.
@property
T[] unify(T)(ref T[] array) {
	if (!array.length) return array;
	size_t j = 0;
	foreach (i; 1 .. array.length) {
		if (array[j] != array[i]) {
			j++;
			array[j] = array[i];
		}
	}
	array.length = j + 1;
	return array;
}

/// Sorts elements of array in-place.
T[] qsort(alias Less = "a < b", T)(T[] array) {
	alias binaryFun!Less lessFun;
	void qsortImpl(size_t f, size_t t) {
		if (t <= f + 1) return;
		size_t l = f;
		size_t r = t;
		size_t d = t - f;
		size_t p = f + d / 2;
		t--;
		auto pe = array[p];
		while (true) {
			while (lessFun(array[f], pe)) f++;
			while (lessFun(pe, array[t])) t--;
			if (t <= f) break;
			swap(array[f], array[t]);
			t--;
		}
		qsortImpl(l, f);
		qsortImpl(f + 1, r);
	}
	qsortImpl(0, array.length);
	return array;
} unittest {
	assert (qsort([1, 4, 8, 5, 2, 3, 1]) == [1, 1, 2, 3, 4, 5, 8]);
	assert (qsort([10, 9, 8, 7, 6, 5, 4]) == [4, 5, 6, 7, 8, 9, 10]);
}

/// TODO comment
size_t qsearchLose(alias Less = "a < b", T)(in T[] array, in T val) {
	alias binaryFun!Less lessFun;
	size_t qsearchLoseImpl(size_t f, size_t t) {
		if (t <= f) {
			return t < array.length ? t : t - 1;
		}
		size_t d = t - f;
		size_t p = f + d / 2;
		if (lessFun(val, array[p])) {
			return qsearchLoseImpl(f, p);
		} else if (lessFun(array[p], val)) {
			return qsearchLoseImpl(p + 1, t);
		}
		return p;
	}
	return qsearchLoseImpl(0, array.length);
} unittest {
	assert (qsearchLose([1, 2, 5, 8, 12, 44], 2) == 1);
	assert (qsearchLose([1, 2, 5, 8, 12, 44], 44) == 5);
	auto r = qsearchLose([1, 2, 5, 8, 12, 44], 6);
	assert (r == 2 || r == 3);
	r = qsearchLose([1, 2, 5, 8, 12, 44], 45);
	assert (r == 5);
}