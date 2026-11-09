#ifndef _GNU_SOURCE
#define _GNU_SOURCE
#endif
#include <dlfcn.h>
#include <link.h>
#include "native_dlopen.h"

void* __mldr_dlopen_private(const char* name)
{
	// OSXER LLVMPIPE (ELF namespace): RTLD_LOCAL and RTLD_DEEPBIND do not
	// isolate STB_GNU_UNIQUE data across incompatible C++ runtimes, even
	// with versioned symbols. Keep this opt-in: ordinary native libraries
	// can depend on sharing objects and state in the base namespace.
	return dlmopen(LM_ID_NEWLM, name, RTLD_LAZY | RTLD_LOCAL);
}
