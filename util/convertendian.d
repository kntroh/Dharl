
/// This module includes functions for bytes I/O considering the endian.
module util.convertendian;

private import std.stream;

version (LittleEndian) {

	/// Gets little endian value.
	alias normalBytes littleEndian;
	/// Gets big endian value.
	alias reverseBytes bigEndian;

	/// Reads big endian value from stream.
	alias readReverse readB;

	/// Reads little endian value from stream.
	alias readNormal readL;

	/// Writes big endian value to stream.
	alias writeReverse writeB;

	/// Writes little endian value to stream.
	alias writeNormal writeL;

} else version (BigEndian) {

	/// Gets little endian value.
	alias reverseBytes littleEndian;
	/// Gets big endian value.
	alias normalBytes bigEndian;

	/// Reads big endian value from stream.
	alias readNormal readB;

	/// Reads little endian value from stream.
	alias readReverse readL;

	/// Writes big endian value to stream.
	alias writeNormal writeB;

	/// Writes little endian value to stream.
	alias writeReverse writeL;

} else static assert (0);

/// Returns bytes.
@property
T normalBytes(T)(T value) {
	return value;
}

/// Reverses bytes.
@property
T reverseBytes(T)(T value) {
	T result = 0;
	for (size_t shift = 0; shift < T.sizeof * 8; shift += 8) {
		result <<= 8;
		result |= (value >>> shift) & 0xFF;
	}
	return result;
} unittest {
	assert (.reverseBytes(cast(short) 0xFDCB) == cast(short) 0xCBFD);
}

/// Reads bytes from stream and reverses it.
T readReverse(T)(InputStream stream) {
	ubyte b;
	stream.read(b);
	T value = b;
	for (size_t shift = 8; shift < T.sizeof * 8; shift += 8) {
		stream.read(b);
		value |= b << shift;
	}
	return value;
}
/// Reads bytes from stream.
T readNormal(T)(InputStream stream) {
	T value;
	static if (is(typeof(stream.read(value)))) {
		stream.read(value);
		return value;
	} else {
		ubyte b;
		stream.read(b);
		value = b;
		foreach (i; 1 .. T.sizeof) {
			value <<= 8;
			stream.read(b);
			value |= b;
		}
		return value;
	}
}

/// Reverses bytes and writes it to stream.
void writeReverse(T)(OutputStream stream, T value) {
	for (size_t shift = 0; shift < T.sizeof * 8; shift += 8) {
		stream.write(cast(ubyte) ((value >>> shift) & 0xFF));
	}
}
/// Writes bytes to stream.
void writeNormal(T)(OutputStream stream, T value) {
	static if (is(typeof(stream.write(value)))) {
		stream.write(value);
	} else {
		for (intptr_t shift = T.sizeof * 8 - 8; shift >= 0; shift -= 8) {
			stream.write(cast(ubyte) ((value >>> shift) & 0xFF));
		}
	}
}
