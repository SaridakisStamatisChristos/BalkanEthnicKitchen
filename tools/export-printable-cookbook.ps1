Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$workspaceRoot = Split-Path -Parent $PSScriptRoot
$cookbookRoot = Join-Path $workspaceRoot 'cookbook'
$exportsRoot = Join-Path $workspaceRoot 'exports'
$htmlOutputPath = Join-Path $exportsRoot 'balkan-cookbook-printable.html'
$pdfOutputPath = Join-Path $exportsRoot 'balkan-cookbook-printable.pdf'
$printDriverPath = Join-Path $PSScriptRoot 'print-to-pdf.mjs'

if (-not (Test-Path $cookbookRoot)) {
    throw "Cookbook directory not found at $cookbookRoot. Generate the cookbook first."
}

if (-not (Test-Path $exportsRoot)) {
    New-Item -ItemType Directory -Path $exportsRoot | Out-Null
}

function Encode-Html {
    param([string]$Text)

    return [System.Net.WebUtility]::HtmlEncode([string]$Text)
}

function New-Slug {
    param([string]$Text)

    $slug = $Text.ToLowerInvariant()
    $slug = $slug -replace '[^a-z0-9]+', '-'
    return $slug.Trim('-')
}

function Get-CountryTheme {
    param([string]$CountryName)

    switch ($CountryName) {
        'Albania' {
            return [pscustomobject]@{
                Accent = '#a04636'
                Ink = '#5a241d'
                Soft = '#f6e0d8'
                Motif = 'Stone Braid'
                MotifNote = 'Stone-braid geometry and mountain market greens frame the chapter opener.'
            }
        }
        'Bosnia and Herzegovina' {
            return [pscustomobject]@{
                Accent = '#7d4a2f'
                Ink = '#48261a'
                Soft = '#f3e0d3'
                Motif = 'Copper Filigree'
                MotifNote = 'Copper filigree rhythm and hearth-fire tones echo old city kitchens and long broths.'
            }
        }
        'Bulgaria' {
            return [pscustomobject]@{
                Accent = '#a9571f'
                Ink = '#5b3116'
                Soft = '#f7e4d1'
                Motif = 'Rose Tile'
                MotifNote = 'Rose-tile bands and sun-warmed clay hues carry the section into bean pots and banitsa.'
            }
        }
        'Croatia' {
            return [pscustomobject]@{
                Accent = '#2f6a74'
                Ink = '#173c45'
                Soft = '#dceff1'
                Motif = 'Adriatic Wave'
                MotifNote = 'Adriatic wave lines and coastal stone light set the tone for fish stews and island baking.'
            }
        }
        'Greece' {
            return [pscustomobject]@{
                Accent = '#3c7193'
                Ink = '#1f4258'
                Soft = '#deecf5'
                Motif = 'Cycladic Meander'
                MotifNote = 'Island meander forms and blue-white contrasts anchor the chapter in sea, herb, and lemon notes.'
            }
        }
        'Kosovo' {
            return [pscustomobject]@{
                Accent = '#8b5e26'
                Ink = '#4d3113'
                Soft = '#f3e5d3'
                Motif = 'Sunburst Thread'
                MotifNote = 'Sunburst threads and highland warmth introduce tray bakes, layered breads, and dairy-rich tables.'
            }
        }
        'Montenegro' {
            return [pscustomobject]@{
                Accent = '#556332'
                Ink = '#2b3317'
                Soft = '#e6ecdb'
                Motif = 'Mountain Fold'
                MotifNote = 'Mountain folds, lake light, and smokehouse earth color the opener for rugged household dishes.'
            }
        }
        'North Macedonia' {
            return [pscustomobject]@{
                Accent = '#91403a'
                Ink = '#561f1c'
                Soft = '#f5dcd9'
                Motif = 'Paprika Lattice'
                MotifNote = 'Paprika lattice and orchard reds introduce the section with market-bright, oven-deep color.'
            }
        }
        'Romania' {
            return [pscustomobject]@{
                Accent = '#7b5a2d'
                Ink = '#473015'
                Soft = '#f2e7d7'
                Motif = 'Carpathian Weave'
                MotifNote = 'Carpathian weave patterns and painted woodwork cues frame soups, cornmeal, and preserves.'
            }
        }
        'Serbia' {
            return [pscustomobject]@{
                Accent = '#8d2f2e'
                Ink = '#531818'
                Soft = '#f3dbdb'
                Motif = 'Oak Crest Stripe'
                MotifNote = 'Oak crest stripes and kiln-brick reds signal the grill smoke and bean-tray depth of the chapter.'
            }
        }
        'Slovenia' {
            return [pscustomobject]@{
                Accent = '#4a6b4d'
                Ink = '#233624'
                Soft = '#dcebdc'
                Motif = 'Alpine Quilt'
                MotifNote = 'Alpine quilt order and meadow greens set a quieter chapter of dairy, buckwheat, and pastry.'
            }
        }
        'Turkey' {
            return [pscustomobject]@{
                Accent = '#985534'
                Ink = '#582b19'
                Soft = '#f4e0d1'
                Motif = 'Iznik Geometry'
                MotifNote = 'Iznik geometry, copper glaze, and market saffron warm the opener for grills, dolma, and sweets.'
            }
        }
        default {
            return [pscustomobject]@{
                Accent = '#8d5a24'
                Ink = '#2a2219'
                Soft = '#f6efe5'
                Motif = 'Market Weave'
                MotifNote = 'A woven market pattern marks the chapter opener.'
            }
        }
    }
}

function Parse-RecipeFile {
    param(
        [string]$FilePath,
        [string]$CountryFolder
    )

    $lines = Get-Content -Path $FilePath
    $ingredients = [System.Collections.Generic.List[string]]::new()
    $method = [System.Collections.Generic.List[string]]::new()

    $title = ''
    $country = ''
    $category = ''
    $yieldText = ''
    $timeText = ''
    $intro = ''
    $servingNote = ''
    $section = ''

    foreach ($line in $lines) {
        if ($line -match '^#\s+(.+)$') {
            $title = $matches[1].Trim()
            continue
        }

        if ($line -match '^- Country:\s+(.+)$') {
            $country = $matches[1].Trim()
            continue
        }

        if ($line -match '^- Category:\s+(.+)$') {
            $category = $matches[1].Trim()
            continue
        }

        if ($line -match '^- Yield:\s+(.+)$') {
            $yieldText = $matches[1].Trim()
            continue
        }

        if ($line -match '^- Time:\s+(.+)$') {
            $timeText = $matches[1].Trim()
            continue
        }

        if ($line -match '^##\s+Intro$') {
            $section = 'Intro'
            continue
        }

        if ($line -match '^##\s+Ingredients$') {
            $section = 'Ingredients'
            continue
        }

        if ($line -match '^##\s+Method$') {
            $section = 'Method'
            continue
        }

        if ($line -match '^##\s+Serving Note$') {
            $section = 'ServingNote'
            continue
        }

        if ([string]::IsNullOrWhiteSpace($line)) {
            continue
        }

        switch ($section) {
            'Intro' {
                if ($intro) {
                    $intro = "$intro $($line.Trim())"
                }
                else {
                    $intro = $line.Trim()
                }
            }
            'Ingredients' {
                if ($line -match '^-\s+(.+)$') {
                    $ingredients.Add($matches[1].Trim())
                }
            }
            'Method' {
                if ($line -match '^\d+\.\s+(.+)$') {
                    $method.Add($matches[1].Trim())
                }
            }
            'ServingNote' {
                if ($servingNote) {
                    $servingNote = "$servingNote $($line.Trim())"
                }
                else {
                    $servingNote = $line.Trim()
                }
            }
        }
    }

    if (-not $title) {
        throw "Recipe title missing in $FilePath"
    }

    return [pscustomobject]@{
        Title = $title
        Country = $country
        Category = $category
        Yield = $yieldText
        Time = $timeText
        Intro = $intro
        Ingredients = $ingredients.ToArray()
        Method = $method.ToArray()
        ServingNote = $servingNote
        FileName = [System.IO.Path]::GetFileName($FilePath)
        Anchor = "$(New-Slug $CountryFolder)-$(New-Slug ([System.IO.Path]::GetFileNameWithoutExtension($FilePath)))"
    }
}

function Find-PdfBrowser {
    $candidatePaths = [System.Collections.Generic.List[string]]::new()

    foreach ($commandName in @('msedge.exe', 'chrome.exe')) {
        $command = Get-Command $commandName -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($command -and $command.Source -and -not $candidatePaths.Contains($command.Source)) {
            $candidatePaths.Add($command.Source)
        }
    }

    if ($Env:ProgramFiles) {
        foreach ($path in @(
            (Join-Path $Env:ProgramFiles 'Microsoft\Edge\Application\msedge.exe'),
            (Join-Path $Env:ProgramFiles 'Google\Chrome\Application\chrome.exe')
        )) {
            if ((Test-Path $path) -and -not $candidatePaths.Contains($path)) {
                $candidatePaths.Add($path)
            }
        }
    }

    if (${Env:ProgramFiles(x86)}) {
        foreach ($path in @(
            (Join-Path ${Env:ProgramFiles(x86)} 'Microsoft\Edge\Application\msedge.exe'),
            (Join-Path ${Env:ProgramFiles(x86)} 'Google\Chrome\Application\chrome.exe')
        )) {
            if ((Test-Path $path) -and -not $candidatePaths.Contains($path)) {
                $candidatePaths.Add($path)
            }
        }
    }

    return ($candidatePaths | Select-Object -First 1)
}

function Wait-ForPdfFile {
    param(
        [string]$PdfPath,
        [int]$TimeoutMilliseconds = 10000
    )

    if ((Test-Path $PdfPath) -and ((Get-Item $PdfPath).Length -gt 0)) {
        return $true
    }

    $directoryPath = Split-Path -Parent $PdfPath
    $fileName = Split-Path -Leaf $PdfPath
    $watcher = [System.IO.FileSystemWatcher]::new($directoryPath, $fileName)
    $watcher.EnableRaisingEvents = $true
    $changeTypes = [System.IO.WatcherChangeTypes]::Created -bor [System.IO.WatcherChangeTypes]::Changed -bor [System.IO.WatcherChangeTypes]::Renamed
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

    try {
        while ($stopwatch.ElapsedMilliseconds -lt $TimeoutMilliseconds) {
            $remainingMilliseconds = $TimeoutMilliseconds - [int]$stopwatch.ElapsedMilliseconds
            if ($remainingMilliseconds -lt 1) {
                break
            }

            $result = $watcher.WaitForChanged($changeTypes, $remainingMilliseconds)
            if ($result.TimedOut) {
                break
            }

            if ((Test-Path $PdfPath) -and ((Get-Item $PdfPath).Length -gt 0)) {
                return $true
            }
        }
    }
    finally {
        $watcher.Dispose()
    }

    return ((Test-Path $PdfPath) -and ((Get-Item $PdfPath).Length -gt 0))
}

function Try-ExportPdf {
    param(
        [string]$HtmlPath,
        [string]$PdfPath
    )

    if (-not (Test-Path $printDriverPath)) {
        return [pscustomobject]@{
            Success = $false
            Reason = "PDF driver not found at $printDriverPath."
            Browser = ''
        }
    }

    $playwrightDependencyPath = Join-Path $workspaceRoot 'node_modules\playwright-core'
    if (-not (Test-Path $playwrightDependencyPath)) {
        return [pscustomobject]@{
            Success = $false
            Reason = 'playwright-core is not installed. Run npm install in the workspace first.'
            Browser = ''
        }
    }

    $browserPath = Find-PdfBrowser
    if (-not $browserPath) {
        return [pscustomobject]@{
            Success = $false
            Reason = 'No supported browser was found for headless PDF export.'
            Browser = ''
        }
    }

    $arguments = @(
        $printDriverPath,
        '--html', $HtmlPath,
        '--pdf', $PdfPath,
        '--browser', $browserPath,
        '--title', $bookTitle,
        '--brand', $brandName,
        '--edition', $editionName
    )

    if (Test-Path $PdfPath) {
        Remove-Item -Path $PdfPath -Force
    }

    try {
        & node @arguments *> $null
    }
    catch {
        return [pscustomobject]@{
            Success = $false
            Reason = $_.Exception.Message
            Browser = $browserPath
        }
    }

    $exitCode = 0
    if (Test-Path variable:LASTEXITCODE) {
        $exitCode = $LASTEXITCODE
    }

    if ($exitCode -eq 0 -and (Wait-ForPdfFile -PdfPath $PdfPath)) {
        return [pscustomobject]@{
            Success = $true
            Reason = ''
            Browser = $browserPath
        }
    }

    return [pscustomobject]@{
        Success = $false
        Reason = "Browser exited with code $exitCode."
        Browser = $browserPath
    }
}

$countryDirectories = Get-ChildItem -Path $cookbookRoot -Directory | Sort-Object Name
if ($countryDirectories.Count -eq 0) {
    throw 'No country folders were found under cookbook/.'
}

$countries = [System.Collections.Generic.List[object]]::new()

foreach ($directory in $countryDirectories) {
    $recipeFiles = Get-ChildItem -Path $directory.FullName -Filter '*.md' -File | Sort-Object Name
    if ($recipeFiles.Count -eq 0) {
        throw "No recipe files were found in $($directory.FullName)."
    }

    $recipes = [System.Collections.Generic.List[object]]::new()
    foreach ($recipeFile in $recipeFiles) {
        $recipes.Add((Parse-RecipeFile -FilePath $recipeFile.FullName -CountryFolder $directory.Name))
    }

    $displayName = $recipes[0].Country
    if (-not $displayName) {
        $displayName = ($directory.Name -replace '-', ' ')
    }

    $theme = Get-CountryTheme $displayName

    $countries.Add([pscustomobject]@{
        DisplayName = $displayName
        Folder = $directory.Name
        Anchor = New-Slug $displayName
        Theme = $theme
        Recipes = $recipes.ToArray()
    })
}

$bookTitle = 'Balkan Cookbook'
$totalRecipes = (($countries | ForEach-Object { $_.Recipes.Count }) | Measure-Object -Sum).Sum
$generatedOn = Get-Date -Format 'MMMM d, yyyy'
$buildTimestamp = Get-Date -Format 'yyyy-MM-dd HH:mm'
$brandName = 'Balkan Ethnick'
$brandSeries = 'Regional Kitchen Library'
$editionName = 'Printable Heritage Edition'
$coverTagline = 'A regional kitchen atlas of breads, stews, grills, sweets, and home-table classics from across the Balkans.'
$exportCommandText = 'pwsh -File .\tools\export-printable-cookbook.ps1'

$recipeIndexEntries = @(
    foreach ($country in $countries) {
        foreach ($recipe in $country.Recipes) {
            $letter = '#'
            if ($recipe.Title -match '^[A-Za-z]') {
                $letter = $matches[0].ToUpperInvariant()
            }

            [pscustomobject]@{
                Letter = $letter
                Title = $recipe.Title
                Country = $country.DisplayName
                Category = $recipe.Category
                Anchor = $recipe.Anchor
            }
        }
    }
) | Sort-Object Letter, Title, Country

$styles = @'
:root {
    --ink: #2a2219;
    --muted: #6d5b49;
    --accent: #8d5a24;
    --line: #dbc9b3;
    --panel: #f6efe5;
}

* {
    box-sizing: border-box;
}

html {
    font-size: 11pt;
}

body {
    margin: 0;
    font-family: Georgia, "Times New Roman", serif;
    color: var(--ink);
    background: radial-gradient(circle at top, #f2dfc3 0%, #eee6d8 40%, #e6dac8 100%);
    line-height: 1.5;
    -webkit-print-color-adjust: exact;
    print-color-adjust: exact;
}

a {
    color: inherit;
    text-decoration: none;
}

main {
    max-width: 190mm;
    margin: 0 auto;
    background: #fffdf9;
    padding: 12mm 12mm 18mm;
}

section,
article {
    width: 100%;
}

.cover {
    position: relative;
    min-height: 270mm;
    overflow: hidden;
    color: #fff7ea;
    background: linear-gradient(135deg, #2c1b15 0%, #6d3a22 42%, #c28543 100%);
}

.cover::before {
    content: "";
    position: absolute;
    inset: 8mm;
    border: 1px solid rgba(255, 247, 234, 0.34);
}

.cover::after {
    content: "";
    position: absolute;
    top: 22mm;
    right: -24mm;
    width: 128mm;
    height: 128mm;
    border-radius: 50%;
    border: 1px solid rgba(255, 247, 234, 0.22);
    background: radial-gradient(circle, rgba(255, 237, 208, 0.28) 0%, rgba(255, 237, 208, 0.08) 44%, rgba(255, 237, 208, 0) 74%);
}

.cover-shell {
    position: relative;
    z-index: 1;
    min-height: 270mm;
    padding: 14mm 14mm 16mm;
    display: flex;
    flex-direction: column;
    justify-content: space-between;
}

.cover-brand-row {
    display: flex;
    justify-content: space-between;
    align-items: flex-start;
    gap: 8mm;
}

.brand-lockup {
    display: flex;
    align-items: center;
    gap: 5mm;
}

.brand-badge {
    width: 18mm;
    height: 18mm;
    border-radius: 50%;
    border: 1.5px solid currentColor;
    display: flex;
    align-items: center;
    justify-content: center;
    flex: 0 0 auto;
    font-size: 0.76rem;
    font-weight: 700;
    letter-spacing: 0.16em;
}

.brand-badge--ink {
    color: var(--accent);
}

.brand-text {
    display: flex;
    flex-direction: column;
    gap: 0.7mm;
}

.brand-text strong {
    font-size: 0.98rem;
    letter-spacing: 0.08em;
    text-transform: uppercase;
}

.brand-text span {
    font-size: 0.76rem;
    letter-spacing: 0.14em;
    text-transform: uppercase;
    color: rgba(255, 247, 234, 0.74);
}

.brand-text--ink span {
    color: var(--muted);
}

.cover-kicker {
    margin: 0;
    text-transform: uppercase;
    letter-spacing: 0.16em;
    font-size: 0.72rem;
    color: rgba(255, 247, 234, 0.8);
}

.eyebrow {
    margin: 0 0 5mm;
    text-transform: uppercase;
    letter-spacing: 0.18em;
    font-size: 0.72rem;
    color: var(--muted);
}

.eyebrow--light {
    color: rgba(255, 247, 234, 0.76);
}

h1,
h2,
h3,
h4 {
    margin: 0;
    font-weight: 600;
    line-height: 1.08;
}

h1 {
    max-width: 12ch;
    font-size: 2.65rem;
}

h2 {
    font-size: 2rem;
}

h3 {
    font-size: 1.45rem;
}

.cover-hero {
    max-width: 126mm;
    padding: 10mm 0 8mm;
}

.cover-title {
    max-width: 7ch;
    font-size: 4.25rem;
    line-height: 0.98;
}

.cover-deck {
    margin: 6mm 0 0;
    max-width: 110mm;
    color: rgba(255, 247, 234, 0.88);
    font-size: 1.06rem;
}

.cover-footer {
    display: flex;
    flex-direction: column;
    gap: 4mm;
}

.cover-stats {
    display: grid;
    grid-template-columns: repeat(3, minmax(0, 1fr));
    gap: 4mm;
}

.cover-stat {
    padding: 4mm 4.5mm;
    border: 1px solid rgba(255, 247, 234, 0.28);
    background: rgba(255, 247, 234, 0.12);
}

.cover-stat strong {
    display: block;
    font-size: 1.5rem;
}

.cover-stat span {
    display: block;
    color: rgba(255, 247, 234, 0.72);
    font-size: 0.85rem;
}

.cover-note {
    max-width: 118mm;
    margin: 0;
    color: rgba(255, 247, 234, 0.82);
}

.title-page {
    min-height: 255mm;
    padding: 14mm 0 8mm;
}

.title-page-shell {
    min-height: 233mm;
    display: flex;
    flex-direction: column;
    justify-content: space-between;
}

.title-page-header {
    display: flex;
    justify-content: space-between;
    align-items: flex-start;
    gap: 8mm;
    padding-bottom: 5mm;
    border-bottom: 1px solid var(--line);
}

.title-page-body {
    display: grid;
    grid-template-columns: minmax(0, 1.35fr) minmax(0, 0.95fr);
    gap: 10mm;
    align-items: start;
    padding-top: 10mm;
}

.title-summary {
    max-width: 102mm;
    margin: 5mm 0 0;
    color: var(--muted);
    font-size: 1.04rem;
}

.title-meta-grid {
    display: grid;
    grid-template-columns: repeat(3, minmax(0, 1fr));
    gap: 4mm;
    margin-top: 8mm;
}

.title-meta-card {
    padding: 4mm;
    border: 1px solid var(--line);
    background: var(--panel);
}

.title-meta-card span {
    display: block;
    margin-bottom: 1.5mm;
    color: var(--muted);
    font-size: 0.72rem;
    text-transform: uppercase;
    letter-spacing: 0.14em;
}

.title-meta-card strong {
    display: block;
    font-size: 0.98rem;
}

.title-page-card {
    padding: 6mm;
    border: 1px solid var(--line);
    background: linear-gradient(180deg, #fbf6ef 0%, #f3e5d3 100%);
}

.title-page-card h3 {
    margin-bottom: 4mm;
    font-size: 1.08rem;
}

.title-country-list {
    margin: 0;
    padding-left: 5mm;
    columns: 2;
    column-gap: 8mm;
}

.title-country-list li {
    break-inside: avoid;
    margin: 0 0 2mm;
}

.title-page-footer {
    display: flex;
    justify-content: space-between;
    gap: 10mm;
    padding-top: 7mm;
    border-top: 1px solid var(--line);
    color: var(--muted);
    font-size: 0.88rem;
}

.title-page-footer p {
    max-width: 88mm;
    margin: 0;
}

.chapter-mark {
    display: flex;
    align-items: center;
    gap: 2.2mm;
    margin: 0 0 5mm;
}

.chapter-mark span {
    display: block;
    height: 3mm;
    border-radius: 999px;
    background: var(--chapter-accent);
}

.chapter-mark span:nth-child(1) {
    width: 18mm;
}

.chapter-mark span:nth-child(2) {
    width: 8mm;
    background: var(--chapter-ink);
}

.chapter-mark span:nth-child(3) {
    width: 12mm;
}

.chapter-mark span:nth-child(4) {
    width: 24mm;
    background: linear-gradient(90deg, var(--chapter-accent) 0%, var(--chapter-soft) 100%);
}

.page-break {
    break-before: page;
    page-break-before: always;
}

.section-block {
    padding-top: 6mm;
}

.country-guide {
    margin: 6mm 0 0;
    padding: 0;
    list-style: none;
    columns: 2;
    column-gap: 10mm;
}

.country-guide li,
.country-recipe-list li {
    break-inside: avoid;
    margin: 0 0 2.2mm;
}

.country-guide a,
.country-recipe-list a {
    border-bottom: 1px solid transparent;
}

.country-guide a:hover,
.country-recipe-list a:hover {
    border-color: var(--accent);
}

.country-count {
    color: var(--muted);
    margin-left: 3mm;
}

.book-endmatter {
    margin-top: 8mm;
    padding-top: 5mm;
    border-top: 1px solid var(--line);
}

.book-endmatter p {
    margin: 0 0 3mm;
    color: var(--muted);
    font-size: 0.9rem;
}

.book-endmatter ul {
    margin: 0;
    padding: 0;
    list-style: none;
    display: grid;
    grid-template-columns: repeat(3, minmax(0, 1fr));
    gap: 4mm;
}

.book-endmatter li {
    break-inside: avoid;
}

.book-endmatter a {
    display: block;
    padding: 3mm 3.5mm;
    border: 1px solid var(--line);
    background: var(--panel);
}

.country-divider {
    --chapter-accent: var(--accent);
    --chapter-ink: var(--ink);
    --chapter-soft: var(--panel);
    position: relative;
    min-height: 255mm;
    overflow: hidden;
    padding: 10mm;
    border-top: 4px solid var(--chapter-accent);
    background: linear-gradient(180deg, var(--chapter-soft) 0%, #fffdf9 72%);
}

.country-divider::before {
    content: "";
    position: absolute;
    inset: 8mm;
    border: 1px solid rgba(42, 34, 25, 0.08);
}

.country-divider::after {
    content: "";
    position: absolute;
    right: -18mm;
    top: 16mm;
    width: 120mm;
    height: 120mm;
    border-radius: 50%;
    background: radial-gradient(circle, rgba(255, 247, 234, 0.42) 0%, rgba(255, 247, 234, 0.18) 34%, rgba(255, 247, 234, 0) 72%);
    opacity: 0.55;
}

.country-divider-shell {
    position: relative;
    z-index: 1;
    min-height: 228mm;
    display: flex;
    flex-direction: column;
}

.country-divider-top {
    display: grid;
    grid-template-columns: minmax(0, 1.15fr) minmax(0, 0.85fr);
    gap: 8mm;
    align-items: end;
}

.country-divider-copy p {
    max-width: 110mm;
    margin: 0;
    color: var(--muted);
}

.country-motif-card {
    padding: 5mm;
    border: 1px solid rgba(42, 34, 25, 0.14);
    background: rgba(255, 253, 249, 0.58);
}

.country-motif-ribbon {
    height: 20mm;
    margin-bottom: 4mm;
    border: 1px solid rgba(42, 34, 25, 0.18);
    background:
        repeating-linear-gradient(135deg, rgba(255, 247, 234, 0.08) 0 5mm, rgba(255, 247, 234, 0.4) 5mm 10mm),
        linear-gradient(90deg, var(--chapter-ink) 0%, var(--chapter-accent) 100%);
}

.country-motif-name {
    margin: 0;
    text-transform: uppercase;
    letter-spacing: 0.14em;
    font-size: 0.72rem;
    color: var(--chapter-ink);
}

.country-motif-note {
    margin: 2mm 0 0;
    color: var(--muted);
    font-size: 0.9rem;
}

.country-recipe-list {
    columns: 2;
    column-gap: 10mm;
    padding-left: 5mm;
    margin: 10mm 0 0;
}

.recipe {
    break-inside: avoid-page;
    page-break-inside: avoid;
    padding: 7mm 0 8mm;
    border-top: 1px solid var(--line);
}

.recipe-header {
    display: flex;
    gap: 6mm;
    justify-content: space-between;
    align-items: flex-start;
}

.recipe-title-block {
    flex: 1 1 auto;
}

.recipe-kicker {
    margin: 0 0 2mm;
    text-transform: uppercase;
    letter-spacing: 0.14em;
    font-size: 0.72rem;
    color: var(--muted);
}

.recipe-meta {
    min-width: 44mm;
    padding-left: 4mm;
    border-left: 1px solid var(--line);
    color: var(--muted);
    font-size: 0.85rem;
}

.recipe-meta div + div {
    margin-top: 1.5mm;
}

.recipe-intro {
    margin: 4mm 0 4.5mm;
}

.recipe-body h4 {
    margin-bottom: 2mm;
    font-size: 0.92rem;
    text-transform: uppercase;
    letter-spacing: 0.12em;
    color: var(--muted);
}

.recipe-body ul,
.recipe-body ol {
    margin: 0;
    padding-left: 5mm;
}

.recipe-body li + li {
    margin-top: 1.5mm;
}

.recipe-ingredients {
    margin-bottom: 4.5mm;
    padding: 4mm 4.5mm;
    background: var(--panel);
    border: 1px solid var(--line);
}

.serving-note {
    margin-top: 4mm;
    padding-top: 3mm;
    border-top: 1px dashed var(--line);
    font-style: italic;
    color: var(--muted);
}

.print-index {
    padding-top: 6mm;
}

.index-lead {
    max-width: 118mm;
    margin: 4mm 0 0;
    color: var(--muted);
}

.index-columns {
    columns: 2;
    column-gap: 8mm;
    margin-top: 8mm;
}

.index-group {
    break-inside: avoid;
    margin: 0 0 6mm;
    padding: 4mm 4.5mm;
    border: 1px solid var(--line);
    background: #fbf7f0;
}

.index-group h3 {
    margin-bottom: 3mm;
    font-size: 1.08rem;
    color: var(--accent);
}

.index-group ul {
    margin: 0;
    padding: 0;
    list-style: none;
}

.index-group li + li {
    margin-top: 2mm;
}

.index-ref {
    display: block;
    color: var(--muted);
    font-size: 0.84rem;
}

.colophon {
    min-height: 255mm;
    padding-top: 6mm;
}

.colophon-shell {
    min-height: 233mm;
    padding: 8mm;
    border: 1px solid var(--line);
    background: linear-gradient(180deg, #fcf8f2 0%, #f3e6d6 100%);
    display: flex;
    flex-direction: column;
    justify-content: space-between;
}

.colophon-grid {
    display: grid;
    grid-template-columns: repeat(2, minmax(0, 1fr));
    gap: 6mm;
    margin-top: 8mm;
}

.colophon-card {
    padding: 5mm;
    border: 1px solid var(--line);
    background: rgba(255, 253, 249, 0.7);
}

.colophon-card h3 {
    margin-bottom: 3mm;
    font-size: 1.02rem;
}

.colophon-card p,
.colophon-card li {
    color: var(--muted);
}

.colophon-card ul {
    margin: 0;
    padding-left: 5mm;
}

.colophon-mono {
    font-family: "Courier New", monospace;
    font-size: 0.86rem;
    color: var(--ink);
}

.colophon-footer {
    margin-top: 8mm;
    padding-top: 5mm;
    border-top: 1px solid var(--line);
    color: var(--muted);
}

.back-cover {
    position: relative;
    overflow: hidden;
    min-height: 270mm;
    color: #fff7ea;
    background: linear-gradient(135deg, #241915 0%, #6d3b24 45%, #b77b3c 100%);
}

.back-cover::before {
    content: "";
    position: absolute;
    inset: 10mm;
    border: 1px solid rgba(255, 247, 234, 0.26);
}

.back-cover::after {
    content: "";
    position: absolute;
    left: -20mm;
    bottom: -26mm;
    width: 138mm;
    height: 138mm;
    border-radius: 50%;
    background: radial-gradient(circle, rgba(255, 237, 208, 0.24) 0%, rgba(255, 237, 208, 0.08) 46%, rgba(255, 237, 208, 0) 74%);
}

.back-cover-shell {
    position: relative;
    z-index: 1;
    min-height: 270mm;
    padding: 14mm;
    display: flex;
    flex-direction: column;
    justify-content: space-between;
}

.back-cover-title {
    max-width: 10ch;
    font-size: 2.9rem;
}

.back-cover-blurb {
    max-width: 108mm;
    margin: 5mm 0 0;
    color: rgba(255, 247, 234, 0.88);
    font-size: 1.02rem;
}

.country-chip-list {
    display: flex;
    flex-wrap: wrap;
    gap: 2.5mm;
    max-width: 140mm;
    margin-top: 6mm;
}

.country-chip {
    padding: 1.6mm 3mm;
    border: 1px solid rgba(255, 247, 234, 0.28);
    background: rgba(255, 247, 234, 0.08);
    font-size: 0.72rem;
    letter-spacing: 0.1em;
    text-transform: uppercase;
}

.back-cover-metrics {
    display: grid;
    grid-template-columns: repeat(3, minmax(0, 1fr));
    gap: 4mm;
}

.back-cover-metrics div {
    padding: 4mm;
    border: 1px solid rgba(255, 247, 234, 0.26);
    background: rgba(255, 247, 234, 0.12);
}

.back-cover-metrics span {
    display: block;
    font-size: 0.76rem;
    text-transform: uppercase;
    letter-spacing: 0.14em;
    color: rgba(255, 247, 234, 0.76);
}

.back-cover-metrics strong {
    display: block;
    margin-top: 1mm;
    font-size: 1.08rem;
}

.back-cover-fine {
    max-width: 108mm;
    margin: 0;
    color: rgba(255, 247, 234, 0.76);
}

@page {
    size: A4;
    margin: 18mm 12mm 18mm;
}

@media screen {
    main {
        margin-top: 10mm;
        margin-bottom: 12mm;
        box-shadow: 0 4mm 12mm rgba(42, 34, 25, 0.12);
    }
}

@media screen and (max-width: 960px) {
    .cover-stats,
    .title-meta-grid,
    .title-page-body,
    .country-divider-top,
    .book-endmatter ul,
    .colophon-grid,
    .back-cover-metrics {
        grid-template-columns: 1fr;
    }

    .country-guide,
    .country-recipe-list,
    .title-country-list,
    .index-columns {
        columns: 1;
    }
}

@media print {
    body {
        background: #ffffff;
    }

    main {
        max-width: none;
        margin: 0;
        padding: 0;
        box-shadow: none;
    }

    a {
        text-decoration: none;
    }
}
'@

$html = [System.Text.StringBuilder]::new()
$null = $html.AppendLine('<!DOCTYPE html>')
$null = $html.AppendLine('<html lang="en">')
$null = $html.AppendLine('<head>')
$null = $html.AppendLine('  <meta charset="utf-8">')
$null = $html.AppendLine('  <meta name="viewport" content="width=device-width, initial-scale=1">')
$null = $html.AppendLine(('  <title>{0} | {1}</title>' -f (Encode-Html $bookTitle), (Encode-Html $brandName)))
$null = $html.AppendLine('  <style>')
$null = $html.AppendLine($styles)
$null = $html.AppendLine('  </style>')
$null = $html.AppendLine('</head>')
$null = $html.AppendLine('<body>')
$null = $html.AppendLine('  <main>')
$null = $html.AppendLine('    <section class="cover">')
$null = $html.AppendLine('      <div class="cover-shell">')
$null = $html.AppendLine('        <div class="cover-brand-row">')
$null = $html.AppendLine('          <div class="brand-lockup">')
$null = $html.AppendLine('            <div class="brand-badge">BE</div>')
$null = $html.AppendLine(('            <div class="brand-text"><strong>{0}</strong><span>{1}</span></div>' -f (Encode-Html $brandName), (Encode-Html $brandSeries)))
$null = $html.AppendLine('          </div>')
$null = $html.AppendLine(('          <p class="cover-kicker">{0}</p>' -f (Encode-Html $editionName)))
$null = $html.AppendLine('        </div>')
$null = $html.AppendLine('        <div class="cover-hero">')
$null = $html.AppendLine('          <p class="eyebrow eyebrow--light">Twelve Countries, One Volume</p>')
$null = $html.AppendLine(('          <h1 class="cover-title">{0}</h1>' -f (Encode-Html $bookTitle)))
$null = $html.AppendLine(('          <p class="cover-deck">{0}</p>' -f (Encode-Html $coverTagline)))
$null = $html.AppendLine('        </div>')
$null = $html.AppendLine('        <div class="cover-footer">')
$null = $html.AppendLine('          <div class="cover-stats">')
$null = $html.AppendLine(('            <div class="cover-stat"><strong>{0}</strong><span>Countries</span></div>' -f $countries.Count))
$null = $html.AppendLine(('            <div class="cover-stat"><strong>{0}</strong><span>Recipes</span></div>' -f $totalRecipes))
$null = $html.AppendLine(('            <div class="cover-stat"><strong>{0}</strong><span>Export Date</span></div>' -f $generatedOn))
$null = $html.AppendLine('          </div>')
$null = $html.AppendLine('          <p class="cover-note">Designed for home printing or bindery output, with country divider chapters and unified recipe styling across the full collection.</p>')
$null = $html.AppendLine('        </div>')
$null = $html.AppendLine('      </div>')
$null = $html.AppendLine('    </section>')
$null = $html.AppendLine('    <section class="title-page page-break">')
$null = $html.AppendLine('      <div class="title-page-shell">')
$null = $html.AppendLine('        <div class="title-page-header">')
$null = $html.AppendLine('          <div>')
$null = $html.AppendLine('            <p class="eyebrow">Title Page</p>')
$null = $html.AppendLine(('            <h2>{0}</h2>' -f (Encode-Html $bookTitle)))
$null = $html.AppendLine('          </div>')
$null = $html.AppendLine('          <div class="brand-lockup">')
$null = $html.AppendLine('            <div class="brand-badge brand-badge--ink">BE</div>')
$null = $html.AppendLine(('            <div class="brand-text brand-text--ink"><strong>{0}</strong><span>{1}</span></div>' -f (Encode-Html $brandName), (Encode-Html $brandSeries)))
$null = $html.AppendLine('          </div>')
$null = $html.AppendLine('        </div>')
$null = $html.AppendLine('        <div class="title-page-body">')
$null = $html.AppendLine('          <div>')
$null = $html.AppendLine('            <p class="eyebrow">Collected Recipes</p>')
$null = $html.AppendLine(('            <p class="title-summary">This printable edition assembles the generated workspace cookbook into one regional volume, structured by country and laid out for clean reading in print or PDF.</p>'))
$null = $html.AppendLine('            <div class="title-meta-grid">')
$null = $html.AppendLine(('              <div class="title-meta-card"><span>Edition</span><strong>{0}</strong></div>' -f (Encode-Html $editionName)))
$null = $html.AppendLine('              <div class="title-meta-card"><span>Format</span><strong>A4 and Letter Ready</strong></div>')
$null = $html.AppendLine(('              <div class="title-meta-card"><span>Scope</span><strong>{0} recipes in one volume</strong></div>' -f $totalRecipes))
$null = $html.AppendLine('            </div>')
$null = $html.AppendLine('          </div>')
$null = $html.AppendLine('          <aside class="title-page-card">')
$null = $html.AppendLine('            <h3>Countries Included</h3>')
$null = $html.AppendLine('            <ol class="title-country-list">')

foreach ($country in $countries) {
    $null = $html.AppendLine(('              <li>{0}</li>' -f (Encode-Html $country.DisplayName)))
}

$null = $html.AppendLine('            </ol>')
$null = $html.AppendLine('          </aside>')
$null = $html.AppendLine('        </div>')
$null = $html.AppendLine('        <div class="title-page-footer">')
$null = $html.AppendLine(('          <p>Exported on {0} for the {1} imprint.</p>' -f $generatedOn, (Encode-Html $brandName)))
$null = $html.AppendLine('          <p>Country divider pages begin on fresh pages, and recipe blocks are kept together where possible for easier printing and binding.</p>')
$null = $html.AppendLine('        </div>')
$null = $html.AppendLine('      </div>')
$null = $html.AppendLine('    </section>')
$null = $html.AppendLine('    <section class="page-break section-block">')
$null = $html.AppendLine('      <p class="eyebrow">Country Guide</p>')
$null = $html.AppendLine('      <h2>Contents</h2>')
$null = $html.AppendLine('      <ul class="country-guide">')

foreach ($country in $countries) {
    $countryName = Encode-Html $country.DisplayName
    $null = $html.AppendLine(('        <li><a href="#{0}">{1}</a><span class="country-count">{2} recipes</span></li>' -f $country.Anchor, $countryName, $country.Recipes.Count))
}

$null = $html.AppendLine('      </ul>')
$null = $html.AppendLine('      <div class="book-endmatter">')
$null = $html.AppendLine('        <p>End matter in this printable edition:</p>')
$null = $html.AppendLine('        <ul>')
$null = $html.AppendLine('          <li><a href="#print-index">Print Index</a></li>')
$null = $html.AppendLine('          <li><a href="#colophon">Colophon</a></li>')
$null = $html.AppendLine('          <li><a href="#back-cover">Back Cover</a></li>')
$null = $html.AppendLine('        </ul>')
$null = $html.AppendLine('      </div>')
$null = $html.AppendLine('    </section>')

foreach ($country in $countries) {
    $countryName = Encode-Html $country.DisplayName
    $chapterStyle = '--chapter-accent: {0}; --chapter-ink: {1}; --chapter-soft: {2};' -f $country.Theme.Accent, $country.Theme.Ink, $country.Theme.Soft
    $chapterSummary = Encode-Html ("This section gathers {0} recipes from {1} into one printable chapter." -f $country.Recipes.Count, $country.DisplayName)
    $motifName = Encode-Html $country.Theme.Motif
    $motifNote = Encode-Html $country.Theme.MotifNote

    $null = $html.AppendLine(('    <section class="country-divider page-break" id="{0}" style="{1}">' -f $country.Anchor, $chapterStyle))
    $null = $html.AppendLine('      <div class="country-divider-shell">')
    $null = $html.AppendLine('        <div class="country-divider-top">')
    $null = $html.AppendLine('          <div class="country-divider-copy">')
    $null = $html.AppendLine('            <p class="eyebrow">Country Section</p>')
    $null = $html.AppendLine('            <div class="chapter-mark" aria-hidden="true"><span></span><span></span><span></span><span></span></div>')
    $null = $html.AppendLine("            <h2>$countryName</h2>")
    $null = $html.AppendLine(('            <p>{0}</p>' -f $chapterSummary))
    $null = $html.AppendLine('          </div>')
    $null = $html.AppendLine('          <aside class="country-motif-card">')
    $null = $html.AppendLine('            <div class="country-motif-ribbon"></div>')
    $null = $html.AppendLine(('            <p class="country-motif-name">Motif: {0}</p>' -f $motifName))
    $null = $html.AppendLine(('            <p class="country-motif-note">{0}</p>' -f $motifNote))
    $null = $html.AppendLine('          </aside>')
    $null = $html.AppendLine('        </div>')
    $null = $html.AppendLine('        <ol class="country-recipe-list">')

    foreach ($recipe in $country.Recipes) {
        $recipeTitle = Encode-Html $recipe.Title
        $null = $html.AppendLine(('        <li><a href="#{0}">{1}</a></li>' -f $recipe.Anchor, $recipeTitle))
    }

    $null = $html.AppendLine('        </ol>')
    $null = $html.AppendLine('      </div>')
    $null = $html.AppendLine('    </section>')

    foreach ($recipe in $country.Recipes) {
        $recipeTitle = Encode-Html $recipe.Title
        $recipeCategory = Encode-Html $recipe.Category
        $recipeIntro = Encode-Html $recipe.Intro
        $recipeYield = Encode-Html $recipe.Yield
        $recipeTime = Encode-Html $recipe.Time
        $servingNote = Encode-Html $recipe.ServingNote

        $null = $html.AppendLine(('    <article class="recipe" id="{0}">' -f $recipe.Anchor))
        $null = $html.AppendLine('      <header class="recipe-header">')
        $null = $html.AppendLine('        <div class="recipe-title-block">')
        $null = $html.AppendLine(('          <p class="recipe-kicker">{0} / {1}</p>' -f $countryName, $recipeCategory))
        $null = $html.AppendLine("          <h3>$recipeTitle</h3>")
        $null = $html.AppendLine('        </div>')
        $null = $html.AppendLine('        <div class="recipe-meta">')
        $null = $html.AppendLine("          <div><strong>Yield</strong><br>$recipeYield</div>")
        $null = $html.AppendLine("          <div><strong>Time</strong><br>$recipeTime</div>")
        $null = $html.AppendLine('        </div>')
        $null = $html.AppendLine('      </header>')
        $null = $html.AppendLine(('      <p class="recipe-intro">{0}</p>' -f $recipeIntro))
        $null = $html.AppendLine('      <div class="recipe-body">')
        $null = $html.AppendLine('        <section class="recipe-ingredients">')
        $null = $html.AppendLine('          <h4>Ingredients</h4>')
        $null = $html.AppendLine('          <ul>')

        foreach ($ingredient in $recipe.Ingredients) {
            $null = $html.AppendLine("            <li>$(Encode-Html $ingredient)</li>")
        }

        $null = $html.AppendLine('          </ul>')
        $null = $html.AppendLine('        </section>')
        $null = $html.AppendLine('        <section>')
        $null = $html.AppendLine('          <h4>Method</h4>')
        $null = $html.AppendLine('          <ol>')

        foreach ($step in $recipe.Method) {
            $null = $html.AppendLine("            <li>$(Encode-Html $step)</li>")
        }

        $null = $html.AppendLine('          </ol>')
        $null = $html.AppendLine('        </section>')
        $null = $html.AppendLine('      </div>')
        $null = $html.AppendLine(('      <p class="serving-note">{0}</p>' -f $servingNote))
        $null = $html.AppendLine('    </article>')
    }
}

$null = $html.AppendLine('    <section class="print-index page-break" id="print-index">')
$null = $html.AppendLine('      <p class="eyebrow">Print Index</p>')
$null = $html.AppendLine('      <h2>Recipe Index</h2>')
$null = $html.AppendLine('      <p class="index-lead">Alphabetized by recipe title for quick lookup in the printable edition. In the PDF export, running folios appear in the footer on every page.</p>')
$null = $html.AppendLine('      <div class="index-columns">')

foreach ($group in ($recipeIndexEntries | Group-Object Letter)) {
    $null = $html.AppendLine('        <section class="index-group">')
    $null = $html.AppendLine(('          <h3>{0}</h3>' -f (Encode-Html $group.Name)))
    $null = $html.AppendLine('          <ul>')

    foreach ($entry in ($group.Group | Sort-Object Title, Country)) {
        $null = $html.AppendLine(('            <li><a href="#{0}">{1}</a><span class="index-ref">{2} / {3}</span></li>' -f $entry.Anchor, (Encode-Html $entry.Title), (Encode-Html $entry.Country), (Encode-Html $entry.Category)))
    }

    $null = $html.AppendLine('          </ul>')
    $null = $html.AppendLine('        </section>')
}

$null = $html.AppendLine('      </div>')
$null = $html.AppendLine('    </section>')
$null = $html.AppendLine('    <section class="colophon page-break" id="colophon">')
$null = $html.AppendLine('      <div class="colophon-shell">')
$null = $html.AppendLine('        <div>')
$null = $html.AppendLine('          <p class="eyebrow">Colophon</p>')
$null = $html.AppendLine('          <h2>Production Notes</h2>')
$null = $html.AppendLine('          <div class="colophon-grid">')
$null = $html.AppendLine('            <section class="colophon-card">')
$null = $html.AppendLine('              <h3>Imprint</h3>')
$null = $html.AppendLine(('              <p>{0} / {1}</p>' -f (Encode-Html $brandName), (Encode-Html $brandSeries)))
$null = $html.AppendLine(('              <p>{0}</p>' -f (Encode-Html $editionName)))
$null = $html.AppendLine(('              <p>Generated on {0}.</p>' -f (Encode-Html $generatedOn)))
$null = $html.AppendLine('            </section>')
$null = $html.AppendLine('            <section class="colophon-card">')
$null = $html.AppendLine('              <h3>Source</h3>')
$null = $html.AppendLine('              <p>This volume was assembled from the recipe markdown files stored under cookbook/ in the workspace.</p>')
$null = $html.AppendLine(('              <p class="colophon-mono">{0}</p>' -f (Encode-Html $exportCommandText)))
$null = $html.AppendLine('            </section>')
$null = $html.AppendLine('            <section class="colophon-card">')
$null = $html.AppendLine('              <h3>Print Features</h3>')
$null = $html.AppendLine('              <ul>')
$null = $html.AppendLine('                <li>Chapter opener pages with country motifs</li>')
$null = $html.AppendLine('                <li>Running headers and folio numbers in the PDF edition</li>')
$null = $html.AppendLine('                <li>Alphabetical print index and full end matter</li>')
$null = $html.AppendLine('              </ul>')
$null = $html.AppendLine('            </section>')
$null = $html.AppendLine('            <section class="colophon-card">')
$null = $html.AppendLine('              <h3>Volume Scope</h3>')
$null = $html.AppendLine(('              <p>{0} countries, {1} recipes, one printable volume.</p>' -f $countries.Count, $totalRecipes))
$null = $html.AppendLine(('              <p>Build timestamp: {0}</p>' -f (Encode-Html $buildTimestamp)))
$null = $html.AppendLine('            </section>')
$null = $html.AppendLine('          </div>')
$null = $html.AppendLine('        </div>')
$null = $html.AppendLine('        <p class="colophon-footer">Prepared for print from the Balkan Ethnick workspace cookbook collection. For best results, use the generated PDF for physical printing.</p>')
$null = $html.AppendLine('      </div>')
$null = $html.AppendLine('    </section>')
$null = $html.AppendLine('    <section class="back-cover page-break" id="back-cover">')
$null = $html.AppendLine('      <div class="back-cover-shell">')
$null = $html.AppendLine('        <div class="brand-lockup">')
$null = $html.AppendLine('          <div class="brand-badge">BE</div>')
$null = $html.AppendLine(('          <div class="brand-text"><strong>{0}</strong><span>{1}</span></div>' -f (Encode-Html $brandName), (Encode-Html $brandSeries)))
$null = $html.AppendLine('        </div>')
$null = $html.AppendLine('        <div>')
$null = $html.AppendLine('          <p class="eyebrow eyebrow--light">Back Cover</p>')
$null = $html.AppendLine('          <h2 class="back-cover-title">Across mountain ovens, coastal grills, orchard sweets, and market tables.</h2>')
$null = $html.AppendLine(('          <p class="back-cover-blurb">{0} brings the full cookbook into one printable object: chaptered by country, indexed for lookup, and finished with bindery-ready end matter.</p>' -f (Encode-Html $brandName)))
 $null = $html.AppendLine('          <div class="country-chip-list">')

foreach ($country in $countries) {
    $null = $html.AppendLine(('            <span class="country-chip">{0}</span>' -f (Encode-Html $country.DisplayName)))
}

$null = $html.AppendLine('          </div>')
$null = $html.AppendLine('        </div>')
$null = $html.AppendLine('        <div class="back-cover-metrics">')
$null = $html.AppendLine(('          <div><span>Edition</span><strong>{0}</strong></div>' -f (Encode-Html $editionName)))
$null = $html.AppendLine(('          <div><span>Countries</span><strong>{0}</strong></div>' -f $countries.Count))
$null = $html.AppendLine(('          <div><span>Recipes</span><strong>{0}</strong></div>' -f $totalRecipes))
$null = $html.AppendLine('        </div>')
$null = $html.AppendLine('        <p class="back-cover-fine">Printed from the Balkan Ethnick workspace export pipeline with chapter motifs, running headers, folios, and a dedicated print index.</p>')
$null = $html.AppendLine('      </div>')
$null = $html.AppendLine('    </section>')

$null = $html.AppendLine('  </main>')
$null = $html.AppendLine('</body>')
$null = $html.AppendLine('</html>')

Set-Content -Path $htmlOutputPath -Value $html.ToString() -Encoding utf8

$pdfResult = Try-ExportPdf -HtmlPath $htmlOutputPath -PdfPath $pdfOutputPath

Write-Host "HTML export created: $htmlOutputPath"
if ($pdfResult.Success) {
    Write-Host "PDF export created: $pdfOutputPath"
}
else {
    Write-Warning "PDF export was skipped or failed: $($pdfResult.Reason)"
}