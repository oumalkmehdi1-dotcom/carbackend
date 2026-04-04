// ============================================================
// db.js — Azure SQL Database Connection
// ============================================================
// Connects to Azure SQL Database using the mssql package.
// Connection details come from environment variables.
// ============================================================

import sql from 'mssql';

// ============================================================
// Database Configuration (from environment variables)
// ============================================================
const config = {
  server: process.env.DB_SERVER,       // e.g. myserver.database.windows.net
  database: process.env.DB_NAME,       // e.g. carrentaldb
  user: process.env.DB_USER,           // e.g. sqladmin
  password: process.env.DB_PASSWORD,   // your password
  options: {
    encrypt: true,                     // Required for Azure SQL
    trustServerCertificate: false,     // Production: always false
  },
  pool: {
    max: 10,
    min: 0,
    idleTimeoutMillis: 30000,
  },
};

// ============================================================
// Connection Pool (reused across all requests)
// ============================================================
let pool;

export async function getPool() {
  if (!pool) {
    pool = await sql.connect(config);
    console.log('✅ Connected to Azure SQL Database.');
  }
  return pool;
}

// ============================================================
// Helper: Run a query with parameters
// ============================================================
export async function query(sqlText, params = {}) {
  const p = await getPool();
  const request = p.request();

  // Add each parameter to the request
  for (const [key, value] of Object.entries(params)) {
    request.input(key, value);
  }

  return request.query(sqlText);
}

export default sql;
