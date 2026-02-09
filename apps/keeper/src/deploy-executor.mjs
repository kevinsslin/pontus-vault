import {createServer} from "node:http";

import {getEnv} from "./env.mjs";
import {PHAROS_ATLANTIC_CHAIN_ID, isAddressLike, runDeployForge, runUpdateRateForge} from "./forge.mjs";

function parseJsonBody(request) {
  return new Promise((resolveBody, rejectBody) => {
    const chunks = [];
    request.on("data", (chunk) => chunks.push(chunk));
    request.on("end", () => {
      try {
        const raw = Buffer.concat(chunks).toString("utf8");
        const parsed = raw ? JSON.parse(raw) : {};
        resolveBody(parsed);
      } catch (error) {
        rejectBody(error);
      }
    });
    request.on("error", rejectBody);
  });
}

function sendJson(response, statusCode, payload) {
  response.writeHead(statusCode, {"content-type": "application/json"});
  response.end(JSON.stringify(payload));
}

function isAuthorized(request) {
  const expectedToken = getEnv("DEPLOY_EXECUTOR_TOKEN");
  if (!expectedToken) return true;
  const header = request.headers.authorization ?? "";
  return header === `Bearer ${expectedToken}`;
}

async function handleDeploy(request, response) {
  if (!isAuthorized(request)) {
    sendJson(response, 401, {error: "Unauthorized"});
    return;
  }

  const body = await parseJsonBody(request);
  const owner = String(body.owner ?? "").trim().toLowerCase();
  const requestedBy = String(body.requestedBy ?? "").trim().toLowerCase();
  const assetAddress = String(body.assetAddress ?? "").trim();

  if (!owner || !requestedBy || !assetAddress) {
    sendJson(response, 400, {
      error: "owner, requestedBy, and assetAddress are required."
    });
    return;
  }

  try {
    const payload = await runDeployForge({owner, requestedBy, assetAddress});
    sendJson(response, 200, payload);
  } catch (error) {
    sendJson(response, 400, {
      error: error instanceof Error ? error.message : String(error)
    });
  }
}

async function handleUpdateRate(request, response) {
  if (!isAuthorized(request)) {
    sendJson(response, 401, {error: "Unauthorized"});
    return;
  }

  const body = await parseJsonBody(request);
  const vaultAddress = String(body.vaultAddress ?? "").trim();
  const accountantAddress = String(body.accountantAddress ?? "").trim();
  const assetAddress = String(body.assetAddress ?? "").trim();
  const minUpdateBps = body.minUpdateBps ?? 1;
  const allowPauseUpdate = body.allowPauseUpdate === true;

  if (!vaultAddress || !accountantAddress || !assetAddress) {
    sendJson(response, 400, {
      error: "vaultAddress, accountantAddress, and assetAddress are required."
    });
    return;
  }

  try {
    const payload = await runUpdateRateForge({
      vaultAddress,
      accountantAddress,
      assetAddress,
      minUpdateBps,
      allowPauseUpdate
    });
    sendJson(response, 200, payload);
  } catch (error) {
    sendJson(response, 400, {
      error: error instanceof Error ? error.message : String(error)
    });
  }
}

async function handleHealth(_, response) {
  sendJson(response, 200, {
    ok: true,
    chainId: Number(PHAROS_ATLANTIC_CHAIN_ID),
    mode: "deploy-executor"
  });
}

async function routeRequest(request, response) {
  if (!request.url) {
    sendJson(response, 404, {error: "Not found"});
    return;
  }

  const url = new URL(request.url, "http://localhost");
  if (request.method === "GET" && url.pathname === "/health") {
    await handleHealth(request, response);
    return;
  }
  if (request.method === "POST" && (url.pathname === "/deploy" || url.pathname === "/")) {
    await handleDeploy(request, response);
    return;
  }
  if (request.method === "POST" && url.pathname === "/update-rate") {
    await handleUpdateRate(request, response);
    return;
  }

  sendJson(response, 404, {error: "Not found"});
}

function main() {
  const host = getEnv("DEPLOY_EXECUTOR_HOST", "0.0.0.0");
  const port = Number(getEnv("DEPLOY_EXECUTOR_PORT", getEnv("PORT", "8787")));
  if (!Number.isFinite(port) || port <= 0) {
    throw new Error("DEPLOY_EXECUTOR_PORT must be a positive number.");
  }

  const server = createServer((request, response) => {
    void routeRequest(request, response).catch((error) => {
      sendJson(response, 500, {
        error: error instanceof Error ? error.message : String(error)
      });
    });
  });

  server.listen(port, host, () => {
    console.log(`[deploy-executor] listening on http://${host}:${port}`);
  });
}

main();
