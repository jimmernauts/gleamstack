import { processImage } from '../../src/upload';
import fs from 'fs/promises';
import path from 'path';

// Import Jimp using require
const Jimp = require('jimp');

/**
 * Manual test script for the image processing functionality
 * This script creates test images of different sizes and processes them
 * to verify the resizing functionality works correctly
 */
async function runManualTest() {
  console.log('Starting manual image processing test...');
  
  // Create a directory for test output
  const testDir = path.join(__dirname, 'manual_test_output');
  try {
    await fs.mkdir(testDir, { recursive: true });
    console.log(`Created test directory: ${testDir}`);
  } catch (err) {
    console.error('Error creating test directory:', err);
  }
  
  // Test with different image sizes
  const testSizes = [
    { width: 800, height: 600, name: 'small' },   // Should be under 5MB
    { width: 2000, height: 1500, name: 'medium' }, // Might be under 5MB
    { width: 4000, height: 3000, name: 'large' }   // Should be over 5MB
  ];
  
  for (const size of testSizes) {
    console.log(`\nTesting with ${size.name} image (${size.width}x${size.height})...`);
    
    // Create test image
    console.log('Creating test image...');
    const image = await Jimp.create(size.width, size.height, 0xffffffff);
    
    // Add some random colored shapes to make the image more realistic
    for (let i = 0; i < 50; i++) {
      const x = Math.floor(Math.random() * size.width);
      const y = Math.floor(Math.random() * size.height);
      const radius = Math.floor(Math.random() * 100) + 50;
      const color = Math.floor(Math.random() * 0xffffff);
      image.scan(x, y, radius, radius, function(x, y, idx) {
        this.bitmap.data[idx] = (color >> 16) & 0xff;
        this.bitmap.data[idx + 1] = (color >> 8) & 0xff;
        this.bitmap.data[idx + 2] = color & 0xff;
        this.bitmap.data[idx + 3] = 0xff;
      });
    }
    
    // Save original image
    const originalPath = path.join(testDir, `${size.name}_original.jpg`);
    await image.writeAsync(originalPath);
    
    // Get image as base64
    const imageBuffer = await image.getBufferAsync(Jimp.MIME_JPEG);
    const imageBase64 = `data:image/jpeg;base64,${imageBuffer.toString('base64')}`;
    
    // Log original size
    const originalSize = imageBuffer.length;
    console.log(`Original size: ${(originalSize / 1024 / 1024).toFixed(2)}MB`);
    
    // Process the image
    console.log('Processing image...');
    const processedImage = await processImage(imageBase64);
    
    // Extract processed image data
    const processedData = processedImage.split(',')[1];
    const processedBuffer = Buffer.from(processedData, 'base64');
    
    // Log processed size
    const processedSize = processedBuffer.length;
    console.log(`Processed size: ${(processedSize / 1024 / 1024).toFixed(2)}MB`);
    
    // Save processed image
    const processedPath = path.join(testDir, `${size.name}_processed.jpg`);
    await fs.writeFile(processedPath, processedBuffer);
    
    // Report if the image was resized
    if (originalSize !== processedSize) {
      console.log(`Image was resized. Size reduction: ${((1 - processedSize / originalSize) * 100).toFixed(2)}%`);
    } else {
      console.log('Image was not resized (under 5MB)');
    }
    
    console.log(`Saved original to: ${originalPath}`);
    console.log(`Saved processed to: ${processedPath}`);
  }
  
  console.log('\nManual test completed. Check the output directory for the processed images.');
}

// Run the test
runManualTest().catch(err => {
  console.error('Error running manual test:', err);
});
