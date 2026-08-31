# mslide

Slides from a markdown file, written in [Mere](https://merelang.org/).

The point is not the HTML. Pages that turn markdown into slides exist; what does
not exist is a **single binary that shows a deck with no browser on the machine**
— `mere -c | clang`, one executable, its own text layout and its own pixels. That
is what this is being built toward, and the page is the first step rather than
the destination.

## Status

Slides come off a document, and the document is
[mere-markdown](https://github.com/284km/mere-markdown)'s. There is no second
parser here and there will not be one.

```sh
mere install                                  # vendor the package dependencies
mere -c mslide.mere > m.c && clang -O2 m.c -o mslide
./mslide deck.md out.html                     # one page, no script
./mslide --png deck.md out/                   # one image per slide, no browser
./mslide --pdf deck.md out.pdf                # what a conference asks for

mere -c present.mere > p.c && clang -O2 -w $(sdl2-config --cflags) p.c \
    -o mspresent $(sdl2-config --libs) -lm
./mspresent deck.md                           # the deck, in a window

sh scripts/check.sh
```

| | |
|---|---|
| deck IR + HTML page | done |
| PNG per slide | done |
| PDF | done |
| presenter binary (a window, arrow keys, a clock) | done |

**Build it before you draw with it.** Encoding one small PNG takes the
interpreter forty-five minutes and the compiled program no time worth measuring,
so `--png` is not a thing to try under `mere` directly. The gate compiles.

## Drawing needs no browser, and nothing here was written for slides

| | |
|---|---|
| `contrib/font` | a TrueType file, as widths and outlines |
| `contrib/raster` | somewhere to put them |
| `contrib/unicode` | where a line may be broken (UAX #14) |
| `mpng` + `mgz` | the file on disk |

The line breaker earns its place immediately: Japanese has no spaces, so a
wrapper that splits on `" "` puts a whole paragraph on one line and runs it off
the slide. `font/MPLUS1p-Regular.ttf` ships with the deck, under the OFL, because
a deck that renders differently on the machine it is shown from is not a deck.

## Front matter, and documents that have no cuts in them

Feeding a published article in was the first honest test of this tool, and it
failed twice.

It starts with YAML fenced by `---`, which is what a static site generator puts
there and what cuts a slide here, so the first slide was metadata and the second
held the whole document with no title. Front matter is now skipped when the very
first line is `---` and a closing `---` follows — without the closing one it is
not front matter but a document opening with a rule, and swallowing it would lose
the deck. A `title:` in it wins over the first heading.

Then it produced one slide, because an essay has headings and no thematic breaks.
An essay is not a deck. Writing the breaks in would make the input agree with the
tool instead of testing it, so `Deck.of_lines_split 2` cuts at every H2 instead.
The default is 0 — cut nowhere but at `---`.

## `---` cuts, `***` does not

A thematic break is one block whichever way it is written, and to a browser
`---` and `***` are the same `<hr>`. They are not the same to the person who
typed them, so the document keeps the rule **as written** and a deck can have
both a slide boundary and a horizontal line. Marp made the same choice, so decks
written for it carry over.

This is the whole reason the parse belongs somewhere else. `deck.mere` has no
scanner, no state machine and no opinion about what a heading looks like — it
folds a list of blocks and starts a new slide when it sees one of them.

## The page needs no JavaScript

Navigation is CSS: a scroll-snapping document with one full-height `<section>`
per slide already moves a slide at a time under the arrow keys, Page Down and the
space bar, because that is what a browser does to a document. There is nothing to
bind them to.

That is not only taste. A deck with no script is a deck that a browser **without
a script engine** can show — which is the browser this project's sibling
[mbrowse](https://github.com/284km/mbrowse) is — so the page and the window
renderer can eventually be pointed at the same file and asked whether they agree.
Everything is inline, so it opens from a memory stick with the network off, and
`@media print` puts one slide on one page.

## The fix that came out of drawing something

Rendering a deck put a bar across the top of every letter with an ascender.
Two of the three causes were mine — the colour word was unpacked by hand and
took green, blue and alpha for red, green and blue, so the first deck came out
blue; and the glyph's sampling box reached above its own ascent.

The third was not. `Font.text_raster f "d" 30 40 8`, one letter and one call into
`contrib/font`, drew a bar the letter does not have. The point-in-glyph test was
half-open in the curve parameter rather than in y, so a vertex that is a y
extremum left an uncancelled crossing, and with the ray running rightward that
put everything to its left inside the glyph. Fixed upstream in Mere v0.1.365,
with an oracle-free gate — inside is inside whichever way the ray goes — that
reports 87 disagreeing pixels against the old rule and none against the new.

Nothing in this repository could have found that by testing itself. It took
drawing something.

## Using it from another repository

The modules are the library and `mslide.mere` is only the default driver, so a
repository of decks can pin a revision and write its own:

    [dependencies]
    mslide = { git = "https://github.com/284km/mslide", rev = "..." }

| import | gives you |
|---|---|
| `.../mslide/deck.mere` | `Deck.of_lines`, `Deck.at`, `Deck.count`, `slide`, `deck` |
| `.../mslide/html.mere` | `DeckHtml.render`, and `MarkdownHtml` under it |
| `.../mslide/png.mere` | `Png.slide_canvas`, `Png.encode`, `Layout`, `Font`, `Canvas` |
| `.../mslide/pdf.mere` | `Pdf.of_pngs` |
| `.../mslide/bundled.mere` | `Bundled.font ()` — where the shipped face went |

`Bundled.font ()` exists because the first program to depend on this package from
somewhere else got `read_file_bytes: cannot open font/MPLUS1p-Regular.ttf` — a
true message about a path nobody had written, since `mere install` puts the font
under `.mere_modules/`. Mere has no way for a module to ask where it is, so the
candidates are listed and the first that exists wins, `MSLIDE_FONT` first.

Nothing but using it from outside could have found that.

## The presenter is the point

`./mspresent deck.md` opens a window and shows the deck. Arrows, space and the
page keys move a slide at a time, home and end jump, `q` or escape leaves. The
corner carries the slide number and how long you have been talking.

The room needs **no browser, no runtime, no fonts installed and no network** —
one executable and one markdown file. Nothing is encoded on this path: deflate is
almost all of what the PNG and PDF commands spend, and none of it is here.

SDL lives behind `contrib/window` and is reached only from `present.mere`, so
`mslide` itself still builds and runs without it. That separation is not
tidiness: only one of the two can be tested without a display.

The keycodes are SDL's documented numbers and no gate checks them — a test would
need a keyboard. Everything else about the presenter is checked below.

## The PDF compresses nothing twice

A PNG's pixel data is a zlib stream over rows that have each been filtered, and
that is exactly what PDF calls `/FlateDecode` with `/Predictor 15`. So the bytes
go across unchanged — no inflate, no re-deflate, no second pass over a megabyte
of pixels. Deflate was nearly all of the time the PNG path spent, and doing it
once was the point. A two-slide deck is 13,419 bytes of PDF over 12,160 bytes of
images: everything else is structure.

The palette travels too. mpng picks the cheapest true claim about a slide's
pixels, which for text on white is a palette, and PDF has `/Indexed` — so the
table goes in the page rather than being expanded back into three bytes a pixel.

Reading the PNGs back to find those bytes uses mpng's own chunk primitives, not
a second idea about what a PNG is.

## What is checked

`scripts/check.sh`, and the interesting one needs no oracle:

- **Cutting creates and destroys nothing.** Strip the cuts and blanks from the
  parse, strip the blanks from every slide, lay the two sequences end to end, and
  they must be identical. The document is its own answer, and when it fails the
  summary names the block that went missing.
- **The cut rule does what the table says.** `test/decks/expected.txt` records a
  slide count per deck, written down rather than derived, because the check above
  asks `Deck.is_cut` what a cut is and therefore cannot notice `Deck.is_cut`
  being wrong.
- **No script, no inline handlers, no `javascript:`, no external stylesheet, no
  `url(`** — checked on generated output rather than asserted here.
- **Every heading in every deck reaches its page.**
- **Compiled output equals interpreted output.** The drawing paths cannot run
  under the interpreter at all — encoding one small PNG takes it 45 minutes — so
  the build is part of the gate rather than an afterthought.
- **The window gives back what was drawn.** The presenter shows a slide and
  reads the pixels back off the window, and the two must be the same bytes. This
  is evidence rather than a tautology because `contrib/window` poisons its pixel
  block with magenta before asking SDL to fill it — a capture that quietly did
  nothing comes back magenta, not correct. And because two blank images also
  compare equal, the picture is required to have ink in it. Showing a blank
  canvas while writing the real one fails **both** assertions, which is how they
  were checked.

  Compiled, and headless under SDL's dummy driver, so it runs in CI without
  opening a window on your desktop.
- **The PDF, through a reader that is not ours.** `pdftoppm` renders it back and
  the pages must have the same size, the same two colours **exactly**, and ink in
  the same places. Not the same pixels: poppler resamples an image however it is
  placed, at 96dpi where one image pixel is one device pixel and at 192dpi too,
  so a two-colour page comes back with hundreds of colours along every stroke.
  That is the reader's business and not the file's, and a gate that demanded
  equality would be a gate about poppler.

  The thresholds were set by breaking the file rather than by taste. Declaring
  `/Predictor 1` on rows that are filtered turns `(22, 24, 29)` into
  `(222, 222, 223)` — caught outright by the colour check — and drops the mask
  agreement to 98.7%, against 99.8% for a correct file. Three tenths of a point
  is no separation, so the mask check is set at 95% and is there to catch ink
  that has *moved*; the colours are what discriminate.

Both invariants have been made to fail on purpose: a cut rule widened to `***`
was caught as two decks with the wrong slide count, and a block dropped at each
boundary was caught with the missing block printed.

## License

MIT.
