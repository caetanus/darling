#ifndef DARLING_OSXER_APPS_H
#define DARLING_OSXER_APPS_H
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
/* OSXER APPS (unsupported APIs): opt-in diagnostics, once per call site and
 * process. No application data is logged. */
#define OSXER_APPS_STUB(message) do { \
    static int osxer_reported; \
    const char *osxer_logging = getenv("OSXER_LOG_STDERR"); \
    if (osxer_logging && strcmp(osxer_logging, "1") == 0 && \
        !__atomic_exchange_n(&osxer_reported, 1, __ATOMIC_RELAXED)) \
        fprintf(stderr, "OSXER APPS (%s): %s\n", __func__, message); \
} while (0)
#endif
