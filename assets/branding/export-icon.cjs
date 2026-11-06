// Render the original SVG at each target size, then package PNG-backed ICOs.
// Tool-only: npm dependencies are installed under the caller's private directory.
const fs = require('node:fs');
const path = require('node:path');

const modulePath = process.argv[2];
if (!modulePath) {
  throw new Error('Usage: node assets/branding/export-icon.cjs <resvg-module-path>');
}
const { Resvg } = require(path.resolve(modulePath));
const root = path.resolve(__dirname, '../..');
const svg = fs.readFileSync(path.join(__dirname, 'app.svg'));
const sizes = [16, 20, 24, 32, 40, 48, 64, 128, 256];
const render = (size) => new Resvg(svg, {
  fitTo: { mode: 'width', value: size },
}).render().asPng();
const images = sizes.map(render);
const header = Buffer.alloc(6 + sizes.length * 16);
header.writeUInt16LE(1, 2);
header.writeUInt16LE(sizes.length, 4);
let offset = header.length;
sizes.forEach((size, index) => {
  const entry = 6 + index * 16;
  header[entry] = size === 256 ? 0 : size;
  header[entry + 1] = size === 256 ? 0 : size;
  header.writeUInt16LE(1, entry + 4);
  header.writeUInt16LE(32, entry + 6);
  header.writeUInt32LE(images[index].length, entry + 8);
  header.writeUInt32LE(offset, entry + 12);
  offset += images[index].length;
});
const icon = Buffer.concat([header, ...images]);
fs.writeFileSync(path.join(__dirname, 'app.png'), images.at(-1));
fs.writeFileSync(path.join(__dirname, 'app-512.png'), render(512));
fs.writeFileSync(path.join(__dirname, 'app.ico'), icon);
fs.writeFileSync(path.join(root, 'windows/runner/resources/app_icon.ico'), icon);
console.log(`Exported app.svg to ${sizes.join('/')}px ICO, 256px and 512px PNG.`);
