/*
This file is part of Darling.

Copyright (C) 2020 Lubos Dolezel

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
#include <CarbonCore/MacErrors.h>
#include "LSHostOpen.h"
#include <stdio.h>
#include <sqlite3.h>
#import <Foundation/NSString.h>
#import <fmdb/FMDatabaseQueue.h>

__attribute__((visibility("hidden")))
FMDatabaseQueue* getDatabaseQueue(void)
{
	static dispatch_once_t pred;
	static FMDatabaseQueue* db;
	dispatch_once(&pred, ^{
		db = [[FMDatabaseQueue databaseQueueWithPath: @"/private/var/db/launchservices.db" flags:SQLITE_OPEN_READONLY] retain];
	});
	return db;
}

__attribute__((visibility("hidden")))
NSString* escape(NSString* str)
{
	return [str stringByReplacingOccurrencesOfString:@"'"
		withString:@"''"];
}

// An SQL-safe fourcc string
static NSString* fourcc(UInt32 code)
{
	CFStringRef str = UTCreateStringForOSType(code);
	NSString* rv = escape((NSString*) str);
	CFRelease(str);

	return rv;
}

OSStatus
LSFindApplicationForInfo(
  OSType inCreator,
  CFStringRef inBundleID,
  CFStringRef inName,
  FSRef * outAppRef,
  CFURLRef * outAppURL)
{
	if (outAppURL)
		*outAppURL = NULL;

	if (inCreator == kLSUnknownCreator && !inBundleID && !inName)
		return paramErr;

	__block OSStatus retval;
	FMDatabaseQueue* dq = getDatabaseQueue();

	if (dq == nil)
		return fnfErr;

	[dq inDatabase:^(FMDatabase* db) {
		NSString* query = @"select path from bundle where package_type='APPL'";

		if (inCreator != kLSUnknownCreator)
			query = [query stringByAppendingFormat:@" and creator = '%@'", fourcc(inCreator)];
		if (inBundleID != NULL)
			query = [query stringByAppendingFormat:@" and bundle_id = '%@'", escape((NSString*) inBundleID)];
		if (inName != NULL)
			query = [query stringByAppendingFormat:@" and path like '%%%@'", escape((NSString*) inName)];
		
		FMResultSet* rs = [db executeQuery:query];
		if ([rs next])
		{
			NSString* path = [rs stringForColumn:@"path"];
			if (outAppURL)
				*outAppURL = (CFURLRef) [[NSURL alloc] initFileURLWithPath:path isDirectory:YES];
			if (outAppRef)
				FSPathMakeRef((const UInt8*) [path fileSystemRepresentation], outAppRef, NULL);

			retval = noErr;
		}
		else
			retval = kLSApplicationNotFoundErr;
		[rs close];
	}];

	return retval;
}

CFArrayRef LSCopyApplicationURLsForBundleIdentifier(CFStringRef inBundleIdentifier, CFErrorRef  _Nullable *outError)
{
	if (!inBundleIdentifier)
	{
		if (outError)
			*outError = CFErrorCreate(NULL, kCFErrorDomainOSStatus, paramErr, NULL);
		return NULL;
	}

	__block CFArrayRef retval;
	FMDatabaseQueue* dq = getDatabaseQueue();

	if (dq == nil)
	{
		if (outError)
			*outError = CFErrorCreate(NULL, kCFErrorDomainOSStatus, fnfErr, NULL);
		return NULL;
	}

	[dq inDatabase:^(FMDatabase* db) {
		FMResultSet* rs = [db executeQuery:@"select path from bundle where package_type='APPL' and bundle_id = ?", inBundleIdentifier];

		if ([rs next])
		{
			NSMutableArray* mut = [[NSMutableArray alloc] init];
			do
			{
				[mut addObject: [NSURL fileURLWithPath: [rs stringForColumn:@"path"] isDirectory: YES]];
			}
			while ([rs next]);

			retval = (CFArrayRef) [[NSArray alloc] initWithArray: mut];
			[mut release];
		}
		else
		{
			if (outError)
				*outError = CFErrorCreate(NULL, kCFErrorDomainOSStatus, kLSApplicationNotFoundErr, NULL);
			retval = NULL;
		}
		[rs close];
	}];

	return retval;
}

static NSString* appendRole(NSString* str, NSString* role)
{
	if (str == nil)
		return [NSString stringWithFormat:@"'%@'", role];
	else
		return [str stringByAppendingFormat:@",'%@'", role];
}

static NSString* roleSQLArray(LSRolesMask inRoleMask)
{
	NSString* str = nil;
	if (inRoleMask & kLSRolesNone)
		str = appendRole(str, @"None");
	if (inRoleMask & kLSRolesViewer)
		str = appendRole(str, @"Viewer");
	if (inRoleMask & kLSRolesEditor)
		str = appendRole(str, @"Editor");
	if (inRoleMask & kLSRolesShell)
		str = appendRole(str, @"Shell");
	return str;
}

OSStatus
LSGetApplicationForInfo(
  OSType inType,
  OSType inCreator,
  CFStringRef inExtension,
  LSRolesMask inRoleMask,
  FSRef * outAppRef,
  CFURLRef * outAppURL)
{
	__block OSStatus retval;

	if (outAppURL)
		*outAppURL = NULL;

	if (inType == kLSUnknownType && inCreator == kLSUnknownCreator && inExtension == NULL)
	{
		return paramErr;
	}

	FMDatabaseQueue* dq = getDatabaseQueue();
	if (dq == nil)
		return fnfErr;

	[dq inDatabase:^(FMDatabase* db) {
		NSString* query = @"select path, AD.rank from bundle INNER JOIN app_doc AD on AD.bundle=bundle.id where bundle.package_type='APPL'";

		if (inExtension != NULL)
		{
			NSString* escaped = escape((NSString*) inExtension);
			query = [query stringByAppendingFormat:@" and (EXISTS (SELECT * FROM app_doc_extension AE WHERE AE.doc=AD.id AND AE.extension = '%@')"
							@" OR "
					@"EXISTS (SELECT * FROM app_doc_uti AU JOIN uti ON uti.type_identifier = AU.uti JOIN uti_tag UT ON UT.uti=uti.id WHERE AU.doc=AD.id AND UT.tag = 'public.filename-extension' AND UT.value='%@'))",
					escaped, escaped];
		}
		
		if (inType != kLSUnknownType)
			query = [query stringByAppendingFormat:@" and signature='%@'", fourcc(inType)];
		if (inCreator != kLSUnknownCreator)
			query = [query stringByAppendingFormat:@" and creator='%@'", fourcc(inCreator)];
		if (inRoleMask != kLSRolesAll)
		{
			query = [query stringByAppendingFormat:@" and AD.role IN (%@)", roleSQLArray(inRoleMask)];
		}

		query = [query stringByAppendingString:@" order by case "
			@"when AD.rank='Owner' then 1 "
			@"when AD.rank='Default' then 2 "
			@"when AD.rank='Alternate' then 3 "
			@"else 5 "
			@"end asc"];

		FMResultSet* rs = [db executeQuery:query];
		if ([rs next])
		{
			NSString* path = [rs stringForColumn:@"path"];
			if (outAppURL)
				*outAppURL = (CFURLRef) [[NSURL alloc] initFileURLWithPath:path isDirectory:YES];
			if (outAppRef)
				FSPathMakeRef((const UInt8*) [path fileSystemRepresentation], outAppRef, NULL);

			retval = noErr;
		}
		else
			retval = kLSApplicationNotFoundErr;
		[rs close];
	}];

	return retval;
}

// OSXER APPKIT (default application consistency): the role-handler API owns
// both user overrides and declared fallbacks. Resolve its bundle through the
// same registration database used by the other application lookup APIs.
CFURLRef LSCopyDefaultApplicationURLForContentType(CFStringRef type, LSRolesMask roles, CFErrorRef *outError)
{
    if (outError) *outError = NULL;
    CFURLRef result = NULL;
    OSStatus status = paramErr;
    if (type != NULL) {
        CFStringRef identifier = LSCopyDefaultRoleHandlerForContentType(type, roles);
        status = kLSApplicationNotFoundErr;
        if (identifier != NULL) {
            status = LSFindApplicationForInfo(kLSUnknownCreator, identifier, NULL, NULL, &result);
            CFRelease(identifier);
        }
    }
    if (status != noErr && outError)
        *outError = CFErrorCreate(NULL, kCFErrorDomainOSStatus, status, NULL);
    return result;
}

CFURLRef LSCopyDefaultApplicationURLForURL(CFURLRef inURL, LSRolesMask inRoleMask, CFErrorRef  _Nullable *outError)
{
	CFURLRef retval = NULL;
	OSStatus status = LSGetApplicationForURL(inURL, inRoleMask, NULL, &retval);

	if (status != noErr)
	{
		if (outError)
			*outError = CFErrorCreate(NULL, kCFErrorDomainOSStatus, status, NULL);
		return NULL;
	}
	else
	{
		if (outError)
			*outError = NULL;
		return retval;
	}
}

OSStatus LSGetApplicationForURL(CFURLRef inURL, LSRolesMask inRoleMask, FSRef *outAppRef, CFURLRef *outAppURL)
{
	/* Web and mail links are opened by the host desktop, not by an application
	   in the prefix, so there is none to report. An extension lookup would map
	   https://x/a.html to a Mac application. */
	if (_LSIsHostOpenURL(inURL))
		return kLSApplicationNotFoundErr;

	NSString* extension = [(NSURL*) inURL pathExtension];
	return LSGetApplicationForInfo(kLSUnknownType, kLSUnknownCreator, (CFStringRef) extension, inRoleMask, outAppRef, outAppURL);
}

CFArrayRef LSCopyAllHandlersForURLScheme(CFStringRef inURLScheme)
{
	puts("LSCopyAllHandlersForURLScheme STUB");
	// NULL is a safe assumption to fall back on in the stub, since it means none were found.
	return NULL;
}

CFArrayRef LSCopyAllRoleHandlersForContentType(CFStringRef inContentType, LSRolesMask inRole)
{
	puts("LSCopyAllRoleHandlersForContentType STUB");
	// NULL is a safe assumption to fall back on in the stub, since it means none were found.
	return NULL;
}

// The user's choice of default handlers is kept in the LaunchServices
// preferences as an "LSHandlers" array. Each entry names either a URL
// scheme or a content type and maps role keys to a bundle identifier.
// Handlers declared by the installed applications come from the database.
static const CFStringRef kLSHandlersPrefsDomain = CFSTR("com.apple.LaunchServices");
static const CFStringRef kLSHandlersKey = CFSTR("LSHandlers");
static const CFStringRef kLSHandlerURLSchemeKey = CFSTR("LSHandlerURLScheme");
static const CFStringRef kLSHandlerContentTypeKey = CFSTR("LSHandlerContentType");
static const CFStringRef kLSHandlerRoleAllKey = CFSTR("LSHandlerRoleAll");

static const struct
{
	LSRolesMask role;
	CFStringRef key;
} kLSHandlerRoleKeys[] = {
	{ kLSRolesNone, CFSTR("LSHandlerRoleNone") },
	{ kLSRolesViewer, CFSTR("LSHandlerRoleViewer") },
	{ kLSRolesEditor, CFSTR("LSHandlerRoleEditor") },
	{ kLSRolesShell, CFSTR("LSHandlerRoleShell") },
};

static Boolean handlerMatches(CFDictionaryRef entry, CFStringRef matchKey, CFStringRef value)
{
	CFStringRef entryValue;

	if (CFGetTypeID(entry) != CFDictionaryGetTypeID())
		return FALSE;

	entryValue = CFDictionaryGetValue(entry, matchKey);
	return entryValue != NULL && CFGetTypeID(entryValue) == CFStringGetTypeID()
		&& CFStringCompare(entryValue, value, kCFCompareCaseInsensitive) == kCFCompareEqualTo;
}

static CFArrayRef copyHandlers(void)
{
	CFPropertyListRef handlers = CFPreferencesCopyValue(kLSHandlersKey, kLSHandlersPrefsDomain,
		kCFPreferencesCurrentUser, kCFPreferencesAnyHost);

	if (handlers != NULL && CFGetTypeID(handlers) != CFArrayGetTypeID())
	{
		CFRelease(handlers);
		handlers = NULL;
	}
	return (CFArrayRef) handlers;
}

// Returns the bundle ID the user chose for the first role key in roleKeys
// that has one.
static CFStringRef copyUserHandler(CFStringRef matchKey, CFStringRef value, const CFStringRef* roleKeys, CFIndex roleKeyCount)
{
	CFArrayRef handlers = copyHandlers();
	CFStringRef result = NULL;

	if (handlers == NULL)
		return NULL;

	for (CFIndex i = 0; i < CFArrayGetCount(handlers) && result == NULL; i++)
	{
		CFDictionaryRef entry = CFArrayGetValueAtIndex(handlers, i);

		if (!handlerMatches(entry, matchKey, value))
			continue;

		for (CFIndex j = 0; j < roleKeyCount; j++)
		{
			CFStringRef bundleID = CFDictionaryGetValue(entry, roleKeys[j]);
			if (bundleID != NULL && CFGetTypeID(bundleID) == CFStringGetTypeID())
			{
				result = CFStringCreateCopy(NULL, bundleID);
				break;
			}
		}
	}

	CFRelease(handlers);
	return result;
}

static OSStatus setUserHandler(CFStringRef matchKey, CFStringRef value, const CFStringRef* roleKeys, CFIndex roleKeyCount, CFStringRef bundleID)
{
	CFArrayRef handlers = copyHandlers();
	CFMutableArrayRef newHandlers;
	CFMutableDictionaryRef entry = NULL;
	CFIndex i, count;
	Boolean synced;

	newHandlers = handlers != NULL
		? CFArrayCreateMutableCopy(NULL, 0, handlers)
		: CFArrayCreateMutable(NULL, 0, &kCFTypeArrayCallBacks);
	if (handlers != NULL)
		CFRelease(handlers);

	count = CFArrayGetCount(newHandlers);
	for (i = 0; i < count; i++)
	{
		CFDictionaryRef existing = CFArrayGetValueAtIndex(newHandlers, i);
		if (handlerMatches(existing, matchKey, value))
		{
			entry = CFDictionaryCreateMutableCopy(NULL, 0, existing);
			break;
		}
	}

	if (entry == NULL)
	{
		entry = CFDictionaryCreateMutable(NULL, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
		CFDictionarySetValue(entry, matchKey, value);
	}

	for (CFIndex j = 0; j < roleKeyCount; j++)
		CFDictionarySetValue(entry, roleKeys[j], bundleID);

	if (i < count)
		CFArraySetValueAtIndex(newHandlers, i, entry);
	else
		CFArrayAppendValue(newHandlers, entry);
	CFRelease(entry);

	CFPreferencesSetValue(kLSHandlersKey, newHandlers, kLSHandlersPrefsDomain,
		kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
	CFRelease(newHandlers);

	synced = CFPreferencesSynchronize(kLSHandlersPrefsDomain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
	return synced ? noErr : kLSUnknownErr;
}

// Role keys to look at for inRole, most specific first.
static CFIndex roleKeysForMask(LSRolesMask inRole, CFStringRef* keys)
{
	CFIndex count = 0;

	if (inRole != kLSRolesAll)
	{
		for (size_t i = 0; i < sizeof(kLSHandlerRoleKeys) / sizeof(kLSHandlerRoleKeys[0]); i++)
		{
			if (inRole & kLSHandlerRoleKeys[i].role)
				keys[count++] = kLSHandlerRoleKeys[i].key;
		}
	}
	return count;
}

static CFStringRef copyDeclaredHandler(NSString* query, CFStringRef value)
{
	__block CFStringRef retval = NULL;
	FMDatabaseQueue* dq = getDatabaseQueue();

	if (dq == nil)
		return NULL;

	[dq inDatabase:^(FMDatabase* db) {
		FMResultSet* rs = [db executeQuery:query, value];
		if ([rs next])
			retval = (CFStringRef) [[rs stringForColumn:@"bundle_id"] copy];
		[rs close];
	}];

	return retval;
}

CFStringRef LSCopyDefaultHandlerForURLScheme(CFStringRef inURLScheme)
{
	CFStringRef roleKeys[] = { kLSHandlerRoleAllKey };
	CFStringRef handler;

	if (inURLScheme == NULL)
		return NULL;

	handler = copyUserHandler(kLSHandlerURLSchemeKey, inURLScheme, roleKeys, 1);
	if (handler != NULL)
		return handler;

	return copyDeclaredHandler(@"select bundle.bundle_id from bundle"
		@" INNER JOIN bundle_url_type T on T.bundle=bundle.id"
		@" INNER JOIN bundle_url_type_scheme S on S.type=T.id"
		@" where bundle.package_type='APPL' and S.scheme=?", inURLScheme);
}

OSStatus LSSetDefaultHandlerForURLScheme(CFStringRef inURLScheme, CFStringRef inHandlerBundleID)
{
	CFStringRef roleKeys[] = { kLSHandlerRoleAllKey };

	if (inURLScheme == NULL || inHandlerBundleID == NULL)
		return paramErr;

	return setUserHandler(kLSHandlerURLSchemeKey, inURLScheme, roleKeys, 1, inHandlerBundleID);
}

CFStringRef LSCopyDefaultRoleHandlerForContentType(CFStringRef inContentType, LSRolesMask inRole)
{
	CFStringRef roleKeys[5];
	CFIndex count;
	CFStringRef handler;
	NSString* query;

	if (inContentType == NULL)
		return NULL;

	count = roleKeysForMask(inRole, roleKeys);
	roleKeys[count++] = kLSHandlerRoleAllKey;

	handler = copyUserHandler(kLSHandlerContentTypeKey, inContentType, roleKeys, count);
	if (handler != NULL)
		return handler;

	query = @"select bundle.bundle_id, AD.rank from bundle INNER JOIN app_doc AD on AD.bundle=bundle.id"
		@" INNER JOIN app_doc_uti AU on AU.doc=AD.id WHERE bundle.package_type='APPL' AND AU.uti=?";
	if (inRole != kLSRolesAll)
		query = [query stringByAppendingFormat:@" and AD.role in (%@)", roleSQLArray(inRole)];
	query = [query stringByAppendingString:@" order by case "
		@"when AD.rank='Owner' then 1 "
		@"when AD.rank='Default' then 2 "
		@"when AD.rank='Alternate' then 3 "
		@"else 5 "
		@"end asc"];

	return copyDeclaredHandler(query, inContentType);
}

OSStatus LSSetDefaultRoleHandlerForContentType(CFStringRef inContentType, LSRolesMask inRole, CFStringRef inHandlerBundleID)
{
	CFStringRef roleKeys[4];
	CFIndex count;

	if (inContentType == NULL || inHandlerBundleID == NULL)
		return paramErr;

	if (inRole == kLSRolesAll)
	{
		roleKeys[0] = kLSHandlerRoleAllKey;
		count = 1;
	}
	else
		count = roleKeysForMask(inRole, roleKeys);

	if (count == 0)
		return paramErr;

	return setUserHandler(kLSHandlerContentTypeKey, inContentType, roleKeys, count, inHandlerBundleID);
}

OSStatus LSCopyApplicationForMIMEType(CFStringRef inMIMEType, LSRolesMask inRoleMask, CFURLRef *outAppURL)
{
	if (!outAppURL)
		return paramErr;
	*outAppURL = NULL;

	if (!inMIMEType)
		return paramErr;

	CFStringRef uti = UTTypeCreatePreferredIdentifierForTag(kUTTagClassMIMEType, inMIMEType, NULL);
	if (!uti)
		return kLSApplicationNotFoundErr;

	CFURLRef appURL = LSCopyDefaultApplicationURLForContentType(uti, inRoleMask, NULL);
	CFRelease(uti);

	if (appURL)
	{
		*outAppURL = appURL;
		return noErr;
	}
	return kLSApplicationNotFoundErr;
}

OSStatus LSCopyDisplayNameForURL(CFURLRef inURL, CFStringRef *outDisplayName)
{
	if (!inURL || !outDisplayName)
		return paramErr;

	NSString* path = [(NSURL*)inURL path];
	if (!path)
		return paramErr;

	NSString* lastComp = [path lastPathComponent];
	if (!lastComp)
		lastComp = path;

	*outDisplayName = (CFStringRef)[lastComp copy];
	return noErr;
}

// OSXER APPS (handler enumeration): use the same LaunchServices registration
// database as the single-handler APIs. An absent registry yields an owned empty array.
CFArrayRef LSCopyApplicationURLsForURL(CFURLRef url, LSRolesMask roles)
{
    if (!url) return NULL;
    NSMutableArray *results = [[NSMutableArray alloc] init];
    FMDatabaseQueue *queue = getDatabaseQueue();
    if (!queue) return (CFArrayRef)results;
    [queue inDatabase:^(FMDatabase *db) {
        NSString *query;
        NSString *value;
        if ([(NSURL *)url isFileURL]) {
            value = [(NSURL *)url pathExtension];
            query = @"select distinct bundle.path from bundle JOIN app_doc AD on AD.bundle=bundle.id "
                @"where bundle.package_type='APPL' and (EXISTS "
                @"(select 1 from app_doc_extension E where E.doc=AD.id and E.extension=?) "
                @"or EXISTS (select 1 from app_doc_uti U JOIN uti on uti.type_identifier=U.uti "
                @"JOIN uti_tag T on T.uti=uti.id where U.doc=AD.id "
                @"and T.tag='public.filename-extension' and T.value=?))";
            if (roles != kLSRolesAll) {
                NSString *roleList = roleSQLArray(roles);
                if (!roleList) return;
                query = [query stringByAppendingFormat:@" and AD.role IN (%@)", roleList];
            }
        } else {
            value = [[(NSURL *)url scheme] lowercaseString];
            query = @"select distinct bundle.path from bundle "
                @"JOIN bundle_url_type T on T.bundle=bundle.id "
                @"JOIN bundle_url_type_scheme S on S.type=T.id "
                @"where bundle.package_type='APPL' and lower(S.scheme)=?";
        }
        if (!value) return;
        FMResultSet *rows = [(NSURL *)url isFileURL] ?
            [db executeQuery:query, value, value] : [db executeQuery:query, value];
        while ([rows next]) {
            NSString *path = [rows stringForColumn:@"path"];
            if (path) [results addObject:[NSURL fileURLWithPath:path isDirectory:YES]];
        }
        [rows close];
    }];
    return (CFArrayRef)results;
}
