const fs = require("fs");
const { Readable } = require("stream");
const { google } = require("googleapis");

function loadJson(pathValue) {
  if (!pathValue) return null;
  const raw = fs.readFileSync(pathValue, "utf8");
  return JSON.parse(raw);
}

function getOAuthClient() {
  const clientPath = process.env.GDRIVE_OAUTH_CLIENT_JSON;
  if (!clientPath) throw new Error("GDRIVE_OAUTH_CLIENT_JSON_MISSING");
  const data = loadJson(clientPath);
  const config = data.installed || data.web;
  if (!config) throw new Error("GDRIVE_OAUTH_CLIENT_INVALID");
  const redirect = (config.redirect_uris && config.redirect_uris[0]) || "urn:ietf:wg:oauth:2.0:oob";
  return new google.auth.OAuth2(config.client_id, config.client_secret, redirect);
}

function getDriveClient() {
  const tokenPath = process.env.GDRIVE_TOKEN_JSON;
  if (!tokenPath) throw new Error("GDRIVE_TOKEN_JSON_MISSING");
  const token = loadJson(tokenPath);
  if (!token) throw new Error("GDRIVE_TOKEN_MISSING");
  const auth = getOAuthClient();
  auth.setCredentials(token);
  return google.drive({ version: "v3", auth });
}

function sanitizeName(value) {
  return String(value || "")
    .trim()
    .replace(/[\\/:*?"<>|]/g, "_")
    .replace(/\s+/g, "_");
}

async function ensureFolder(drive, name, parentId) {
  const safeName = sanitizeName(name);
  const query = [
    `'${parentId}' in parents`,
    `name='${safeName}'`,
    "mimeType='application/vnd.google-apps.folder'",
    "trashed=false"
  ].join(" and ");
  const list = await drive.files.list({
    q: query,
    fields: "files(id,name)"
  });
  if (list.data.files && list.data.files.length) {
    return list.data.files[0].id;
  }
  const created = await drive.files.create({
    requestBody: {
      name: safeName,
      parents: [parentId],
      mimeType: "application/vnd.google-apps.folder"
    },
    fields: "id"
  });
  return created.data.id;
}

async function createGDriveProductFolder({ year, customer, project, serial }) {
  const rootId = process.env.GDRIVE_FOLDER_ID;
  if (!rootId) {
    throw new Error("GDRIVE_FOLDER_ID_MISSING");
  }
  const drive = getDriveClient();
  const yearId = await ensureFolder(drive, year, rootId);
  const customerId = await ensureFolder(drive, customer, yearId);
  const projectId = await ensureFolder(drive, project, customerId);
  const productId = await ensureFolder(drive, serial, projectId);

  const subfolders = ["Photos", "Docs", "Test", "Label", "ProjectFiles"];
  for (const name of subfolders) {
    await ensureFolder(drive, name, productId);
  }
  const projectSubs = ["Drawings", "Hydraulic", "Electrical", "Software"];
  const projectFilesId = await ensureFolder(drive, "ProjectFiles", productId);
  for (const name of projectSubs) {
    await ensureFolder(drive, name, projectFilesId);
  }
  return { productFolderId: productId };
}

function resolveFolderName(type, category) {
  if (type === "photo") return "Photos";
  if (type === "test_report") return "Test";
  if (type === "label") return "Label";
  if (type === "project_file") return category ? sanitizeName(category) : "ProjectFiles";
  return "Docs";
}

async function uploadGDriveFile({
  productFolderId,
  type,
  category,
  originalName,
  buffer,
  mimeType
}) {
  const drive = getDriveClient();
  let targetParent = productFolderId;
  if (type === "project_file" && category) {
    const projectFilesId = await ensureFolder(drive, "ProjectFiles", productFolderId);
    targetParent = await ensureFolder(drive, category, projectFilesId);
  } else {
    targetParent = await ensureFolder(drive, resolveFolderName(type, category), productFolderId);
  }
  const response = await drive.files.create({
    requestBody: {
      name: sanitizeName(originalName),
      parents: [targetParent]
    },
    media: {
      mimeType: mimeType || "application/octet-stream",
      body: Readable.from(buffer)
    },
    fields: "id,name,webViewLink,webContentLink"
  });
  return response.data;
}

async function downloadGDriveFile({ fileId }) {
  const drive = getDriveClient();
  const meta = await drive.files.get({
    fileId,
    fields: "name,mimeType"
  });
  const stream = await drive.files.get(
    { fileId, alt: "media" },
    { responseType: "stream" }
  );
  return {
    name: meta.data.name,
    mimeType: meta.data.mimeType,
    stream: stream.data
  };
}

module.exports = {
  getOAuthClient,
  createGDriveProductFolder,
  uploadGDriveFile,
  downloadGDriveFile
};
