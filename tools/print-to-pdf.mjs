import { chromium } from 'playwright-core';
import fs from 'node:fs/promises';
import path from 'node:path';
import process from 'node:process';
import { pathToFileURL } from 'node:url';

function getArg(name) {
  const index = process.argv.indexOf(`--${name}`);
  if (index === -1 || index === process.argv.length - 1) {
    throw new Error(`Missing required argument --${name}`);
  }

  return process.argv[index + 1];
}

function escapeHtml(value) {
  return String(value)
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#39;');
}

const htmlPath = path.resolve(getArg('html'));
const pdfPath = path.resolve(getArg('pdf'));
const browserPath = path.resolve(getArg('browser'));
const title = getArg('title');
const brand = getArg('brand');
const edition = getArg('edition');

const headerTemplate = `
  <style>
    .print-header {
      width: 100%;
      font-family: Georgia, 'Times New Roman', serif;
      font-size: 8px;
      color: #6d5b49;
      padding: 0 10mm;
      box-sizing: border-box;
    }

    .print-header__row {
      width: 100%;
      display: flex;
      justify-content: space-between;
      align-items: center;
      padding: 0 0 3px;
      border-bottom: 1px solid #dbc9b3;
      text-transform: uppercase;
      letter-spacing: 0.1em;
    }
  </style>
  <div class="print-header">
    <div class="print-header__row">
      <span>${escapeHtml(brand)}</span>
      <span>${escapeHtml(title)}</span>
    </div>
  </div>
`;

const footerTemplate = `
  <style>
    .print-footer {
      width: 100%;
      font-family: Georgia, 'Times New Roman', serif;
      font-size: 8px;
      color: #6d5b49;
      padding: 0 10mm;
      box-sizing: border-box;
    }

    .print-footer__row {
      width: 100%;
      display: flex;
      justify-content: space-between;
      align-items: center;
      padding: 3px 0 0;
      border-top: 1px solid #dbc9b3;
    }
  </style>
  <div class="print-footer">
    <div class="print-footer__row">
      <span>${escapeHtml(edition)}</span>
      <span><span class="pageNumber"></span> / <span class="totalPages"></span></span>
    </div>
  </div>
`;

const browser = await chromium.launch({
  executablePath: browserPath,
  headless: true
});

try {
  await fs.rm(pdfPath, { force: true });

  const page = await browser.newPage();
  await page.emulateMedia({ media: 'print' });
  await page.goto(pathToFileURL(htmlPath).href, { waitUntil: 'networkidle' });
  await page.pdf({
    path: pdfPath,
    displayHeaderFooter: true,
    headerTemplate,
    footerTemplate,
    printBackground: true,
    preferCSSPageSize: true,
    margin: {
      top: '18mm',
      right: '12mm',
      bottom: '18mm',
      left: '12mm'
    }
  });
} finally {
  await browser.close();
}