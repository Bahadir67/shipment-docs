const DB_NAME = "shipment_docs";
const DB_VERSION = 1;
const STORE_UPLOADS = "upload_queue";

function openDb() {
  return new Promise((resolve, reject) => {
    const request = indexedDB.open(DB_NAME, DB_VERSION);
    request.onupgradeneeded = () => {
      const db = request.result;
      if (!db.objectStoreNames.contains(STORE_UPLOADS)) {
        db.createObjectStore(STORE_UPLOADS, { keyPath: "id", autoIncrement: true });
      }
    };
    request.onsuccess = () => resolve(request.result);
    request.onerror = () => reject(request.error);
  });
}

export async function addUpload(item) {
  const db = await openDb();
  return new Promise((resolve, reject) => {
    const tx = db.transaction(STORE_UPLOADS, "readwrite");
    const store = tx.objectStore(STORE_UPLOADS);
    const request = store.add(item);
    request.onsuccess = () => resolve(request.result);
    request.onerror = () => reject(request.error);
  });
}

export async function listUploads() {
  const db = await openDb();
  return new Promise((resolve, reject) => {
    const tx = db.transaction(STORE_UPLOADS, "readonly");
    const store = tx.objectStore(STORE_UPLOADS);
    const request = store.getAll();
    request.onsuccess = () => resolve(request.result || []);
    request.onerror = () => reject(request.error);
  });
}

export async function deleteUpload(id) {
  const db = await openDb();
  return new Promise((resolve, reject) => {
    const tx = db.transaction(STORE_UPLOADS, "readwrite");
    const store = tx.objectStore(STORE_UPLOADS);
    const request = store.delete(id);
    request.onsuccess = () => resolve();
    request.onerror = () => reject(request.error);
  });
}
