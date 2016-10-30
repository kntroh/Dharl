
/// This module includes common utility functions.
///
/// License: Public Domain
/// Authors: kntroh
module util.utils;

private import std.algorithm;
private import std.array;
private import std.conv;
private import std.exception;
private import std.file;
private import std.functional;
private import std.math;
private import std.path;
private import std.stdio;
private import std.string;
private import std.traits;

shared string errorLog = "";

version (Console) {
	private import std.stdio;

	/// Prints debug message.
	void coutf(T...)(string msgf, T args) {
		.writefln(msgf, args);
	}
	/// ditto
	void cout(T...)(T args) {
		.writeln(args);
	}
} else {
	/// Prints debug message.
	void coutf(T...)(string msgf, T args) { /* No processing */ }
	/// ditto
	void cout(T...)(T args) { /* No processing */ }
}
/// Outputs error message.
void erroroutf(T...)(string msgf, T args) {
	if (errorLog != "") {
		std.file.append(errorLog, "%s\n\n".format(msgf.format(args)));
	}
	version (Console) {
		.writefln(msgf, args);
	}
}
/// ditto
void errorout(T...)(T args) {
	if (errorLog != "") {
		std.file.append(errorLog, "%s\n\n".format(args.text()));
	}
	version (Console) {
		.writeln(args);
	}
}

debug private import std.datetime;

debug __gshared TickDuration[128] performance;
debug __gshared size_t[128] performanceCount;
debug {
	immutable BPerfS = `debug auto performanceCounter = std.datetime.StopWatch(std.datetime.AutoStart.yes);`;
} else {
	immutable BPerfS = ``;
}
template BPerf(size_t I) {
	const BPerf =
		`debug performanceCounter.stop();`
		~ `debug performance[` ~ .text(I) ~ `] += performanceCounter.peek();`
		~ `debug performanceCount[` ~ .text(I) ~ `]++;`
		~ `debug performanceCounter.reset();`
		~ `debug performanceCounter.start();`;
}
template FPerf(size_t I) {
	const FPerf =
		`debug auto performanceCounter = std.datetime.StopWatch(std.datetime.AutoStart.yes);`
		~ `debug scope (exit) performanceCount[` ~ .text(I) ~ `]++;`
		~ `debug scope (exit) performance[` ~ .text(I) ~ `] += performanceCounter.peek();`;
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
		value -= cast(ulong)(value / to) * to;
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
		if (receiver is cast(const)receivers[i]) {
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
T roundCast(T, N)(in N value, in T min = T.min, in T max = T.max) {
	return cast(T).min(max, .max(min, value));
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
*/
C[] omitPath(C)(C[] path, size_t length, string omitString = "...") {
	auto dpath = path.to!dstring();
	auto domit = omitString.to!dstring();
	if (length < dpath.length) {
		auto drive = dpath.driveName();
		auto rlen = drive.length + 1;
		auto flen = dpath.baseName().length + 1;
		auto plen = ((flen + rlen) < length) ? (length - flen - rlen) : 0;
		if (plen < rlen) plen = rlen;
		if (dpath.length <= plen + flen + domit.length) return path;
		return (dpath[0 .. plen] ~ domit ~ dpath[$ - flen .. $]).to!(C[])();
	} else {
		return path;
	}
}
///
unittest {
	version (Windows) {
		assert (omitPath(`C:\longlonglonglong\longlong\long\path.txt`, 30) == `C:\longlonglonglon...\path.txt`, omitPath(`C:\longlonglonglong\longlong\long\path.txt`, 30));
		assert (omitPath(`C:\short\val.txt`, 15) == `C:\s...\val.txt`);
		assert (omitPath(`C:\short\va.txt`, 15) == `C:\short\va.txt`);
		assert (omitPath(`C:\short\val.txt`, 5) == `C:\...\val.txt`);
		assert (omitPath(`C:\short\longlonglongfilename.txt`, 5) == `C:\...\longlonglongfilename.txt`);
		assert (omitPath(`C:\sht\longlonglongfilename.txt`, 5) == `C:\sht\longlonglongfilename.txt`);
		assert (omitPath(`C:\sh\longlonglongfilename.txt`, 5) == `C:\sh\longlonglongfilename.txt`);
	} else {
		assert (omitPath(`/longlonglonglong/longlong/long/path.txt`, 28) == `/longlonglonglong/.../path.txt`);
		assert (omitPath(`/short/path`, 8) == `/s.../path`);
		assert (omitPath(`/short/pat`, 8) == `/short/pat`);
		assert (omitPath(`/short/path`, 3) == `/.../path`);
		assert (omitPath(`/short/longlonglongfilename.txt`, 5) == `/.../longlonglongfilename.txt`);
		assert (omitPath(`/sht/longlonglongfilename.txt`, 5) == `/sht/longlonglongfilename.txt`);
		assert (omitPath(`/sh/longlonglongfilename.txt`, 5) == `/sh/longlonglongfilename.txt`);
	}
}

/// Replaces all line endings in text to "\n".
C[] normalizeLineEndings(C)(C[] text) {
	return text.replace("\r\n", "\n").replace("\r", "\n");
}

/// Gets file entries from matching by glob.
auto glob(const(char)[] pattern, bool followSymlink = true) {
	struct S {
		private const(char)[] pattern;
		private DirEntry[] array;

		@property
		const
		bool empty() { return !array.length; }

		@property
		DirEntry front() { return array[0]; }

		void popFront() { array = array[1 .. $]; }

		this (const(char)[] pattern) {
			this.pattern = pattern;
			auto drive = pattern.driveName();
			auto cSplitted = pathSplitter(pattern).array();
			if (!cSplitted.length) return;
			if (drive != "") {
				cSplitted = cSplitted[1..$];
			} else if (cSplitted[0].length == 1 && cSplitted[0][0].isDirSeparator()) {
				drive = cSplitted[0];
				cSplitted = cSplitted[1..$];
			}
			auto splitted = .assumeUnique(cSplitted);
			size_t sIndex = 0;
			void recurse(string current, size_t sIndex) {
				if (splitted[sIndex] == "." || splitted[sIndex] == "..") {
					recurse(current.buildPath(splitted[sIndex]), sIndex + 1);
					return;
				}
				if (current == "") current = ".";
				foreach (DirEntry file; dirEntries(current, splitted[sIndex], SpanMode.shallow, followSymlink)) {
					if (sIndex + 1 == splitted.length) {
						array ~= file;
					} else if (file.isDir) {
						recurse(cast(string)file, sIndex + 1);
					}
				}
			}
			recurse(.assumeUnique(drive), sIndex);
		}
	}
	return S(pattern);

	static assert (isIterable!S);
}
