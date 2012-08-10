#!/usr/bin/rdmd
/// ビルドスクリプト。
module build;

immutable NAME = "dharl";
immutable string[] CRITICAL = [
];

import std.algorithm;
import std.file;
import std.path;
import std.process;
import std.exception;
import std.array;
import std.string : splitLines;
import std.stdio : writeln, writefln;
import std.datetime;
import std.container;

version (Windows) {
	immutable RCC = "rcc";
	immutable RC = NAME.setExtension("rc");
	immutable RES = NAME.setExtension("res");
	immutable EXE = NAME.setExtension("exe");
	immutable LIB = [
		"-L/rc:" ~ NAME,
		"-L/NOM",
		"-L+advapi32.lib",
		"-L+comctl32.lib",
		"-L+comdlg32.lib",
		"-L+gdi32.lib",
		"-L+kernel32.lib",
		"-L+shell32.lib",
		"-L+ole32.lib",
		"-L+oleaut32.lib",
		"-L+olepro32.lib",
		"-L+oleacc.lib",
		"-L+user32.lib",
		"-L+usp10.lib",
		"-L+msimg32.lib",
		"-L+opengl32.lib",
		"-L+shlwapi.lib",
		"-L+dwt-base.lib",
		"-L+org.eclipse.swt.win32.win32.x86.lib",
	];
	immutable DEBUG_FLAGS = [
		"-debug",
		"-unittest",
	];
	immutable string[] DEBUG_FLAGS_L = [
		"-debug",
		"-unittest",
	];
	immutable CONSOLE_FLAGS_L = [
		"-of" ~ EXE,
		"-L/exet:nt/su:console:4.0",
	];
	immutable string[] WINDOW_FLAGS_L = [
		"-of" ~ EXE,
		"-L/exet:nt/su:windows:4.0",
	];
	immutable O = "obj";
} else {
	immutable EXE = NAME;
	immutable LIB = [
		"org.eclipse.swt.gtk.linux.x86.a",
		"dwt-base.a",
		"-L-lgnomeui-2",
		"-L-lcairo",
		"-L-lglib-2.0",
		"-L-ldl",
		"-L-lgmodule-2.0",
		"-L-lgobject-2.0",
		"-L-lpango-1.0",
		"-L-lXfixes",
		"-L-lX11",
		"-L-lXdamage",
		"-L-lXcomposite",
		"-L-lXcursor",
		"-L-lXrandr",
		"-L-lXi",
		"-L-lXinerama",
		"-L-lXrender",
		"-L-lXext",
		"-L-lXtst",
		"-L-lfontconfig",
		"-L-lpangocairo-1.0",
		"-L-lgthread-2.0",
		"-L-lgdk_pixbuf-2.0",
		"-L-latk-1.0",
		"-L-lgdk-x11-2.0",
		"-L-lgtk-x11-2.0",
	];
	immutable DEBUG_FLAGS = [
		"-g",
		"-debug",
		"-unittest",
	];
	immutable string[] DEBUG_FLAGS_L = [
		"-g",
		"-debug",
		"-unittest",
	];
	immutable CONSOLE_FLAGS_L = [
		"-of" ~ EXE,
	];
	immutable string[] WINDOW_FLAGS_L = [
		"-of" ~ EXE,
	];
	immutable O = "o";
}

immutable FLAGS = [
	"-op",
	"-property",
	"-c",
];
immutable CRITICAL_FLAGS = [
	"-c",
	"-release",
	"-O",
	"-inline",
	"-op",
];
immutable RELEASE_FLAGS = [
	"-release",
];

immutable CONSOLE_FLAGS = [
	"-version=Console",
];
immutable string[] WINDOW_FLAGS = [
];
immutable string[] RELEASE_FLAGS_L = [
	"-release",
	"-O",
];

immutable DMD = "dmd";

/// コマンドを実行。
void exec(string[] cmd ...) {
	string line = cmd.join(" ");
	writeln(line);
	auto timer = StopWatch(AutoStart.yes);
	enforce(0 == system(line), new Exception(line));
	timer.stop();
	writefln("%d msecs", timer.peek().msecs);
}
/// ファイル名が一致するか。
bool equalsFilename(string a, string b) {
	return 0 == a.filenameCmp(b);
}
/// コンパイル対象の情報を格納する。
string[] put(string file, ref string[string] objs, in string[] qual) {
	string obj = "objs".buildPath(file).setExtension(O);
	objs[file] = obj;
	string[] array;
	if (qual.length) {
		if (!qual.find!equalsFilename(file.baseName()).empty) {
			array ~= file;
		}
	} else {
		if (file.newer(obj)) {
			array ~= file;
		}
	}
	return array;
}
/// argsにflagが含まれているか(大文字・小文字を区別しない)。
bool has(in string[] args, string flag) {
	return !find!("0 == icmp(a, b)")(args, flag).empty;
}
/// pathがtargより新しいか。
bool newer(string path, string targ) {
	return !targ.exists() || path.timeLastModified() > targ.timeLastModified();
}
/// pathを削除する。
void removeFile(string path) {
	if (!path.exists()) return;
	if (path.isDir()) {
		path.rmdirRecurse();
	} else {
		path.remove();
	}
	writefln("removed: %s", path);
}
/// argsの内容を分類する。
void divide(in string[] args, out string[] file, out string[] option, out string[] dmdOption) {
	foreach (a; args) {
		if (0 == a.extension().filenameCmp(".d")) {
			file ~= a;
		} else if (a.startsWith("-")) {
			dmdOption ~= a;
		} else {
			option ~= a;
		}
	}
}

void main(string[] args) {
	auto timer = StopWatch(AutoStart.yes);

	// ビルドフラグ
	string[] test, option, dmdOption;
	divide(args[1 .. $], test, option, dmdOption);
	test = test.sort;
	option = option.sort;
	bool help = option.has("help");
	bool release = option.has("release");
	bool console = option.has("cui");
	bool window = (release && !console) || option.has("gui");
	bool clean = option.has("clean");
	bool run = option.has("run");

	if (help) {
		writeln("Usage: rdmd build [help | clean | cui | gui | release | run | *.d]");
		return;
	}

	// 前回のフラグと比較・保存
	bool mod = false;
	if (!test.length) {
		auto option2 = option.dup;
		option2 = std.algorithm.remove!(a => a == "clean")(option2);
		option2 = std.algorithm.remove!(a => a == "run")(option2);
		mod = "build.log".exists() && option2 != "build.log".readText().splitLines();
		"build.log".write(option2.join("\n"));
	}

	if (clean || mod) {
		// クリーン
		EXE.removeFile();
		version (Windows) {
			RES.removeFile();
		}
		"objs".removeFile();
		"build.d.deps".removeFile();
		"build.log".removeFile();
		if (clean && 1 == test.length + option.length) return;
	}

	// ソースコードとオブジェクトファイルのリスト
	string[string] objs; // コンパイル対象と生成されるオブジェクトファイルのテーブル
	string[][string] files; // コンパイル対象(ディレクトリ毎)
	string[] critical; // 速度優先でコンパイルされるべきファイル
	auto res = .make!(RedBlackTree!string)(); // リソースのディレクトリ
	foreach (string file; ".".dirEntries(SpanMode.depth)) {
		if (file.isDir()) continue;
		if (!file.extension().equalsFilename(".d")) {
			res.insert("-J" ~ file.dirName);
			continue;
		}
		file = file.buildNormalizedPath();
		if (file.equalsFilename(__FILE__)) continue;
		if (-1 != CRITICAL.countUntil!equalsFilename(file)) {
			critical ~= put(file, objs, test);
			continue;
		}
		files[file.dirName] ~= put(file, objs, test);
	}

	string[] cmd;

	version (Windows) {
		// リソースファイル
		if (RC.length && RC.newer(RES)) {
			cmd = [RCC];
			exec(cmd ~ RC);
		}
	}

	cmd = [DMD];

	// *.dのコンパイル
	string[] flags = FLAGS.dup;
	flags ~= release ? RELEASE_FLAGS : DEBUG_FLAGS;
	flags ~= window ? WINDOW_FLAGS : CONSOLE_FLAGS;
	if (critical.length) {
		exec(cmd ~ CRITICAL_FLAGS ~ res.array() ~ critical ~ "-odobjs" ~ dmdOption);
	}
	foreach (dir, array; files) {
		if (!array.length) continue;
		exec(cmd ~ flags ~ array ~ res.array() ~ "-odobjs" ~ dmdOption);
	}

	// ファイルが指定されている場合はコンパイルテストなのでここで終了
	if (test.length) {
		foreach (f; critical ~ files.values.join()) {
			auto obj = objs[f];
			writefln("%s: %s KB", obj, obj.getSize() / 1024);
		}
		timer.stop();
		writefln("Compiled: %d msecs", timer.peek().msecs);
		return;
	}

	// リンク
	flags = LIB.dup;
	flags ~= release ? RELEASE_FLAGS_L : DEBUG_FLAGS_L;
	flags ~= window ? WINDOW_FLAGS_L : CONSOLE_FLAGS_L;
	exec(cmd ~ flags ~ objs.values);

	timer.stop();
	writefln("Compiled: %d msecs", timer.peek().msecs);

	if (run) {
		exec(".".buildPath(EXE));
	}
}