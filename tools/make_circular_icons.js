const sharp = require('sharp');
const path = require('path');
const fs = require('fs');

// Dark navy background - matches the app's splash/theme color
const BG_COLOR = '#0a2540';

// Safe zone for maskable icons: 40% of size must be centered
// padding = (size - safeZone) / 2 = (size - 0.4*size) / 2 = 0.3*size
function getMaskablePadding(size) {
  return Math.round(size * 0.3); // 40% safe zone in center
}

async function make(input, output, size, { maskable = false, padding = 0 } = {}) {
  const innerSize = size - padding * 2;

  // Resize the icon with transparent alpha, then composite onto solid background
  const resized = await sharp(input)
    .resize(innerSize, innerSize, { fit: 'contain', background: { r: 0, g: 0, b: 0, alpha: 0 } })
    .png()
    .toBuffer();

  // Create solid color background
  const bgSvg = `<svg width="${size}" height="${size}"><rect width="${size}" height="${size}" fill="${BG_COLOR}"/></svg>`;

  // Composite the icon onto the background
  await sharp(Buffer.from(bgSvg))
    .composite([{ input: resized, left: padding, top: padding }])
    .png()
    .toFile(output);

  console.log(`Created ${output} (${size}x${size}${maskable ? ', maskable' : ''}${padding ? `, pad=${padding}` : ''})`);
}

(async () => {
  const input = path.join(__dirname, '..', 'assets', 'isksularstracklogo.png');
  const base = path.join(__dirname, '..', 'web', 'icons');
  const assets = path.join(__dirname, '..', 'assets');

  // 1. Standard icons (no padding) - for "any" purpose
  await make(input, path.join(base, 'Icon-192.png'), 192);
  await make(input, path.join(base, 'Icon-512.png'), 512);

  // 2. Circle icons (alias of standard, for "any" purpose in manifest)
  await make(input, path.join(base, 'Icon-circle-192.png'), 192);
  await make(input, path.join(base, 'Icon-circle-512.png'), 512);

  // 3. Maskable icons - 40% safe zone (30% padding on each side)
  const maskablePad192 = getMaskablePadding(192); // ~58px
  const maskablePad512 = getMaskablePadding(512); // ~154px
  await make(input, path.join(base, 'Icon-maskable-192.png'), 192, { maskable: true, padding: maskablePad192 });
  await make(input, path.join(base, 'Icon-maskable-512.png'), 512, { maskable: true, padding: maskablePad512 });

  // 4. Apple touch icon (180px for iPhone, but we generate 192 for compatibility)
  // iOS uses 180x180 for iPhone, 192x192 for iPad Pro
  await make(input, path.join(base, 'apple-touch-icon.png'), 192);

  // 5. Flutter assets icon
  await make(input, path.join(assets, 'icon.png'), 192);

  // 6. Favicon variants (small sizes)
  await make(input, path.join(base, 'favicon-16.png'), 16);
  await make(input, path.join(base, 'favicon-32.png'), 32);
  await make(input, path.join(base, 'favicon-64.png'), 64);

  // Copy apple-touch-icon.png with cache-busting version to match index.html
  fs.copyFileSync(
    path.join(base, 'apple-touch-icon.png'),
    path.join(base, 'apple-touch-icon-v278.png')
  );

  console.log('All icons generated with dark navy background');
  console.log(`Maskable padding: 192px=${maskablePad192}, 512px=${maskablePad512} (40% safe zone)`);
})();