const GRAPH_BASE = "https://graph.microsoft.com/v1.0";

const tokenCache = {
  token: null,
  expiresAt: 0
};

function getConfig() {
  return {
    tenantId: process.env.GRAPH_TENANT_ID,
    clientId: process.env.GRAPH_CLIENT_ID,
    clientSecret: process.env.GRAPH_CLIENT_SECRET,
    driveId: process.env.GRAPH_DRIVE_ID,
    siteId: process.env.GRAPH_SITE_ID,
    basePath: process.env.GRAPH_BASE_PATH || "ShipmentDocs"
  };
}

function getDriveRootPath(config) {
  if (config.driveId) return `/drives/${config.driveId}`;
  if (config.siteId) return `/sites/${config.siteId}/drive`;
  return "/me/drive";
}

async function getAccessToken() {
  const now = Date.now();
  if (tokenCache.token && tokenCache.expiresAt > now + 60000) {
    return tokenCache.token;
  }
  const { tenantId, clientId, clientSecret } = getConfig();
  if (!tenantId || !clientId || !clientSecret) {
    throw new Error("GRAPH_CONFIG_MISSING");
  }
  const params = new URLSearchParams();
  params.set("client_id", clientId);
  params.set("client_secret", clientSecret);
  params.set("scope", "https://graph.microsoft.com/.default");
  params.set("grant_type", "client_credentials");
  const response = await fetch(
    `https://login.microsoftonline.com/${tenantId}/oauth2/v2.0/token`,
    {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: params.toString()
    }
  );
  if (!response.ok) {
    const text = await response.text();
    throw new Error(`GRAPH_TOKEN_FAILED: ${text}`);
  }
  const payload = await response.json();
  tokenCache.token = payload.access_token;
  tokenCache.expiresAt = now + payload.expires_in * 1000;
  return tokenCache.token;
}

async function graphRequest(path, options = {}) {
  const token = await getAccessToken();
  const response = await fetch(`${GRAPH_BASE}${path}`, {
    ...options,
    headers: {
      Authorization: `Bearer ${token}`,
      ...options.headers
    }
  });
  if (!response.ok) {
    const text = await response.text();
    throw new Error(`GRAPH_REQUEST_FAILED: ${text}`);
  }
  if (response.status === 204) return null;
  return response.json();
}

async function createFolder(path) {
  const config = getConfig();
  const driveRoot = getDriveRootPath(config);
  const safePath = path.replace(/^\/+/, "");
  return graphRequest(
    `${driveRoot}/root:/${safePath}`,
    {
      method: "PUT",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        folder: {},
        "@microsoft.graph.conflictBehavior": "replace"
      })
    }
  );
}

async function createProductFolder({ year, customer, project, serial }) {
  const config = getConfig();
  const parts = [config.basePath, String(year), customer, project, serial]
    .filter(Boolean)
    .map((part) => part.replace(/[\\/:*?"<>|]/g, "_"));
  const productPath = parts.join("/");
  const rootFolder = await createFolder(productPath);
  const subfolders = ["Photos", "Docs", "Test", "Label", "ProjectFiles"];
  for (const folder of subfolders) {
    await createFolder(`${productPath}/${folder}`);
  }
  return { productPath, rootFolder };
}

async function uploadBase64({ path, contentBase64 }) {
  const config = getConfig();
  const driveRoot = getDriveRootPath(config);
  const safePath = path.replace(/^\/+/, "");
  const buffer = Buffer.from(contentBase64, "base64");
  return graphRequest(
    `${driveRoot}/root:/${safePath}:/content`,
    {
      method: "PUT",
      headers: { "Content-Type": "application/octet-stream" },
      body: buffer
    }
  );
}

async function createShareLink({ itemId, type = "view", scope = "anonymous" }) {
  const config = getConfig();
  const driveRoot = getDriveRootPath(config);
  return graphRequest(
    `${driveRoot}/items/${itemId}/createLink`,
    {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ type, scope })
    }
  );
}

async function getItem(itemId) {
  const config = getConfig();
  const driveRoot = getDriveRootPath(config);
  return graphRequest(`${driveRoot}/items/${itemId}`);
}

module.exports = {
  getConfig,
  createProductFolder,
  uploadBase64,
  createShareLink,
  getItem
};
