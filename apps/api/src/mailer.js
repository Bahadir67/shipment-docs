const nodemailer = require("nodemailer");

function getTransporter() {
  const host = process.env.SMTP_HOST;
  const port = process.env.SMTP_PORT;
  const user = process.env.SMTP_USER;
  const pass = process.env.SMTP_PASS;
  if (!host || !port || !user || !pass) return null;
  return nodemailer.createTransport({
    host,
    port: Number(port),
    secure: Number(port) === 465,
    auth: { user, pass }
  });
}

async function sendAdminNotice({ subject, text }) {
  const adminEmails = (process.env.ADMIN_EMAILS || "")
    .split(",")
    .map((value) => value.trim())
    .filter(Boolean);
  if (!adminEmails.length) return;
  const transporter = getTransporter();
  if (!transporter) return;
  const from = process.env.SMTP_FROM || process.env.SMTP_USER;
  await transporter.sendMail({
    from,
    to: adminEmails,
    subject,
    text
  });
}

module.exports = { sendAdminNotice };
