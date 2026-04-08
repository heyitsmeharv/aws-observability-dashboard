/**
 * frontend-health-check.js
 *
 * CloudWatch Synthetics canary — frontend URL health check.
 *
 * Performs a headless page load of the target URL and checks:
 *   - HTTP 200 response
 *   - Page loads without JavaScript errors
 *   - A configurable element is present in the DOM
 *
 * The TARGET_URL environment variable is injected by the canary definition.
 */

const synthetics = require("Synthetics");
const syntheticsConfiguration = synthetics.getConfiguration();
const log = require("SyntheticsLogger");

const TARGET_URL = process.env.TARGET_URL;
const EXPECTED_SELECTOR = process.env.EXPECTED_SELECTOR || "body";

syntheticsConfiguration.setConfig({
  screenshotOnStepStart: false,
  screenshotOnStepSuccess: true,
  screenshotOnStepFailure: true,
  includeResponseHeaders: true,
  includeRequestHeaders: true,
  restrictedHeaders: [],
  restrictedUrlParameters: [],
});

const frontendCheck = async function () {
  if (!TARGET_URL) {
    throw new Error("TARGET_URL environment variable is not set.");
  }

  log.info(`Checking frontend URL: ${TARGET_URL}`);

  const page = await synthetics.getPage();

  // Capture any uncaught page errors
  const pageErrors = [];
  page.on("pageerror", (err) => {
    pageErrors.push(err.message);
    log.warn(`Page JS error: ${err.message}`);
  });

  await synthetics.executeStep("Load page", async () => {
    const response = await page.goto(TARGET_URL, {
      waitUntil: "networkidle0",
      timeout: 30000,
    });

    const statusCode = response.status();
    log.info(`HTTP status: ${statusCode}`);

    if (statusCode !== 200) {
      throw new Error(
        `Expected HTTP 200 but received ${statusCode} for ${TARGET_URL}`
      );
    }
  });

  await synthetics.executeStep("Verify DOM element", async () => {
    const element = await page.$(EXPECTED_SELECTOR);
    if (!element) {
      throw new Error(
        `Expected DOM selector '${EXPECTED_SELECTOR}' not found on the page.`
      );
    }
    log.info(`Found expected element: ${EXPECTED_SELECTOR}`);
  });

  if (pageErrors.length > 0) {
    throw new Error(
      `Page loaded with ${pageErrors.length} JavaScript error(s): ${pageErrors.slice(0, 3).join("; ")}`
    );
  }

  log.info("Frontend health check passed.");
};

exports.handler = async () => {
  return await frontendCheck();
};
