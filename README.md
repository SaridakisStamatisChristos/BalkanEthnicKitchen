# Balkan Cookbook

This workspace contains an original Balkan-inspired cookbook organized by country.

Scope:
- Countries included: Albania, Bosnia and Herzegovina, Bulgaria, Croatia, Greece, Kosovo, Montenegro, North Macedonia, Romania, Serbia, Slovenia, and Turkey.
- The generated cookbook lives under `cookbook/`.
- Each country folder contains exactly 50 recipe markdown files.
- Recipes are original writeups inspired by regional home cooking traditions.

Files:
- `cookbook/` holds the country folders and the generated table of contents.
- `tools/generate-cookbook.ps1` regenerates the full cookbook.
- `tools/export-printable-cookbook.ps1` creates a single print-ready cookbook export in `exports/`.
- `tools/print-to-pdf.mjs` renders the printable HTML to PDF with running headers and folio numbers.
- `package.json` declares the print-export dependency used for PDF generation.

Notes:
- This uses a broad modern Balkan scope that includes Slovenia, Romania, Kosovo, and the Balkan region of Turkey.
- Recipe titles mix recognizable traditional dishes with original regional house-style variations so the collection can reach 50 recipes per country.

Export:
- Run `npm install` once to install the PDF export dependency.
- Run `pwsh -File .\tools\export-printable-cookbook.ps1` to build `exports/balkan-cookbook-printable.html`.
- If Microsoft Edge or Google Chrome is available, the same command also creates `exports/balkan-cookbook-printable.pdf` with running headers, page numbers, a print index, chapter opener pages, a colophon, and a back cover.