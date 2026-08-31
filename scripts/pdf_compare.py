#!/usr/bin/env python3
"""Compare a page rendered out of the PDF with the PNG that went into it.

Not for equality. poppler resamples an image however it is placed and at
whatever resolution — at 96dpi, where one image pixel is one device pixel, and
at 192dpi too — so a render of a two-colour page comes back with hundreds of
colours along every stroke. That is the reader's business and not the file's.

What the file is responsible for survives resampling and is checked here:

  * the two colours the page is drawn in come back **exactly**. A wrong
    `/Predictor` turns the image into noise and a wrong palette turns it into
    the wrong colours; neither can produce the right two.
  * the ink is in the same **places**. Thresholded at half, the two masks have
    to agree almost everywhere: smoothing moves a stroke's edge values, not the
    stroke.
  * the page is the size it claimed.

This reads PNG itself rather than importing anything, so that the answer does
not come from the same code that wrote the file.
"""
import collections
import struct
import sys
import zlib


def read_png(path):
    d = open(path, 'rb').read()
    if d[:8] != b'\x89PNG\r\n\x1a\n':
        raise SystemExit('%s: not a PNG' % path)
    w, h = struct.unpack('>II', d[16:24])
    depth, ctype = d[24], d[25]
    if depth != 8:
        raise SystemExit('%s: only 8-bit is handled here' % path)
    idat, plte, i = b'', None, 8
    while i + 8 <= len(d):
        n = struct.unpack('>I', d[i:i + 4])[0]
        tag = d[i + 4:i + 8]
        if tag == b'IDAT':
            idat += d[i + 8:i + 8 + n]
        elif tag == b'PLTE':
            plte = d[i + 8:i + 8 + n]
        i += 12 + n
    bpp = {0: 1, 2: 3, 3: 1, 4: 2, 6: 4}[ctype]
    raw, stride = zlib.decompress(idat), w * bpp
    prev, rows, pos = bytearray(stride), [], 0
    for _ in range(h):
        ft = raw[pos]
        pos += 1
        line = bytearray(raw[pos:pos + stride])
        pos += stride
        for k in range(stride):
            a = line[k - bpp] if k >= bpp else 0
            b = prev[k]
            c = prev[k - bpp] if k >= bpp else 0
            if ft == 1:
                line[k] = (line[k] + a) & 255
            elif ft == 2:
                line[k] = (line[k] + b) & 255
            elif ft == 3:
                line[k] = (line[k] + (a + b) // 2) & 255
            elif ft == 4:
                p = a + b - c
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                pr = a if (pa <= pb and pa <= pc) else (b if pb <= pc else c)
                line[k] = (line[k] + pr) & 255
        rows.append(bytes(line))
        prev = line
    pixels = []
    for line in rows:
        row = []
        for k in range(0, len(line), bpp):
            px = line[k:k + bpp]
            row.append(tuple(plte[3 * px[0]:3 * px[0] + 3]) if ctype == 3 else
                       (px[0], px[0], px[0]) if bpp == 1 else tuple(px[:3]))
        pixels.append(row)
    return w, h, pixels


def main(src, out, min_agree):
    sw, sh, sp = read_png(src)
    ow, oh, op = read_png(out)
    bad = []
    if (sw, sh) != (ow, oh):
        bad.append('size %dx%d in, %dx%d out' % (sw, sh, ow, oh))
    top_in = [c for c, _ in collections.Counter(
        p for row in sp for p in row).most_common(2)]
    top_out = [c for c, _ in collections.Counter(
        p for row in op for p in row).most_common(2)]
    if sorted(top_in) != sorted(top_out):
        bad.append('colours %s in, %s out' % (sorted(top_in), sorted(top_out)))
    if (sw, sh) == (ow, oh):
        dark = lambda p: (p[0] * 30 + p[1] * 59 + p[2] * 11) // 100 < 128
        agree = sum(1 for y in range(sh) for x in range(sw)
                    if dark(sp[y][x]) == dark(op[y][x]))
        pct = 100.0 * agree / (sw * sh)
        if pct < min_agree:
            bad.append('masks agree on %.4f%%, below %.2f%%' % (pct, min_agree))
        print('  %s: %dx%d, colours %s, masks agree %.4f%%'
              % (out.split('/')[-1], ow, oh, sorted(top_out), pct))
    for b in bad:
        print('MISMATCH %s: %s' % (out.split('/')[-1], b))
    return 1 if bad else 0


if __name__ == '__main__':
    if len(sys.argv) != 4:
        raise SystemExit('usage: pdf_compare.py <source.png> <from-pdf.png> <min-agree-pct>')
    sys.exit(main(sys.argv[1], sys.argv[2], float(sys.argv[3])))
