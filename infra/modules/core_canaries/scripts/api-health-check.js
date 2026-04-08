/**
 * api-health-check.js
 *
 * CloudWatch Synthetics canary — API endpoint health check.
 *
 * Makes an HTTP GET request to the target API health endpoint and checks:
 *   - HTTP 200 response
 *   - Response body contains expected JSON shape (optional)
 *   - Response time is under a configurable threshold
 *
 * Environment variables injected by the canary definition:
 *   TARGET_URL          - The API URL to probe (required)
 *   EXPECTED_STATUS     - Expected HTTP status code (default: 200)
 *   MAX_DURATION_MS     - Max acceptable response time in ms (default: 3000)
 */

const synthetics = require("Synthetics");
const syntheticsConfiguration = synthetics.getConfiguration();
const log = require("SyntheticsLogger");
const https = require("https");
const http = require("http");
const { URL } = require("url");

const TARGET_URL = process.env.TARGET_URL;
const EXPECTED_STATUS = parseInt(process.env.EXPECTED_STATUS || "200", 10);
const MAX_DURATION_MS = parseInt(process.env.MAX_DURATION_MS || "3000", 10);

syntheticsConfiguration.setConfig({
  includeResponseHeaders: true,
  includeRequestHeaders: true,
  restrictedHeaders: ["Authorization", "x-api-key"],
  restrictedUrlParameters: [],
});

const makeRequest = (url) => {
  return new Promise((resolve, reject) => {
    const parsed = new URL(url);
    const client = parsed.protocol === "https:" ? https : http;
    const startTime = Date.now();

    const req = client.get(
      url,
      {
        headers: {
          "User-Agent": "CloudWatchSynthetics/1.0",
          Accept: "application/json",
        },
        timeout: MAX_DURATION_MS,
      },
      (res) => {
        let body = "";
        res.on("data", (chunk) => {
          body += chunk;
        });
        res.on("end", () => {
          resolve({
            statusCode: res.statusCode,
            headers: res.headers,
            body,
            durationMs: Date.now() - startTime,
          });
        });
      }
    );

    req.on("error", reject);
    req.on("timeout", () => {
      req.destroy();
      reject(new Error(`Request timed out after ${MAX_DURATION_MS}ms`));
    });
  });
};

const apiCheck = async function () {
  if (!TARGET_URL) {
    throw new Error("TARGET_URL environment variable is not set.");
  }

  log.info(`Checking API endpoint: ${TARGET_URL}`);
  log.info(
    `Expected status: ${EXPECTED_STATUS}, max duration: ${MAX_DURATION_MS}ms`
  );

  await synthetics.executeStep("API health check", async () => {
    const result = await makeRequest(TARGET_URL);

    log.info(`Response status: ${result.statusCode}`);
    log.info(`Response time: ${result.durationMs}ms`);

    if (result.statusCode !== EXPECTED_STATUS) {
      throw new Error(
        `Expected HTTP ${EXPECTED_STATUS} but received ${result.statusCode} from ${TARGET_URL}. Body: ${result.body.slice(0, 500)}`
      );
    }

    if (result.durationMs > MAX_DURATION_MS) {
      throw new Error(
        `Response time ${result.durationMs}ms exceeded threshold of ${MAX_DURATION_MS}ms`
      );
    }

    // Attempt to parse JSON — not required but logged for debugging
    try {
      const json = JSON.parse(result.body);
      log.info(`Parsed response body: ${JSON.stringify(json).slice(0, 200)}`);
    } catch (_) {
      log.info(
        `Response body (non-JSON): ${result.body.slice(0, 200)}`
      );
    }

    log.info("API health check passed.");
  });
};

exports.handler = async () => {
  return await apiCheck();
};
