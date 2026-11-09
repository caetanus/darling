#ifndef MLDR_NATIVE_DLOPEN_H
#define MLDR_NATIVE_DLOPEN_H

// Each call creates an independent ELF namespace. Exchange only opaque handles
// and C ABI values; release allocations through the library that owns them.
void* __mldr_dlopen_private(const char* name);

#endif
