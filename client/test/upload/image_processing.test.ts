import { describe, it, expect, beforeAll, afterAll, vi, beforeEach, afterEach } from 'vitest';
import { Jimp } from 'jimp';
import fs from 'fs/promises';
import path from 'path';

// Import the processImage function
// Note: We need to modify the upload.ts file to export the processImage function
import { processImage } from '../../src/upload';

describe('Image Processing Tests', () => {
  
  // Sample small and large images for testing
  let smallImageBase64: string;
  let largeImageBase64: string;
  
  beforeAll(async () => {

    // Create a small test image (under 5MB)
    const smallImage = await Jimp.read(`${__dirname}/test_input/medium_image.jpg`);
    smallImageBase64 = await smallImage.getBase64("image/jpeg");
    
    // Create a large test image (over 5MB)
    const largeImage = await Jimp.read(`${__dirname}/test_input/large_image.jpg`);
    largeImageBase64 = await largeImage.getBase64("image/jpeg");
    
  });
  
  afterAll(async () => {
    // Clean up test directory
    //try {
    //  await fs.rm(testDir, { recursive: true, force: true });
    //} catch (err) {
    //  console.error('Error removing test directory:', err);
    //}
  });
  
  // Mock console.log to avoid cluttering test output
  beforeEach(() => {
    vi.spyOn(console, 'log').mockImplementation(() => {});
  });
  
  afterEach(() => {
    vi.restoreAllMocks();
  });
  
  it('should not modify images under 5MB', async () => {
    // Process the small image
    const processedImage = await processImage(smallImageBase64);
    
    // The processed image should be the same as the original
    expect(processedImage).toBe(smallImageBase64);
  });
  
  it('should resize images over 5MB', async () => {
    // Process the large image
    const processedImage = await processImage(largeImageBase64);
    
    // The processed image should be different from the original
    expect(processedImage).not.toBe(largeImageBase64);
    
    // The processed image should be smaller than the original
    const originalSize = Buffer.from(largeImageBase64.split(',')[1], 'base64').length;
    const processedSize = Buffer.from(processedImage.split(',')[1], 'base64').length;
    expect(processedSize).toBeLessThan(originalSize);
    
    // The processed image should be under 5MB
    const MAX_SIZE = 5 * 1024 * 1024;
    expect(processedSize).toBeLessThanOrEqual(MAX_SIZE);
  });
  
  it('should maintain image format (JPEG)', async () => {
    // Process the large image
    const processedImage = await processImage(largeImageBase64);
    
    // The processed image should still be a JPEG
    expect(processedImage.startsWith('data:image/jpeg;base64,')).toBe(true);
  });
  
  it('should handle PNG images', async () => {
    // Create a PNG test image
    const pngImage = new Jimp({width: 2000, height: 1500, color: 0xffffffff});
    const pngImageBase64 = `data:image/png;base64,${pngImage.getBase64("image/png")}`;
    
    // Process the PNG image
    const processedImage = await processImage(pngImageBase64);
    
    // The processed image should be in JPEG format (our implementation converts to JPEG)
    expect(processedImage.startsWith('data:image/jpeg;base64,')).toBe(true);
  });
  
  it('should handle invalid input gracefully', async () => {
    // Test with invalid base64 data
    const invalidBase64 = 'data:image/jpeg;base64,invalid_base64_data';
    
    // The function should throw an error or return a rejected promise
    await expect(processImage(invalidBase64)).rejects.toThrow();
  });
});
