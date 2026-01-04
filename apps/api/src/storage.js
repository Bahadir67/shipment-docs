const fs = require("fs");
const path = require("path");
const gdrive = require("./gdrive");

function sanitizeSegment(value) {
  return String(value || "")
    .trim()
    .replace(/[\\/:*?"<>|]/g, "_")
    .replace(/\s+/g, "_");
}

function getStorageConfig() {
  return {
    mode: process.env.STORAGE_MODE || "local",
    root: process.env.STORAGE_ROOT || path.join(process.cwd(), "storage"),
    basePath: process.env.STORAGE_BASE_PATH || "ShipmentDocs"
  };
}

function ensureDir(dirPath) {
  fs.mkdirSync(dirPath, { recursive: true });
}

function buildProductPath({ year, customer, project, serial }) {
  const config = getStorageConfig();
  const parts = [
    config.root,
    config.basePath,
    sanitizeSegment(year),
    sanitizeSegment(customer),
    sanitizeSegment(project),
    sanitizeSegment(serial)
  ];
  return path.join(...parts);
}

function createLocalProductFolders({ year, customer, project, serial }) {
  const basePath = buildProductPath({ year, customer, project, serial });
  ensureDir(basePath);
  const subfolders = ["Photos", "Docs", "Test", "Label", "ProjectFiles"];
  for (const folder of subfolders) {
    ensureDir(path.join(basePath, folder));
  }
  ensureDir(path.join(basePath, "Photos", "Thumbnails"));
  const projectSub = ["Drawings", "Hydraulic", "Electrical", "Software"];
  for (const folder of projectSub) {
    ensureDir(path.join(basePath, "ProjectFiles", folder));
  }
  return basePath;
}

function resolveTargetFolder({ basePath, type, category }) {
  if (type === "photo") return path.join(basePath, "Photos");
  if (type === "test_report") return path.join(basePath, "Test");
  if (type === "label") return path.join(basePath, "Label");
  if (type === "project_file") {
    const segment = sanitizeSegment(category || "General");
    return path.join(basePath, "ProjectFiles", segment);
  }
  return path.join(basePath, "Docs");
}

function saveBufferToFile({ basePath, type, category, originalName, buffer }) {
  const folder = resolveTargetFolder({ basePath, type, category });
  ensureDir(folder);
  
  const stdNames = ["onden", "sagdan", "soldan", "arkadan", "etiket", "genel"];
  const namePart = sanitizeSegment(originalName);
  const isStdPhoto = stdNames.some(std => namePart.toLowerCase().startsWith(std));

  const safeName = isStdPhoto ? namePart : `${Date.now()}_${namePart}`;
  const fullPath = path.join(folder, safeName);
  fs.writeFileSync(fullPath, buffer);
  return { fullPath, fileName: safeName };
}

function saveThumbnailToFile({ basePath, originalName, buffer }) {
  const folder = path.join(basePath, "Photos", "Thumbnails");
  ensureDir(folder);
  const parsed = path.parse(sanitizeSegment(originalName));
  const safeName = `${parsed.name}.jpg`;
  const fullPath = path.join(folder, safeName);
  fs.writeFileSync(fullPath, buffer);
  return { fullPath, fileName: safeName };
}

function getFileStream(filePath) {
  return fs.createReadStream(filePath);
}

function deleteEmptyLocalParents(dirPath, levels) {
  if (levels <= 0) return;
  try {
    const parent = path.dirname(dirPath);
    // Don't go above the storage root
    const config = getStorageConfig();
    const storageRoot = path.join(config.root, config.basePath);
    
    if (parent.length <= storageRoot.length) return;

    const files = fs.readdirSync(parent);
    if (files.length === 0) {
      fs.rmdirSync(parent);
      console.log(`Local: Deleted empty parent folder: ${parent}`);
      deleteEmptyLocalParents(parent, levels - 1);
    }
  } catch (e) {
    console.warn("Local parent cleanup skipped:", e.message);
  }
}

async function deleteProductFolder({ year, customer, project, serial }) {
  const config = getStorageConfig();
  
  if (config.mode === "gdrive") {
    console.log(`Storage Mode: GDrive. Deleting folder for ${serial}...`);
    try {
      await gdrive.deleteGDriveProductFolder({ year, customer, project, serial });
    } catch (e) {
      console.error("GDrive delete failed:", e.message);
    }
  } else {
    // Local Mode
    const basePath = buildProductPath({ year, customer, project, serial });
    console.log(`Storage Mode: Local. Attempting to delete folder: ${basePath}`);
    if (fs.existsSync(basePath)) {
      fs.rmSync(basePath, { recursive: true, force: true });
      console.log("Folder deleted successfully. Cleaning up parents...");
      // Max 4 levels up after serial folder: project -> customer -> year -> base
      deleteEmptyLocalParents(basePath, 4);
    } else {
      console.log("Folder not found, skipping.");
    }
  }
}

module.exports = {
  getStorageConfig,
  createLocalProductFolders,
  saveBufferToFile,
  saveThumbnailToFile,
  getFileStream,
  deleteProductFolder
};
