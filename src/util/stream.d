
/// This module includes functions for stream processing.
///
/// License: Public Domain
/// Authors: kntroh
module util.stream;

private import std.algorithm;
private import std.exception;

/// This struct provide an interface for a array similar to std.stdio.File.
struct ArrayStream(T) {
	/// Processing target array.
	T[] array;
	/// Processing position (The index of the array).
	size_t tell = 0;

	/// Creates new instance for array.
	this (T[] array) {
		this.array = array;
		this.tell = 0;
	}

	/// Reads element of the array.
	/// Returns the slice of buffer containing the data that was actually read.
	T[] rawRead(T[] buffer) {
		auto len = .min(array.length - tell, buffer.length);
		buffer[0 .. len] = array[tell .. tell + len];
		tell += len;
		return buffer[0 .. len];
	}

	/// Writes data in buffer to the array.
	void rawWrite(in T[] buffer) {
		if (array.length < tell + buffer.length) {
			array.length = tell + buffer.length;
		}
		array[tell .. tell + buffer.length] = buffer[];
		tell += buffer.length;
	}
}

// Creates new instance of ArrayStream.
ArrayStream!T arrayStream(T)(T[] array) {
	return ArrayStream!T(array);
} unittest {
	auto a = "abcdef".dup;
	auto s = .arrayStream(a);

	char[8] buf1;
	assert (s.rawRead(buf1) == "abcdef");
	assert (s.tell == 6);
	s.tell = 0;
	assert (s.rawRead(buf1[0 .. 3]) == "abc");
	assert (s.tell == 3);
	assert (s.rawRead(buf1) == "def");
	assert (buf1 == "defdef" ~ char.init ~ char.init);
	assert (s.tell == 6);
	s.rawWrite("ghi");
	assert (s.array == "abcdefghi");
	assert (s.tell == 9);
	s.tell = 7;
	s.rawWrite("j");
	assert (s.array == "abcdefgji");
	assert (s.tell == 8);
	s.rawWrite("klmn");
	assert (s.array == "abcdefgjklmn");
	assert (s.tell == 12);
	char b;
	try {
		s.read(b);
		assert (false);
	} catch (Exception e) {
		// ok
	}
	s.tell = 10;
	s.read(b);
	assert (b == 'm');
	assert (s.tell == 11);
	s.write(b);
	assert (s.array == "abcdefgjklmm");
	assert (s.tell == 12);
	s.write(cast(ubyte)'n');
	assert (s.array == "abcdefgjklmmn");
	assert (s.tell == 13);
}

/// Wrapper for read/write of single element by rawRead and rawWrite.
void read(InputStream, T)(ref InputStream stream, out T b) {
	T[1] buf;
	.enforce(stream.rawRead(buf).length == 1);
	b = buf[0];
}
/// ditto
void write(OutputStream, T)(ref OutputStream stream, T b) {
	stream.rawWrite([b]);
}
