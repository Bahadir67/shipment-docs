const crypto = require("crypto");

const users = [];
const sessions = new Map();
const viewLogs = [];

function hashPassword(password, salt = crypto.randomBytes(16).toString("hex")) {
  const hash = crypto.pbkdf2Sync(password, salt, 100000, 64, "sha512").toString("hex");
  return { salt, hash };
}

function verifyPassword(user, password) {
  const { hash } = hashPassword(password, user.salt);
  return crypto.timingSafeEqual(Buffer.from(hash, "hex"), Buffer.from(user.hash, "hex"));
}

function createUser({ username, password, role = "user", email }) {
  const { salt, hash } = hashPassword(password);
  const id = crypto.randomUUID();
  const user = { id, username, role, email: email || null, salt, hash };
  users.push(user);
  return user;
}

function findUserByUsername(username) {
  return users.find((user) => user.username === username);
}

function createSession(user) {
  const token = crypto.randomBytes(24).toString("hex");
  sessions.set(token, user.id);
  return token;
}

function getUserByToken(token) {
  const userId = sessions.get(token);
  if (!userId) return null;
  return users.find((user) => user.id === userId) || null;
}

function resetPassword(userId, password) {
  const user = users.find((entry) => entry.id === userId);
  if (!user) return null;
  const { salt, hash } = hashPassword(password);
  user.salt = salt;
  user.hash = hash;
  return user;
}

function addViewLog({ userId, productId, fileId, action }) {
  const entry = {
    id: crypto.randomUUID(),
    userId,
    productId,
    fileId,
    action,
    createdAt: new Date().toISOString()
  };
  viewLogs.push(entry);
  return entry;
}

function listViewLogs() {
  return viewLogs.slice().reverse();
}

module.exports = {
  users,
  createUser,
  findUserByUsername,
  verifyPassword,
  createSession,
  getUserByToken,
  resetPassword,
  addViewLog,
  listViewLogs
};
