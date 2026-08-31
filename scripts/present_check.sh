#!/bin/sh
# scripts/present_check.sh — the window gives back what was drawn.
#
# The presenter is the point of this repository and the one part a file
# comparison cannot reach: it puts pixels on a screen. So it is asked to do that
# and then to read them back, and the two have to be the same bytes.
#
# The readback is evidence rather than a tautology because `contrib/window`
# poisons its pixel block with magenta before asking SDL to fill it — a capture
# that quietly did nothing comes back magenta, not correct. And because two blank
# images would also compare equal, the picture is required to have ink in it.
#
# Compiled, and under SDL's dummy video driver: a software renderer and a real
# event queue with no display, so it runs in CI and does not open a window on
# your desktop. Skips when SDL2 is absent, the way the optional gates upstream do.
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MERE="${MERE:-mere}"
command -v "$MERE" >/dev/null 2>&1 || { echo "present_check: no mere — set MERE=..." >&2; exit 1; }
cd "$ROOT"
CC="${CC:-clang}"; command -v "$CC" >/dev/null 2>&1 || CC=cc
command -v "$CC" >/dev/null 2>&1 || { echo "present_check: no C compiler — skipping" >&2; exit 0; }
command -v sdl2-config >/dev/null 2>&1 || {
  echo "present_check: sdl2-config not found — skipping (this gate is optional)"; exit 0; }
command -v python3 >/dev/null 2>&1 || { echo "present_check: no python3 — skipping" >&2; exit 0; }

T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT

# The build is the first assertion, and it says why when it fails.
"$MERE" -c present.mere > "$T/p.c" || { echo "present_check: present.mere did not compile to C" >&2; exit 1; }
if ! $CC -O2 -w $(sdl2-config --cflags) "$T/p.c" -o "$T/mspresent" $(sdl2-config --libs) -lm 2> "$T/cc.err"; then
  echo "present_check: the generated C did not build" >&2; sed -n '1,12p' "$T/cc.err" >&2; exit 1
fi

fail=0
for i in 0 1; do
  SDL_VIDEODRIVER=dummy "$T/mspresent" --capture test/decks/japanese.md "$i" \
    "$T/direct$i.png" "$T/shown$i.png" || { echo "MISMATCH: slide $i would not capture"; fail=1; continue; }
  if cmp -s "$T/direct$i.png" "$T/shown$i.png"; then
    echo "  slide $i: the window gave back exactly what was drawn"
  else
    echo "MISMATCH: slide $i differs between what was drawn and what came back"; fail=1
  fi
  # Two blank images compare equal, so the picture has to be a picture.
  python3 - "$T/shown$i.png" <<'PY' || fail=1
import sys, collections
sys.path.insert(0, 'scripts')
from pdf_compare import read_png
w, h, px = read_png(sys.argv[1])
cols = collections.Counter(p for row in px for p in row)
if len(cols) < 2:
    print('MISMATCH: the captured slide is one flat colour, %s' % list(cols))
    sys.exit(1)
ink = sum(n for c, n in cols.items() if (c[0]*30+c[1]*59+c[2]*11)//100 < 128)
if ink < 100:
    print('MISMATCH: the captured slide has %d ink pixels' % ink)
    sys.exit(1)
print('           %dx%d, %d colours, %d ink pixels' % (w, h, len(cols), ink))
PY
done

[ "$fail" -eq 0 ] || { echo "present_check: failed" >&2; exit 1; }
echo "present_check: ok"
