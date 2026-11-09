// OSXER LLVMPIPE (regression): exercise the real bridge and DARLING LLVM client
// on Linux, including constructors, native TLS and reuse of cached functions.
#include <iridium/dynamic-llvm.hpp>
#include <elfcalls.h>
extern "C" {
#include "native_dlopen.h"
}
#include <cstdio>
#include <cstdlib>
#include <thread>

static elf_calls calls = {};
extern "C" { elf_calls* _elfcalls = &calls; }
static unsigned private_opens;

static void require(bool condition, const char* message) {
	if (!condition) {
		fprintf(stderr, "FAIL: %s\n", message);
		exit(1);
	}
}

static void* open_private(const char* name) {
	++private_opens;
	return __mldr_dlopen_private(name);
}

template<typename T> static T symbol(void* handle, const char* name) {
	auto result = reinterpret_cast<T>(dlsym(handle, name));
	require(result != nullptr, "missing fixture symbol");
	return result;
}

int main(int argc, char** argv) {
	calls.dlopen_private = open_private;
	calls.dlsym = dlsym;
	if (argc == 1) {
		for (int cycle = 0; cycle < 32; ++cycle)
			require(!Iridium::DynamicLLVM::init(), "wrong LLVM major must fail");
		require(private_opens == 1, "failed init must not leak ELF namespaces");
		puts("PASS: incompatible private runtime rejected across 32 init attempts");
		return 0;
	}
	require(argc == 3, "expected two fixture paths");
	void* first = dlopen(argv[1], RTLD_NOW | RTLD_LOCAL);
	void* second = dlopen(argv[2], RTLD_NOW | RTLD_LOCAL);
	require(first && second, "fixture load");
	using Identity = int (*)();
	using Table = const void* (*)();
	const void* base_table = symbol<Table>(first, "osxer_table")();
	require(base_table == symbol<Table>(second, "osxer_table")(), "baseline must reproduce GNU-unique collision");
	require(symbol<Identity>(second, "osxer_identity")() == 23, "baseline must use the first runtime callback");
	for (int cycle = 0; cycle < 32; ++cycle) {
		require(Iridium::DynamicLLVM::init(), "isolated client init");
		auto id = reinterpret_cast<Identity>(Iridium::DynamicLLVM::resolveSymbol("osxer_identity"));
		auto table = reinterpret_cast<Table>(Iridium::DynamicLLVM::resolveSymbol("osxer_table"));
		require(id && table && id() == 22 && table() != base_table, "isolated runtime identity");
		auto options = Iridium::DynamicLLVM::LLVMCreatePassBuilderOptions();
		require(options != nullptr, "cached native call");
		Iridium::DynamicLLVM::LLVMDisposePassBuilderOptions(options);
		if (cycle == 0) {
			auto state = reinterpret_cast<Identity>(Iridium::DynamicLLVM::resolveSymbol("osxer_thread_state"));
			require(state && state() == 1 && state() == 2, "main-thread constructor/TLS/TSD");
			std::thread worker([&] {
				require(state() == 1 && state() == 2, "worker TLS/TSD");
			});
			worker.join();
			require(state() == 3, "independent per-thread state");
		}
		Iridium::DynamicLLVM::finit();
	}
	require(private_opens == 1, "finit/init must not leak ELF namespaces");
	require(__mldr_dlopen_private("/osxer-no-such-runtime.so") == nullptr, "missing runtime must fail");
	require(dlerror() != nullptr, "missing runtime must provide loader error");
	puts("PASS: collision reproduced; isolated identity, constructors, TLS/TSD, cached calls, 32 reloads and errors");
}
