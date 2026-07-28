const sharp = require('sharp');
const path = require('path');

async function makeCircular(input, output, size) {
  const half = size / 2;
  const circleSvg = `<svg width="${size}" height="${size}"><circle cx="${half}" cy="${half}" r="${half}" fill="black"/></svg>`;

  await sharp(input)
    .resize(size, size, { fit: 'cover', position: 'center' })
    .composite([{ input: Buffer.from(circleSvg), blend: 'dest-in' }])
    .png()
    .toFile(output);

  console.log(`Created ${output}`);
}

(async () => {
  const base = path.join(__dirname, '..', 'web', 'icons');
  const input = path.join(__dirname, '..', 'assets', 'icon.png');
  await makeCircular(input, path.join(base, 'Icon-circle-192.png'), 192);
  await makeCircular(input, path.join(base, 'Icon-circle-512.png'), 512);
})();