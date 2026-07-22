---
name: pdf-non-latin-text
description: >-
  Use this skill BEFORE writing any ReportLab/PDF generation code whenever the document content includes ANY non-Latin text — Cyrillic (Russian, Ukrainian, Bulgarian, Serbian, Belarusian, Macedonian), Greek, Hebrew, Arabic, Chinese, Japanese, Korean, Vietnamese with diacritics, Armenian, Georgian, Thai, Devanagari, or any other script beyond basic ASCII/Latin-1. ReportLab's built-in fonts (Helvetica, Times-Roman, Courier and variants) silently render these characters as solid black rectangles ("tofu"). Trigger this skill even if only ONE word, subtitle, header, label, or note is non-Latin while the rest is English. Also trigger when fixing a PDF that already shows boxes/squares instead of letters, when the user mentions Cyrillic/Russian/Chinese/etc. PDFs, or when reusing an earlier ReportLab snippet with new non-English content. Always register a Unicode-capable TTF before generating the PDF — never assume Helvetica is fine.
---

# PDF Generation with Non-Latin Text

## The trap

ReportLab's 14 built-in PDF fonts (Helvetica, Times-Roman, Courier, Symbol, ZapfDingbats and their bold/italic variants) are PostScript Type 1 fonts that only cover Latin-1. Anything outside that range — Cyrillic, Greek, Hebrew, Arabic, CJK, Devanagari, even some Western European symbols — renders as solid black rectangles. ReportLab does **not** warn or fail; the PDF builds cleanly and the problem is only visible when the file is opened.

This means a document that is 99% English with a single Russian subtitle or a Greek formula will silently break.

**Rule:** if any string in the document contains a codepoint outside basic Latin, register a Unicode TTF before drawing.

## Default solution: DejaVu

DejaVu Sans / Sans Mono / Serif covers Latin, Cyrillic, Greek, Hebrew, IPA, Armenian, Georgian, and many symbols. It is preinstalled on Anthropic's code execution container and most Linux distros at `/usr/share/fonts/truetype/dejavu/`.

```python
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.pdfbase.pdfmetrics import registerFontFamily

FDIR = "/usr/share/fonts/truetype/dejavu"

# Sans family
pdfmetrics.registerFont(TTFont("DejaVu",              f"{FDIR}/DejaVuSans.ttf"))
pdfmetrics.registerFont(TTFont("DejaVu-Bold",         f"{FDIR}/DejaVuSans-Bold.ttf"))
pdfmetrics.registerFont(TTFont("DejaVu-Oblique",      f"{FDIR}/DejaVuSans-Oblique.ttf"))
pdfmetrics.registerFont(TTFont("DejaVu-BoldOblique",  f"{FDIR}/DejaVuSans-BoldOblique.ttf"))

# Mono (use instead of Courier)
pdfmetrics.registerFont(TTFont("DejaVuMono",          f"{FDIR}/DejaVuSansMono.ttf"))
pdfmetrics.registerFont(TTFont("DejaVuMono-Bold",     f"{FDIR}/DejaVuSansMono-Bold.ttf"))

# Serif (optional, use instead of Times-Roman)
pdfmetrics.registerFont(TTFont("DejaVuSerif",         f"{FDIR}/DejaVuSerif.ttf"))
pdfmetrics.registerFont(TTFont("DejaVuSerif-Bold",    f"{FDIR}/DejaVuSerif-Bold.ttf"))

# Register families so <b>/<i> markup in Paragraph picks the right face
registerFontFamily("DejaVu",
    normal="DejaVu", bold="DejaVu-Bold",
    italic="DejaVu-Oblique", boldItalic="DejaVu-BoldOblique")
registerFontFamily("DejaVuMono",
    normal="DejaVuMono", bold="DejaVuMono-Bold")
```

Then substitute everywhere you would have used a built-in name:

| Built-in (broken for non-Latin) | DejaVu replacement   |
|---------------------------------|----------------------|
| `Helvetica`                     | `DejaVu`             |
| `Helvetica-Bold`                | `DejaVu-Bold`        |
| `Helvetica-Oblique`             | `DejaVu-Oblique`     |
| `Courier`                       | `DejaVuMono`         |
| `Courier-Bold`                  | `DejaVuMono-Bold`    |
| `Times-Roman`                   | `DejaVuSerif`        |
| `Times-Bold`                    | `DejaVuSerif-Bold`   |

```python
style = ParagraphStyle("body", fontName="DejaVu", fontSize=11)
canvas.setFont("DejaVu-Bold", 14)
```

## Why `registerFontFamily` matters

Without it, `<b>текст</b>` inside a `Paragraph` may silently fall back to the regular face (looks not-bold) or to a built-in Helvetica-Bold (boxes again). Always register the family if you use HTML-style markup or `getSampleStyleSheet()` styles.

## Scripts DejaVu does NOT cover

DejaVu lacks CJK, Arabic, Thai, and Devanagari. For those, install and register Noto.

```bash
apt-get install -y fonts-noto-core fonts-noto-cjk
```

| Script                       | Font                                    | Path                                                       |
|------------------------------|-----------------------------------------|------------------------------------------------------------|
| Chinese / Japanese / Korean  | Noto Sans CJK                           | `/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc`   |
| Arabic                       | Noto Sans Arabic                        | `/usr/share/fonts/truetype/noto/NotoSansArabic-Regular.ttf`|
| Thai                         | Noto Sans Thai                          | `/usr/share/fonts/truetype/noto/NotoSansThai-Regular.ttf`  |
| Devanagari (Hindi, etc.)     | Noto Sans Devanagari                    | `/usr/share/fonts/truetype/noto/NotoSansDevanagari-Regular.ttf` |

`TTFont` accepts `.ttf`, `.otf`, and `.ttc` despite the class name. For `.ttc` collections, pass `subfontIndex=0` (or the appropriate index) if needed.

```python
pdfmetrics.registerFont(TTFont("NotoCJK",
    "/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc", subfontIndex=0))
```

## Verify before delivering

ReportLab's silent failure mode means you must **look at** the rendered PDF before presenting it. Render the first page to PNG and inspect:

```python
from pdf2image import convert_from_path
img = convert_from_path("output.pdf", dpi=110, first_page=1, last_page=1)[0]
img.save("/home/claude/check.png")
# then view check.png
```

If you see solid black rectangles where letters should be, a built-in font slipped through somewhere — most often in a `ParagraphStyle` copied from `getSampleStyleSheet()`, which defaults to Helvetica/Times. Audit every `fontName=` and rebuild.

## Pre-flight checklist

Before running the PDF build script:

1. Does the content contain any non-ASCII codepoint? If yes, continue.
2. Register DejaVu (or Noto for CJK/Arabic/Thai/Devanagari).
3. Call `registerFontFamily` for every family you'll use with `<b>`/`<i>` markup.
4. Replace every `Helvetica` / `Courier` / `Times` literal — including ones hidden inside `getSampleStyleSheet()` styles you've cloned.
5. Build, render page 1 to PNG, eyeball it for tofu, then present.

## Out of scope

This skill is specifically for **ReportLab-generated PDFs**. It does not apply to:

- DOCX / PPTX / XLSX — those embed font names that are resolved by Word/PowerPoint/Excel at view time; the rendering machine needs the font, not the build machine.
- HTML-to-PDF (WeasyPrint, wkhtmltopdf, Playwright) — these use system font resolution via Pango/Chromium and generally handle Unicode automatically as long as the font is installed.
- Matplotlib figures — separate font-cache machinery; if Matplotlib boxes appear, set `rcParams["font.family"] = "DejaVu Sans"` (already the default) and ensure the font is in the Matplotlib cache.
