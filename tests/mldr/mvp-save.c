/* OSXER MVP (native regressions). Run only through mvp-save.sh.
 * Apple documents an 8 MiB macOS main stack; mmap(2) specifies guard faults.
 * Prefix policy is specified by BRIEF-mvp-save.md, not a macOS quirk.
 */
#define _GNU_SOURCE
#include "main_stack.h"
#include "local_documents.h"
#include <assert.h>
#include <fcntl.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/wait.h>
#include <ucontext.h>

static ucontext_t caller, stacked;
static volatile unsigned visited;
__attribute__((noinline)) static void recurse(unsigned depth) {
    volatile unsigned char frame[32768];
    for (size_t i = 0; i < sizeof(frame); i += 4096)
        frame[i] = (unsigned char) depth;
    if (depth) recurse(depth - 1);
    for (size_t i = 0; i < sizeof(frame); i += 4096)
        assert(frame[i] == (unsigned char) depth);
    visited++;
}
static void exercise_stack(void) { recurse(160); }

int main(void) {
    size_t page = sysconf(_SC_PAGESIZE), size = MLDR_DEFAULT_STACK_SIZE;
    assert(mldr_main_stack_size(RLIM_INFINITY, page) == size);
    assert(mldr_main_stack_size(256 * 1024, page) == 256 * 1024);
    assert(mldr_main_stack_size(size * 2, page) == size * 2);
    assert(mldr_main_stack_size(0, page) == 0);
    void *reservation = mmap(NULL, size + page, PROT_NONE, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
    assert(reservation != MAP_FAILED);
    uintptr_t top = (uintptr_t) reservation + size + page;
    assert(munmap(reservation, size + page) == 0);
    assert(mldr_map_main_stack(top, size, page) == 0);
    volatile char *bottom = (char *)(top - size);
    bottom[0] = 42;
    assert(mldr_map_main_stack(top, size, page) == -1);
    assert(bottom[0] == 42); // No clobber on address collision.
    assert(getcontext(&stacked) == 0);
    stacked.uc_stack.ss_sp = (void *)bottom;
    stacked.uc_stack.ss_size = size;
    stacked.uc_link = &caller;
    makecontext(&stacked, exercise_stack, 0);
    assert(swapcontext(&caller, &stacked) == 0);
    assert(visited == 161); // More than 5 MiB, far beyond the old initial 64 KiB.
    struct rlimit core = {0, 0};
    assert(setrlimit(RLIMIT_CORE, &core) == 0);
    pid_t child = fork();
    assert(child >= 0);
    if (!child) { bottom[-1] = 1; _exit(99); }
    int status;
    assert(waitpid(child, &status, 0) == child);
    assert(WIFSIGNALED(status) && WTERMSIG(status) == SIGSEGV);
    assert(munmap(reservation, size + page) == 0);

    assert(mkdir("host", 0700) == 0);
    int fd = open("host/keep", O_CREAT | O_EXCL | O_WRONLY, 0600);
    assert(fd >= 0 && write(fd, "keep", 4) == 4);
    close(fd);
    assert(symlink("host", "Documents") == 0);
    assert(ensure_local_documents("Documents") == 0);
    struct stat info;
    assert(lstat("Documents", &info) == 0 && S_ISDIR(info.st_mode));
    assert(stat("host/keep", &info) == 0 && info.st_size == 4);
    assert(ensure_local_documents("Documents") == 0);
    assert(ensure_local_documents("host/keep") == -1 && errno == ENOTDIR);
    assert(ensure_local_documents("MissingDocuments") == 0);
    assert(symlink("absent", "DanglingDocuments") == 0);
    assert(ensure_local_documents("DanglingDocuments") == 0);
    puts("PASS: stack >5 MiB, guard, limits, collisions; local Documents migration preserves target");
    return 0;
}
