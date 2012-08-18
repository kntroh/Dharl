
/// This module includes common utility functions.
module util.utils;

private import std.algorithm;
private import std.conv;
private import std.functional;
private import std.math;
private import std.path;
private import std.traits;

version (Console) {
	private import std.stdio;

	/// Prints debug message.
	void coutf(T...)(string msgf, T args) {
		writefln(msgf, args);
	}
	/// ditto
	void cout(T...)(T args) {
		writeln(args);
	}
	/// Outputs error message.
	void erroroutf(T...)(string msgf, T args) {
		writefln(msgf, args);
	}
	/// ditto
	void errorout(T...)(T args) {
		writeln(args);
	}
} else {
	/// Prints debug message.
	void coutf(T...)(string msgf, T args) { /* Do nothing */ }
	/// ditto
	void cout(T...)(T args) { /* Do nothing */ }
	/// Outputs error message.
	void erroroutf(T...)(string msgf, T args) { /* Do nothing */ }
	/// ditto
	void errorout(T...)(T args) { /* Do nothing */ }
}

debug private import std.datetime;

debug __gshared TickDuration performance[128];
debug __gshared size_t performanceCount[128];
debug {
	immutable BPerfS = `debug auto performanceCounter = std.datetime.StopWatch(std.datetime.AutoStart.yes);`;
} else {
	immutable BPerfS = ``;
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

/// Converts from degree to radian.
@safe nothrow pure
real radian(real degree) {
	return degree * PI / 180;
}
/// Converts from radian to degree.
@safe nothrow pure
real degree(real radian) {
	return radian * 180 / PI;
}

/// Distance of 1 to 2.
@safe nothrow pure
real distance(real x1, real y1, real x2, real y2) {
	real d1 = x1 - x2;
	real d2 = y1 - y2;
	return sqrt(d1 * d1 + d2 * d2);
}

/// Calculates padding of n-byte boundary.
@safe nothrow pure
uint padding(uint count, uint n) {
	return (n - (count % n)) % n;
}

/// Normalizes range value.
@safe nothrow pure
T1 normalizeRange(T1, T2, T3)(T1 value, T2 from, T3 to) {
	if (0 == to) return value;
	if (to <= value || value < from) {
		value -= cast(ulong) (value / to) * to;
	}
	if (value < from) {
		value += to;
	}
	return value;
} unittest {
	assert (normalizeRange( 3750, 0, 360) == 150);
	assert (normalizeRange(-3750, 0, 360) == 210);
	assert (normalizeRange(  360, 0, 360) ==   0);
}

/// Send event to receivers.
RetType raiseEvent(RetType, Args ...)(RetType delegate(Args)[] receivers, Args args) {
	static if (!is(RetType == void)) {
		RetType ret;
		if (!receivers) return ret;
	} else {
		if (!receivers) return;
	}
	foreach (i, receiver; receivers) {
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

/// Parse string. This function don't throw an exception.
T safeParse(T)(string s, lazy T defaultValue) {
	try {
		return parse!T(s);
	} catch (ConvException e) {
		return defaultValue;
	}
}

/// Search val from in array.
/// If val not found, this function returns the index closest to the target.
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

/**
Omit longer path.
Example:
---
version (Windows) {
	assert (omitPath(`C:\longlonglonglong\longlong\long\path.txt`, 30) == `C:\longlonglonglon...\path.txt`, omitPath(`C:\longlonglonglong\longlong\long\path.txt`, 30));
	assert (omitPath(`C:\short\val.txt`, 15) == `C:\s...\val.txt`);
	assert (omitPath(`C:\short\va.txt`, 15) == `C:\short\va.txt`);
	assert (omitPath(`C:\short\val.txt`, 5) == `C:\...\val.txt`);
} else {
	assert (omitPath(`/longlonglonglong/longlong/long/path.txt`, 30) == `/longlonglonglong/.../path.txt`);
	assert (omitPath(`/short/path`, 10) == `/s.../path`);
	assert (omitPath(`/short/pat`, 10) == `/short/pat`);
	assert (omitPath(`/short/path`, 5) == `/.../path`);
}
---
*/
string omitPath(string path, size_t length, string omitString = "...") {
	auto dpath = path.to!dstring();
	auto domit = omitString.to!dstring();
	if (length < dpath.length) {
		auto drive = dpath.driveName();
		int rlen = drive.length + 1;
		int flen = dpath.baseName().length + 1;
		int plen = length - flen - rlen;
		if (plen < rlen) plen = rlen;
		return (dpath[0 .. plen] ~ domit ~ dpath[$ - flen .. $]).to!string();
	} else {
		return path;
	}
} unittest {
	version (Windows) {
		assert (omitPath(`C:\longlonglonglong\longlong\long\path.txt`, 30) == `C:\longlonglonglon...\path.txt`, omitPath(`C:\longlonglonglong\longlong\long\path.txt`, 30));
		assert (omitPath(`C:\short\val.txt`, 15) == `C:\s...\val.txt`);
		assert (omitPath(`C:\short\va.txt`, 15) == `C:\short\va.txt`);
		assert (omitPath(`C:\short\val.txt`, 5) == `C:\...\val.txt`);
	} else {
		assert (omitPath(`/longlonglonglong/longlong/long/path.txt`, 30) == `/longlonglonglong/.../path.txt`);
		assert (omitPath(`/short/path`, 10) == `/s.../path`);
		assert (omitPath(`/short/pat`, 10) == `/short/pat`);
		assert (omitPath(`/short/path`, 5) == `/.../path`);
	}
}
