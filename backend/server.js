import crypto from "node:crypto";
import express from "express";
import { Resend } from "resend";
import { SignJWT } from "jose";

const app = express();
app.use(express.json({ limit: "16kb" }));

const port = Number(process.env.PORT || 3000);
const resendKey = process.env.RESEND_API_KEY;
const from = process.env.RESEND_FROM;
const jwtSecret = process.env.JWT_SECRET;

if (!resendKey || !from || !jwtSecret) {
  throw new Error("RESEND_API_KEY, RESEND_FROM, and JWT_SECRET are required.");
}

const resend = new Resend(resendKey);
const secret = new TextEncoder().encode(jwtSecret);

// For one small VPS process this is enough to launch/test.
// Move codes + rate limits to Redis/Postgres before scaling horizontally.
const pendingCodes = new Map();
const requests = new Map();

function normalizeEmail(value) {
  return String(value || "").trim().toLowerCase();
}

function isEmail(value) {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value);
}

function codeHash(email, code) {
  return crypto
    .createHmac("sha256", jwtSecret)
    .update(email + ":" + code)
    .digest("hex");
}

function rateLimited(email) {
  const now = Date.now();
  const previous = requests.get(email) || [];
  const recent = previous.filter((time) => now - time < 15 * 60 * 1000);

  if (recent.length >= 5) return true;

  recent.push(now);
  requests.set(email, recent);
  return false;
}

app.get("/health", (_req, res) => {
  res.json({ ok: true });
});

app.post("/auth/request-code", async (req, res) => {
  const email = normalizeEmail(req.body?.email);

  if (!isEmail(email)) {
    return res.status(400).json({ error: "Enter a valid email address." });
  }

  if (rateLimited(email)) {
    return res.status(429).json({ error: "Too many codes requested. Try again later." });
  }

  const code = String(crypto.randomInt(0, 1_000_000)).padStart(6, "0");

  pendingCodes.set(email, {
    hash: codeHash(email, code),
    expiresAt: Date.now() + 10 * 60 * 1000,
    attemptsLeft: 5
  });

  const { error } = await resend.emails.send({
    from,
    to: email,
    subject: "Your Chore Tracker sign-in code",
    text: `Your Chore Tracker verification code is ${code}. It expires in 10 minutes.`,
    html: `
      <div style="font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;max-width:520px;margin:auto;padding:32px">
        <div style="font-size:36px;margin-bottom:12px">🏠</div>
        <h1 style="font-size:24px;margin:0 0 12px">Your sign-in code</h1>
        <p style="color:#555">Enter this code in Chore Tracker:</p>
        <div style="font-size:36px;font-weight:700;letter-spacing:8px;margin:28px 0">${code}</div>
        <p style="color:#777;font-size:14px">This code expires in 10 minutes. If you didn't request it, you can ignore this email.</p>
      </div>
    `
  });

  if (error) {
    pendingCodes.delete(email);
    console.error(error);
    return res.status(502).json({ error: "We couldn't send the email. Try again." });
  }

  return res.json({ ok: true });
});

app.post("/auth/verify-code", async (req, res) => {
  const email = normalizeEmail(req.body?.email);
  const code = String(req.body?.code || "").trim();
  const pending = pendingCodes.get(email);

  if (!pending) {
    return res.status(400).json({ error: "Request a new verification code." });
  }

  if (Date.now() > pending.expiresAt) {
    pendingCodes.delete(email);
    return res.status(400).json({ error: "That code expired. Request a new one." });
  }

  if (pending.attemptsLeft <= 0) {
    pendingCodes.delete(email);
    return res.status(429).json({ error: "Too many attempts. Request a new code." });
  }

  pending.attemptsLeft -= 1;

  const actual = Buffer.from(pending.hash, "hex");
  const supplied = Buffer.from(codeHash(email, code), "hex");
  const matches = actual.length === supplied.length &&
    crypto.timingSafeEqual(actual, supplied);

  if (!matches) {
    return res.status(400).json({ error: "That verification code is not correct." });
  }

  pendingCodes.delete(email);

  const token = await new SignJWT({ email })
    .setProtectedHeader({ alg: "HS256" })
    .setSubject(email)
    .setIssuedAt()
    .setExpirationTime("30d")
    .sign(secret);

  return res.json({ token });
});

app.listen(port, "0.0.0.0", () => {
  console.log(`Chore Tracker auth API listening on :${port}`);
});
