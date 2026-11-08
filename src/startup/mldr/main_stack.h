/* OSXER MVP (main stack): reserve the whole stack before loading libraries.
 * Pages remain demand-paged. A fixed guard prevents growth into other mappings.
 * https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/Multithreading/CreatingThreads/CreatingThreads.html
 */
#ifndef MLDR_MAIN_STACK_H
#define MLDR_MAIN_STACK_H
#include <errno.h>
#include <stdint.h>
#include <sys/mman.h>
#include <sys/resource.h>

#ifndef MAP_FIXED_NOREPLACE
#define MAP_FIXED_NOREPLACE 0x100000
#endif
#define MLDR_DEFAULT_STACK_SIZE (8UL * 1024 * 1024)

static inline size_t mldr_main_stack_size(rlim_t limit, size_t page_size) {
    rlim_t size = limit == RLIM_INFINITY ? MLDR_DEFAULT_STACK_SIZE : limit;
    if (size < page_size || size > SIZE_MAX - page_size) {
        errno = EINVAL;
        return 0;
    }
    return (size_t) size / page_size * page_size;
}

static inline int mldr_map_main_stack(uintptr_t top, size_t size, size_t page_size) {
    if (size == 0 || size > SIZE_MAX - page_size || top < size + page_size ||
        top % page_size || size % page_size) {
        errno = EINVAL;
        return -1;
    }
    void *base = (void *) (top - size - page_size);
    size_t total = size + page_size;
    void *mapped = mmap(base, total, PROT_NONE,
                       MAP_PRIVATE | MAP_ANONYMOUS | MAP_FIXED_NOREPLACE, -1, 0);
    if (mapped == MAP_FAILED)
        return -1;
    // Older Linux may ignore NOREPLACE. Never overwrite an existing mapping.
    if (mapped != base) {
        munmap(mapped, total);
        errno = EEXIST;
        return -1;
    }
    if (mprotect((void *) (top - size), size, PROT_READ | PROT_WRITE) != 0) {
        int saved_errno = errno;
        munmap(base, total);
        errno = saved_errno;
        return -1;
    }
    return 0;
}
#endif
