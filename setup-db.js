// ============================================================
// setup-db.js — Create Tables & Seed Data in Azure SQL
// ============================================================
// Run this ONCE after creating the Azure SQL Database:
//   node setup-db.js
// ============================================================

import 'dotenv/config';
import { getPool, query } from './db.js';

async function setupDatabase() {
  console.log('🔧 Setting up Azure SQL Database...\n');

  try {
    await getPool();

    // --------------------------------------------------------
    // Create Cars table
    // --------------------------------------------------------
    await query(`
      IF NOT EXISTS (SELECT * FROM sysobjects WHERE name='cars' AND xtype='U')
      CREATE TABLE cars (
        id          INT IDENTITY(1,1) PRIMARY KEY,
        brand       NVARCHAR(50)  NOT NULL,
        model       NVARCHAR(50)  NOT NULL,
        image_url   NVARCHAR(500) NULL,
        created_at  DATETIME2     DEFAULT GETUTCDATE()
      );
    `);
    console.log('✅ Table "cars" ready.');

    // --------------------------------------------------------
    // Create Reservations table
    // --------------------------------------------------------
    await query(`
      IF NOT EXISTS (SELECT * FROM sysobjects WHERE name='reservations' AND xtype='U')
      CREATE TABLE reservations (
        id            INT IDENTITY(1,1) PRIMARY KEY,
        car_id        INT           NOT NULL,
        customer_name NVARCHAR(100) NOT NULL,
        phone         NVARCHAR(20)  NOT NULL,
        start_date    DATE          NOT NULL,
        end_date      DATE          NOT NULL,
        created_at    DATETIME2     DEFAULT GETUTCDATE(),
        FOREIGN KEY (car_id) REFERENCES cars(id) ON DELETE CASCADE
      );
    `);
    console.log('✅ Table "reservations" ready.');

    // --------------------------------------------------------
    // Seed starter cars (only if table is empty)
    // --------------------------------------------------------
    const countResult = await query('SELECT COUNT(*) AS count FROM cars');
    const carCount = countResult.recordset[0].count;

    if (carCount === 0) {
      const seedCars = [
        ['Toyota', 'Corolla'],
        ['Toyota', 'Yaris'],
        ['Renault', 'Clio'],
        ['Renault', 'Megane'],
        ['Peugeot', '208'],
        ['Peugeot', '3008'],
        ['Ford', 'Focus'],
        ['BMW', 'Série 3'],
        ['Mercedes-Benz', 'Classe A'],
        ['Hyundai', 'Tucson'],
      ];

      for (const [brand, model] of seedCars) {
        await query(
          'INSERT INTO cars (brand, model) VALUES (@brand, @model)',
          { brand, model }
        );
      }
      console.log('✅ Seeded 10 starter cars.');
    } else {
      console.log(`ℹ️  Cars table already has ${carCount} rows. Skipping seed.`);
    }

    console.log('\n🎉 Database setup complete!');
  } catch (err) {
    console.error('❌ Setup failed:', err.message);
  }

  process.exit(0);
}

setupDatabase();
