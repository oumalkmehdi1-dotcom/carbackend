# Car Rental App — Complete Azure Guide

## Table of Contents

1. [How the App Works](#1-how-the-app-works)
2. [Architecture Overview](#2-architecture-overview)
3. [Project Structure](#3-project-structure)
4. [Tech Stack Explained](#4-tech-stack-explained)
5. [Prerequisites](#5-prerequisites)
6. [Deploy to Azure (One Command)](#6-deploy-to-azure-one-command)
7. [Deploy Step-by-Step (Manual)](#7-deploy-step-by-step-manual)
8. [How the Code Works](#8-how-the-code-works)
9. [API Reference](#9-api-reference)
10. [Estimated Costs](#10-estimated-costs)
11. [Troubleshooting](#11-troubleshooting)
12. [Clean Up (Delete Everything)](#12-clean-up-delete-everything)
13. [What to Learn Next](#13-what-to-learn-next)

---

## 1. How the App Works

This is a car rental web application deployed on **Azure** with **three Azure services**:

### User Interface (`/`)
- Users see a **grid of available cars with images**
- Click **"Reserve"** on any car
- Fill in: name, phone number, start date, end date
- Reservation is saved to Azure SQL Database

### Admin Interface (`/admin.html`)
- Admin can **add new cars** with brand, model, and an **image upload**
- Admin can **see all cars** in a table and delete them
- Admin can **see all reservations** and cancel them
- Car images are stored in **Azure Blob Storage**

### How it flows:
```
User visits https://your-app.azurewebsites.net
     ↓
App Service serves the HTML page
     ↓
Page fetches car list from API → API queries Azure SQL Database
     ↓
Car images load directly from Azure Blob Storage URLs
     ↓
User clicks "Reserve" → API saves reservation to Azure SQL
     ↓
Admin uploads a car with image → image goes to Blob Storage, data to SQL
```

---

## 2. Architecture Overview

```
┌──────────────────────────────────────────────────────────┐
│                      AZURE CLOUD                         │
│                                                          │
│  ┌─────────────────┐    ┌───────────────────────────┐   │
│  │  App Service     │───▶│  Azure SQL Database       │   │
│  │  (B1 Linux)      │    │  (Basic tier, 5 DTU)      │   │
│  │  Node.js 18      │    │  Tables: cars,reservations │   │
│  │  Express server   │    └───────────────────────────┘   │
│  │                   │                                    │
│  │  Your app runs    │    ┌───────────────────────────┐   │
│  │  here             │───▶│  Azure Blob Storage       │   │
│  └─────────────────┘    │  (Standard_LRS)            │   │
│          ▲               │  Container: car-images     │   │
│          │               │  Stores uploaded photos    │   │
│          │               └───────────────────────────┘   │
└──────────│───────────────────────────────────────────────┘
           │
     HTTPS requests
           │
    ┌──────┴──────┐
    │   Browser   │
    │  (You/Users)│
    └─────────────┘
```

### Three Azure Services Used

| Service | Purpose | Monthly Cost |
|---------|---------|-------------|
| **App Service** (B1 Linux) | Runs your Node.js server | ~$13 |
| **Azure SQL Database** (Basic) | Stores cars & reservations | ~$5 |
| **Blob Storage** (Standard_LRS) | Stores car images | ~$0.02 |
| **Total** | | **~$18/month** |

---

## 3. Project Structure

```
carbackend/
├── server.js           ← Express server (API + static files)
├── db.js               ← Azure SQL Database connection
├── storage.js          ← Azure Blob Storage helper (image upload)
├── setup-db.js         ← One-time script to create tables & seed data
├── package.json        ← Project config & dependencies
├── .env                ← Environment variables (Azure credentials)
├── .env.example        ← Template showing required variables
├── .gitignore          ← Files Git should ignore
├── GUIDE.md            ← This file
│
├── deploy.ps1          ← One-command deployment (Windows PowerShell)
├── deploy.sh           ← One-command deployment (Mac/Linux bash)
│
├── infra/              ← Infrastructure as Code
│   ├── main.bicep      ← Azure resource definitions (Bicep)
│   └── parameters.json ← Deployment parameter values
│
└── public/             ← Frontend files (served to browser)
    ├── index.html      ← User interface (browse + reserve cars)
    ├── admin.html      ← Admin interface (manage cars + reservations)
    └── css/
        └── styles.css  ← All styles for both pages
```

---

## 4. Tech Stack Explained

| Technology | What it does | Why we chose it |
|------------|-------------|-----------------|
| **Node.js 18** | Runs JavaScript on the server | Most popular, beginner-friendly |
| **Express 4** | Web framework for Node.js | Simple, minimal, well-documented |
| **Azure SQL Database** | Cloud relational database | Managed, auto-backups, always available |
| **Azure Blob Storage** | File/image storage in the cloud | Cheap, fast, images load via direct URL |
| **Azure App Service** | Cloud hosting for the server | Easy deployment, auto-scaling, HTTPS |
| **mssql** (npm) | Node.js driver for SQL Server | Official Microsoft driver |
| **@azure/storage-blob** (npm) | Node.js SDK for Blob Storage | Official Azure SDK |
| **Multer** (npm) | Handles file uploads | Most popular Express upload middleware |
| **Bicep** | Infrastructure as Code | Defines Azure resources in a template |

---

## 5. Prerequisites

Before deploying, you need:

### 1. Azure Account
- Create a **free account**: https://azure.microsoft.com/free/
- You get $200 free credits for 30 days
- Make sure your **subscription is active** (not Disabled)

### 2. Azure CLI
- Install from: https://learn.microsoft.com/en-us/cli/azure/install-azure-cli-windows
- After installing, restart your terminal
- Verify: `az --version`

### 3. Node.js 18+
- Download from: https://nodejs.org/
- Verify: `node --version`

### 4. Log in to Azure
```powershell
az login
```
This opens your browser. Sign in with your Azure account.

---

## 6. Deploy to Azure (One Command)

The fastest way to deploy. The script creates all Azure resources and deploys your code.

### Windows (PowerShell)
```powershell
cd path\to\carbackend
.\deploy.ps1
```

### Mac/Linux (Bash)
```bash
cd path/to/carbackend
chmod +x deploy.sh
./deploy.sh
```

### What the script does:
1. Creates a Resource Group (container for all resources)
2. Creates Azure SQL Server + Database (Basic tier)
3. Configures firewall rules for database access
4. Creates Storage Account + Blob Container
5. Creates App Service Plan (B1 Linux)
6. Creates Web App with all environment variables
7. Zips and deploys your code
8. Updates your local `.env` with Azure credentials
9. Runs `npm run setup-db` to create tables and seed data
10. Opens the app in your browser

After completion, you'll see:
```
  App URL:    https://carrental-app-XXXXX.azurewebsites.net
  Admin URL:  https://carrental-app-XXXXX.azurewebsites.net/admin.html
```

---

## 7. Deploy Step-by-Step (Manual)

If you prefer to understand each step, follow this manual guide.

### Step 1: Login to Azure
```powershell
az login
```

### Step 2: Create a Resource Group
```powershell
az group create --name car-rental-rg --location eastus
```

### Step 3: Create SQL Server
```powershell
az sql server create `
    --name carrental-sql-UNIQUE `
    --resource-group car-rental-rg `
    --location eastus `
    --admin-user sqladmin `
    --admin-password "YourPassword123!"
```
> Replace `UNIQUE` with something unique (e.g., your initials + date: `jd0710`).

### Step 4: Configure SQL Firewall
```powershell
# Allow Azure services
az sql server firewall-rule create `
    --resource-group car-rental-rg `
    --server carrental-sql-UNIQUE `
    --name AllowAzureServices `
    --start-ip-address 0.0.0.0 `
    --end-ip-address 0.0.0.0

# Allow your IP (for running setup-db locally)
az sql server firewall-rule create `
    --resource-group car-rental-rg `
    --server carrental-sql-UNIQUE `
    --name AllowMyIP `
    --start-ip-address 0.0.0.0 `
    --end-ip-address 255.255.255.255
```

### Step 5: Create SQL Database
```powershell
az sql db create `
    --resource-group car-rental-rg `
    --server carrental-sql-UNIQUE `
    --name carrentaldb `
    --edition Basic `
    --capacity 5 `
    --max-size 2GB
```

### Step 6: Create Storage Account
```powershell
az storage account create `
    --name carrentalstorUNIQUE `
    --resource-group car-rental-rg `
    --location eastus `
    --sku Standard_LRS `
    --kind StorageV2 `
    --allow-blob-public-access true
```
> Storage account names must be all lowercase, no hyphens, globally unique.

### Step 7: Create Blob Container
```powershell
az storage container create `
    --name car-images `
    --account-name carrentalstorUNIQUE `
    --public-access blob
```

### Step 8: Get Storage Connection String
```powershell
az storage account show-connection-string `
    --name carrentalstorUNIQUE `
    --resource-group car-rental-rg `
    --query connectionString -o tsv
```
> Save this value — you'll need it in Step 11.

### Step 9: Create App Service Plan
```powershell
az appservice plan create `
    --name car-rental-plan `
    --resource-group car-rental-rg `
    --location eastus `
    --sku B1 `
    --is-linux
```

### Step 10: Create Web App
```powershell
az webapp create `
    --name carrental-app-UNIQUE `
    --resource-group car-rental-rg `
    --plan car-rental-plan `
    --runtime "NODE:18-lts"
```

### Step 11: Configure Environment Variables
```powershell
az webapp config appsettings set `
    --name carrental-app-UNIQUE `
    --resource-group car-rental-rg `
    --settings `
    PORT=8080 `
    DB_SERVER="carrental-sql-UNIQUE.database.windows.net" `
    DB_NAME=carrentaldb `
    DB_USER=sqladmin `
    DB_PASSWORD="YourPassword123!" `
    AZURE_STORAGE_CONNECTION_STRING="<paste-from-step-8>" `
    AZURE_STORAGE_CONTAINER=car-images

az webapp config set `
    --name carrental-app-UNIQUE `
    --resource-group car-rental-rg `
    --startup-file "node server.js"
```

### Step 12: Update Local .env
Update your `.env` file with the same values so `setup-db` can connect:
```
PORT=8080
DB_SERVER=carrental-sql-UNIQUE.database.windows.net
DB_NAME=carrentaldb
DB_USER=sqladmin
DB_PASSWORD=YourPassword123!
AZURE_STORAGE_CONNECTION_STRING=<paste-from-step-8>
AZURE_STORAGE_CONTAINER=car-images
```

### Step 13: Create Database Tables
```powershell
npm run setup-db
```
This creates the `cars` and `reservations` tables and inserts 10 starter cars.

### Step 14: Deploy Code
```powershell
# Zip the project
Compress-Archive -Path .\* -DestinationPath deploy.zip -Force

# Deploy
az webapp deploy `
    --name carrental-app-UNIQUE `
    --resource-group car-rental-rg `
    --src-path deploy.zip `
    --type zip

# Clean up
Remove-Item deploy.zip
```

### Step 15: Visit Your App
```
https://carrental-app-UNIQUE.azurewebsites.net
```

---

## 8. How the Code Works

### `db.js` — Azure SQL Connection
1. Creates a **connection pool** to Azure SQL Database using `mssql`
2. Pool is reused across all requests (efficient)
3. Exports a `query(sqlText, params)` function for parameterized queries
4. Connection config reads from environment variables
5. Uses `encrypt: true` (required by Azure SQL)

### `storage.js` — Blob Storage Helper
1. Creates a `BlobServiceClient` from the connection string
2. `initStorage()` — creates the blob container if it doesn't exist
3. `uploadImage(buffer, name, mime)` — uploads a file, returns its public URL
4. `deleteImage(url)` — deletes a blob by its URL
5. Blob names are prefixed with a timestamp to avoid collisions

### `setup-db.js` — Database Setup Script
1. Runs once via `npm run setup-db`
2. Creates `cars` table (id, brand, model, image_url, created_at)
3. Creates `reservations` table (id, car_id, customer_name, phone, dates)
4. Seeds 10 starter cars if the table is empty
5. Uses `IF NOT EXISTS` so it's safe to run multiple times

### `server.js` — Express Server
1. Loads environment variables from `.env`
2. Connects to Azure SQL Database and Azure Blob Storage
3. Sets up middleware: CORS, JSON parsing, rate limiting, static files
4. Multer middleware handles image file uploads (5MB max, images only)
5. API routes use parameterized queries (`@param` syntax) to prevent SQL injection
6. Cars API supports image upload via `multipart/form-data`
7. Deleting a car also deletes its image from Blob Storage

### `public/index.html` — User Page
1. Fetches all cars from `GET /api/cars`
2. Shows car images from Blob Storage URLs (or a placeholder emoji)
3. "Reserve" button opens a modal with a date form
4. Submits reservations to `POST /api/reservations`

### `public/admin.html` — Admin Page
1. "Add Car" form uses `FormData` for file upload (brand + model + image)
2. Submits to `POST /api/cars` with `multipart/form-data` encoding
3. Displays car image thumbnails in the management table
4. Delete/Cancel buttons call the respective `DELETE` endpoints

---

## 9. API Reference

### Cars

| Method | URL | Description | Body |
|--------|-----|-------------|------|
| `GET` | `/api/cars` | List all cars | — |
| `POST` | `/api/cars` | Add a car (with optional image) | `FormData: brand, model, image` |
| `DELETE` | `/api/cars/:id` | Delete a car + its image | — |

### Reservations

| Method | URL | Description | Body |
|--------|-----|-------------|------|
| `GET` | `/api/reservations` | List all with car details | — |
| `POST` | `/api/reservations` | Create reservation | `JSON: { car_id, customer_name, phone, start_date, end_date }` |
| `DELETE` | `/api/reservations/:id` | Cancel reservation | — |

### Test with PowerShell

```powershell
# List cars
Invoke-RestMethod http://localhost:8080/api/cars

# Add a car (without image)
Invoke-RestMethod -Uri http://localhost:8080/api/cars `
  -Method POST `
  -ContentType "application/json" `
  -Body '{"brand":"Audi","model":"A3"}'

# Make a reservation
Invoke-RestMethod -Uri http://localhost:8080/api/reservations `
  -Method POST `
  -ContentType "application/json" `
  -Body '{"car_id":1,"customer_name":"Alice","phone":"+33600000000","start_date":"2026-05-01","end_date":"2026-05-05"}'
```

---

## 10. Estimated Costs

This project uses the **cheapest possible Azure services** for learning.

| Resource | Tier | Monthly Cost | Notes |
|----------|------|-------------|-------|
| App Service Plan | B1 Linux | ~$13/month | Cheapest always-on tier |
| SQL Database | Basic (5 DTU) | ~$5/month | 2GB storage included |
| Blob Storage | Standard_LRS | ~$0.02/month | Pay only for stored images |
| **Total** | | **~$18/month** | |

> **Important:** Delete everything when you're done learning to avoid charges. See [Clean Up](#12-clean-up-delete-everything).

> **Free tier alternative:** You can use App Service F1 (free) but it has limitations (no always-on, 60 min CPU/day, no custom domain).

---

## 11. Troubleshooting

### "Cannot connect to SQL Database"
- Check `DB_SERVER`, `DB_USER`, `DB_PASSWORD` in `.env`
- Make sure firewall rules allow your IP: `az sql server firewall-rule list --server YOUR-SERVER --resource-group car-rental-rg`
- Azure SQL requires `encrypt: true` in the connection (already configured in `db.js`)

### "Storage container not found"
- Check `AZURE_STORAGE_CONNECTION_STRING` in `.env`
- Run the app once — `initStorage()` creates the container automatically
- Verify the container name matches `AZURE_STORAGE_CONTAINER`

### "Image upload fails"
- Max file size is 5MB
- Only JPEG, PNG, GIF, and WebP are allowed
- Check that Blob Storage has public blob access enabled

### "Application Error" on Azure
1. Check logs:
   ```powershell
   az webapp log tail --name YOUR-APP --resource-group car-rental-rg
   ```
2. Verify all environment variables are set:
   ```powershell
   az webapp config appsettings list --name YOUR-APP --resource-group car-rental-rg
   ```
3. Make sure startup is set to `node server.js`

### "Azure subscription is Disabled"
1. Go to https://portal.azure.com
2. Search for "Subscriptions"
3. Click on your subscription
4. Click "Reactivate" or check billing

### "Azure CLI not installed"
- Windows: `winget install Microsoft.AzureCLI`
- Or download from: https://learn.microsoft.com/en-us/cli/azure/install-azure-cli-windows
- After installing, **restart your terminal**

### "setup-db fails"
- Make sure `.env` has the correct Azure SQL credentials
- Make sure the SQL firewall allows your current IP
- Try: `az sql server firewall-rule create --server YOUR-SERVER --resource-group car-rental-rg --name AllowMe --start-ip-address YOUR-IP --end-ip-address YOUR-IP`

### Port issues locally
The app defaults to port 8080. Change it in `.env` if needed:
```
PORT=3000
```

---

## 12. Clean Up (Delete Everything)

When you're done learning, **delete all Azure resources** to stop charges:

```powershell
az group delete --name car-rental-rg --yes --no-wait
```

This deletes the resource group and **everything inside it** (SQL server, storage, app service).

---

## 13. What to Learn Next

### Easy Improvements
- [ ] Add **price per day** to cars and show total cost
- [ ] Add a **search/filter** by brand on the user page
- [ ] Add more detailed **form validation messages**
- [ ] Add **car availability status** (available/rented)

### Medium Improvements
- [ ] Add **user authentication** (login/register)
- [ ] Protect the admin page with a password
- [ ] Add **date conflict detection** (prevent double-booking)
- [ ] Add **pagination** for large car lists
- [ ] Add **image resizing** before upload

### Advanced Improvements
- [ ] Replace frontend with **React or Vue**
- [ ] Add **CI/CD with GitHub Actions** (auto-deploy on push)
- [ ] Add **Azure Application Insights** for monitoring
- [ ] Add **Azure Key Vault** for storing secrets
- [ ] Add **unit tests** with Jest
- [ ] Add **custom domain + SSL certificate**

---

## Quick Commands Reference

```powershell
# Install dependencies
npm install

# Set up database tables (run once after deployment)
npm run setup-db

# Start the server locally
npm start

# Deploy everything to Azure (one command)
.\deploy.ps1

# Check Azure app logs
az webapp log tail --name YOUR-APP --resource-group car-rental-rg

# Restart the Azure app
az webapp restart --name YOUR-APP --resource-group car-rental-rg

# Delete ALL Azure resources (stop charges)
az group delete --name car-rental-rg --yes
```

---

**Built for learning purposes. Have fun coding!**
