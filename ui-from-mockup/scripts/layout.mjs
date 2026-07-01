#!/usr/bin/env node
import { chromium } from "playwright";
import { mkdir, writeFile } from "node:fs/promises";
import { dirname, resolve } from "node:path";

function parseArgs(argv) {
  const args = {
    vw: 1280,
    vh: 900,
    freeze: false,
    headed: false,
    timeout: 30000,
    maxElements: 300,
    minArea: 24,
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
      case "--headed":
        args.headed = true;
        break;
      case "--timeout":
        args.timeout = Number(next());
        break;
      case "--max-elements":
        args.maxElements = Number(next());
        break;
      case "--min-area":
        args.minArea = Number(next());
        break;
      default:
        console.error(`Unknown flag: ${key}`);
        process.exit(2);
    }
  }

  if (!args.url || !args.out) {
    console.error("Required: --url <url> --out <file.json>");
    process.exit(2);
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

const FREEZE_CSS = `*,*::before,*::after{
  animation: none !important;
  transition: none !important;
  animation-duration: 0s !important;
  animation-delay: 0s !important;
  transition-duration: 0s !important;
  scroll-behavior: auto !important;
}`;

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

async function snapshotLayout(page, args) {
  return page.evaluate(
    ({ selector, maxElements, minArea }) => {
      const viewport = {
        width: window.innerWidth,
        height: window.innerHeight,
        devicePixelRatio: window.devicePixelRatio,
        scrollX: window.scrollX,
        scrollY: window.scrollY,
      };

      const collapse = (value, limit = 160) => {
        const text = String(value || "").replace(/\s+/g, " ").trim();
        return text.length > limit ? `${text.slice(0, limit - 1)}...` : text;
      };

      const number = (value) => Number(value.toFixed(2));

      const serializeRect = (rect) => ({
        x: number(rect.x),
        y: number(rect.y),
        top: number(rect.top),
        right: number(rect.right),
        bottom: number(rect.bottom),
        left: number(rect.left),
        width: number(rect.width),
        height: number(rect.height),
      });

      const cssPath = (element) => {
        const parts = [];
        let current = element;
        while (current && current.nodeType === Node.ELEMENT_NODE && current !== document.documentElement) {
          const tag = current.tagName.toLowerCase();
          const id = current.getAttribute("id");
          if (id) {
            parts.unshift(`${tag}#${CSS.escape(id)}`);
            break;
          }

          const testId =
            current.getAttribute("data-testid") ||
            current.getAttribute("data-test") ||
            current.getAttribute("data-cy");
          if (testId) {
            parts.unshift(`${tag}[data-testid="${CSS.escape(testId)}"]`);
            current = current.parentElement;
            continue;
          }

          let nth = 1;
          let sibling = current.previousElementSibling;
          while (sibling) {
            if (sibling.tagName === current.tagName) nth += 1;
            sibling = sibling.previousElementSibling;
          }
          parts.unshift(`${tag}:nth-of-type(${nth})`);
          current = current.parentElement;
        }
        return parts.join(" > ");
      };

      const directText = (element) =>
        collapse(
          Array.from(element.childNodes)
            .filter((node) => node.nodeType === Node.TEXT_NODE)
            .map((node) => node.textContent)
            .join(" "),
        );

      const className = (element) => {
        const value = element.getAttribute("class") || "";
        return collapse(value, 180);
      };

      const root = selector ? document.querySelector(selector) : document.body;
      const rootMissing = selector && !root;
      const allElements = root ? [root, ...Array.from(root.querySelectorAll("*"))] : [];

      const semanticTags = new Set([
        "a",
        "article",
        "aside",
        "button",
        "canvas",
        "footer",
        "form",
        "h1",
        "h2",
        "h3",
        "h4",
        "h5",
        "h6",
        "header",
        "img",
        "input",
        "label",
        "li",
        "main",
        "nav",
        "p",
        "section",
        "select",
        "svg",
        "textarea",
        "video",
      ]);

      const elements = [];

      for (const element of allElements) {
        const rect = element.getBoundingClientRect();
        const style = getComputedStyle(element);
        const tag = element.tagName.toLowerCase();
        const role = element.getAttribute("role") || "";
        const ariaLabel = element.getAttribute("aria-label") || "";
        const testId =
          element.getAttribute("data-testid") ||
          element.getAttribute("data-test") ||
          element.getAttribute("data-cy") ||
          "";
        const text = directText(element) || (semanticTags.has(tag) ? collapse(element.innerText) : "");
        const area = rect.width * rect.height;
        const intersectsViewport =
          rect.right > 0 &&
          rect.bottom > 0 &&
          rect.left < viewport.width &&
          rect.top < viewport.height;
        const visible =
          intersectsViewport &&
          area >= minArea &&
          style.display !== "none" &&
          style.visibility !== "hidden" &&
          Number(style.opacity) !== 0;

        if (!visible) continue;

        const hasIdentity =
          Boolean(text) ||
          Boolean(role) ||
          Boolean(ariaLabel) ||
          Boolean(testId) ||
          Boolean(element.id) ||
          semanticTags.has(tag);
        const isLayoutSurface =
          area >= 400 &&
          ["block", "flex", "grid", "inline-flex", "inline-grid", "list-item"].includes(style.display);
        if (!hasIdentity && !isLayoutSurface) continue;

        elements.push({
          tag,
          path: cssPath(element),
          id: element.id || "",
          className: className(element),
          testId,
          role,
          ariaLabel: collapse(ariaLabel),
          text,
          rect: serializeRect(rect),
          area: number(area),
          style: {
            display: style.display,
            position: style.position,
            zIndex: style.zIndex,
            fontFamily: style.fontFamily,
            fontSize: style.fontSize,
            fontWeight: style.fontWeight,
            lineHeight: style.lineHeight,
            letterSpacing: style.letterSpacing,
            color: style.color,
            backgroundColor: style.backgroundColor,
            borderColor: style.borderColor,
            borderWidth: style.borderWidth,
            borderRadius: style.borderRadius,
            boxShadow: style.boxShadow,
            padding: `${style.paddingTop} ${style.paddingRight} ${style.paddingBottom} ${style.paddingLeft}`,
            margin: `${style.marginTop} ${style.marginRight} ${style.marginBottom} ${style.marginLeft}`,
            gap: style.gap,
            alignItems: style.alignItems,
            justifyContent: style.justifyContent,
            overflow: style.overflow,
          },
        });
      }

      return {
        url: window.location.href,
        title: document.title,
        capturedAt: new Date().toISOString(),
        selector: selector || null,
        selectorFound: !rootMissing,
        viewport,
        elementCount: elements.length,
        maxElements,
        elements: elements.slice(0, maxElements).map((element, index) => ({
          index,
          ...element,
        })),
      };
    },
    {
      selector: args.selector || "",
      maxElements: args.maxElements,
      minArea: args.minArea,
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

    const snapshot = await snapshotLayout(page, args);
    const outPath = resolve(args.out);
    await mkdir(dirname(outPath), { recursive: true });
    await writeFile(outPath, `${JSON.stringify(snapshot, null, 2)}\n`);
    console.log(
      `OK ${outPath}: ${snapshot.elements.length}/${snapshot.elementCount} elements (${args.vw}x${args.vh}${args.freeze ? " frozen" : ""}${args.selector ? ` selector=${args.selector}` : ""})`,
    );
  } finally {
    await browser.close();
  }
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
