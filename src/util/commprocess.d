
/// This module includes functions of process communication.
///
/// License: Public Domain
/// Authors: kntroh
module util.commprocess;

private import core.thread;

/// Maximum length for message on process communication.
private immutable MAX_MESSAGE = 0x8000;

/// Send message to named pipe.
/// If pipe not found, returns false.
/// If want to terminate a communication, return a empty string from send.
bool sendToPipe(string name, string delegate(in char[] reply) send) {
	return .sendToPipeImpl(name, send);
}
/// ditto
bool sendToPipe(string name, string message) {
	return .sendToPipe(name, (reply) => reply is null ? message : null);
}
/// To start communication with named pipe.
/// Messages will be forwarded to callback.
/// If want to terminate a communication, return a empty string from callback.
/// If want to quit server, set true to quit of callback parameter.
bool startPipeServer(string name, string delegate(in char[] recv, out bool quit) callback, bool blocking, uint timeoutMillis = 1000) {
	return .startPipeServerImpl(name, callback, blocking, timeoutMillis);
}

version (Windows) {

	private import std.utf;
	private import core.sys.windows.windows;

	extern (Windows) {
		/// Functions and constant values for named pipe.
		private HANDLE CreateNamedPipeW(
			LPCWSTR lpName,
			DWORD   dwOpenMode,
			DWORD   dwPipeMode,
			DWORD   nMaxInstances,
			DWORD   nOutBufferSize,
			DWORD   nInBufferSize,
			DWORD   nDefaultTimeOut,
			LPSECURITY_ATTRIBUTES lpSecurityAttributes
		);
		/// ditto
		private BOOL ConnectNamedPipe(
			HANDLE hNamedPipe,
			OVERLAPPED* lpOverlapped
		);
		/// ditto
		private BOOL DisconnectNamedPipe(
			HANDLE hNamedPipe
		);
		private immutable PIPE_ACCESS_DUPLEX = 0x0003; /// ditto
		private immutable PIPE_TYPE_BYTE     = 0x0000; /// ditto
		private immutable PIPE_READMODE_BYTE = 0x0000; /// ditto
		private immutable PIPE_WAIT          = 0x0000; /// ditto
	}

	/// Handle of named pipe.
	private alias HANDLE pipeHandle;

	/// Invalid pipe handle.
	private immutable INVALID_PIPE = INVALID_HANDLE_VALUE;


	/* ----- Functions ------------------------------------------------- */

	/// Creates pipe name based on name.
	private const(wchar)* createPipeName(string name) {
		return ("\\\\.\\pipe\\" ~ name).toUTF16z();
	}

	/// Creates a named pipe.
	private pipeHandle createPipe(string name, uint timeoutMillis) {
		return CreateNamedPipeW(
			name.createPipeName(),
			PIPE_ACCESS_DUPLEX,
			PIPE_TYPE_BYTE | PIPE_READMODE_BYTE | PIPE_WAIT,
			1,
			MAX_MESSAGE,
			MAX_MESSAGE,
			timeoutMillis,
			null
		);
	}
	/// Close a named pipe.
	private void closePipe(pipeHandle pipe) {
		CloseHandle(pipe);
	}

	/// Implement functions.
	private bool sendToPipeImpl(string name, string delegate(in char[] reply) send) {
		if (!send) return false;

		char[MAX_MESSAGE] buf;
		DWORD len;
		auto pipe = CreateFileW(name.createPipeName(), GENERIC_READ | GENERIC_WRITE, 0, null, OPEN_EXISTING, 0, null);
		if (INVALID_HANDLE_VALUE == pipe) return false;
		scope (exit) CloseHandle(pipe);
		char[] reply = null;
		while (true) {
			auto msg = send(reply);
			if (msg is null || !msg.length) break;
			if (!WriteFile(pipe, msg.ptr, cast(DWORD)msg.length, &len, null)) break;
			if (!ReadFile(pipe, buf.ptr, cast(DWORD)buf.length, &len, null)) break;
			reply = buf[0 .. len];
		}
		return true;
	}
	/// ditto
	private bool startPipeServerImpl(string name, string delegate(in char[] recv, out bool quit) callback, bool blocking, uint timeoutMillis) {
		if (!callback) return false;

		auto pipe = .createPipe(name, timeoutMillis);
		if (INVALID_PIPE == pipe) return false;

		void func() {
			scope (exit) .closePipe(pipe);

			char[MAX_MESSAGE] buf;
			DWORD len;
			bool quit = false;
			while (!quit && ConnectNamedPipe(pipe, null)) {
				scope (exit) DisconnectNamedPipe(pipe);
				while (true) {
					if (!ReadFile(pipe, buf.ptr, buf.length, &len, null)) break;
					auto recv = buf[0 .. len];
					string msg = callback(recv, quit);
					if (quit) break; // quit server
					// When returned null from callback, quit communication.
					if (msg is null || !msg.length) break;
					if (!WriteFile(pipe, msg.ptr, cast(DWORD)msg.length, &len, null)) break;
				}
			}
		}

		if (blocking) {
			func();
		} else {
			(new Thread(&func)).start();
		}
		return true;
	}

} else version (Posix) {

	private import core.stdc.errno;
	private import core.stdc.string;

	private import core.sys.posix.sys.socket;
	private import core.sys.posix.sys.time;
	private import core.sys.posix.sys.un;

	private import core.sys.posix.unistd;

	private import core.thread;

	private import std.path;
	private import std.string;

	/// Handle of named pipe.
	private alias int pipeHandle;

	/// Invalid pipe handle.
	private immutable INVALID_PIPE = -1;

	/// Close a named pipe.
	private void closePipe(pipeHandle pipe, string name) {
		.shutdown(pipe, 2);
		.close(pipe);
		.unlink(name.toStringz());
	}

	/// Implement functions.
	private bool sendToPipeImpl(string name, string delegate(in char[] reply) send) {
		if (!send) return false;

		char[MAX_MESSAGE] buf;
		auto pipe = .socket(AF_UNIX, SOCK_STREAM, 0);
		if (INVALID_PIPE == pipe) return false;
		scope (exit) .close(pipe);

		name = "/tmp".buildPath(name);
		sockaddr_un raddr;
		raddr.sun_family = AF_UNIX;
		.strcpy(cast(char*)raddr.sun_path.ptr, name.toStringz());
		if (-1 == .connect(pipe, cast(sockaddr*)&raddr, raddr.sizeof)) {
			return false;
		}

		char[] reply = null;
		while (true) {
			auto msg = send(reply);
			if (msg is null || !msg.length) break;
			if (-1 == .write(pipe, msg.toStringz(), msg.length)) return false;
			auto len = .read(pipe, buf.ptr, buf.length - 1);
			if (-1 == len) break;
			reply = buf[0 .. len];
		}
		return true;
	}
	/// ditto
	private bool startPipeServerImpl(string name, string delegate(in char[] recv, out bool quit) callback, bool blocking, uint timeoutMillis) {
		if (!callback) return false;

		name = "/tmp".buildPath(name);
		.unlink(name.toStringz());
		auto pipe = .socket(AF_UNIX, SOCK_STREAM, 0);
		if (INVALID_PIPE == pipe) return false;

		sockaddr_un laddr;
		laddr.sun_family = AF_UNIX;
		.strcpy(cast(char*)laddr.sun_path.ptr, name.toStringz());

		if (0 != .bind(pipe, cast(sockaddr*)&laddr, laddr.sizeof)) {
			return false;
		}
		if (0 != .listen(pipe, 1024)) {
			return false;
		}

		auto parentThread = Thread.getThis();

		void func() {
			scope (exit) .closePipe(pipe, name);

			char[MAX_MESSAGE] buf;
			intptr_t len;
			pipeHandle rsock;

			bool quit = false;
			while (!quit) {
				timeval tout;
				tout.tv_sec = 1;
				tout.tv_usec = 0;

				fd_set fdr;
				FD_ZERO(&fdr);
				FD_SET(pipe, &fdr);
				auto selret = .select(FD_SETSIZE, &fdr, null, null, &tout);
				if (-1 == selret && EINTR == errno) {
					if (parentThread.isRunning) {
						continue;
					} else {
						break;
					}
				}
				if (-1 == selret) break;
				if (0 == selret) continue;
				if (!FD_ISSET(pipe, &fdr)) continue;
				rsock = .accept(pipe, null, null);
				if (-1 == rsock) break;
				scope (exit) .close(rsock);

				while (true) {
					if (-1 == (len = .read(rsock, buf.ptr, buf.length - 1))) break;
					auto recv = buf[0 .. len];
					auto msg = callback(recv, quit);
					if (quit) break; // quit server
					// When returned null from callback, quit communication.
					if (msg is null || !msg.length) break;
					if (-1 == .write(rsock, msg.ptr, msg.length)) break;
				}
			}
		}

		if (blocking) {
			func();
		} else {
			(new Thread(&func)).start();
		}
		return true;
	}

} else static assert (0);
