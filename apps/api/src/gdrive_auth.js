const fs = require("fs");
const readline = require("readline");
const { getOAuthClient } = require("./gdrive");

const tokenPath = process.env.GDRIVE_TOKEN_JSON;
if (!tokenPath) {
  console.error("GDRIVE_TOKEN_JSON is required.");
  process.exit(1);
}

const auth = getOAuthClient();
const scopes = ["https://www.googleapis.com/auth/drive"];
const authUrl = auth.generateAuthUrl({
  access_type: "offline",
  scope: scopes,
  prompt: "consent"
});

console.log("Open this URL in your browser and approve access:");
console.log(authUrl);

const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout
});

rl.question("Paste the code here: ", async (code) => {
  rl.close();
  try {
    const tokenResponse = await auth.getToken(code.trim());
    auth.setCredentials(tokenResponse.tokens);
    fs.writeFileSync(tokenPath, JSON.stringify(tokenResponse.tokens, null, 2));
    console.log(`Token saved to ${tokenPath}`);
  } catch (error) {
    console.error("Token exchange failed:", error.message);
    process.exit(1);
  }
});
