# OSXER APPS (QuickLookUI): existing preview classes now live in their own framework.
project(QuickLookUI)
remove_sdk_framework(QuickLookUI)
include_directories(${CMAKE_CURRENT_SOURCE_DIR}/include)
set(DYLIB_COMPAT_VERSION "1.0.0")
set(DYLIB_CURRENT_VERSION "1.0.0")
generate_sdk_framework(QuickLookUI VERSION A HEADER "include/QuickLookUI")
add_framework(QuickLookUI FAT CURRENT_VERSION VERSION A
    SOURCES src/QLPreviewPanel.m src/QLPreviewView.m
    DEPENDENCIES system objc Foundation AppKit QuickLook)
