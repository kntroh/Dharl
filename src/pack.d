#!/usr/bin/rdmd

/// Packaging script.
module pack;

immutable FILE = "dharl_%s.zip";
immutable DIR = "dharl";

private import std.array;
private import std.datetime;
private import std.exception;
private import std.file;
private import std.path;
private import std.process;
private import std.string;
private import std.zip;

void main(string[] args) {
	enforce(0 == .system("rdmd build clean release"));
	auto time = Clock.currTime().SysTimeToDosFileTime();

	// Creates archive member.
	ArchiveMember createMember(string file) {
		static immutable UNICODE_FILENAME = 0x0800;
		static immutable MEMBER_IS_FILE   = 0x0020;
		auto member = new ArchiveMember;
		member.name = DIR.buildPath(file).replace(dirSeparator, "/");
		member.time = time;
		member.compressionMethod = 8;
		member.externalAttributes = MEMBER_IS_FILE;
		member.internalAttributes = 1;
		member.flags |= UNICODE_FILENAME;
		member.expandedData = cast(ubyte[])file.read();
		return member;
	}

	auto ver = cast(char[])"@version.txt".read();
	ver = ver.chomp().toLower().replace(" ", "");

	auto archive = new ZipArchive();
	archive.addMember(createMember("dharl.exe"));
	archive.addMember(createMember("readme.en.txt"));
	archive.addMember(createMember("readme.jp.txt"));
	foreach (string file; "lang".dirEntries(SpanMode.shallow)) {
		archive.addMember(createMember(file));
	}
	archive.addMember(createMember("plugin".buildPath("readme.txt")));
	FILE.format(ver).write(archive.build());
}
