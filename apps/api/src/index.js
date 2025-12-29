const express = require("express");
const cors = require("cors");
require("dotenv").config();

const {
  createUser,
  findUserByUsername,
  verifyPassword,
  createSession,
  getUserByToken,
  resetPassword,
  addViewLog,
  listViewLogs
} = require("./store");
const { sendAdminNotice } = require("./mailer");

const app = express();
app.use(cors());
app.use(express.json({ limit: "10mb" }));

function requireAuth(req, res, next) {
  const header = req.headers.authorization || "";
  const token = header.startsWith("Bearer ") ? header.slice(7) : null;
  if (!token) return res.status(401).json({ error: "missing_token" });
  const user = getUserByToken(token);
  if (!user) return res.status(401).json({ error: "invalid_token" });
  req.user = user;
  return next();
}

function requireAdmin(req, res, next) {
  if (!req.user || req.user.role !== "admin") {
    return res.status(403).json({ error: "admin_only" });
  }
  return next();
}

app.get("/health", (req, res) => {
  res.json({
    status: "ok",
    env: process.env.APP_ENV || "development",
    time: new Date().toISOString()
  });
});

app.post("/auth/login", (req, res) => {
  const { username, password } = req.body || {};
  if (!username || !password) return res.status(400).json({ error: "missing_credentials" });
  const user = findUserByUsername(username);
  if (!user || !verifyPassword(user, password)) {
    return res.status(401).json({ error: "invalid_credentials" });
  }
  const token = createSession(user);
  return res.json({
    token,
    user: { id: user.id, username: user.username, role: user.role }
  });
});

app.get("/auth/me", requireAuth, (req, res) => {
  const { id, username, role } = req.user;
  res.json({ id, username, role });
});

app.post("/auth/users", requireAuth, requireAdmin, (req, res) => {
  const { username, password, role, email } = req.body || {};
  if (!username || !password) return res.status(400).json({ error: "missing_fields" });
  if (findUserByUsername(username)) return res.status(409).json({ error: "user_exists" });
  const user = createUser({ username, password, role, email });
  res.status(201).json({ id: user.id, username: user.username, role: user.role });
});

app.post("/auth/users/:id/reset-password", requireAuth, requireAdmin, (req, res) => {
  const { password } = req.body || {};
  if (!password) return res.status(400).json({ error: "missing_password" });
  const user = resetPassword(req.params.id, password);
  if (!user) return res.status(404).json({ error: "user_not_found" });
  res.json({ id: user.id, username: user.username });
});

app.get("/products/:id/files/:fileId/view", requireAuth, async (req, res) => {
  const { id: productId, fileId } = req.params;
  const entry = addViewLog({
    userId: req.user.id,
    productId,
    fileId,
    action: "view"
  });
  const subject = `File viewed: ${fileId}`;
  const text = `User ${req.user.username} viewed file ${fileId} for product ${productId} at ${entry.createdAt}`;
  try {
    await sendAdminNotice({ subject, text });
  } catch (error) {
    console.warn("Failed to send admin notice", error.message);
  }
  res.json({ status: "logged", logId: entry.id });
});

app.get("/products/:id/files/:fileId/download", requireAuth, requireAdmin, (req, res) => {
  res.status(501).json({ error: "not_implemented" });
});

app.get("/admin/view-logs", requireAuth, requireAdmin, (req, res) => {
  res.json({ data: listViewLogs() });
});

function seedAdmin() {
  const username = process.env.ADMIN_USERNAME;
  const password = process.env.ADMIN_PASSWORD;
  if (!username || !password) return;
  if (findUserByUsername(username)) return;
  createUser({
    username,
    password,
    role: "admin",
    email: process.env.ADMIN_EMAIL || null
  });
}

seedAdmin();

const port = process.env.PORT || 3000;
app.listen(port, () => {
  console.log(`API listening on http://localhost:${port}`);
});
