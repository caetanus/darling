# OSXER APPS (FinderSync): app-gaps.json specifies a load command, no bound symbols.
project(FinderSync)
remove_sdk_framework(FinderSync)
set(DYLIB_COMPAT_VERSION "1.0.0")
set(DYLIB_CURRENT_VERSION "1.0.0")
generate_sdk_framework(FinderSync VERSION A HEADER "include/FinderSync")
add_framework(FinderSync FAT CURRENT_VERSION VERSION A SOURCES empty.c DEPENDENCIES system)
