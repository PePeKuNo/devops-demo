import React, { useState, useEffect } from 'react';
import { BrowserRouter, Routes, Route, Link } from 'react-router-dom';

// Trzymam stronę główną jako osobny widok
function Home() {
  return <h2>Strona Główna Dashboardu</h2>;
}

// Trzymam listę produktów na osobnej podstronie
function Products() {
  const [products, setProducts] = useState([]); // Przechowuję aktualną listę produktów
  const [name, setName] = useState(''); // Przechowuję bieżącą wartość pola formularza

  // Pobieram produkty przez proxy w Nginx
  const fetchProducts = () => {
    // Dzięki temu omijam problem CORS między frontendem a backendem
    fetch('/api/items')
      .then(res => res.json())
      .then(data => setProducts(data));
  };

  // Ładuję dane raz po wejściu na stronę
  useEffect(() => { fetchProducts(); }, []);

  // Wysyłam nowy produkt do backendu
  const addProduct = (e) => {
    e.preventDefault(); // Zatrzymuję domyślne przeładowanie formularza
    fetch('/api/items', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ name }) // Przekazuję wpisaną nazwę w formacie JSON
    }).then(() => {
      setName(''); // Czyszczę pole po udanym zapisie
      fetchProducts(); // Odświeżam listę od razu po dodaniu produktu
    });
  };

  return (
    <div>
      <h2>Produkty</h2>
      <ul>{products.map(p => <li key={p.id}>{p.name}</li>)}</ul>
      <form onSubmit={addProduct}>
        <input value={name} onChange={e => setName(e.target.value)} required placeholder="Podaj nazwę" />
        <button type="submit">Dodaj</button>
      </form>
    </div>
  );
}

// Trzymam statystyki na osobnej podstronie
function Stats() {
  const [stats, setStats] = useState({});

  useEffect(() => {
    // Pobieram statystyki przez ścieżkę, na której Nginx ma cache
    fetch('/api/stats')
      .then(res => res.json())
      .then(data => setStats(data));
  }, []);

  return (
    <div>
      <h2>Statystyki</h2>
      <p>Całkowita liczba produktów: {stats.totalProducts}</p>
      {/* Pokazuję ID instancji backendu, która obsłużyła żądanie */}
      <p>ID instancji backendu: {stats.backendInstanceId}</p>
    </div>
  );
}

// Zarządzam tutaj routingiem po stronie klienta
export default function App() {
  return (
    <BrowserRouter>
      <nav>
        <Link to="/">Główna</Link> | <Link to="/products">Produkty</Link> | <Link to="/stats">Statystyki</Link>
      </nav>
      <hr />
      <Routes>
        {/* Przypisuję adres URL do odpowiedniego komponentu React */}
        <Route path="/" element={<Home />} />
        <Route path="/products" element={<Products />} />
        <Route path="/stats" element={<Stats />} />
      </Routes>
    </BrowserRouter>
  );
}
