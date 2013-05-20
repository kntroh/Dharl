
/// This module includes functions to handle Susie Plug-in.
///
/// License: Public Domain
/// Authors: kntroh
module dharl.image.susie;

private import dharl.image.mlimage;

version (Windows) {

	private import core.stdc.string;
	private import core.stdc.time;

	private import core.sys.windows.windows;

	private import util.convertendian;
	private import util.environment;
	private import util.sjis;
	private import util.utils;

	private import std.algorithm;
	private import std.datetime;
	private import std.file;
	private import std.math;
	private import std.path;
	private import std.stream;
	private import std.string;

	private import std.windows.charset;

	private import org.eclipse.swt.all;
	private import org.eclipse.swt.internal.win32.WINTYPES : BITMAPFILEHEADER;

	private import java.io.ByteArrayInputStream;

	/// Susie plugin API.
	private extern (Windows) {
		/// Information of image.
		struct PictureInfo {
			LONG left;        /// Image position.
			LONG top;         /// ditto
			LONG width;       /// Width.
			LONG height;      /// Height.
			WORD x_density;   /// Horizontal density.
			WORD y_density;   /// Vertical density.
			SHORT colorDepth; /// Depth.
			HLOCAL hInfo;     /// Text info.
		}
		/// File information in archive.
		struct fileInfo {
			char[8] method;     /// Compression method.
			ULONG position;     /// Position in the archive.
			ULONG compsize;     /// File size (at compressed).
			ULONG filesize;     /// File size (at uncompressed).
			time_t timestamp;   /// Timestamp of file.
			char[200] path;     /// Path of file.
			char[200] filename; /// Filename.
			ULONG crc;          /// Checksum.
		}
		/// Callback function.
		nothrow
		alias INT function(INT nNum, INT nDenom, LONG lData) susieCallback;

		/// Gets susie plugin information.
		alias INT function(INT infono, LPSTR buf, INT buflen) GetPluginInfo;
		/// If plugin is supported image with filename, returns 0.
		alias INT function(LPCSTR filename, DWORD dw) IsSupported;
		/// Gets inromation of plugin.
		alias INT function(LPCSTR buf, LONG len, UINT flag, PictureInfo *lpInfo) GetPictureInfo;
		/// Loads image.
		alias INT function(LPCSTR buf, LONG len, UINT flag, HLOCAL* pHBInfo, HLOCAL* pHBm, susieCallback lpPrgressCallback, LONG lData) GetPicture;
		/// Creates preview image from buf.
		alias INT function(LPCSTR buf, LONG len, UINT flag, HLOCAL* pHBInfo, HLOCAL* pHBm, susieCallback lpPrgressCallback, LONG lData) GetPreview;

		/// Gets archive file information.
		alias INT function(LPCSTR buf, LONG len, UINT flag, HLOCAL* lphInf) GetArchiveInfo;
		/// Gets file information in archive.
		alias INT function(LPCSTR buf, LONG len, in LPCSTR filename, UINT flag, fileInfo* lpInfo) GetFileInfo;
		/// Gets file data in archive.
		alias INT function(LPCSTR src, LONG len, LPSTR dest, UINT flag, susieCallback prgressCallback, LONG lData) GetFile;

		/// A prgressCallback (no processing).
		nothrow
		int ProgressCallback(INT nNum, INT nDenom, LONG lData) { return 0; }
	}

	/// Information of Susie Plug-in.
	private struct PluginInfo {
		string pluginFile;     /// Plug-in file name.
		libHandle handle;      /// Plug-in handle.
		string apiVersion;     /// Plug-in API verison.
		string about;          /// About Plug-in.
		string[] extension;    /// Supported file extension.
		string[] fileTypeName; /// Name of supported file type.

		/// Functions in the Plug-in.
		GetPluginInfo  getPluginInfo  = null;
		IsSupported    isSupported    = null; /// ditto
		GetPictureInfo getPictureInfo = null; /// ditto
		GetPicture     getPicture     = null; /// ditto
		GetArchiveInfo getArchiveInfo = null; /// ditto
		GetFileInfo    getFileInfo    = null; /// ditto
		GetFile        getFile        = null; /// ditto
	}

	/// Susie Plug-in management class.
	class SusiePlugin {

		/// Susie Plug-in informations.
		private PluginInfo[] _plugins;
		/// Last loaded directory path.
		private string _loadDir = null;
		/// Last loaded time.
		private SysTime _loadTime;

		/// The only constructor.
		this () {
			_loadTime = SysTime.min;
		}

		~this () {
			releaseSusiePlugins();
		}

		/// Initialize Susie Plug-ins in dir.
		void loadSusiePlugins(string dir) {
			if (!dir) return;
			if (!dir.exists()) return;

			auto modified = dir.timeLastModified();

			if (_loadDir && _loadDir == dir && modified == _loadTime) {
				// No change of dir.
				return;
			}

			releaseSusiePlugins();
			_loadDir = dir;
			_loadTime = modified;

			char[1024] buf;
			foreach (string file; dir.dirEntries(SpanMode.shallow)) {
				if (0 != file.extension().filenameCmp(".spi")) continue;

				auto lib = file.dlopen();
				if (!lib) continue;

				// Load functions.
				PluginInfo info;
				info.getPluginInfo = cast(GetPluginInfo)lib.dlsym("GetPluginInfo");
				if (!info.getPluginInfo) {
					lib.dlclose();
					continue;
				}
				info.isSupported    = cast(IsSupported)lib.dlsym("IsSupported");
				info.getPictureInfo = cast(GetPictureInfo)lib.dlsym("GetPictureInfo");
				info.getPicture     = cast(GetPicture)lib.dlsym("GetPicture");
				info.getArchiveInfo = cast(GetArchiveInfo)lib.dlsym("GetArchiveInfo");
				info.getFileInfo    = cast(GetFileInfo)lib.dlsym("GetFileInfo");
				info.getFile        = cast(GetFile)lib.dlsym("GetFile");

				info.handle = lib;
				info.pluginFile     = file.absolutePath().buildNormalizedPath();

				// BUG: len includes '\0' sometimes.
				int len;
				len = info.getPluginInfo(0, buf.ptr, buf.length);
				if (len) info.apiVersion = buf[0 .. .strlen(buf.ptr)].idup;
				len = info.getPluginInfo(1, buf.ptr, buf.length);
				if (len) info.about = buf[0 .. .strlen(buf.ptr)].idup;
				for (size_t n = 2; ; n += 2) {
					len = info.getPluginInfo(n + 0, buf.ptr, buf.length);
					if (!len) break;
					info.extension ~= buf[0 .. .strlen(buf.ptr)].idup;
					len = info.getPluginInfo(n + 1, buf.ptr, buf.length);
					if (!len) break;
					info.fileTypeName ~= buf[0 .. .strlen(buf.ptr)].idup;
				}

				_plugins ~= info;
			}
		}

		/// Releases all Susie Plug-ins.
		void releaseSusiePlugins() {
			foreach (lib; _plugins) {
				libHandle handle = lib.handle;
				handle.dlclose();
			}
			_plugins.length = 0;
			_loadDir = null;
			_loadTime = SysTime.min;
		}

		/// Gets loadable image file extensions from Susie Plug-ins in dir.
		@property
		string[] susieExtensions() {
			string[] r;
			foreach (lib; _plugins) {
				foreach (ext; lib.extension) {
					r ~= ext.toLower().split(";");
				}
			}
			return r;
		}

		/// Loads file with Susie Plug-in.
		/// If load failure, returns empty array.
		/// If tryLoadWithoutPlugin() exist,
		/// try load image without plugin before load with Susie Plug-in.
		/// Parameters of tryLoadWithoutPlugin() is file data in archive sometimes.
		MLImage[] loadWithSusie(
			string file,
			string newLayerName,
			MLImage[] delegate(string fileExtension, lazy ubyte[] fileData) tryLoadWithoutPlugin
		) {
			file = file.absolutePath().buildNormalizedPath();

			ubyte[2048] head; // Beginning (2KB) of file.
			{
				auto s = new BufferedFile(file);
				scope (exit) s.close();
				size_t len = s.read(head);
				head[len .. $] = 0;
			}
			return loadWithSusieImpl(file, file.extension(), newLayerName, tryLoadWithoutPlugin, head, {
				return cast(ubyte[])file.read();
			});
		}
		/// ditto
		private MLImage[] loadWithSusieImpl(
			string file,
			string ext,
			string newLayerName,
			MLImage[] delegate(string fileExtension, lazy ubyte[] fileData) tryLoadWithoutPlugin,
			in ubyte[2048] head,
			ubyte[] delegate() readData
		) {
			MLImage[] r;

			ubyte[] fileBytes = null;

			if (tryLoadWithoutPlugin) {
				// Try load without Susie Plug-in.
				r ~= tryLoadWithoutPlugin(ext, (fileBytes ? fileBytes : fileBytes = readData()));
				if (r.length) {
					// Successfully.
					return r;
				}
			}

			// Parameters for IsSupported().
			auto dw = cast(DWORD)head.ptr;
			auto filename = file.toMBSz();

			all: foreach (lib; _plugins) {
				if (!lib.isSupported) continue;
				static immutable uint DISC   = 0x0000;
				static immutable uint MEMORY = 0x0001;

				switch (lib.apiVersion) {

				case "00IN":
					if (!lib.getPicture) continue;

					if (!lib.isSupported(filename, dw)) continue;

					// Memory image of file.
					auto data = cast(char[])(fileBytes is null ? readData() : fileBytes);
					int errcode;

					// Gets bitmap data by Susie Plug-in.
					HLOCAL bInfo = null;
					HLOCAL bm = null;
					scope (exit) {
						if (bInfo && !(*(cast(void**)bInfo))) LocalFree(*(cast(void**)bInfo));
						if (bm && !(*(cast(void**)bm))) LocalFree(*(cast(void**)bm));
					}
					errcode = lib.getPicture(data.ptr, data.length, MEMORY, &bInfo, &bm, null, 0);
					if (0 != errcode) continue;
					if (!bInfo || !bm || !(*(cast(void**)bInfo)) || !(*(cast(void**)bm))) {
						continue;
					}

					// Creates bitmap data.
					auto info = *(cast(BITMAPINFO**)bInfo);
					auto bmp = *(cast(ubyte**)bm);
					auto w = info.bmiHeader.biWidth.littleEndian;
					auto h = info.bmiHeader.biHeight.littleEndian;
					auto bytesPerLine = w + .padding(w, 4);

					static immutable BITMAPFILEHEADER_SIZE = 14;
					static immutable RGBQUAD_SIZE = 4;
					size_t headerSize = info.bmiHeader.biSize.littleEndian;
					auto bitCount = info.bmiHeader.biBitCount.littleEndian;
					auto clrUsed = info.bmiHeader.biClrUsed.littleEndian;
					if (0 == clrUsed) {
						switch (bitCount) {
						case 1:
							headerSize += RGBQUAD_SIZE * (0x01 << 1);
							break;
						case 4:
							headerSize += RGBQUAD_SIZE * (0x01 << 4);
							break;
						case 8:
							headerSize += RGBQUAD_SIZE * (0x01 << 8);
							break;
						default:
							break;
						}
					} else {
						headerSize += RGBQUAD_SIZE * clrUsed;
					}
					auto size = info.bmiHeader.biSizeImage;
					if (!size) {
						// Calculates bitmap data size.
						size = w;
						switch (bitCount) {
						case 1:
							size /= 8;
							break;
						case 4:
							size /= 2;
							break;
						default:
							size *= bitCount / 8;
						}
						size += size.padding(4);
						size *= h.abs();
					}

					// Bitmap data bytes.
					auto bytes = new byte[BITMAPFILEHEADER_SIZE + headerSize + size];
					auto header = cast(BITMAPFILEHEADER*)bytes.ptr;
					header.bfType = (cast(USHORT)('B' | ('M' << 8))).littleEndian;
					header.bfSize = bytes.length.littleEndian;
					header.bfOffBits = (BITMAPFILEHEADER_SIZE + headerSize).littleEndian;

					.memmove(&bytes[BITMAPFILEHEADER_SIZE], info, headerSize);
					.memmove(&bytes[header.bfOffBits], bmp, size);

					// Loads bitmap.
					auto buf = new ByteArrayInputStream(bytes);
					auto imgData = new ImageData(buf);

					// Creates MLImage.
					r ~= new MLImage(imgData, newLayerName);
					break;

				case "00AM":
					if (!lib.getArchiveInfo) continue;
					if (!lib.getFile) continue;

					if (!lib.isSupported(filename, dw)) continue;

					// Memory image of file.
					auto data = cast(char[])(fileBytes is null ? readData() : fileBytes);
					int errcode;

					// Gets archive file information.
					HLOCAL info = null;
					scope (exit) {
						if (info && !(*(cast(void**)info))) LocalFree((*(cast(void**)info)));
					}
					errcode = lib.getArchiveInfo(data.ptr, data.length, MEMORY, &info);
					if (0 != errcode) continue;
					if (!info) continue;
					auto fileInfo = *(cast(fileInfo**)info);
					if (!fileInfo) continue;

					// Processing files in archive.
					while ('\0' != fileInfo.method[0]) {

						HLOCAL dest;
						scope (exit) {
							if (dest && !(*(cast(void**)dest))) LocalFree((*(cast(void**)dest)));
						}
						// BUG: Pass a memory image to axzip.spi, to hang.
						errcode = lib.getFile(filename, fileInfo.position, cast(char*)&dest, 0x0100, null, 0);
						if (0 != errcode) continue all;
						auto uncomp = *(cast(ubyte**)dest);

						// Beginning (2KB) of file in archive.
						ubyte[2048] headA;
						headA[] = 0;
						.memmove(headA.ptr, uncomp, .min(headA.sizeof, fileInfo.filesize));

						// Loads image in archive.
						auto name = fileInfo.filename[0 .. .strlen(fileInfo.filename.ptr)];
						auto compExt = name.extension().idup;
						r ~= loadWithSusieImpl("", compExt, newLayerName, tryLoadWithoutPlugin, headA, {
							return uncomp[0 .. fileInfo.filesize];
						});

						// Advance pointer.
						fileInfo++;
					}
					break;

				default:
					continue;
				}

				/// Successful to load a image by lib.
				if (r.length) break;
			}
			return r;
		}
	}

} else {

	/// Susie Plug-in management class.
	class SusiePlugin {

		/// The only constructor.
		this () {
			// No processing.
		}

		/// Initialize Susie Plug-ins in dir.
		void loadSusiePlugins(string dir) {
			// No processing.
		}

		/// Releases all Susie Plug-ins.
		void releaseSusiePlugins() {
			// No processing.
		}

		/// Gets loadable image file extensions from susie plugins in dir.
		@property
		string[] susieExtensions() { return []; }

		/// Loads file with Susie Plug-in.
		/// If load failure, returns empty array.
		/// If tryLoadWithoutPlugin() exist,
		/// try load image without plugin before load with Susie Plug-in.
		/// Parameters of tryLoadWithoutPlugin() is file data in archive sometimes.
		MLImage[] loadWithSusie(
			string file,
			string newLayerName,
			MLImage[] delegate(string fileExtension, lazy ubyte[] fileData) tryLoadWithoutPlugin
		) {
			return [];
		}
	}
}
