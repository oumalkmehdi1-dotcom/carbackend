// ============================================================
// server.js — Car Rental App (Express + Azure SQL + Azure Blob)
// ============================================================
// Main entry point. Connects to Azure SQL Database for data,
// Azure Blob Storage for car images, and serves the frontend.
// ============================================================

import 'dotenv/config';
import express from 'express';
import cors from 'cors';
import rateLimit from 'express-rate-limit';
import multer from 'multer';
import path from 'path';
import { fileURLToPath } from 'url';
import { getPool, query } from './db.js';
import { initStorage, uploadImage, deleteImage } from './storage.js';

// ES module directory helpers
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const app = express();
const port = process.env.PORT || 8080;

// Multer config for image uploads (in memory, max 5MB)
const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 5 * 1024 * 1024 }, // 5 MB
  fileFilter: (req, file, cb) => {
    const allowed = ['image/jpeg', 'image/png', 'image/gif', 'image/webp'];
    if (allowed.includes(file.mimetype)) {
      cb(null, true);
    } else {
      cb(new Error('Only image files (JPEG, PNG, GIF, WebP) are allowed'));
    }
  },
});

// ============================================================
// Middleware
// ============================================================
app.use(cors());
app.use(express.json());

// Rate limiting — prevent abuse (100 requests per 15 min per IP)
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 100,
  standardHeaders: true,
  legacyHeaders: false,
});
app.use('/api/', limiter);

// Serve static frontend files from /public
app.use(express.static(path.join(__dirname, 'public')));

// ============================================================
// API ROUTES — Cars
// ============================================================

// GET /api/cars — List all cars
app.get('/api/cars', async (req, res) => {
  try {
    const result = await query('SELECT * FROM cars ORDER BY brand, model');
    res.json(result.recordset);
  } catch (err) {
    console.error('Error fetching cars:', err.message);
    res.status(500).json({ error: 'Failed to fetch cars' });
  }
});

// POST /api/cars — Add a new car with optional image (Admin)
app.post('/api/cars', upload.single('image'), async (req, res) => {
  const { brand, model } = req.body;

  // Validation
  if (!brand || !model) {
    return res.status(400).json({ error: 'Brand and model are required' });
  }
  if (brand.length > 50 || model.length > 50) {
    return res.status(400).json({ error: 'Brand and model must be under 50 characters' });
  }

  try {
    let imageUrl = null;

    // Upload image to Azure Blob Storage if provided
    if (req.file) {
      try {
        imageUrl = await uploadImage(req.file.buffer, req.file.originalname, req.file.mimetype);
      } catch (uploadErr) {
        console.error('Image upload failed:', uploadErr.message);
        // Continue without image — don't block car creation
      }
    }

    const result = await query(
      `INSERT INTO cars (brand, model, image_url) 
       OUTPUT INSERTED.*
       VALUES (@brand, @model, @imageUrl)`,
      { brand: brand.trim(), model: model.trim(), imageUrl }
    );

    res.status(201).json(result.recordset[0]);
  } catch (err) {
    console.error('Error adding car:', err.message);
    res.status(500).json({ error: 'Failed to add car' });
  }
});

// DELETE /api/cars/:id — Delete a car (Admin)
app.delete('/api/cars/:id', async (req, res) => {
  const id = Number(req.params.id);
  if (!Number.isInteger(id) || id <= 0) {
    return res.status(400).json({ error: 'Invalid car ID' });
  }

  try {
    // Get the car first to delete its image
    const carResult = await query('SELECT * FROM cars WHERE id = @id', { id });
    if (carResult.recordset.length === 0) {
      return res.status(404).json({ error: 'Car not found' });
    }

    const car = carResult.recordset[0];

    // Delete car from database (cascade deletes reservations)
    await query('DELETE FROM cars WHERE id = @id', { id });

    // Delete image from blob storage
    if (car.image_url) {
      await deleteImage(car.image_url);
    }

    res.json({ message: 'Car deleted successfully' });
  } catch (err) {
    console.error('Error deleting car:', err.message);
    res.status(500).json({ error: 'Failed to delete car' });
  }
});

// ============================================================
// API ROUTES — Reservations
// ============================================================

// GET /api/reservations — List all reservations (Admin)
app.get('/api/reservations', async (req, res) => {
  try {
    const result = await query(`
      SELECT 
        r.id,
        r.customer_name,
        r.phone,
        r.start_date,
        r.end_date,
        r.created_at,
        c.brand,
        c.model
      FROM reservations r
      JOIN cars c ON r.car_id = c.id
      ORDER BY r.created_at DESC
    `);
    res.json(result.recordset);
  } catch (err) {
    console.error('Error fetching reservations:', err.message);
    res.status(500).json({ error: 'Failed to fetch reservations' });
  }
});

// POST /api/reservations — Create a reservation (User)
app.post('/api/reservations', async (req, res) => {
  const { car_id, customer_name, phone, start_date, end_date } = req.body;

  // Validation
  if (!car_id || !customer_name || !phone || !start_date || !end_date) {
    return res.status(400).json({ error: 'All fields are required' });
  }
  if (customer_name.length > 100) {
    return res.status(400).json({ error: 'Name must be under 100 characters' });
  }
  const phonePattern = /^[0-9\s\-+()]{6,20}$/;
  if (!phonePattern.test(phone)) {
    return res.status(400).json({ error: 'Invalid phone number format' });
  }
  const start = new Date(start_date);
  const end = new Date(end_date);
  if (isNaN(start.getTime()) || isNaN(end.getTime())) {
    return res.status(400).json({ error: 'Invalid date format' });
  }
  if (end <= start) {
    return res.status(400).json({ error: 'End date must be after start date' });
  }

  try {
    // Check that the car exists
    const carResult = await query('SELECT id FROM cars WHERE id = @carId', { carId: Number(car_id) });
    if (carResult.recordset.length === 0) {
      return res.status(404).json({ error: 'Car not found' });
    }

    const result = await query(
      `INSERT INTO reservations (car_id, customer_name, phone, start_date, end_date)
       OUTPUT INSERTED.id
       VALUES (@carId, @customerName, @phone, @startDate, @endDate)`,
      {
        carId: Number(car_id),
        customerName: customer_name.trim(),
        phone: phone.trim(),
        startDate: start_date,
        endDate: end_date,
      }
    );

    res.status(201).json({
      message: 'Reservation created successfully',
      id: result.recordset[0].id,
    });
  } catch (err) {
    console.error('Error creating reservation:', err.message);
    res.status(500).json({ error: 'Failed to create reservation' });
  }
});

// DELETE /api/reservations/:id — Cancel a reservation (Admin)
app.delete('/api/reservations/:id', async (req, res) => {
  const id = Number(req.params.id);
  if (!Number.isInteger(id) || id <= 0) {
    return res.status(400).json({ error: 'Invalid reservation ID' });
  }

  try {
    const result = await query('DELETE FROM reservations WHERE id = @id', { id });
    if (result.rowsAffected[0] === 0) {
      return res.status(404).json({ error: 'Reservation not found' });
    }
    res.json({ message: 'Reservation cancelled successfully' });
  } catch (err) {
    console.error('Error deleting reservation:', err.message);
    res.status(500).json({ error: 'Failed to delete reservation' });
  }
});

// ============================================================
// Fallback — Serve index.html for any non-API route
// ============================================================
app.get('*', (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

// ============================================================
// Start Server — Connect to DB and Storage first
// ============================================================
async function start() {
  try {
    await getPool();            // Connect to Azure SQL
    await initStorage();        // Connect to Azure Blob Storage

    app.listen(port, () => {
      console.log(`🚗 Car Rental App running at http://localhost:${port}`);
      console.log(`📋 Admin panel at http://localhost:${port}/admin.html`);
    });
  } catch (err) {
    console.error('❌ Failed to start:', err.message);
    process.exit(1);
  }
}

start();
