# FlSteamLua introduction

Static GitHub Pages site. Publish this directory as the Pages artifact; no build
step, external font CDN, framework or API key is required.

- `index.html`: semantic content, a real-client screenshot exhibition, original
  CSS/SVG illustrations and interactive library/save/transfer studies. The latter
  are explicitly identified as information studies, not product screenshots.
- `style.css`: responsive editorial layout, transform/opacity animation,
  reduced-motion support and visible keyboard focus.
- `script.js`: accessible tabs, arrow/Home/End navigation, subtle pointer-follow
  screenshot perspective, animation control and progressive section reveals.
  Core content and download links work without JS.
- `favicon.svg`: the repository's existing app mark.
- `assets/screenshots/`: real client captures supplied by the project owner.
  Replace only with actual app captures; the exhibition reserves its ratio
  before loading.

The default presentation is Chinese with supporting English labels. Release
links use GitHub's `releases/latest`, so patch releases do not require site edits.
All local URLs are relative and work under a repository Pages path.

For a local preview, run `python -m http.server 8080 --directory site` from the
repository root, then open `http://localhost:8080`. No Node installation or build
command is needed to serve the site. `node --check site/script.js` checks the
script syntax. When adding a page anchor or local asset, keep links relative to
this directory and ensure every tab's `aria-controls` matches its panel ID.

The GitHub Pages deployment workflow lives outside this directory. Downloads
resolve through the repository's latest release rather than a hardcoded version.
