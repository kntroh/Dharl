
/// This module includes functions with result for each environment.
///
/// License: Public Domain
/// Authors: kntroh
module util.environment;

private import std.algorithm;
private import std.conv;
private import std.exception;
private import std.string;
private import std.uni;
private import std.path;

/// Handle of module or symbol.
alias shared(void)* libHandle;

/// Maximum length for file path.
/// This overwrite MAX_PATH and FILENAME_MAX etc.
private immutable MAX_PATH = 0x8000;


/* ----- Filename ------------------------------------------------------ */

/// Can use c in filename?
@property
@safe
pure
bool isFilenameChar(dchar c) {
	return c.isGraphical() && -1 == std.string.indexOf(INVALID_FILENAME, c);
} unittest {
	version (Windows) {
		assert (!'/'.isFilenameChar);
		assert (!'\n'.isFilenameChar);
		assert (!'*'.isFilenameChar);
		assert ('a'.isFilenameChar);
		assert ('b'.isFilenameChar);
		assert ('!'.isFilenameChar);
		assert ('日'.isFilenameChar);
	} else version (Posix) {
		assert (!'/'.isFilenameChar);
		assert (!'\n'.isFilenameChar);
		assert ('*'.isFilenameChar);
		assert ('a'.isFilenameChar);
		assert ('b'.isFilenameChar);
		assert ('!'.isFilenameChar);
		assert ('日'.isFilenameChar);
	}
}

/// If name contains characters that can't use in filename,
/// replace it to c.
@property
string validFilename(string name, dchar c = '_') {
	dchar[] filename;
	foreach (dchar n; name) {
		if (n.isFilenameChar) {
			filename ~= n;
		} else {
			filename ~= c;
		}
	}
	return filename.text();
} unittest {
	version (Windows) {
		assert ("*test/!日本語.bmp".validFilename == "_test_!日本語.bmp");
	} else version (Posix) {
		assert ("*test/!日本語.bmp".validFilename == "*test_!日本語.bmp");
	}
}

version (Windows) {

	private import std.utf;
	private import core.stdc.wchar_;
	private import core.sys.windows.windows;

	/// This characters can't use to filename.
	private immutable INVALID_FILENAME = "\\/:*?\"<>|/\\"d;

	/// Handle of shell32.dll or shell64.dll.
	private libHandle _dllShell = null;
	extern (Windows) {
		/// Functions and constant values of the shell32.dll.
		private alias HRESULT function(
			/* in  */ HWND   hwndOwner,
			/* in  */ INT    nFolder,
			/* in  */ HANDLE hToken,
			/* in  */ DWORD  dwFlags,
			/* out */ LPWSTR pszPath
		) SHGetFolderPathW;
		private immutable S_OK               = 0x0000; /// ditto
		private immutable CSIDL_APPDATA      = 0x001A; /// ditto
		private immutable SHGFP_TYPE_CURRENT = 0x0000; /// ditto
	}

	shared static ~this () {
		if (_dllShell) .dlclose(_dllShell);
	}


	/* ----- Shared library -------------------------------------------- */

	/// Load shared library.
	libHandle dlopen(string lib) {
		return cast(libHandle)LoadLibraryW(.toUTF16z(lib));
	}
	/// Gets symbol on shared library.
	nothrow
	libHandle dlsym(libHandle lib, string sym) {
		if (!lib) return null;
		return cast(libHandle)GetProcAddress(cast(void*)lib, .toStringz(sym));
	}
	/// Release shared library.
	nothrow
	bool dlclose(ref libHandle lib) {
		if (!lib) return false;
		auto result = FreeLibrary(cast(void*)lib);
		if (result) lib = null;
		return 0 != result;
	}


	/* ----- File and directory ---------------------------------------- */

	/// Gets default application data directory from the environment.
	string appData(string defaultValue, bool freeLibrary) {
		if (!_dllShell) {
			version (Win64) {
				_dllShell = .dlopen("shell64.dll");
			} else version (Win32) {
				_dllShell = .dlopen("shell32.dll");
			} else static assert (0);
		}
		if (!_dllShell) return defaultValue;
		scope (exit) {
			if (freeLibrary) .dlclose(_dllShell);
		}

		auto fSHGetFolderPath = cast(SHGetFolderPathW)dlsym(_dllShell, "SHGetFolderPathW");
		if (!fSHGetFolderPath) return defaultValue;

		wchar[MAX_PATH] pathBuf;
		auto result = fSHGetFolderPath(null, CSIDL_APPDATA, null, SHGFP_TYPE_CURRENT, pathBuf.ptr);
		if (S_OK != result) return defaultValue;
		return .text(pathBuf[0 .. .wcslen(pathBuf.ptr)]);
	}

} else version (Posix) {

	private static import core.sys.posix.dlfcn;

	private import core.sys.posix.pwd;
	private import core.sys.posix.unistd;

	/// This characters can't use to filename.
	private immutable INVALID_FILENAME = "/";


	/* ----- Shared library -------------------------------------------- */

	/// Load shared library.
	libHandle dlopen(string lib) {
		return cast(libHandle)core.sys.posix.dlfcn.dlopen(.toStringz(lib), core.sys.posix.dlfcn.RTLD_NOW);
	}
	/// Gets symbol on shared library.
	nothrow
	libHandle dlsym(libHandle lib, string sym) {
		if (!lib) return null;
		return cast(libHandle)core.sys.posix.dlfcn.dlsym(cast(void*)lib, .toStringz(sym));
	}
	/// Release shared library.
	nothrow
	bool dlclose(ref libHandle lib) {
		if (!lib) return false;
		auto result = core.sys.posix.dlfcn.dlclose(cast(void*)lib);
		if (0 == result) lib = null;
		return 0 == result;
	}


	/* ----- File and directory ---------------------------------------- */

	/// Gets default application data directory from the environment.
	string appData(string defaultValue, bool freeLibrary) {
		return .to!string(getpwuid(getuid()).pw_dir);
	}

} else static assert (0);
