const sharp = require('sharp');
const path = require('path');

async function makeCircular(input, output, size, padding = 0) {
  const innerSize = size - padding * 2;
  const half = size / 2;
  const innerR = innerSize / 2;
  const circleSvg = `<svg width="${size}" height="${size}"><circle cx="${half}" cy="${half}" r="${innerR}" fill="black"/></svg>`;

  // Padding offset centers the mask in the padded area
  const maskInput = padding > 0
    ? { input: Buffer.from(circleSvg), blend: 'dest-in', left: padding, top: padding }
    : { input: Buffer.from(circleSvg), blend: 'dest-in' };

  await sharp(input)
    .resize(innerSize, innerSize, { fit: 'cover', position: 'center' })
    .flatten({ background: { r: 10, g: 37, b: 64 } })
    .extend({ top: padding, bottom: padding, left: padding, right: padding, background: { r: 10, g: 37, b: 64 } })
    .composite([maskInput])
    .png()
    .toFile(output);

  console.log(`Created ${output}`);
}

(async () => {
  const base = path.join(__dirname, '..', 'web', 'icons');
  const input = path.join(__dirname, '..', 'assets', 'icon.png');
  await makeCircular(input, path.join(base, 'Icon-circle-192.png'), 192, 4);
  await makeCircular(input, path.join(base, 'Icon-circle-512.png'), 512, 12);
})();