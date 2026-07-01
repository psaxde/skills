#!/usr/bin/env node
import { chromium } from "playwright";
import { mkdir } from "node:fs/promises";
import { dirname, resolve } from "node:path";

function parseArgs(argv) {
  const args = {
    vw: 1280,
    vh: 900,
    full: false,
    freeze: false,
    frames: 1,
    interval: 120,
    headed: false,
    timeout: 30000,
    ls: [],
    ss: [],
    cookie: [],
  };

  for (let i = 2; i < argv.length; i += 1) {
    const key = argv[i];
    const next = () => argv[++i];
    switch (key) {
      case "--url":
        args.url = next();
        break;
      case "--out":
        args.out = next();
        break;
      case "--vw":
        args.vw = Number(next());
        break;
      case "--vh":
        args.vh = Number(next());
        break;
      case "--full":
        args.full = true;
        break;
      case "--selector":
        args.selector = next();
        break;
      case "--wait":
        args.wait = next();
        break;
      case "--ls":
        args.ls.push(next());
        break;
      case "--ss":
        args.ss.push(next());
        break;
      case "--cookie":
        args.cookie.push(next());
        break;
      case "--freeze":
        args.freeze = true;
        break;
      case "--click":
        args.click = next();
        break;
      case "--frames":
        args.frames = Number(next());
        break;
      case "--interval":
        args.interval = Number(next());
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

  if (!args.url || !args.out) {
    console.error("Required: --url <url> --out <file.png>");
    process.exit(2);
  }

  if (args.freeze && args.frames > 1) {
    console.error("Warning: --freeze + --frames will produce identical frames.");
  }

  return args;
}

function originOf(url) {
  try {
    return new URL(url).origin;
  } catch {
    return null;
  }
}

function parsePairs(items) {
  return items.map((entry) => {
    const index = entry.indexOf("=");
    if (index === -1) return [entry, ""];
    return [entry.slice(0, index), entry.slice(index + 1)];
  });
}

function framePath(out, index) {
  const match = out.match(/^(.*?)(\.[^./\\]+)?$/);
  return `${match[1]}-f${index}${match[2] || ".png"}`;
}

const FREEZE_CSS = `*,*::before,*::after{
  animation: none !important;
  transition: none !important;
  animation-duration: 0s !important;
  animation-delay: 0s !important;
  transition-duration: 0s !important;
  scroll-behavior: auto !important;
}`;

async function capture(page, args, outPath) {
  await mkdir(dirname(outPath), { recursive: true });
  if (args.selector) {
    const element = await page.waitForSelector(args.selector, {
      timeout: args.timeout,
    });
    await element.screenshot({ path: outPath });
    return;
  }
  await page.screenshot({ path: outPath, fullPage: args.full });
}

async function seedBrowserState(context, page, args) {
  const origin = originOf(args.url);
  if (!origin || origin === "null") return;

  if (args.cookie.length > 0) {
    const cookies = parsePairs(args.cookie).map(([name, value]) => ({
      name,
      value,
      url: origin,
    }));
    await context.addCookies(cookies);
  }

  if (args.ls.length === 0 && args.ss.length === 0) return;

  await page.goto(origin, {
    waitUntil: "domcontentloaded",
    timeout: args.timeout,
  });

  await page.evaluate(
    ({ localPairs, sessionPairs }) => {
      for (const [key, value] of localPairs) localStorage.setItem(key, value);
      for (const [key, value] of sessionPairs) sessionStorage.setItem(key, value);
    },
    {
      localPairs: parsePairs(args.ls),
      sessionPairs: parsePairs(args.ss),
    },
  );
}

async function main() {
  const args = parseArgs(process.argv);
  const browser = await chromium.launch({ headless: !args.headed });
  const context = await browser.newContext({
    viewport: { width: args.vw, height: args.vh },
    reducedMotion: args.freeze ? "reduce" : "no-preference",
  });
  const page = await context.newPage();

  try {
    await seedBrowserState(context, page, args);
    await page.goto(args.url, { waitUntil: "networkidle", timeout: args.timeout });

    if (args.freeze) await page.addStyleTag({ content: FREEZE_CSS });

    if (args.wait) {
      if (/^\d+$/.test(args.wait)) {
        await page.waitForTimeout(Number(args.wait));
      } else {
        await page.waitForSelector(args.wait, { timeout: args.timeout });
      }
    }

    if (args.click) await page.click(args.click, { timeout: args.timeout });

    if (args.frames > 1) {
      const written = [];
      for (let i = 0; i < args.frames; i += 1) {
        const outPath = resolve(framePath(args.out, i));
        await capture(page, args, outPath);
        written.push(outPath);
        if (i < args.frames - 1) await page.waitForTimeout(args.interval);
      }
      console.log(
        `OK ${args.frames} frames @${args.interval}ms (${args.vw}x${args.vh}): ${written[0]} ... ${written[written.length - 1]}`,
      );
      return;
    }

    const outPath = resolve(args.out);
    await capture(page, args, outPath);
    console.log(
      `OK ${outPath} (${args.vw}x${args.vh}${args.full ? " fullPage" : ""}${args.freeze ? " frozen" : ""}${args.selector ? ` selector=${args.selector}` : ""})`,
    );
  } finally {
    await browser.close();
  }
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
