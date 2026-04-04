// ============================================================
// update-images.js — One-time script to add real car photos
// ============================================================
// Fetches an actual photo of each car from Wikipedia's free API
// and saves the URL in the Azure SQL database.
//
// Usage:
//   node update-images.js
// ============================================================

import 'dotenv/config';
import { query } from './db.js';

// Each car in the database mapped to its English Wikipedia article title.
// Wikipedia's REST API returns the article's main image — the real car photo.
const cars = [
  { id: 1,  brand: 'Toyota',        model: 'Corolla',    wiki: 'Toyota_Corolla' },
  { id: 2,  brand: 'Toyota',        model: 'Yaris',      wiki: 'Toyota_Yaris' },
  { id: 3,  brand: 'Renault',       model: 'Clio',       wiki: 'Renault_Clio' },
  { id: 4,  brand: 'Renault',       model: 'Megane',     wiki: 'Renault_M%C3%A9gane' },
  { id: 5,  brand: 'Peugeot',       model: '208',        wiki: 'Peugeot_208' },
  { id: 6,  brand: 'Peugeot',       model: '3008',       wiki: 'Peugeot_3008' },
  { id: 7,  brand: 'Ford',          model: 'Focus',      wiki: 'Ford_Focus' },
  { id: 8,  brand: 'BMW',           model: 'Série 3',    wiki: 'BMW_3_Series' },
  { id: 9,  brand: 'Mercedes-Benz', model: 'Classe A',   wiki: 'Mercedes-Benz_A-Class' },
  { id: 10, brand: 'Hyundai',       model: 'Tucson',     wiki: 'Hyundai_Tucson' },
];

// ─── Fetch a car image URL from Wikipedia ──────────────────
async function getWikipediaImage(wikiTitle) {
  const url = `https://en.wikipedia.org/api/rest_v1/page/summary/${wikiTitle}`;
  const res = await fetch(url, {
    headers: { 'User-Agent': 'CarRentalApp/1.0 (learning project)' }
  });
  if (!res.ok) return null;
  const data = await res.json();
  // Prefer the full-size original, fall back to thumbnail
  return data.originalimage?.source ?? data.thumbnail?.source ?? null;
}

// ─── Main ──────────────────────────────────────────────────
async function run() {
  console.log('🔍 Fetching real car photos from Wikipedia...\n');

  let updated = 0;
  let failed = 0;

  for (const car of cars) {
    try {
      const imageUrl = await getWikipediaImage(car.wiki);

      if (imageUrl) {
        await query(
          'UPDATE cars SET image_url = @imageUrl WHERE id = @id',
          { imageUrl, id: car.id }
        );
        console.log(`✅ ${car.brand} ${car.model}`);
        console.log(`   ${imageUrl.substring(0, 90)}...`);
        updated++;
      } else {
        console.log(`⚠️  ${car.brand} ${car.model} — no image found on Wikipedia`);
        failed++;
      }
    } catch (err) {
      console.error(`❌ ${car.brand} ${car.model} — ${err.message}`);
      failed++;
    }
  }

  console.log(`\n🎉 Done! ${updated} updated, ${failed} failed.`);
  console.log('\nVisit your app to see the photos:');
  console.log('  https://carrental-app-cr105440.azurewebsites.net\n');
  process.exit(0);
}

run();
