#!/bin/sh
# scripts/check.sh — everything this repository can be held to, so far.
#
# Needs a built `mere` on PATH, or MERE pointing at one, and the package
# dependencies vendored (`mere install`).
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MERE="${MERE:-mere}"
command -v "$MERE" >/dev/null 2>&1 || { echo "check: no mere — set MERE=/path/to/mere.exe" >&2; exit 1; }
cd "$ROOT"
[ -d .mere_modules ] || { echo "check: no .mere_modules — run: $MERE install" >&2; exit 1; }

fail=0
note() { echo "$1"; }
bad() { echo "FAIL  $1" >&2; fail=1; }

# 1. Cutting a document into slides creates and destroys nothing, and the cut
#    rule does what the table says. A PROGRAM THAT DOES NOT RUN IS A FAILURE:
#    searching the output of a program that never started finds no MISMATCH and
#    would report that as agreement.
if ! out=$("$MERE" test/deck_check.mere test/decks/*.md 2>&1); then
  echo "$out" >&2; bad "test/deck_check.mere did not run"
else
  echo "$out"
  case "$out" in *MISMATCH*) bad "deck_check" ;; esac
  n=$(echo "$out" | grep -c '^ok' || true)
  want=$(ls test/decks/*.md | wc -l | tr -d ' ')
  [ "$n" = "$want" ] || bad "deck_check reported $n decks, there are $want"
fi

# 2. The page needs no JavaScript, and that is the claim the whole design rests
#    on: a deck with no script is one a browser without a script engine can
#    show. Checked on real output rather than asserted in the README.
OUT="$(mktemp -d)"
trap 'rm -rf "$OUT"' EXIT
for f in test/decks/*.md; do
  b=$(basename "$f" .md)
  "$MERE" mslide.mere "$f" "$OUT/$b.html" >/dev/null || bad "mslide failed on $b"
done
for h in "$OUT"/*.html; do
  b=$(basename "$h")
  grep -qi '<script' "$h" && bad "$b contains a script tag"
  grep -qiE '<[a-z][a-z0-9]* [^>]*\bon[a-z]+=' "$h" && bad "$b contains an inline event handler"
  grep -qi 'javascript:' "$h" && bad "$b contains a javascript: url"
  grep -qi '<link ' "$h" && bad "$b links an external stylesheet"
  grep -qi '@import' "$h" && bad "$b imports a stylesheet"
  grep -qiE 'url\(' "$h" && bad "$b fetches something from css"
done
note "ok    no script, no handlers, no external stylesheet, no css fetch"

# 3. A slide's own heading reaches the page. Weak on its own — it is the
#    rendering that is being trusted here — but it is what fails first if
#    slides are emitted in the wrong order or dropped after the cut.
for f in test/decks/*.md; do
  b=$(basename "$f" .md)
  want=$(grep -cE '^#+ ' "$f" || true)
  got=$(grep -cE '<h[1-6]>' "$OUT/$b.html" || true)
  [ "$want" = "$got" ] || bad "$b: $want headings in the source, $got in the page"
done
note "ok    every heading in every deck reaches its page"

# 4. The compiled program is the interpreted one. The PNG and PDF renderers to
#    come cannot run under the interpreter at all, so the build is part of the
#    gate from here rather than an afterthought.
if command -v clang >/dev/null 2>&1; then
  "$MERE" -c mslide.mere > "$OUT/m.c" 2>/dev/null || bad "mslide.mere did not compile to C"
  clang -O2 -o "$OUT/mslide" "$OUT/m.c" 2>/dev/null || bad "the generated C did not build"
  if [ -x "$OUT/mslide" ]; then
    "$OUT/mslide" test/decks/basic.md "$OUT/compiled.html" >/dev/null
    cmp -s "$OUT/basic.html" "$OUT/compiled.html" || bad "compiled output differs from interpreted"
    note "ok    compiled == interpreted"
  fi
else
  note "skip  no clang, so compiled == interpreted was not checked"
fi

[ "$fail" -eq 0 ] || { echo "check: FAILED" >&2; exit 1; }
echo "check: ok"
