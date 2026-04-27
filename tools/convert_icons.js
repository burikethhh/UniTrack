const sharp = require('sharp');
const fs = require('fs');
const path = require('path');

const assetsDir = path.join(__dirname, '..', 'assets');

async function convertSvgToPng(inputFile, outputFile, size) {
  const inputPath = path.join(assetsDir, inputFile);
  const outputPath = path.join(assetsDir, outputFile);
  
  console.log(`Converting ${inputFile} to ${outputFile} (${size}x${size})...`);
  
  await sharp(inputPath, { density: 300 })
    .resize(size, size)
    .png({ compressionLevel: 9 })
    .toFile(outputPath);
  
  console.log(`Created ${outputPath}`);
}

async function main() {
  try {
    // Convert logo_v3.svg to icon.png (1024x1024 for main icon)
    await convertSvgToPng('logo_v3.svg', 'icon.png', 1024);
    
    // Convert icon_foreground_v3.svg to icon_foreground.png (1024x1024)
    await convertSvgToPng('icon_foreground_v3.svg', 'icon_foreground.png', 1024);
    
    // Convert icon_monochrome_v3.svg to icon_monochrome.png (1024x1024)
    await convertSvgToPng('icon_monochrome_v3.svg', 'icon_monochrome.png', 1024);
    
    console.log('\nAll icons converted successfully!');
  } catch (error) {
    console.error('Error converting icons:', error);
    process.exit(1);
  }
}

main();
