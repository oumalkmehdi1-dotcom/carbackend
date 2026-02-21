import express from "express";
import cors from "cors";
import sql from "mssql";

const app = express();
const port = process.env.PORT || 3000;

app.use(cors());
app.use(express.json());

// ✅ Connection string from Azure App Service Configuration
const connStr = process.env.SQL_CONNECTION_STRING;

async function getPool() {
  if (!connStr) throw new Error("SQL_CONNECTION_STRING is missing");
  return await sql.connect(connStr);
}

// ✅ Helper: brands + models (strings)
async function fetchCarsNamesOnly() {
  const pool = await getPool();
  const result = await pool.request().query(
    "SELECT brand, model FROM Cars ORDER BY brand, model;"
  );

  const map = new Map();
  for (const row of result.recordset) {
    if (!map.has(row.brand)) map.set(row.brand, []);
    map.get(row.brand).push(row.model);
  }

  return Array.from(map.entries()).map(([brand, models]) => ({ brand, models }));
}

// ✅ Helper: brands + models with pricePerDay
async function fetchCarsWithPrices() {
  const pool = await getPool();
  const result = await pool.request().query(
    "SELECT brand, model, price AS pricePerDay FROM Cars ORDER BY brand, model;"
  );

  const map = new Map();
  for (const row of result.recordset) {
    if (!map.has(row.brand)) map.set(row.brand, []);
    map.get(row.brand).push({ name: row.model, pricePerDay: row.pricePerDay });
  }

  return Array.from(map.entries()).map(([brand, models]) => ({ brand, models }));
}

// ✅ GET /api/cars
app.get("/api/cars", async (req, res) => {
  try {
    const data = await fetchCarsNamesOnly();
    res.json(data);
  } catch (err) {
    console.error("DB error:", err);
    res.status(500).json({ error: "Database error", details: err.message });
  }
});

// ✅ GET /api/cars-prices
app.get("/api/cars-prices", async (req, res) => {
  try {
    const data = await fetchCarsWithPrices();
    res.json(data);
  } catch (err) {
    console.error("DB error:", err);
    res.status(500).json({ error: "Database error", details: err.message });
  }
});

app.listen(port, () => {
  console.log(`Server running on port ${port}`);
});
