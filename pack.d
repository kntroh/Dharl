#!/usr/bin/rdmd

/// Packaging script.
module pack;

immutable FILE = "dharl_%s_%s.zip";
immutable SRC_FILE = "src.zip";
immutable DIR = "dharl";

private import std.array;
private import std.datetime;
private import std.exception;
private import std.file;
private import std.getopt;
private import std.path;
private import std.process;
private import std.string;
private import std.zip;

void main(string[] args) {
	bool m64;
	args.getopt("64", &m64);
	if (m64) {
		.enforce(0 == ("dub build --arch=x86_64").executeShell().status);
	} else {
		.enforce(0 == ("dub build").executeShell().status);
	}
	auto time = Clock.currTime().SysTimeToDosFileTime();

	// Creates archive member.
	ArchiveMember createMember(string file) {
		static immutable UNICODE_FILENAME = 0x0800;
		static immutable MEMBER_IS_FILE   = 0x0020;
		auto member = new ArchiveMember;
		member.name = DIR.buildPath(file).replace(dirSeparator, "/");
		member.time = time;
		member.fileAttributes = MEMBER_IS_FILE;
		member.internalAttributes = 1;
		member.flags |= UNICODE_FILENAME;
		member.expandedData = cast(ubyte[])file.read();
		return member;
	}

	auto ver = cast(char[])"src/@version.txt".read();
	ver = ver.chomp().toLower().replace(" ", "");

	auto srcArc = new ZipArchive();
	foreach (file; "src".dirEntries(SpanMode.depth)) {
		if (file.extension.filenameCmp(".res") == 0) continue;
		if (file.isDir) continue;
		srcArc.addMember(createMember(file));
	}
	srcArc.addMember(createMember("dub.json"));
	srcArc.addMember(createMember("pack.d"));
	srcArc.addMember(createMember(".gitignore"));
	SRC_FILE.write(srcArc.build());

	auto archive = new ZipArchive();
	archive.addMember(createMember("dharl.exe"));
	archive.addMember(createMember("readme.en.txt"));
	archive.addMember(createMember("readme.jp.txt"));
	archive.addMember(createMember("src.zip"));
	foreach (file; "lang".dirEntries(SpanMode.shallow)) {
		archive.addMember(createMember(file));
	}
	archive.addMember(createMember("plugin".buildPath("readme.en.txt")));
	archive.addMember(createMember("plugin".buildPath("readme.jp.txt")));
	auto arch = m64 ? "x64" : "x86";
	FILE.format(ver, arch).write(archive.build());

	SRC_FILE.remove();
}
