import "dotenv/config";
import Database from "better-sqlite3";
import { betterAuth } from "better-auth";
import { bearer, emailOTP } from "better-auth/plugins";
import { Pool } from "pg";
import { Resend } from "resend";

const resendKey = process.env.RESEND_API_KEY;
const from = process.env.RESEND_FROM;

if (!resendKey || !from) {
  throw new Error("RESEND_API_KEY and RESEND_FROM are required.");
}

const database = process.env.DATABASE_URL
  ? new Pool({
      connectionString: process.env.DATABASE_URL,
      ssl: process.env.DATABASE_SSL === "true"
        ? { rejectUnauthorized: false }
        : undefined
    })
  : new Database(process.env.SQLITE_PATH || "./auth.sqlite");

const resend = new Resend(resendKey);

if (!process.env.BETTER_AUTH_SECRET) {
  throw new Error("BETTER_AUTH_SECRET is required.");
}

export const auth = betterAuth({
  appName: "Chore Tracker",
  database,
  baseURL: process.env.BETTER_AUTH_URL || "http://127.0.0.1:3000",
  basePath: "/api/auth",
  secret: process.env.BETTER_AUTH_SECRET,
  trustedOrigins: (process.env.BETTER_AUTH_TRUSTED_ORIGINS || "")
    .split(",")
    .map((value) => value.trim())
    .filter(Boolean),
  session: {
    expiresIn: 60 * 60 * 24 * 30,
    updateAge: 60 * 60 * 24
  },
  user: {
    deleteUser: {
      enabled: true
    }
  },
  rateLimit: {
    enabled: true,
    window: 60,
    max: 60
  },
  advanced: {
    ipAddress: {
      ipAddressHeaders: ["cf-connecting-ip"]
    },
    database: {
      joins: true
    }
  },
  plugins: [
    bearer({
      requireSignature: true
    }),
    emailOTP({
      otpLength: 6,
      expiresIn: 10 * 60,
      allowedAttempts: 5,
      storeOTP: "hashed",
      async sendVerificationOTP({ email, otp, type }) {
        if (type !== "sign-in") return;

        const { error } = await resend.emails.send({
          from,
          to: email,
          subject: "Your Chore Tracker sign-in code",
          text: `Your verification code is ${otp}. It expires in 10 minutes.`,
          html: `
            <div style="font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;max-width:520px;margin:auto;padding:32px">
              <div style="font-size:36px;margin-bottom:12px">🏠</div>
              <h1 style="font-size:24px;margin:0 0 12px">Your sign-in code</h1>
              <p style="color:#555">Enter this code in the app:</p>
              <div style="font-size:36px;font-weight:700;letter-spacing:8px;margin:28px 0">${otp}</div>
              <p style="color:#777;font-size:14px">This code expires in 10 minutes. If you didn't request it, you can ignore this email.</p>
            </div>
          `
        });

        if (error) {
          console.error("Resend failed to send OTP", error);
          throw new Error("Unable to send verification email.");
        }
      }
    })
  ]
});
