const express = require("express");
const path = require("path");

const app = express();
const PORT = process.env.PORT || 8080;

app.use(express.json());
app.use(express.static(path.join(__dirname, "public")));

// In-memory store (demo kosam). Real project lo database use cheyyali.
let books = [
  { id: 1, title: "Clean Code", author: "Robert C. Martin" },
  { id: 2, title: "The Pragmatic Programmer", author: "Andrew Hunt" },
];
let nextId = 3;

// Health check (App Service + pipeline smoke test kosam)
app.get("/health", (req, res) => res.status(200).json({ status: "healthy" }));

// Environment info. Secret value ni expose cheyyam, set ayyindo ledo matrame chupistham.
app.get("/api/info", (req, res) => {
  res.json({
    environment: process.env.APP_ENV || "local",
    version: process.env.APP_VERSION || "dev",
    keyVaultSecretLoaded: Boolean(process.env.APP_SECRET),
  });
});

app.get("/api/books", (req, res) => res.json(books));

app.post("/api/books", (req, res) => {
  const { title, author } = req.body || {};
  if (!title || !author) {
    return res.status(400).json({ error: "title and author are required" });
  }
  const book = { id: nextId++, title, author };
  books.push(book);
  res.status(201).json(book);
});

app.delete("/api/books/:id", (req, res) => {
  const id = Number(req.params.id);
  const before = books.length;
  books = books.filter((b) => b.id !== id);
  if (books.length === before) return res.status(404).json({ error: "not found" });
  res.status(204).end();
});

app.listen(PORT, () => console.log(`Book Library running on port ${PORT}`));
