/*
This file is part of Darling.

Copyright (C) 2012-2020 Lubos Dolezel

Darling is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

Darling is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with Darling.  If not, see <http://www.gnu.org/licenses/>.
*/

#include <CoreServices/FileManager.h>
#include <cstdlib>
#include <string>
#include <cstring>
#include <sys/stat.h>
#include <sys/types.h>
#include <unistd.h>
#include <algorithm>
#include <memory>
#include <errno.h>
#include <iconv.h>
#include <alloca.h>
#include <libgen.h>
#include <sstream>
#include <fstream>
#include <map>
#include <regex.h>
#include <fcntl.h>
#include <vector>
#include <copyfile.h>
#include <sys/xattr.h>
#include <darling/osxer-apps.h>
#include <CarbonCore/DateTimeUtils.h>
#include <errno.h>
#include <darling/emulation/linux_premigration/ext/file_handle.h>

#define STUB() printf("STUB %s\n", __PRETTY_FUNCTION__);

// Is the current user member of the specified group?
static bool hasgid(gid_t gid);

OSStatus FSPathMakeRef(const uint8_t* path, FSRef* fsref, Boolean* isDirectory)
{
	return FSPathMakeRefWithOptions(path, kFSPathMakeRefDoNotFollowLeafSymlink, fsref, isDirectory); 
}

OSStatus FSPathMakeRefWithOptions(const uint8_t* path, long options, FSRef* fsref, Boolean* isDirectory)
{
	if (!path || !fsref)
		return paramErr;

	int flags = 1;
	if (options & kFSPathMakeRefDoNotFollowLeafSymlink)
		flags = 0;

	int err = sys_name_to_handle((const char*) path, (RefData*) fsref, flags);
	if (err != 0)
		return fnfErr;

	if (isDirectory)
	{
		struct stat st;

		if (options & kFSPathMakeRefDoNotFollowLeafSymlink)
			err = lstat((const char*) path, &st);
		else
			err = stat((const char*) path, &st);

		if (err == 0)
			*isDirectory = S_ISDIR(st.st_mode);
		else
			*isDirectory = 0;
	}

	return noErr; 
}

bool FSRefMakePath(const FSRef* fsref, std::string& out)
{
	char name[4096];
	int ret = sys_handle_to_name((RefData*) fsref, name);
	if (ret != 0)
		return false;

	out = name;
	return true;
}

OSStatus FSCompareFSRefs(const FSRef* ref1, const FSRef* ref2)
{
	if (!ref1 || !ref2)
		return paramErr;

	std::string path1, path2;
	struct stat st1, st2;

	if (!FSRefMakePath(ref1, path1) || !FSRefMakePath(ref2, path2))
		return fnfErr;

	if (lstat(path1.c_str(), &st1) != 0 || lstat(path2.c_str(), &st2) != 0)
		return fnfErr;

	if (st1.st_dev != st2.st_dev)
		return diffVolErr;

	return (st1.st_ino == st2.st_ino) ? noErr : errFSRefsDifferent;
}

bool FSRefParamMakePath(const FSRefParam* param, std::string& out)
{
	std::string dir;
	CFStringRef str;
	std::unique_ptr<char[]> buf;
	size_t bufsize;
	Boolean success;
	
	if (!FSRefMakePath(param->ref, dir))
		return false;
	
	out = dir;
	if (out.back() != '/')
		out += '/';
	
	str = CFStringCreateWithCharacters(NULL, param->name, param->nameLength);
	bufsize = CFStringGetLength(str)*4+1;
	buf.reset(new char[bufsize]);
	
	success = CFStringGetCString(str, buf.get(), bufsize, kCFStringEncodingUTF8);
	CFRelease(str);
	
	if (success)
	{
		out += buf.get();
		return true;
	}
	else
		return false;
}

OSStatus FSDeleteObject(const FSRef* fsref)
{
	std::string path;
	if (FSRefMakePath(fsref, path))
	{
		if (::unlink(path.c_str()) == -1)
			return makeOSStatus(errno);
		return noErr;
	}
	return fnfErr;
}

OSStatus FSRefMakePath(const FSRef* fsref, uint8_t* path, uint32_t maxSize)
{
	std::string rpath;

	if (!fsref || !path || !maxSize)
		return paramErr;

	if (!FSRefMakePath(fsref, rpath))
		return fnfErr;

	strncpy((char*) path, rpath.c_str(), maxSize);
	path[maxSize-1] = 0;

	return noErr;
}

// OSXER APPS (catalog): path resolution stays in the existing FSRef backend.
OSStatus FSGetCatalogInfo(const FSRef* ref, uint32_t infoBits, FSCatalogInfo* infoOut,
    HFSUniStr255* nameOut, FSSpecPtr fsspec, FSRef* parentDir)
{
    if (!ref || (infoBits && !infoOut)) return paramErr;
    if (fsspec) {
        OSXER_APPS_STUB("legacy FSSpec output unavailable");
        return unimpErr;
    }
    const uint32_t supported = kFSCatInfoNodeFlags | kFSCatInfoNodeID |
        kFSCatInfoParentDirID | kFSCatInfoCreateDate | kFSCatInfoContentMod |
        kFSCatInfoAttrMod | kFSCatInfoAccessDate | kFSCatInfoPermissions |
        kFSCatInfoUserAccess | kFSCatInfoUserPrivs | kFSCatInfoDataSizes |
        kFSCatInfoRsrcSizes | kFSCatInfoFinderInfo | kFSCatInfoFinderXInfo |
        kFSCatInfoValence;
    if (infoBits & ~supported) {
        OSXER_APPS_STUB("requested catalog fields unavailable");
        return unimpErr;
    }
    std::string path;
    if (!FSRefMakePath(ref, path)) return fnfErr;
    struct stat st;
    if (lstat(path.c_str(), &st) != 0) return makeOSStatus(errno);
    auto slash = path.find_last_of('/');
    std::string parent = slash == 0 ? "/" : path.substr(0, slash);
    std::string leaf = path == "/" ? "/" : path.substr(slash + 1);
    if (nameOut) {
        CFStringRef name = CFStringCreateWithCString(NULL, leaf.c_str(), kCFStringEncodingUTF8);
        if (!name) return bdNamErr;
        CFIndex length = CFStringGetLength(name);
        if (length > 255) { CFRelease(name); return errFSNameTooLong; }
        nameOut->length = length;
        CFStringGetCharacters(name, CFRangeMake(0, length), nameOut->unicode);
        CFRelease(name);
    }
    if (parentDir) {
        OSStatus result = FSPathMakeRef((const UInt8*)parent.c_str(), parentDir, NULL);
        if (result) return result;
    }
    if (!infoOut || !infoBits) return noErr;
    memset(infoOut, 0, sizeof(*infoOut));
    if (infoBits & kFSCatInfoNodeFlags) infoOut->nodeFlags = S_ISDIR(st.st_mode) ? 4 : 0;
    if (infoBits & kFSCatInfoNodeID) infoOut->nodeID = st.st_ino;
    if (infoBits & kFSCatInfoParentDirID) {
        struct stat pst;
        if (stat(parent.c_str(), &pst)) return makeOSStatus(errno);
        infoOut->parentDirID = pst.st_ino;
    }
    if (infoBits & kFSCatInfoDataSizes) {
        infoOut->dataLogicalSize = st.st_size;
        infoOut->dataPhysicalSize = st.st_blocks * 512;
    }
    if (infoBits & kFSCatInfoRsrcSizes) {
        ssize_t length = getxattr(path.c_str(), "com.apple.ResourceFork", NULL, 0, 0, XATTR_NOFOLLOW);
        if (length < 0 && errno != ENOATTR && errno != ENOTSUP) return makeOSStatus(errno);
        infoOut->rsrcLogicalSize = infoOut->rsrcPhysicalSize = length < 0 ? 0 : length;
    }
    if (infoBits & (kFSCatInfoFinderInfo | kFSCatInfoFinderXInfo)) {
        unsigned char finder[32] = {};
        ssize_t length = getxattr(path.c_str(), "com.apple.FinderInfo", finder, sizeof(finder), 0, XATTR_NOFOLLOW);
        if (length < 0 && errno != ENOATTR && errno != ENOTSUP) return makeOSStatus(errno);
        if (infoBits & kFSCatInfoFinderInfo) memcpy(infoOut->finderInfo, finder, 16);
        if (infoBits & kFSCatInfoFinderXInfo) memcpy(infoOut->extFinderInfo, finder + 16, 16);
    }
    int access = st.st_uid == geteuid() ? (st.st_mode >> 6) & 7 :
        hasgid(st.st_gid) ? (st.st_mode >> 3) & 7 : st.st_mode & 7;
    if (infoBits & (kFSCatInfoPermissions | kFSCatInfoUserAccess)) {
        infoOut->fsPermissionInfo.userID = st.st_uid;
        infoOut->fsPermissionInfo.groupID = st.st_gid;
        infoOut->fsPermissionInfo.mode = st.st_mode & 07777;
        infoOut->fsPermissionInfo.userAccess = access;
    }
    if (infoBits & kFSCatInfoUserPrivs) {
        if (!(access & 2)) infoOut->userPrivileges |= 4;
        if (geteuid() != st.st_uid) infoOut->userPrivileges |= 0x80;
    }
    if (infoBits & kFSCatInfoCreateDate) infoOut->createDate = Darling::time_tToUTC(st.st_birthtime);
    if (infoBits & kFSCatInfoContentMod) infoOut->contentModDate = Darling::time_tToUTC(st.st_mtime);
    if (infoBits & kFSCatInfoAttrMod) infoOut->attributeModDate = Darling::time_tToUTC(st.st_ctime);
    if (infoBits & kFSCatInfoAccessDate) infoOut->accessDate = Darling::time_tToUTC(st.st_atime);
    if ((infoBits & kFSCatInfoValence) && S_ISDIR(st.st_mode)) {
        DIR *dir = opendir(path.c_str());
        if (!dir) return makeOSStatus(errno);
        errno = 0;
        while (struct dirent *entry = readdir(dir)) {
            if (strcmp(entry->d_name, ".") && strcmp(entry->d_name, "..")) ++infoOut->valence;
        }
        int error = errno;
        closedir(dir);
        if (error) return makeOSStatus(error);
    }
    return noErr;
}

// OSXER APPS (file copy): the default operation copies data and metadata through
// libcopyfile. Unsupported policy flags fail before any filesystem changes.
OSStatus FSCopyObjectSync(const FSRef *source, const FSRef *destDir, CFStringRef destName,
                         FSRef *target, OptionBits options)
{
    if (!source || !destDir) return paramErr;
    if (options) { OSXER_APPS_STUB("non-default file copy options unavailable"); return unimpErr; }
    std::string from, directory;
    if (!FSRefMakePath(source, from) || !FSRefMakePath(destDir, directory)) return fnfErr;
    struct stat st;
    if (stat(directory.c_str(), &st)) return makeOSStatus(errno);
    if (!S_ISDIR(st.st_mode)) return errFSNotAFolder;
    std::string name = from.substr(from.find_last_of('/') + 1);
    if (destName) {
        CFIndex size = CFStringGetMaximumSizeForEncoding(CFStringGetLength(destName), kCFStringEncodingUTF8) + 1;
        std::vector<char> buffer(size);
        if (!CFStringGetCString(destName, buffer.data(), size, kCFStringEncodingUTF8)) return bdNamErr;
        // Reject embedded NULs instead of silently shortening the requested name.
        CFStringRef roundtrip = CFStringCreateWithCString(NULL, buffer.data(), kCFStringEncodingUTF8);
        bool matches = roundtrip && CFEqual(roundtrip, destName);
        if (roundtrip) CFRelease(roundtrip);
        if (!matches) return bdNamErr;
        name = buffer.data();
    }
    if (name.empty() || name == "." || name == ".." || name.find('/') != std::string::npos) return bdNamErr;
    struct stat sourceStat;
    if (lstat(from.c_str(), &sourceStat)) return makeOSStatus(errno);
    if (S_ISDIR(sourceStat.st_mode)) {
        // libcopyfile does not currently reject recursive copies into the source.
        // Canonical directory paths catch aliases as well as direct descendants.
        std::unique_ptr<char, decltype(&free)> realSource(realpath(from.c_str(), NULL), free);
        std::unique_ptr<char, decltype(&free)> realDestination(realpath(directory.c_str(), NULL), free);
        if (!realSource || !realDestination) return makeOSStatus(errno);
        std::string base = realSource.get(), destination = realDestination.get();
        if (destination == base || base == "/" || destination.compare(0, base.size() + 1, base + "/") == 0)
            return paramErr;
    }
    std::string to = directory + "/" + name;
    if (copyfile(from.c_str(), to.c_str(), NULL,
        COPYFILE_ALL | COPYFILE_RECURSIVE | COPYFILE_EXCL | COPYFILE_NOFOLLOW)) return makeOSStatus(errno);
    return target ? FSPathMakeRef((const UInt8*)to.c_str(), target, NULL) : noErr;
}

// OSXER APPS (catalog permissions): bound retries and avoid the old endless loop.
bool hasgid(gid_t gid)
{
    if (getegid() == gid) return true;
    for (int attempt = 0; attempt < 3; ++attempt) {
        int count = getgroups(0, NULL);
        if (count < 0) return false;
        std::vector<gid_t> groups(count);
        int actual = getgroups(count, groups.data());
        if (actual < 0) { if (errno == EINVAL) continue; return false; }
        if (actual > count) continue;
        return std::find(groups.begin(), groups.begin() + actual, gid) != groups.begin() + actual;
    }
    return false;
}

static std::string getUserDirsConfigPath()
{
	std::stringstream ss;
	const char *home, *config;
	
	config = getenv("XDG_CONFIG_HOME");
	
	if (!config)
	{
		home = getenv("HOME");
		if (!home)
			return std::string();
	
		ss << home << "/.config";
	}
	else
		ss << config;
	ss << "user-dirs.dirs";
	
	return ss.str();
}

static std::string extractXDGValue(const char* home, const std::string& line)
{
	regmatch_t matches[2];
	static regex_t regexp = []() -> regex_t {
		regex_t re;
		regcomp(&re, "=\"([^\"]+)\"", REG_EXTENDED);
		return re;
	}();
	
	if (regexec(&regexp, line.c_str(), 2, matches, 0) == 0)
	{
		std::string value = line.substr(matches[1].rm_so, matches[1].rm_eo - matches[1].rm_so);
		size_t pos = value.find("$HOME");
		
		if (pos != std::string::npos)
			value.replace(pos, 5, home);
		return value;
	}
	
	return std::string();
}

// TODO: Test this function!
OSStatus FSFindFolder(long vRefNum, OSType folderType, Boolean createFolder, FSRef* location)
{
	if (folderType == kTemporaryFolderType)
	{
		const char* tmpdir = getenv("TMPDIR");
		
		if (!tmpdir)
			tmpdir = "/tmp";
		
		FSPathMakeRef((const uint8_t*) tmpdir, location, nullptr);
		
		if (createFolder && access(tmpdir, F_OK) != 0)
			mkdir(tmpdir, 0777);
		
		return noErr;
	}
	else if (folderType == kDesktopFolderType || folderType == kSystemDesktopFolderType)
	{
		std::string xdgConfig = getUserDirsConfigPath();
		std::ifstream cfg(xdgConfig.c_str());
		std::string line, desktop;
		const char* home = getenv("HOME");
		
		desktop = home;
		desktop += "/Desktop";
	
		if (cfg.is_open())
		{
			while (std::getline(cfg, line))
			{
				if (line.compare(0, 17, "XDG_DESKTOP_DIR=\"") == 0)
				{
					std::string d = extractXDGValue(home, line);
					if (!d.empty())
						desktop = d;
					
					break;
				}
			}
		}
		
		FSPathMakeRef((const uint8_t*) desktop.c_str(), location, nullptr);
		
		if (createFolder && access(desktop.c_str(), F_OK) != 0)
			mkdir(desktop.c_str(), 0777);
		
		return noErr;
	}
	else
		return unimpErr;
}

OSErr PBCreateDirectoryUnicodeSync(FSRefParam* paramBlock)
{
	std::string path;
	
	if (!FSRefParamMakePath(paramBlock, path))
		return fnfErr;
	if (mkdir(path.c_str(), 0777) == -1)
		return makeOSStatus(errno);
	
	if (paramBlock->newRef)
		FSPathMakeRef((uint8_t*) path.c_str(), paramBlock->newRef, nullptr);
	
	return noErr;
}

OSErr PBCreateFileUnicodeSync(FSRefParam* paramBlock)
{
	std::string path;
	
	if (!FSRefParamMakePath(paramBlock, path))
		return fnfErr;
	if (open(path.c_str(), O_CREAT|O_EXCL, 0666) == -1)
		return makeOSStatus(errno);
	
	if (paramBlock->newRef)
		FSPathMakeRef((uint8_t*) path.c_str(), paramBlock->newRef, nullptr);
	
	return noErr;
}

OSErr PBGetCatalogInfoSync(FSRefParam *paramBlock)
{
	STUB();
	return unimpErr;
}

OSErr PBMakeFSRefUnicodeSync(FSRefParam *paramBlock)
{
	std::string path;
	
	if (!paramBlock->newRef)
		return paramErr;
	if (!FSRefParamMakePath(paramBlock, path))
		return fnfErr;
	FSPathMakeRef((uint8_t*) path.c_str(), paramBlock->newRef, nullptr);
	
	return noErr;
}

OSErr PBOpenForkSync(FSForkIOParam *paramBlock)
{
	STUB();
	return unimpErr;
}

OSErr PBReadForkSync(FSForkIOParam *paramBlock)
{
	STUB();
	return unimpErr;
}

OSErr PBWriteForkSync(FSForkIOParam *paramBlock)
{
	STUB();
	return unimpErr;
}

OSErr PBIterateForksSync(FSForkIOParam *paramBlock)
{
	STUB();
	return unimpErr;
}

OSErr PBCloseForkSync(FSForkIOParam *paramBlock)
{
	STUB();
	return unimpErr;
}
