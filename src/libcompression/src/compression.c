/* OSXER (libcompression): buffer compression for LZFSE and ZLIB.

   This was a stub that returned 0 for everything, so any app using libcompression got no
   data back. LZFSE (and the LZVN blocks it contains) comes from Apple's reference
   implementation, vendored in ../lzfse (BSD 3-clause, ../lzfse/LICENSE, upstream commit
   e634ca58b4821d9f3d560cdc6df5dec02ffc93fd). COMPRESSION_ZLIB is raw DEFLATE (RFC 1951, no
   zlib header), as Apple documents. LZ4 and LZMA and the streaming API are not implemented
   yet: they report failure, as before. */

#include <compression.h>
#include <stdlib.h>
#include <string.h>
#include <zlib.h>
#include "../lzfse/lzfse.h"
#include "../lzfse/lzvn_decode_base.h"

size_t
compression_encode_scratch_buffer_size(compression_algorithm algorithm) {
    return algorithm == COMPRESSION_LZFSE ? lzfse_encode_scratch_size() : 0;
}

size_t
compression_decode_scratch_buffer_size(compression_algorithm algorithm) {
    return algorithm == COMPRESSION_LZFSE ? lzfse_decode_scratch_size() : 0;
}

static size_t deflate_raw(uint8_t *dst, size_t dst_size, const uint8_t *src, size_t src_size) {
    z_stream z;
    memset(&z, 0, sizeof z);
    if (deflateInit2(&z, 5, Z_DEFLATED, -15, 8, Z_DEFAULT_STRATEGY) != Z_OK)
        return 0;
    z.next_in = (Bytef *) src;
    z.avail_in = (uInt) src_size;
    z.next_out = dst;
    z.avail_out = (uInt) dst_size;
    int status = deflate(&z, Z_FINISH);
    size_t written = dst_size - z.avail_out;
    deflateEnd(&z);
    return status == Z_STREAM_END ? written : 0; // Apple: 0 when it does not fit
}

static size_t inflate_raw(uint8_t *dst, size_t dst_size, const uint8_t *src, size_t src_size) {
    z_stream z;
    memset(&z, 0, sizeof z);
    if (inflateInit2(&z, -15) != Z_OK)
        return 0;
    z.next_in = (Bytef *) src;
    z.avail_in = (uInt) src_size;
    z.next_out = dst;
    z.avail_out = (uInt) dst_size;
    int status = inflate(&z, Z_FINISH);
    size_t written = dst_size - z.avail_out;
    inflateEnd(&z);
    // A full destination is a truncated result, which Apple reports as dst_size.
    return (status == Z_STREAM_END || (status == Z_BUF_ERROR && z.avail_out == 0)) ? written : 0;
}

size_t
compression_encode_buffer(uint8_t * __restrict dst_buffer, size_t dst_size,
                          const uint8_t * __restrict src_buffer, size_t src_size,
                          void * __restrict __nullable scratch_buffer,
                          compression_algorithm algorithm) {
    switch (algorithm) {
    case COMPRESSION_LZFSE:
        return lzfse_encode_buffer(dst_buffer, dst_size, src_buffer, src_size, scratch_buffer);
    case COMPRESSION_ZLIB:
        return deflate_raw(dst_buffer, dst_size, src_buffer, src_size);
    default:
        return 0;
    }
}

size_t
compression_decode_buffer(uint8_t * __restrict dst_buffer, size_t dst_size,
                          const uint8_t * __restrict src_buffer, size_t src_size,
                          void * __restrict __nullable scratch_buffer,
                          compression_algorithm algorithm) {
    switch (algorithm) {
    case COMPRESSION_LZFSE:
        return lzfse_decode_buffer(dst_buffer, dst_size, src_buffer, src_size, scratch_buffer);
    case COMPRESSION_ZLIB:
        return inflate_raw(dst_buffer, dst_size, src_buffer, src_size);
    default:
        return 0;
    }
}

/* Private to Darling: raw LZVN (no "bvxn" block header), as CoreUI asset catalogs store it
   inside Deepmap2 bitmaps. Returns the bytes written. */
size_t
__darling_lzvn_decode_buffer(uint8_t *dst_buffer, size_t dst_size,
                             const uint8_t *src_buffer, size_t src_size) {
    lzvn_decoder_state state;
    memset(&state, 0, sizeof state);
    state.src = src_buffer;
    state.src_end = src_buffer + src_size;
    state.dst = state.dst_begin = state.dst_current = dst_buffer;
    state.dst_end = dst_buffer + dst_size;
    lzvn_decode(&state);
    return (size_t) (state.dst - dst_buffer);
}

compression_status
compression_stream_init(compression_stream * stream,
                        compression_stream_operation operation,
                        compression_algorithm algorithm) {
    return COMPRESSION_STATUS_ERROR;
}

compression_status
compression_stream_process(compression_stream * stream,
                           int flags) {
    return COMPRESSION_STATUS_ERROR;
}

compression_status
compression_stream_destroy(compression_stream * stream) {
    return COMPRESSION_STATUS_ERROR;
}
