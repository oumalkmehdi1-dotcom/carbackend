// ============================================================
// storage.js — Azure Blob Storage Helper
// ============================================================
// Handles uploading car images to Azure Blob Storage.
// Images are stored in a public container so they can be
// displayed directly in the browser via URL.
// ============================================================

import { BlobServiceClient } from '@azure/storage-blob';

const connectionString = process.env.AZURE_STORAGE_CONNECTION_STRING;
const containerName = process.env.AZURE_STORAGE_CONTAINER || 'car-images';

let containerClient;

// ============================================================
// Initialize the blob container client
// ============================================================
export async function initStorage() {
  if (!connectionString) {
    console.warn('⚠️  AZURE_STORAGE_CONNECTION_STRING not set. Image upload disabled.');
    return false;
  }

  try {
    const blobServiceClient = BlobServiceClient.fromConnectionString(connectionString);
    containerClient = blobServiceClient.getContainerClient(containerName);

    // Create container if it doesn't exist (with public blob access)
    await containerClient.createIfNotExists({
      access: 'blob', // Public read access for blobs (images)
    });

    console.log(`✅ Azure Blob Storage ready (container: ${containerName}).`);
    return true;
  } catch (err) {
    console.error('❌ Storage init failed:', err.message);
    return false;
  }
}

// ============================================================
// Upload an image buffer to blob storage
// Returns the public URL of the uploaded image
// ============================================================
export async function uploadImage(buffer, originalName, mimeType) {
  if (!containerClient) {
    throw new Error('Storage not initialized');
  }

  // Create a unique blob name: timestamp-originalname
  const timestamp = Date.now();
  const safeName = originalName.replace(/[^a-zA-Z0-9._-]/g, '_');
  const blobName = `${timestamp}-${safeName}`;

  const blockBlobClient = containerClient.getBlockBlobClient(blobName);

  await blockBlobClient.uploadData(buffer, {
    blobHTTPHeaders: {
      blobContentType: mimeType,
    },
  });

  return blockBlobClient.url; // Public URL
}

// ============================================================
// Delete an image from blob storage
// ============================================================
export async function deleteImage(imageUrl) {
  if (!containerClient || !imageUrl) return;

  try {
    // Extract blob name from URL
    const url = new URL(imageUrl);
    const blobName = url.pathname.split('/').pop();
    const blockBlobClient = containerClient.getBlockBlobClient(blobName);
    await blockBlobClient.deleteIfExists();
  } catch (err) {
    console.error('Warning: Could not delete blob:', err.message);
  }
}
