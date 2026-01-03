const express = require("express");
const cors = require("cors");
const crypto = require("crypto");
const sharp = require("sharp");
require("dotenv").config();

const prisma = require("./db/prisma");
const { sendAdminNotice } = require("./mailer");
const {
  getConfig,
  createProductFolder,
  uploadBase64,
  createShareLink,
  getItem
} = require("./graph");
const {
  createGDriveProductFolder,
  uploadGDriveFile,
  uploadGDriveThumbnail,
  downloadGDriveFile
} = require("./gdrive");
const multer = require("multer");
const mime = require("mime-types");
const {
  getStorageConfig,
  createLocalProductFolders,
  saveBufferToFile,
  saveThumbnailToFile,
  getFileStream
} = require("./storage");

const app = express();
// Allow all origins for demo purposes
app.use(cors({ origin: "*" }));
app.use(express.json({ limit: "10mb" }));
const upload = multer({ storage: multer.memoryStorage() });

const sessionTtlDays = Number(process.env.SESSION_TTL_DAYS || "30");

function hashPassword(password, salt = crypto.randomBytes(16).toString("hex")) {
  const hash = crypto.pbkdf2Sync(password, salt, 100000, 64, "sha512").toString("hex");
  return { salt, hash };
}

function verifyPassword(user, password) {
  const { hash } = hashPassword(password, user.passwordSalt);
  return crypto.timingSafeEqual(Buffer.from(hash, "hex"), Buffer.from(user.passwordHash, "hex"));
}

function getSessionExpiry() {
  const expiresAt = new Date();
  expiresAt.setDate(expiresAt.getDate() + sessionTtlDays);
  return expiresAt;
}

async function createSession(userId) {
  await prisma.session.deleteMany({
    where: {
      OR: [{ userId }, { expiresAt: { lt: new Date() } }]
    }
  });
  const token = crypto.randomBytes(24).toString("hex");
  await prisma.session.create({
    data: {
      token,
      userId,
      expiresAt: getSessionExpiry()
    }
  });
  return token;
}

async function requireAuth(req, res, next) {
  const header = req.headers.authorization || "";
  const token = header.startsWith("Bearer ") ? header.slice(7) : null;
  if (!token) return res.status(401).json({ error: "missing_token" });
  try {
    const session = await prisma.session.findUnique({
      where: { token },
      include: { user: true }
    });
    if (!session) return res.status(401).json({ error: "invalid_token" });
    if (session.expiresAt && session.expiresAt < new Date()) {
      await prisma.session.delete({ where: { token } }).catch(() => {});
      return res.status(401).json({ error: "token_expired" });
    }
    if (!session.user) return res.status(401).json({ error: "invalid_user" });
    req.user = session.user;
    return next();
  } catch (error) {
    console.error("Auth lookup failed", error.message);
    return res.status(500).json({ error: "auth_error" });
  }
}

function requireAdmin(req, res, next) {
  if (!req.user || req.user.role !== "admin") {
    return res.status(403).json({ error: "admin_only" });
  }
  return next();
}

async function createThumbnailBuffer(buffer) {
  return sharp(buffer)
    .rotate()
    .resize(256, 256, { fit: "cover" })
    .jpeg({ quality: 72 })
    .toBuffer();
}

app.get("/health", (req, res) => {
  res.json({
    status: "ok",
    env: process.env.APP_ENV || "development",
    time: new Date().toISOString()
  });
});

app.post("/auth/login", async (req, res) => {
  const { username, password } = req.body || {};
  if (!username || !password) return res.status(400).json({ error: "missing_credentials" });
  try {
    const user = await prisma.user.findUnique({ where: { username } });
    if (!user || !verifyPassword(user, password)) {
      return res.status(401).json({ error: "invalid_credentials" });
    }
    const token = await createSession(user.id);
    return res.json({
      token,
      user: { id: user.id, username: user.username, role: user.role }
    });
  } catch (error) {
    console.error("Login failed", error.message);
    return res.status(500).json({ error: "login_failed" });
  }
});

app.get("/auth/me", requireAuth, (req, res) => {
  const { id, username, role } = req.user;
  res.json({ id, username, role });
});

app.get("/auth/users", requireAuth, requireAdmin, async (req, res) => {
  try {
    const users = await prisma.user.findMany({
      select: { id: true, username: true, role: true, email: true }
    });
    return res.json({ data: users });
  } catch (error) {
    console.error("User list failed", error.message);
    return res.status(500).json({ error: "list_failed" });
  }
});

app.post("/auth/users", requireAuth, requireAdmin, async (req, res) => {
  const { username, password, role, email } = req.body || {};
  if (!username || !password) return res.status(400).json({ error: "missing_fields" });
  try {
    const existing = await prisma.user.findUnique({ where: { username } });
    if (existing) return res.status(409).json({ error: "user_exists" });
    const { salt, hash } = hashPassword(password);
    const user = await prisma.user.create({
      data: {
        username,
        email: email || null,
        role: role || "user",
        passwordHash: hash,
        passwordSalt: salt
      }
    });
    return res.status(201).json({ id: user.id, username: user.username, role: user.role });
  } catch (error) {
    console.error("User create failed", error.message);
    return res.status(500).json({ error: "user_create_failed" });
  }
});

app.post("/auth/users/:id/reset-password", requireAuth, requireAdmin, async (req, res) => {
  const { password } = req.body || {};
  if (!password) return res.status(400).json({ error: "missing_password" });
  const { salt, hash } = hashPassword(password);
  try {
    const user = await prisma.user.update({
      where: { id: req.params.id },
      data: {
        passwordHash: hash,
        passwordSalt: salt
      }
    });
    return res.json({ id: user.id, username: user.username });
  } catch (error) {
    if (error.code === "P2025") {
      return res.status(404).json({ error: "user_not_found" });
    }
    console.error("Password reset failed", error.message);
    return res.status(500).json({ error: "reset_failed" });
  }
});

app.post("/products", requireAuth, async (req, res) => {
  const { serial, customer, project, productType, year } = req.body || {};
  if (!serial || !customer || !project) {
    return res.status(400).json({ error: "missing_fields" });
  }
  const parsedYear = Number(year) || new Date().getFullYear();
  try {
    const existing = await prisma.product.findUnique({ where: { serial } });
    if (existing) return res.status(409).json({ error: "serial_exists" });
    let storagePath = null;
    const storage = getStorageConfig();
    if (storage.mode === "local") {
      storagePath = createLocalProductFolders({
        year: parsedYear,
        customer,
        project,
        serial
      });
    }
    if (storage.mode === "gdrive") {
      const result = await createGDriveProductFolder({
        year: parsedYear,
        customer,
        project,
        serial
      });
      storagePath = result.productFolderId;
    }
    const product = await prisma.product.create({
      data: {
        serial,
        customer,
        project,
        productType: productType || null,
        year: parsedYear,
        status: "open",
        onedriveFolder: storagePath
      }
    });

    // Initialize default checklist for demo
    const defaultItems = [
      { category: "Visual", itemKey: "visual_inspection", label: "Gorsel Kontrol" },
      { category: "Mechanical", itemKey: "oil_level_check", label: "Yag Seviyesi Kontrolu" },
      { category: "Test", itemKey: "pressure_test", label: "Basinc Testi Tamam" },
      { category: "Electrical", itemKey: "wiring_check", label: "Kablolama Kontrolu" },
      { category: "Final", itemKey: "labels_attached", label: "Etiketler Takildi" },
      { category: "Final", itemKey: "cleaning", label: "Son Temizlik" }
    ];

    await Promise.all(
      defaultItems.map((item) =>
        prisma.checklistItem.create({
          data: {
            productId: product.id,
            category: item.category,
            itemKey: item.itemKey,
            completed: false
          }
        })
      )
    );

    return res.status(201).json(product);
  } catch (error) {
    console.error("Product create failed", error.message);
    return res.status(500).json({ error: "product_create_failed" });
  }
});

app.get("/products/:id/checklist", requireAuth, async (req, res) => {
  try {
    const items = await prisma.checklistItem.findMany({
      where: { productId: req.params.id },
      orderBy: { category: "asc" }
    });
    return res.json({ data: items });
  } catch (error) {
    return res.status(500).json({ error: "checklist_fetch_failed" });
  }
});

app.post("/products/:id/checklist", requireAuth, async (req, res) => {
  const { itemKey, completed } = req.body || {};
  if (!itemKey) return res.status(400).json({ error: "missing_item_key" });
  try {
    const updated = await prisma.checklistItem.update({
      where: {
        productId_category_itemKey: {
          productId: req.params.id,
          category: req.body.category, // Assuming category is passed or found
          itemKey
        }
      },
      data: {
        completed: !!completed,
        updatedAt: new Date()
      }
    });
    return res.json(updated);
  } catch (error) {
    // If specific unique constraint update fails, try finding by productId and itemKey only
    try {
        const item = await prisma.checklistItem.findFirst({
            where: { productId: req.params.id, itemKey }
        });
        if (item) {
            const updated = await prisma.checklistItem.update({
                where: { id: item.id },
                data: { completed: !!completed, updatedAt: new Date() }
            });
            return res.json(updated);
        }
    } catch (e) {}
    console.error("Checklist update failed", error.message);
    return res.status(500).json({ error: "checklist_update_failed" });
  }
});

app.get("/products/:id/files", requireAuth, async (req, res) => {
  try {
    const files = await prisma.file.findMany({
      where: { productId: req.params.id },
      orderBy: { createdAt: "desc" }
    });
    return res.json({ data: files });
  } catch (error) {
    return res.status(500).json({ error: "files_fetch_failed" });
  }
});

app.get("/products/:id", requireAuth, async (req, res) => {
  try {
    const product = await prisma.product.findUnique({ where: { id: req.params.id } });
    if (!product) return res.status(404).json({ error: "product_not_found" });
    return res.json(product);
  } catch (error) {
    console.error("Product fetch failed", error.message);
    return res.status(500).json({ error: "product_fetch_failed" });
  }
});

app.get("/products", requireAuth, async (req, res) => {
  try {
    const products = await prisma.product.findMany({ orderBy: { createdAt: "desc" } });
    return res.json({ data: products });
  } catch (error) {
    console.error("Product list failed", error.message);
    return res.status(500).json({ error: "product_list_failed" });
  }
});

app.put("/products/:id", requireAuth, requireAdmin, async (req, res) => {
  const { serial, customer, project, productType, year, status } = req.body || {};
  const data = {};
  if (serial) data.serial = serial;
  if (customer) data.customer = customer;
  if (project) data.project = project;
  if (productType !== undefined) data.productType = productType || null;
  if (year) data.year = Number(year);
  if (status) data.status = status;
  try {
    const updated = await prisma.product.update({
      where: { id: req.params.id },
      data
    });
    return res.json(updated);
  } catch (error) {
    if (error.code === "P2025") {
      return res.status(404).json({ error: "product_not_found" });
    }
    console.error("Product update failed", error.message);
    return res.status(500).json({ error: "product_update_failed" });
  }
});

app.delete("/products/:id", requireAuth, requireAdmin, async (req, res) => {
  const hard = req.query.hard === "true";
  try {
    if (hard) {
      // Fetch product first to get folder details
      const product = await prisma.product.findUnique({ where: { id: req.params.id } });
      if (product) {
        // Delete physical folder
        storage.deleteProductFolder({
          year: product.year,
          customer: product.customer,
          project: product.project,
          serial: product.serial
        });
      }

      await prisma.file.deleteMany({ where: { productId: req.params.id } });
      await prisma.checklistItem.deleteMany({ where: { productId: req.params.id } });
      const deleted = await prisma.product.delete({ where: { id: req.params.id } });
      return res.json(deleted);
    } else {
      const updated = await prisma.product.update({
        where: { id: req.params.id },
        data: { status: "deleted" }
      });
      return res.json(updated);
    }
  } catch (error) {
    if (error.code === "P2025") {
      return res.status(404).json({ error: "product_not_found" });
    }
    console.error("Product delete failed", error.message);
    return res.status(500).json({ error: "product_delete_failed" });
  }
});

app.post("/products/:id/files", requireAuth, upload.single("file"), async (req, res) => {
  const { id } = req.params;
  const { type, category } = req.body || {};
  if (!req.file || !type) {
    return res.status(400).json({ error: "missing_fields" });
  }
  try {
    const product = await prisma.product.findUnique({ where: { id } });
    if (!product) return res.status(404).json({ error: "product_not_found" });
    const storage = getStorageConfig();
    let fileRecord;
    if (storage.mode === "local") {
      const basePath = product.onedriveFolder || createLocalProductFolders({
        year: product.year,
        customer: product.customer,
        project: product.project,
        serial: product.serial
      });
      const saved = saveBufferToFile({
        basePath,
        type,
        category,
        originalName: req.file.originalname,
        buffer: req.file.buffer
      });
      let thumbnail = null;
      if (type === "photo") {
        try {
          const thumbBuffer = await createThumbnailBuffer(req.file.buffer);
          thumbnail = saveThumbnailToFile({
            basePath,
            originalName: saved.fileName,
            buffer: thumbBuffer
          });
        } catch (error) {
          console.warn("Thumbnail creation failed", error.message);
        }
      }
      fileRecord = await prisma.file.create({
        data: {
          productId: product.id,
          type,
          category: category || null,
          fileId: saved.fileName,
          fileUrl: saved.fullPath,
          thumbnailId: thumbnail?.fileName || null,
          thumbnailUrl: thumbnail?.fullPath || null
        }
      });
    }
    if (storage.mode === "gdrive") {
      const folderId =
        product.onedriveFolder ||
        (await createGDriveProductFolder({
          year: product.year,
          customer: product.customer,
          project: product.project,
          serial: product.serial
        })).productFolderId;
      const saved = await uploadGDriveFile({
        productFolderId: folderId,
          type,
          category,
          originalName: req.file.originalname,
          buffer: req.file.buffer,
          mimeType: req.file.mimetype
        });
      let thumbnailId = null;
      if (type === "photo") {
        try {
          const thumbBuffer = await createThumbnailBuffer(req.file.buffer);
          const thumbnail = await uploadGDriveThumbnail({
            productFolderId: folderId,
            originalName: saved.name || req.file.originalname,
            buffer: thumbBuffer
          });
          thumbnailId = thumbnail.id;
        } catch (error) {
          console.warn("Thumbnail upload failed", error.message);
        }
      }
      fileRecord = await prisma.file.create({
        data: {
          productId: product.id,
          type,
          category: category || null,
          fileId: saved.id,
          fileUrl: saved.webViewLink || saved.webContentLink || null,
          thumbnailId,
          thumbnailUrl: null
        }
      });
    }
    if (!fileRecord) {
      return res.status(501).json({ error: "storage_not_configured" });
    }
    return res.status(201).json(fileRecord);
  } catch (error) {
    console.error("File upload failed", error.message);
    return res.status(500).json({ error: "file_upload_failed" });
  }
});

app.get("/products/:id/files/:fileId/view", requireAuth, async (req, res) => {
  const { id: productId, fileId } = req.params;
  let entry;
  try {
    const file = await prisma.file.findUnique({ where: { id: fileId } });
    if (!file || file.productId !== productId) {
      return res.status(404).json({ error: "file_not_found" });
    }
    entry = await prisma.viewLog.create({
      data: {
        userId: req.user.id,
        productId,
        fileId,
        action: "view"
      }
    });
    const storage = getStorageConfig();
    if (storage.mode === "local" && file.fileUrl) {
      const contentType = mime.lookup(file.fileUrl) || "application/octet-stream";
      res.setHeader("Content-Type", contentType);
      return getFileStream(file.fileUrl).pipe(res);
    }
    if (storage.mode === "gdrive" && file.fileUrl) {
      const download = await downloadGDriveFile({ fileId: file.fileId });
      res.setHeader(
        "Content-Type",
        download.mimeType || mime.lookup(file.fileUrl) || "application/octet-stream"
      );
      return download.stream.pipe(res);
    }
  } catch (error) {
    console.error("View log failed", error.message);
    return res.status(500).json({ error: "view_log_failed" });
  }
  const subject = `File viewed: ${fileId}`;
  const text = `User ${req.user.username} viewed file ${fileId} for product ${productId} at ${entry.createdAt}`;
  try {
    await sendAdminNotice({ subject, text });
  } catch (error) {
    console.warn("Failed to send admin notice", error.message);
  }
  res.json({ status: "logged", logId: entry.id });
});

app.get("/products/:id/files/:fileId/thumb", requireAuth, async (req, res) => {
  const { id: productId, fileId } = req.params;
  try {
    const file = await prisma.file.findUnique({ where: { id: fileId } });
    if (!file || file.productId !== productId) {
      return res.status(404).json({ error: "file_not_found" });
    }
    const storage = getStorageConfig();
    if (storage.mode === "local") {
      const targetPath = file.thumbnailUrl || file.fileUrl;
      if (!targetPath) return res.status(404).json({ error: "file_missing" });
      res.setHeader(
        "Content-Type",
        mime.lookup(targetPath) || "application/octet-stream"
      );
      return getFileStream(targetPath).pipe(res);
    }
    if (storage.mode === "gdrive") {
      const targetId = file.thumbnailId || file.fileId;
      if (!targetId) return res.status(404).json({ error: "file_missing" });
      const download = await downloadGDriveFile({ fileId: targetId });
      res.setHeader("Content-Type", download.mimeType || "application/octet-stream");
      return download.stream.pipe(res);
    }
  } catch (error) {
    console.error("Thumbnail fetch failed", error.message);
    return res.status(500).json({ error: "thumbnail_fetch_failed" });
  }
  return res.status(501).json({ error: "storage_not_configured" });
});

app.get("/products/:id/files/:fileId/download", requireAuth, requireAdmin, (req, res) => {
  prisma.file
    .findUnique({ where: { id: req.params.fileId } })
    .then(async (file) => {
      if (!file || file.productId !== req.params.id) {
        return res.status(404).json({ error: "file_not_found" });
      }
      const storage = getStorageConfig();
      if (storage.mode === "local") {
        if (!file.fileUrl) {
          return res.status(404).json({ error: "file_missing" });
        }
        res.setHeader(
          "Content-Type",
          mime.lookup(file.fileUrl) || "application/octet-stream"
        );
        res.setHeader("Content-Disposition", `attachment; filename=\"${file.fileId}\"`);
        return getFileStream(file.fileUrl).pipe(res);
      }
      if (storage.mode === "gdrive") {
        const download = await downloadGDriveFile({ fileId: file.fileId });
        res.setHeader("Content-Type", download.mimeType || "application/octet-stream");
        res.setHeader("Content-Disposition", `attachment; filename=\"${download.name}\"`);
        return download.stream.pipe(res);
      }
      return res.status(501).json({ error: "storage_not_configured" });
    })
    .catch((error) => {
      console.error("File download failed", error.message);
      res.status(500).json({ error: "file_download_failed" });
    });
});

app.get("/admin/view-logs", requireAuth, requireAdmin, async (req, res) => {
  try {
    const logs = await prisma.viewLog.findMany({ orderBy: { createdAt: "desc" } });
    return res.json({ data: logs });
  } catch (error) {
    console.error("View log list failed", error.message);
    return res.status(500).json({ error: "view_log_list_failed" });
  }
});

app.get("/graph/health", requireAuth, async (req, res) => {
  try {
    const config = getConfig();
    if (!config.tenantId || !config.clientId || !config.clientSecret) {
      return res.status(400).json({ error: "graph_config_missing" });
    }
    return res.json({ status: "ok", driveId: config.driveId || null, siteId: config.siteId || null });
  } catch (error) {
    return res.status(500).json({ error: "graph_health_failed" });
  }
});

app.post("/graph/folders", requireAuth, async (req, res) => {
  const { year, customer, project, serial } = req.body || {};
  if (!year || !customer || !project || !serial) {
    return res.status(400).json({ error: "missing_fields" });
  }
  try {
    const result = await createProductFolder({ year, customer, project, serial });
    return res.status(201).json(result);
  } catch (error) {
    console.error("Graph folder create failed", error.message);
    return res.status(500).json({ error: "graph_folder_failed" });
  }
});

app.post("/graph/uploads", requireAuth, async (req, res) => {
  const { path, contentBase64 } = req.body || {};
  if (!path || !contentBase64) {
    return res.status(400).json({ error: "missing_fields" });
  }
  try {
    const item = await uploadBase64({ path, contentBase64 });
    return res.status(201).json(item);
  } catch (error) {
    console.error("Graph upload failed", error.message);
    return res.status(500).json({ error: "graph_upload_failed" });
  }
});

app.post("/graph/share-link", requireAuth, async (req, res) => {
  const { itemId, type, scope } = req.body || {};
  if (!itemId) return res.status(400).json({ error: "missing_item_id" });
  try {
    const link = await createShareLink({ itemId, type, scope });
    return res.status(201).json(link);
  } catch (error) {
    console.error("Graph share link failed", error.message);
    return res.status(500).json({ error: "graph_share_failed" });
  }
});

app.get("/graph/items/:itemId", requireAuth, async (req, res) => {
  try {
    const item = await getItem(req.params.itemId);
    return res.json(item);
  } catch (error) {
    console.error("Graph item fetch failed", error.message);
    return res.status(500).json({ error: "graph_item_failed" });
  }
});

app.post("/auth/change-password", requireAuth, async (req, res) => {
  const { currentPassword, newPassword } = req.body || {};
  if (!currentPassword || !newPassword) {
    return res.status(400).json({ error: "missing_fields" });
  }
  try {
    const user = await prisma.user.findUnique({ where: { id: req.user.id } });
    if (!verifyPassword(user, currentPassword)) {
      return res.status(401).json({ error: "invalid_current_password" });
    }
    const { salt, hash } = hashPassword(newPassword);
    await prisma.user.update({
      where: { id: user.id },
      data: { passwordHash: hash, passwordSalt: salt }
    });
    return res.json({ success: true });
  } catch (error) {
    console.error("Password change failed", error.message);
    return res.status(500).json({ error: "change_failed" });
  }
});

app.put("/products/:id/restore", requireAuth, requireAdmin, async (req, res) => {
  try {
    const updated = await prisma.product.update({
      where: { id: req.params.id },
      data: { status: "open" }
    });
    return res.json(updated);
  } catch (error) {
    if (error.code === "P2025") {
      return res.status(404).json({ error: "product_not_found" });
    }
    console.error("Product restore failed", error.message);
    return res.status(500).json({ error: "product_restore_failed" });
  }
});

async function seedAdmin() {
  const username = process.env.ADMIN_USERNAME;
  const password = process.env.ADMIN_PASSWORD;
  if (!username || !password) return;
  const existing = await prisma.user.findUnique({ where: { username } });
  if (existing) return;
  const { salt, hash } = hashPassword(password);
  await prisma.user.create({
    data: {
      username,
      email: process.env.ADMIN_EMAIL || null,
      role: "admin",
      passwordHash: hash,
      passwordSalt: salt
    }
  });
}

seedAdmin().catch((error) => {
  console.error("Admin seed failed", error.message);
});

const port = process.env.PORT || 3000;
app.listen(port, "0.0.0.0", () => {
  console.log(`API listening on port ${port}`);
});
