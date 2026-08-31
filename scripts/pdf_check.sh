#!/bin/sh
# scripts/pdf_check.sh — the deck, through a PDF reader that is not ours.
#
# The PDF carries the PNGs' own compressed pixels: a PNG's image data is a zlib
# stream over filtered rows, which is what PDF calls /FlateDecode with
# /Predictor 15, so nothing is inflated and nothing is compressed twice. That
# claim has two halves and both are checked here — that a real reader gets the
# right picture out, and that the file is not much bigger than the pictures in it.
#
# Needs a compiled mslide (the interpreter cannot encode a PNG in useful time),
# pdftoppm from poppler, and python3.
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
command -v pdftoppm >/dev/null 2>&1 || { echo "pdf_check: no pdftoppm — skipping" >&2; exit 0; }
command -v python3 >/dev/null 2>&1 || { echo "pdf_check: no python3 — skipping" >&2; exit 0; }
[ -x "${MSLIDE:-./mslide}" ] || { echo "pdf_check: no compiled mslide — set MSLIDE=..." >&2; exit 1; }
MS="${MSLIDE:-./mslide}"
DECK="${DECK:-test/decks/japanese.md}"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
"$MS" --png "$DECK" "$TMP/png" > /dev/null
"$MS" --pdf "$DECK" "$TMP/deck.pdf" > /dev/null
pdftoppm -r 96 -png "$TMP/deck.pdf" "$TMP/back"

fail=0
n=0
for src in "$TMP"/png/*.png; do
  n=$((n + 1))
  # A page that is not there is not a page that matched.
  [ -f "$TMP/back-$n.png" ] || { echo "MISMATCH: the PDF has no page $n"; fail=1; continue; }
  # 95, not 99. The threshold was set by breaking the file rather than by taste:
  # declaring /Predictor 1 on rows that are filtered drops the masks to 98.7 and
  # 97.5, and a correct file sits at 99.8 and 99.0 — 0.3 points apart, which is
  # no separation at all. The colours are what actually discriminates (a wrong
  # predictor turned (22,24,29) into (222,222,223)), and this only has to catch
  # ink that has moved.
  python3 scripts/pdf_compare.py "$src" "$TMP/back-$n.png" 95.0 || fail=1
done
[ "$n" -gt 0 ] || { echo "pdf_check: no slides were rendered" >&2; exit 1; }
extra=$(ls "$TMP"/back-*.png | wc -l | tr -d ' ')
[ "$extra" = "$n" ] || { echo "MISMATCH: $n slides in, $extra pages out"; fail=1; }

# Nothing was compressed twice: the file is the images plus its own structure.
imgs=$(cat "$TMP"/png/*.png | wc -c | tr -d ' ')
pdf=$(wc -c < "$TMP/deck.pdf" | tr -d ' ')
echo "  images $imgs bytes, pdf $pdf bytes"
python3 -c "import sys; sys.exit(0 if $pdf < $imgs * 3 // 2 else 1)" || {
  echo "MISMATCH: the pdf is more than half again the size of its images — something re-compressed"; fail=1; }

[ "$fail" -eq 0 ] || { echo "pdf_check: failed" >&2; exit 1; }
echo "pdf_check: ok"
