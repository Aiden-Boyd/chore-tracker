import "dotenv/config";
import express from "express";
import { toNodeHandler } from "better-auth/node";
import { auth } from "./auth.js";

const app = express();
const port = Number(process.env.PORT || 3000);

app.disable("x-powered-by");
app.use((_req, res, next) => {
  res.setHeader("X-Content-Type-Options", "nosniff");
  res.setHeader("Referrer-Policy", "no-referrer");
  res.setHeader("Cache-Control", "no-store");
  next();
});

// Better Auth must receive the raw request before express.json() consumes it.
app.all("/api/auth/*splat", toNodeHandler(auth));

app.use(express.json({ limit: "16kb" }));

app.get("/health", (_req, res) => {
  res.json({
    ok: true,
    auth: "better-auth",
    database: process.env.DATABASE_URL ? "postgres" : "sqlite"
  });
});

app.listen(port, "0.0.0.0", () => {
  console.log(`Chore Tracker auth API listening on :${port}`);
});
