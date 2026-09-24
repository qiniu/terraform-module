import { timingSafeEqual } from "node:crypto";

export const name = "las-dsh-auth-bootstrap";
export const inject = ["webServer", "connection"];

const SECRET_HEADER = "x-las-dsh-auth-bootstrap-secret";
const LOOPBACK_ADDRESSES = new Set(["127.0.0.1", "::1", "::ffff:127.0.0.1"]);

function reject(response, statusCode) {
  response.statusCode = statusCode;
  response.setHeader("Cache-Control", "no-store");
  response.end();
}

function secretMatches(candidate, expected) {
  if (typeof candidate !== "string") return false;
  const actualBuffer = Buffer.from(candidate);
  const expectedBuffer = Buffer.from(expected);
  return actualBuffer.length === expectedBuffer.length
    && timingSafeEqual(actualBuffer, expectedBuffer);
}

function isCrossSiteDocumentNavigation(request) {
  return request.headers["sec-fetch-site"] === "cross-site"
    && request.headers["sec-fetch-mode"] === "navigate"
    && request.headers["sec-fetch-dest"] === "document";
}

function escapeHtmlAttribute(value) {
  return value
    .replaceAll("&", "&amp;")
    .replaceAll('"', "&quot;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;");
}

function transitionDocument(authenticatedUrl) {
  const escapedUrl = escapeHtmlAttribute(authenticatedUrl);
  return `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="referrer" content="no-referrer">
<meta http-equiv="refresh" content="0;url=${escapedUrl}">
<title>Opening DeepSeek Harness</title>
</head>
<body><a href="${escapedUrl}">Continue to DeepSeek Harness</a></body>
</html>
`;
}

function readConfiguration() {
  const secret = process.env.DSH_AUTH_BOOTSTRAP_SECRET ?? "";
  const route = process.env.DSH_AUTH_BOOTSTRAP_ROUTE ?? "";
  const publicUrl = process.env.DSH_AUTH_BOOTSTRAP_PUBLIC_URL ?? "";

  if (!/^[0-9a-f]{64}$/.test(secret)) {
    throw new Error("las-dsh-auth-bootstrap: invalid bootstrap secret");
  }
  if (!route.startsWith("/") || route.endsWith("/")) {
    throw new Error("las-dsh-auth-bootstrap: invalid exact route");
  }

  const parsedUrl = new URL(publicUrl);
  if (parsedUrl.protocol !== "https:" || parsedUrl.pathname !== "/"
    || parsedUrl.search !== "" || parsedUrl.hash !== ""
    || parsedUrl.username !== "" || parsedUrl.password !== "") {
    throw new Error("las-dsh-auth-bootstrap: invalid public URL");
  }

  return { publicUrl: parsedUrl.toString(), route, secret };
}

export function apply(ctx) {
  const config = readConfiguration();
  const route = {
    kind: "exact",
    path: config.route,
    handler(request, response) {
      if (request.method !== "GET") return reject(response, 405);
      if (!LOOPBACK_ADDRESSES.has(request.socket.remoteAddress ?? "")) {
        return reject(response, 403);
      }

      const suppliedSecret = request.headers[SECRET_HEADER];
      if (Array.isArray(suppliedSecret) || !secretMatches(suppliedSecret, config.secret)) {
        return reject(response, 403);
      }

      const authenticatedUrl = ctx.connection.authenticatedUrl(config.publicUrl);
      response.setHeader("Cache-Control", "no-store");
      response.setHeader("Pragma", "no-cache");
      response.setHeader("Referrer-Policy", "no-referrer");
      response.setHeader("X-Content-Type-Options", "nosniff");

      if (isCrossSiteDocumentNavigation(request)) {
        response.statusCode = 200;
        response.setHeader("Content-Type", "text/html; charset=utf-8");
        response.setHeader(
          "Content-Security-Policy",
          "default-src 'none'; base-uri 'none'; form-action 'none'; frame-ancestors 'none'",
        );
        response.setHeader("X-Frame-Options", "DENY");
        response.end(transitionDocument(authenticatedUrl));
        return;
      }

      response.statusCode = 303;
      response.setHeader("Location", authenticatedUrl);
      response.end();
    },
  };

  ctx.effect(
    () => ctx.webServer.register(route),
    "las-dsh-auth-bootstrap: authenticated browser redirect",
  );
}
