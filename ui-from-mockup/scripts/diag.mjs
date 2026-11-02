#!/usr/bin/env node
import { chromium } from "playwright";

function parseArgs(argv) {
  const args = {
    vw: 1280,
    vh: 900,
    wait: 3000,
    headed: false,
    timeout: 30000,
    grep: "",
  };

  for (let i = 2; i < argv.length; i += 1) {
    const key = argv[i];
    const next = () => argv[++i];
    switch (key) {
      case "--url":
        args.url = next();
        break;
      case "--vw":
        args.vw = Number(next());
        break;
      case "--vh":
        args.vh = Number(next());
        break;
      case "--wait":
        args.wait = next();
        break;
      case "--grep":
        args.grep = next();
        break;
      case "--headed":
        args.headed = true;
        break;
      case "--timeout":
        args.timeout = Number(next());
        break;
      default:
        console.error(`Unknown flag: ${key}`);
        process.exit(2);
    }
  }

  if (!args.url) {
    console.error("Required: --url <url>");
    process.exit(2);
  }

  return args;
}

function matches(pattern, value) {
  if (!pattern) return true;
  return new RegExp(pattern).test(value);
}

const args = parseArgs(process.argv);
const browser = await chromium.launch({
  headless: !args.headed,
  channel: "chrome",
  chromiumSandbox: true,
});
const page = await browser.newPage({
  viewport: { width: args.vw, height: args.vh },
});

page.on("console", (message) => {
  console.log("[console]", message.type(), message.text());
});

page.on("pageerror", (error) => {
  console.log("[pageerror]", error.message);
});

page.on("requestfailed", (request) => {
  console.log("[requestfailed]", request.url(), request.failure()?.errorText);
});

page.on("response", (response) => {
  const url = response.url();
  if (matches(args.grep, url)) {
    console.log("[response]", response.status(), response.request().method(), url);
  }
});

try {
  await page.goto(args.url, { waitUntil: "networkidle", timeout: args.timeout });
  if (/^\d+$/.test(String(args.wait))) {
    await page.waitForTimeout(Number(args.wait));
  } else {
    await page.waitForSelector(String(args.wait), { timeout: args.timeout });
  }

  console.log("[final-url]", page.url());
  console.log(
    "[storage]",
    await page.evaluate(() => ({
      localStorageKeys: Object.keys(localStorage),
      sessionStorageKeys: Object.keys(sessionStorage),
    })),
  );
  console.log(
    "[body]",
    ((await page.textContent("body")) || "").replace(/\s+/g, " ").trim().slice(0, 500),
  );
} finally {
  await browser.close();
}
