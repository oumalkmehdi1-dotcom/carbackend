// server.js
import express from 'express';
import cors from 'cors';

const app = express();
const port = process.env.PORT || 3000;

// Activer CORS pour le front-end
app.use(cors());
app.use(express.json());

// Données simulées pour les voitures
const cars = [
  { brand: "Toyota", models: ["Corolla", "Yaris", "Land Cruiser", "Rav4"] },
  { brand: "Renault", models: ["Clio", "Megane", "Captur", "Duster"] },
  { brand: "Peugeot", models: ["208", "308", "3008", "5008"] },
  { brand: "Ford", models: ["Fiesta", "Focus", "Mustang", "Explorer"] },
  { brand: "Hyundai", models: ["i10", "i20", "Tucson", "Santa Fe"] },
  { brand: "Mercedes-Benz", models: ["Classe A", "Classe C", "GLC", "GLE"] },
  { brand: "BMW", models: ["Série 1", "Série 3", "X3", "X5"] },
  { brand: "Nissan", models: ["Micra", "Qashqai", "X-Trail", "Patrol"] },
  { brand: "Kia", models: ["Picanto", "Rio", "Sportage", "Sorento"] },
  { brand: "Volkswagen", models: ["Polo", "Golf", "Tiguan", "Passat"] }
];

// GET /api/cars → toutes les marques
app.get('/api/cars', (req, res) => {
  res.json(cars);
});

// GET /api/cars/:brand → marque spécifique
app.get('/api/cars/:brand', (req, res) => {
  const brandName = req.params.brand.toLowerCase();
  const car = cars.find(c => c.brand.toLowerCase() === brandName);
  if (car) {
    res.json(car);
  } else {
    res.status(404).json({ message: "Marque non trouvée" });
  }
});

app.listen(port, () => {
  console.log(`Server running on port ${port}`);
});
