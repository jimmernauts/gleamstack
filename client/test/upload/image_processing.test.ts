import { describe, it, expect, beforeAll, afterAll, vi, beforeEach, afterEach } from 'vitest';
import { Jimp } from 'jimp';
import { processImage } from '../../src/upload';

async function quickHash(str: string): Promise<string> {
  const encoder = new TextEncoder();
  const data = encoder.encode(str);
  const hashBuffer = await crypto.subtle.digest('SHA-1', data); // SHA-1 is fast but not cryptographically secure
  const hashArray = Array.from(new Uint8Array(hashBuffer));
  return hashArray.map(b => b.toString(16).padStart(2, '0')).join('');
}



describe.concurrent('Image Processing Tests', () => {
  
  // Sample small and large images for testing
  let smallImageBase64: string;
  let largeImageBase64: string;
  
  beforeAll(async () => {

    // Create a small test image (under 5MB)
    const smallImage = await Jimp.read(`${__dirname}/test_input/small_image.jpg`);
    smallImageBase64 = await smallImage.getBase64("image/jpeg");
    
    // Create a large test image (over 5MB)
    const largeImage = await Jimp.read(`${__dirname}/test_input/large_image.jpg`);
    largeImageBase64 = await largeImage.getBase64("image/jpeg");
    
  },30000);
  
  afterAll(async () => {
  });
  
  // Mock console.log to avoid cluttering test output
  beforeEach(() => {
    
  });
  
  afterEach(() => {
    vi.restoreAllMocks();
  });
  
  it('should not modify images under 5MB', async () => {
    // Process the small image
    const processedImage = await processImage(smallImageBase64);
    console.log("input image: ", smallImageBase64.slice(0,100));
    console.log("processed image: ", processedImage.slice(0,100));
    const inputHash = await quickHash(smallImageBase64)
    const outputHash = await quickHash(processedImage) 
    // The processed image should be the same as the original
    expect(inputHash).toBe(outputHash);
  },30000);
  
  it('should resize images over 5MB', async () => {
    // Process the large image
    const processedImage = await processImage(largeImageBase64);
    
    // The processed image should be smaller than the original
    const originalSize = Buffer.from(largeImageBase64.split(',')[1], 'base64').length;
    const processedSize = Buffer.from(processedImage.split(',')[1], 'base64').length;
    expect(processedSize).toBeLessThan(originalSize);
    
    // The processed image should be under 5MB
    const MAX_SIZE = 5 * 1024 * 1024;
    expect(processedSize).toBeLessThanOrEqual(MAX_SIZE);
    expect(processedImage.startsWith('data:image/jpeg;base64,')).toBe(true);
  },30000);

  
  
  it('should handle invalid input gracefully', async () => {
    // Test with invalid base64 data
    const invalidBase64 = 'data:image/jpeg;base64,invalid_base64_data';
    
    // The function should throw an error or return a rejected promise
    await expect(processImage(invalidBase64)).rejects.toThrow();
  });
});
