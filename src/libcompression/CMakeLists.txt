project(compression)

set(DYLIB_INSTALL_NAME "/usr/lib/libcompression.dylib")
set(DYLIB_COMPAT_VERSION "1.0.0")
set(DYLIB_CURRENT_VERSION "1.0.0")

# OSXER (libcompression): Apple's reference LZFSE/LZVN (lzfse/, BSD 3-clause) and zlib.
add_darling_library(compression
	src/compression.c
	lzfse/lzfse_decode.c
	lzfse/lzfse_decode_base.c
	lzfse/lzfse_encode.c
	lzfse/lzfse_encode_base.c
	lzfse/lzfse_fse.c
	lzfse/lzvn_decode_base.c
	lzfse/lzvn_encode_base.c
)
make_fat(compression)
target_link_libraries(compression system z)

install(TARGETS compression DESTINATION libexec/darling/usr/lib)
