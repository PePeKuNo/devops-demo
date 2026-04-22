import React, { useEffect, useState } from 'react';
import { HashRouter, Link, Route, Routes } from 'react-router-dom';

function Home() {
  return <h2>Strona Glowna Dashboardu</h2>;
}

function Products() {
  const [products, setProducts] = useState([]);
  const [name, setName] = useState('');

  const fetchProducts = () => {
    fetch('/api/items')
      .then((res) => res.json())
      .then((data) => setProducts(data));
  };

  useEffect(() => {
    fetchProducts();
  }, []);

  const addProduct = (event) => {
    event.preventDefault();
    fetch('/api/items', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ name })
    }).then(() => {
      setName('');
      fetchProducts();
    });
  };

  return (
    <div>
      <h2>Produkty</h2>
      <ul>{products.map((product) => <li key={product.id}>{product.name}</li>)}</ul>
      <form onSubmit={addProduct}>
        <input value={name} onChange={(event) => setName(event.target.value)} required placeholder="Podaj nazwe" />
        <button type="submit">Dodaj</button>
      </form>
    </div>
  );
}

function formatUptime(seconds) {
  if (seconds == null) {
    return 'brak danych';
  }

  return `${Number(seconds).toFixed(3)} s`;
}

function formatDate(value) {
  if (!value) {
    return 'brak danych';
  }

  return new Date(value).toLocaleString();
}

function Stats() {
  const [stats, setStats] = useState({});

  useEffect(() => {
    fetch('/api/stats')
      .then((res) => res.json())
      .then((data) => setStats(data));
  }, []);

  return (
    <div>
      <h2>Statystyki</h2>
      <p>Calkowita liczba produktow: {stats.totalProducts ?? 'brak danych'}</p>
      <p>ID instancji backendu: {stats.backendInstanceId ?? 'brak danych'}</p>
      <p>Czas pracy serwera: {formatUptime(stats.uptimeSeconds)}</p>
      <p>Liczba obsluzonych zadan: {stats.requestCount ?? 'brak danych'}</p>
      <p>Aktualny czas serwera: {formatDate(stats.serverTime)}</p>
    </div>
  );
}

export default function App() {
  return (
    <HashRouter>
      <nav>
        <Link to="/">Glowna</Link> | <Link to="/products">Produkty</Link> | <Link to="/stats">Statystyki</Link>
      </nav>
      <hr />
      <Routes>
        <Route path="/" element={<Home />} />
        <Route path="/products" element={<Products />} />
        <Route path="/stats" element={<Stats />} />
      </Routes>
    </HashRouter>
  );
}
