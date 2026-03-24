const express = require('express'); // Używam Expressa do zbudowania API
const os = require('os'); // Odczytuję hostname kontenera przez moduł OS
const app = express();

// Parsuję dane JSON z ciała żądania
app.use(express.json());

// Przechowuję listę produktów w pamięci RAM
let products = [
  { id: 1, name: 'Laptop' },
  { id: 2, name: 'Smartfon' }
];

// Zwracam pełną listę produktów
app.get('/items', (req, res) => {
  res.json(products);
});

// Dodaję nowy produkt do tablicy
app.post('/items', (req, res) => {
  const newProduct = {
    id: products.length + 1, // Nadaję kolejne ID na podstawie długości tablicy
    name: req.body.name || 'Nowy produkt' // Biorę nazwę z żądania albo ustawiam wartość domyślną
  };

  products.push(newProduct); // Zapisuję produkt w tablicy
  res.status(201).json(newProduct); // Odsyłam utworzony obiekt z kodem 201
});

// Zwracam statystyki wymagane w projekcie
app.get('/stats', (req, res) => {
  res.json({
    totalProducts: products.length,
    // W Dockerze hostname zwykle odpowiada identyfikatorowi kontenera
    backendInstanceId: process.env.INSTANCE_ID || os.hostname()
  });
});

// Uruchamiam serwer na porcie 3000
app.listen(3000, () => {
  console.log('Backend działa na porcie 3000');
});
