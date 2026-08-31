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
mere install                        # vendor the package dependencies
mere mslide.mere deck.md out.html   # or: mere -c mslide.mere > m.c && clang -O2 m.c -o mslide
sh scripts/check.sh
```

| | |
|---|---|
| deck IR + HTML page | done |
| PNG per slide | not started |
| PDF | not started |
| presenter binary (a window, arrow keys, a clock) | not started |

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
- **Compiled output equals interpreted output.** The renderers still to come
  cannot run under the interpreter at all — encoding one small PNG takes it 45
  minutes — so the build is part of the gate from here rather than an
  afterthought.

Both invariants have been made to fail on purpose: a cut rule widened to `***`
was caught as two decks with the wrong slide count, and a block dropped at each
boundary was caught with the missing block printed.

## License

MIT.
