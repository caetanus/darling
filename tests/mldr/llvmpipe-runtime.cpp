// OSXER LLVMPIPE (regression fixture): independently authored ELF C++ runtime.
// Two builds use different versions but the same GNU-unique object name, as
// permitted by GCC: https://gcc.gnu.org/onlinedocs/gcc/Code-Gen-Options.html
#include <llvm/Config/llvm-config.h>
#include <pthread.h>

struct RuntimeTable {
	static int identity() { return RUNTIME_ID; }
	static auto& table() {
		static int (*const callback)() = identity;
		return callback;
	}
};

static int initialized;
static pthread_key_t key;
static thread_local int thread_count;

__attribute__((constructor)) static void initialize() {
	initialized = pthread_key_create(&key, nullptr) == 0;
}

extern "C" int osxer_identity() { return RuntimeTable::table()(); }
extern "C" const void* osxer_table() { return &RuntimeTable::table(); }
extern "C" int osxer_thread_state() {
	if (!initialized) return -1;
	if (thread_count == 0) {
		if (pthread_getspecific(key) != nullptr) return -2;
		if (pthread_setspecific(key, &thread_count) != 0) return -3;
	}
	if (pthread_getspecific(key) != &thread_count) return -4;
	return ++thread_count;
}

extern "C" void LLVMGetVersion(unsigned* major, unsigned* minor, unsigned* patch) {
	*major = LLVM_VERSION_MAJOR;
	*minor = *patch = 0;
}

// A cached DynamicFunction with an opaque result, owned by this runtime.
extern "C" void* LLVMCreatePassBuilderOptions() { return &initialized; }
extern "C" void LLVMDisposePassBuilderOptions(void*) {}
