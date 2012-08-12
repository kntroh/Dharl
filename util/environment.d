
/// This module includes functions with result for each environment
module util.environment;

private import std.conv;
private import std.exception;
private import std.string;
private import std.path;

/// Handle of module or symbol.
alias shared(void)* libHandle;

/// Maximum length for file path.
/// This overwrite MAX_PATH and FILENAME_MAX etc.
private immutable MAX_PATH = 0x8000;

version (Windows) {
	private import std.utf;
	private import core.sys.windows.windows;

	/// Handle of shell32.dll or shell64.dll.
	private libHandle _dllShell = null;
	extern (Windows) {
		/// Functions of shell32.dll.
		private alias HRESULT function(
			/* in  */ HWND   hwndOwner,
			/* in  */ INT    nFolder,
			/* in  */ HANDLE hToken,
			/* in  */ DWORD  dwFlags,
			/* out */ LPWSTR pszPath
		) SHGetFolderPathW;

		private immutable S_OK               = 0x0000;
		private immutable CSIDL_APPDATA      = 0x001A;
		private immutable SHGFP_TYPE_CURRENT = 0x0000;
	}

	shared static ~this () {
		if (_dllShell) .dlclose(_dllShell);
	}

	/// Load shared library.
	libHandle dlopen(string lib) {
		return cast(libHandle) LoadLibraryW(.toUTF16z(lib));
	}
	/// Gets symbol on shared library.
	nothrow
	libHandle dlsym(libHandle lib, string sym) {
		if (!lib) return null;
		return cast(libHandle) GetProcAddress(cast(void*) lib, .toStringz(sym));
	}
	/// Release shared library.
	nothrow
	bool dlclose(ref libHandle lib) {
		if (!lib) return false;
		auto result = FreeLibrary(cast(void*) lib);
		if (result) lib = null;
		return 0 != result;
	}

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

		auto fSHGetFolderPath = cast(SHGetFolderPathW) dlsym(_dllShell, "SHGetFolderPathW");
		if (!fSHGetFolderPath) return defaultValue;

		wchar[MAX_PATH] pathBuf;
		auto result = fSHGetFolderPath(null, CSIDL_APPDATA, null, SHGFP_TYPE_CURRENT, pathBuf.ptr);
		if (S_OK != result) return defaultValue;
		return .text(pathBuf[0 .. .wcslen(pathBuf.ptr)]);
	}

	/// Gets executing module file path.
	string moduleFileName(string args0) {
		wchar[MAX_PATH] pathBuf;
		if (GetModuleFileNameW(null, pathBuf.ptr, pathBuf.length)) {
			return .text(pathBuf[0 .. .wcslen(pathBuf.ptr)]);
		}
		return args0.isAbsolute() ? args0 : args0.absolutePath();
	}

} else version (Posix) {
	private static import core.sys.posix.dlfcn;

	private import core.sys.posix.unistd;
	private import core.sys.posix.pwd;

	/// Load shared library.
	libHandle dlopen(string lib) {
		return cast(libHandle) core.sys.posix.dlfcn.dlopen(.toStringz(lib), RTLD_NOW);
	}
	/// Gets symbol on shared library.
	nothrow
	libHandle dlsym(libHandle lib, string sym) {
		if (!lib) return null;
		return cast(libHandle) core.sys.posix.dlfcn.dlsym(cast(void*) lib, .toStringz(sym));
	}
	/// Release shared library.
	nothrow
	bool dlclose(ref libHandle lib) {
		if (!lib) return false;
		auto result = core.sys.posix.dlfcn.dlclose(cast(void*) lib);
		if (0 == result) lib = null;
		return 0 == result;
	}

	/// Gets default application data directory from the environment.
	string appData(string defaultValue, bool freeLibrary) {
		return .to!string(getpwuid(getuid()).pw_dir);
	}

	/// Gets executing module file path.
	string moduleFileName(string args0) {
		version (linux) {
			char[MAX_PATH] buf;
			buf[] = '\0';
			if (-1 != .readlink("/proc/self/exe", buf.ptr, buf.sizeof)) {
				auto result = buf[0 .. .strlen(buf.ptr)];
				return result.assumeUnique();
			}
		}
		return args0.isAbsolute() ? args0 : args0.absolutePath();
	}

} else static assert (0);
