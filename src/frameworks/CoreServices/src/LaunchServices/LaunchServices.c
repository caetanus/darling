/*
 This file is part of Darling.

 Copyright (C) 2019 Lubos Dolezel

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

#include <LaunchServices/LaunchServices.h>
#include <LaunchServices/LaunchServicesPriv.h>
#include "LSHostOpen.h"
#include <stdio.h>
#include <stdlib.h>
#include <launch_priv.h>
#include <errno.h>
#include <stdint.h>
#include <os/log.h>

static void get_main_executable_info(CFURLRef appURL, CFStringRef *exec, CFStringRef *bundleName);
static OSStatus launch_application_with_items(CFURLRef appURL, CFArrayRef items);

static int verbose = 0;

__attribute__((constructor)) static void initme(void) {
	verbose = getenv("STUB_VERBOSE") != NULL;
}

OSStatus LSRegisterURL(CFURLRef inURL, Boolean inUpdate)
{
	if (verbose)
		printf("STUB: LSRegisterURL\n");
	return 0;
}

static Boolean is_application_url(CFURLRef url)
{
	CFStringRef extension = CFURLCopyPathExtension(url);
	Boolean ret = FALSE;

	if (extension != NULL)
	{
		ret = CFStringCompare(extension, CFSTR("app"), kCFCompareCaseInsensitive) == kCFCompareEqualTo;
		CFRelease(extension);
	}
	return ret;
}

static Boolean is_file_url(CFURLRef url)
{
	CFStringRef scheme = CFURLCopyScheme(url);
	Boolean ret = FALSE;

	if (scheme != NULL)
	{
		ret = CFStringCompare(scheme, CFSTR("file"), kCFCompareCaseInsensitive) == kCFCompareEqualTo;
		CFRelease(scheme);
	}
	return ret;
}

static OSStatus launch_application(CFURLRef appURL, CFArrayRef items, CFURLRef *outLaunchedURL)
{
	OSStatus ret = launch_application_with_items(appURL, items);

	if (ret == noErr && outLaunchedURL != NULL)
	{
		if (*outLaunchedURL != NULL)
			CFRelease(*outLaunchedURL);
		*outLaunchedURL = CFRetain(appURL);
	}
	return ret;
}

/*
 * Not supported yet:
 * - Apple Events: no transport to a running application exists yet.
 *   OSXER MVP (open documents): new instances receive file paths as argv,
 *   which AppKit routes to the delegate/document controller at launch.
 * - passThruParams and launchFlags: every call starts a new instance.
 */
OSStatus LSOpenFromURLSpec(const LSLaunchURLSpec *inLaunchSpec, CFURLRef *outLaunchedURL)
{
	CFIndex count, i;
	CFURLRef url;
	OSStatus ret = noErr, temp;

	if (outLaunchedURL != NULL)
		*outLaunchedURL = NULL;

	if (inLaunchSpec == NULL)
		return paramErr;

	count = inLaunchSpec->itemURLs != NULL ? CFArrayGetCount(inLaunchSpec->itemURLs) : 0;

	if (inLaunchSpec->appURL != NULL)
	{
		/* The application opens all items, so it is launched once */
		return launch_application(inLaunchSpec->appURL, inLaunchSpec->itemURLs, outLaunchedURL);
	}

	if (count == 0)
		return paramErr;

	for (i = 0; i < count; i++)
	{
		url = CFArrayGetValueAtIndex(inLaunchSpec->itemURLs, i);

		if (is_file_url(url))
		{
			/* OSXER MVP (open documents): use the existing file association API. */
			if (is_application_url(url))
				temp = launch_application(url, NULL, outLaunchedURL);
			else {
				CFURLRef app = NULL;
				temp = LSGetApplicationForURL(url, kLSRolesAll, NULL, &app);
				if (temp == noErr && app) {
					CFArrayRef items = CFArrayCreate(NULL, (const void **)&url, 1, &kCFTypeArrayCallBacks);
					temp = items ? launch_application(app, items, outLaunchedURL) : memFullErr;
					if (items) CFRelease(items);
				} else if (temp == noErr) {
					temp = kLSApplicationNotFoundErr;
				}
				if (app) CFRelease(app);
			}
		}
		else if (_LSIsHostOpenURL(url))
		{
			temp = _LSOpenURLOnHost(url);
			if (temp)
				ret = temp;
		}
		else
			temp = kLSApplicationNotFoundErr;

		if (temp != noErr)
			ret = temp;
	}
	return ret;
}

OSStatus _LSLaunchApplication(CFURLRef appPath)
{
	return launch_application_with_items(appPath, NULL);
}

// OSXER MVP (open documents): argv owns copied, absolute file paths until spawn.
static OSStatus launch_application_with_items(CFURLRef appPath, CFArrayRef items)
{
	CFStringRef executable = NULL, bundleName = NULL;
	CFIndex nameSize = 0, execSize = 0;
	CFURLRef pre = NULL, url_plus_exec = NULL;
	pid_t pid = -1;
	char *name = NULL, *exec = NULL, **argv = NULL;
	CFIndex count = items ? CFArrayGetCount(items) : 0;
	OSStatus status = kLSApplicationNotFoundErr;
	if (count < 0 || (uint64_t) count > SIZE_MAX / sizeof(char *) - 2)
		return paramErr;
	argv = calloc((size_t) count + 2, sizeof(char *));
	if (!argv)
		return memFullErr;
	for (CFIndex i = 0; i < count; i++) {
		CFURLRef item = CFArrayGetValueAtIndex(items, i);
		if (!item || CFGetTypeID(item) != CFURLGetTypeID() || !is_file_url(item)) {
			status = paramErr;
			goto cleanup;
		}
		CFURLRef absolute = CFURLCopyAbsoluteURL(item);
		CFStringRef path = absolute ? CFURLCopyFileSystemPath(absolute, kCFURLPOSIXPathStyle) : NULL;
		if (absolute) CFRelease(absolute);
		CFIndex size = path ? CFStringGetMaximumSizeOfFileSystemRepresentation(path) : 0;
		argv[i + 1] = size > 0 ? malloc(size) : NULL;
		Boolean converted = argv[i + 1] && CFStringGetFileSystemRepresentation(path, argv[i + 1], size);
		if (path) CFRelease(path);
		if (!converted) {
			status = paramErr;
			goto cleanup;
		}
	}

	/* Read info.plist, find path to main executable */
	get_main_executable_info(appPath, &executable, &bundleName);
	if (executable == NULL)
	{
		goto cleanup;
	}

	url_plus_exec = CFURLCreateCopyAppendingPathComponent(kCFAllocatorDefault, appPath, CFSTR("Contents"), TRUE);
	if (!url_plus_exec)
		goto cleanup;

	pre = CFURLCreateCopyAppendingPathComponent(kCFAllocatorDefault, url_plus_exec, CFSTR("MacOS"), TRUE);
	CFRelease(url_plus_exec);
	url_plus_exec = NULL;
	if (!pre)
		goto cleanup;

	url_plus_exec = CFURLCreateCopyAppendingPathComponent(kCFAllocatorDefault, pre, executable, FALSE);
	CFRelease(pre);
	pre = NULL;
	if (!url_plus_exec)
		goto cleanup;

	/* Launch the executable */
	CFStringRef execPath = CFURLCopyFileSystemPath(url_plus_exec, kCFURLPOSIXPathStyle);
	CFRelease(url_plus_exec);
	url_plus_exec = NULL;
	if (!execPath)
		goto cleanup;

	/* Try to use CFBundleName first */
	if (bundleName == NULL)
		bundleName = CFStringCreateCopy(kCFAllocatorDefault, execPath);
	if (!bundleName)
	{
		CFRelease(execPath);
		goto cleanup;
	}

	nameSize = CFStringGetMaximumSizeOfFileSystemRepresentation(bundleName);
	name = malloc(nameSize);
	if (!name)
	{
		CFRelease(execPath);
		goto cleanup;
	}
	CFStringGetFileSystemRepresentation(bundleName, name, nameSize);

	execSize = CFStringGetMaximumSizeOfFileSystemRepresentation(execPath);
	exec = malloc(execSize);
	if (!exec)
	{
		CFRelease(execPath);
		goto cleanup;
	}
	CFStringGetFileSystemRepresentation(execPath, exec, execSize);
	CFRelease(execPath);

	argv[0] = exec;
	/* Applications are launchd jobs, as on macOS. */
	pid = spawn_via_launchd(name, (const char *const *)argv, NULL);
	if (pid < 0)
	{
		os_log_error(OS_LOG_DEFAULT, "LaunchServices: launchd could not spawn %{public}s: %{darwin.errno}d", exec, errno);
		status = kLSApplicationNotFoundErr;
		goto cleanup;
	}

	status = noErr;

cleanup:
	if (argv) {
		for (CFIndex i = 0; i < count; i++)
			free(argv[i + 1]);
		free(argv);
	}
	if (name)
		free(name);
	if (exec)
		free(exec);
	if (executable)
		CFRelease(executable);
	if (bundleName)
		CFRelease(bundleName);

	return status;
}

static void get_main_executable_info(CFURLRef appURL, CFStringRef *exec, CFStringRef *bundleName)
{
	CFURLRef pre = CFURLCreateCopyAppendingPathComponent(kCFAllocatorDefault, appURL, CFSTR("Contents"), TRUE);
	CFURLRef info_plist_url = CFURLCreateCopyAppendingPathComponent(kCFAllocatorDefault, pre, CFSTR("Info.plist"), FALSE);
	CFReadStreamRef rs = CFReadStreamCreateWithFile(kCFAllocatorDefault, info_plist_url);
	CFDictionaryRef info_plist;
	CFStringRef ret = NULL;

	/* TODO: Simplify by using CFBundleGetInfoDictionary */

	*exec = NULL;
	*bundleName = NULL;

	CFRelease(pre);

	if (!CFReadStreamOpen(rs))
		goto err_pre_info;

	info_plist = CFPropertyListCreateWithStream(kCFAllocatorDefault, rs, 0, 0, NULL, NULL);
	if (info_plist == NULL)
		goto err_close;

	if (CFGetTypeID(info_plist) != CFDictionaryGetTypeID())
		goto err;

	ret = CFDictionaryGetValue(info_plist, CFSTR("CFBundleExecutable"));
	if (ret != NULL)
		ret = CFStringCreateCopy(kCFAllocatorDefault, ret);

	*exec = ret;

	ret = CFDictionaryGetValue(info_plist, CFSTR("CFBundleName"));
	if (ret != NULL)
		*bundleName = CFStringCreateCopy(kCFAllocatorDefault, ret);

err:
	CFRelease(info_plist);
err_close:
	CFReadStreamClose(rs);
err_pre_info:
	CFRelease(rs);
	CFRelease(info_plist_url);
}
