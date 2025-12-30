const fs = require("fs");
const { Readable } = require("stream");
const { google } = require("googleapis");

function loadServiceAccount() {
  if (process.env.GDRIVE_SERVICE_ACCOUNT_JSON) {
    const raw = fs.readFileSync(process.env.GDRIVE_SERVICE_ACCOUNT_JSON, "utf8");
    return JSON.parse(raw);
  }
  if (process.env.GDRIVE_SERVICE_ACCOUNT_B64) {
    const raw = Buffer.from(process.env.GDRIVE_SERVICE_ACCOUNT_B64, "base64").toString("utf8");
    return JSON.parse(raw);
  }
  if (process.env.GDRIVE_SERVICE_ACCOUNT) {
    return JSON.parse(process.env.GDRIVE_SERVICE_ACCOUNT);
  }
  throw new Error("GDRIVE_SERVICE_ACCOUNT_MISSING");
}

function getDriveClient() {
  const serviceAccount = loadServiceAccount();
  const auth = new google.auth.JWT(
    serviceAccount.client_email,
    null,
    serviceAccount.private_key,
    ["https://www.googleapis.com/auth/drive"]
  );
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
  createGDriveProductFolder,
  uploadGDriveFile,
  downloadGDriveFile
};
