#!/usr/bin/env node
import { readFile, writeFile, mkdir } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import { PNG } from "pngjs";

function parseArgs(argv) {
  const args = {
    threshold: 0.06,
    minRegionPixels: 30,
    maxRegions: 10,
    regionPadding: 12,
    boxes: true,
    alpha: 220,
    shiftDetect: true,
    shiftRange: 64,
    shiftStep: 4,
    shiftSample: 6,
  };

  for (let i = 2; i < argv.length; i += 1) {
    const key = argv[i];
    const next = () => argv[++i];
    switch (key) {
      case "--expected":
      case "--target":
      case "--a":
        args.expected = next();
        break;
      case "--actual":
      case "--b":
        args.actual = next();
        break;
      case "--out":
        args.out = next();
        break;
      case "--json":
        args.json = next();
        break;
      case "--compare-out":
        args.compareOut = next();
        break;
      case "--regions-dir":
        args.regionsDir = next();
        break;
      case "--region-padding":
        args.regionPadding = Number(next());
        break;
      case "--threshold":
        args.threshold = Number(next());
        break;
      case "--min-region-pixels":
        args.minRegionPixels = Number(next());
        break;
      case "--max-regions":
        args.maxRegions = Number(next());
        break;
      case "--alpha":
        args.alpha = Number(next());
        break;
      case "--shift-range":
        args.shiftRange = Number(next());
        break;
      case "--shift-step":
        args.shiftStep = Number(next());
        break;
      case "--shift-sample":
        args.shiftSample = Number(next());
        break;
      case "--no-shift-detect":
        args.shiftDetect = false;
        break;
      case "--no-boxes":
        args.boxes = false;
        break;
      case "--fail-over-percent":
        args.failOverPercent = Number(next());
        break;
      case "--fail-over-pixels":
        args.failOverPixels = Number(next());
        break;
      default:
        console.error(`Unknown flag: ${key}`);
        process.exit(2);
    }
  }

  if (!args.expected || !args.actual || !args.out) {
    console.error("Required: --expected <png> --actual <png> --out <diff.png>");
    process.exit(2);
  }

  if (!Number.isFinite(args.threshold) || args.threshold < 0 || args.threshold > 1) {
    console.error("--threshold must be a number from 0 to 1");
    process.exit(2);
  }

  if (!Number.isFinite(args.shiftRange) || args.shiftRange < 0) {
    console.error("--shift-range must be a non-negative number");
    process.exit(2);
  }

  if (!Number.isFinite(args.shiftStep) || args.shiftStep < 1) {
    console.error("--shift-step must be a positive number");
    process.exit(2);
  }

  if (!Number.isFinite(args.shiftSample) || args.shiftSample < 1) {
    console.error("--shift-sample must be a positive number");
    process.exit(2);
  }

  return args;
}

async function readPng(path) {
  return PNG.sync.read(await readFile(path));
}

function offset(width, x, y) {
  return (y * width + x) * 4;
}

function hasPixel(image, x, y) {
  return x >= 0 && y >= 0 && x < image.width && y < image.height;
}

function pixelDelta(expected, actual, x, y) {
  const expectedExists = hasPixel(expected, x, y);
  const actualExists = hasPixel(actual, x, y);

  if (!expectedExists || !actualExists) {
    return {
      differs: expectedExists !== actualExists,
      normalized: expectedExists === actualExists ? 0 : 1,
      sizeOnly: expectedExists !== actualExists,
      expectedExists,
      actualExists,
    };
  }

  const e = offset(expected.width, x, y);
  const a = offset(actual.width, x, y);
  const dr = expected.data[e] - actual.data[a];
  const dg = expected.data[e + 1] - actual.data[a + 1];
  const db = expected.data[e + 2] - actual.data[a + 2];
  const da = expected.data[e + 3] - actual.data[a + 3];
  const normalized = Math.sqrt(dr * dr + dg * dg + db * db + da * da) / (510);

  return { differs: false, normalized, sizeOnly: false, expectedExists, actualExists };
}

function grayscaleBase(expected, actual, x, y) {
  const source = hasPixel(actual, x, y) ? actual : expected;
  if (!hasPixel(source, x, y)) return [250, 250, 250, 255];

  const p = offset(source.width, x, y);
  const gray = Math.round(
    source.data[p] * 0.299 + source.data[p + 1] * 0.587 + source.data[p + 2] * 0.114,
  );
  const soft = Math.round(gray * 0.35 + 245 * 0.65);
  return [soft, soft, soft, 255];
}

function writePixel(image, x, y, rgba) {
  const p = offset(image.width, x, y);
  image.data[p] = rgba[0];
  image.data[p + 1] = rgba[1];
  image.data[p + 2] = rgba[2];
  image.data[p + 3] = rgba[3];
}

function drawBox(image, box, color) {
  const x1 = Math.max(0, box.x);
  const y1 = Math.max(0, box.y);
  const x2 = Math.min(image.width - 1, box.x + box.width - 1);
  const y2 = Math.min(image.height - 1, box.y + box.height - 1);

  for (let x = x1; x <= x2; x += 1) {
    writePixel(image, x, y1, color);
    writePixel(image, x, y2, color);
    if (y1 + 1 <= y2) writePixel(image, x, y1 + 1, color);
    if (y2 - 1 >= y1) writePixel(image, x, y2 - 1, color);
  }
  for (let y = y1; y <= y2; y += 1) {
    writePixel(image, x1, y, color);
    writePixel(image, x2, y, color);
    if (x1 + 1 <= x2) writePixel(image, x1 + 1, y, color);
    if (x2 - 1 >= x1) writePixel(image, x2 - 1, y, color);
  }
}

function fill(image, rgba) {
  for (let y = 0; y < image.height; y += 1) {
    for (let x = 0; x < image.width; x += 1) {
      writePixel(image, x, y, rgba);
    }
  }
}

function readPixel(image, x, y, fallback = [255, 255, 255, 255]) {
  if (!hasPixel(image, x, y)) return fallback;
  const p = offset(image.width, x, y);
  return [
    image.data[p],
    image.data[p + 1],
    image.data[p + 2],
    image.data[p + 3],
  ];
}

function pixelGray(image, x, y) {
  if (!hasPixel(image, x, y)) return null;
  const p = offset(image.width, x, y);
  const alpha = image.data[p + 3] / 255;
  const red = image.data[p] * alpha + 255 * (1 - alpha);
  const green = image.data[p + 1] * alpha + 255 * (1 - alpha);
  const blue = image.data[p + 2] * alpha + 255 * (1 - alpha);
  return red * 0.299 + green * 0.587 + blue * 0.114;
}

function shiftScore(expected, actual, dx, dy, sample) {
  const startX = Math.max(0, -dx);
  const startY = Math.max(0, -dy);
  const endX = Math.min(expected.width, actual.width - dx);
  const endY = Math.min(expected.height, actual.height - dy);

  if (endX <= startX || endY <= startY) {
    return { score: Number.POSITIVE_INFINITY, samples: 0, coverage: 0 };
  }

  let total = 0;
  let samples = 0;

  for (let y = startY; y < endY; y += sample) {
    for (let x = startX; x < endX; x += sample) {
      const expectedGray = pixelGray(expected, x, y);
      const actualGray = pixelGray(actual, x + dx, y + dy);
      if (expectedGray == null || actualGray == null) continue;
      total += Math.abs(expectedGray - actualGray);
      samples += 1;
    }
  }

  const maxPossibleSamples =
    Math.ceil(expected.height / sample) * Math.ceil(expected.width / sample);
  const coverage = maxPossibleSamples === 0 ? 0 : samples / maxPossibleSamples;
  const rawScore = samples === 0 ? Number.POSITIVE_INFINITY : total / samples / 255;
  const coveragePenalty = Math.max(0, 1 - coverage) * 0.08;
  return { score: rawScore + coveragePenalty, samples, coverage };
}

function detectShift(expected, actual, { shiftRange, shiftStep, shiftSample }) {
  const range = Math.round(shiftRange);
  const step = Math.round(shiftStep);
  const sample = Math.round(shiftSample);
  const zero = shiftScore(expected, actual, 0, 0, sample);
  let best = { dx: 0, dy: 0, ...zero };

  for (let dy = -range; dy <= range; dy += step) {
    for (let dx = -range; dx <= range; dx += step) {
      if (dx === 0 && dy === 0) continue;
      const candidate = shiftScore(expected, actual, dx, dy, sample);
      if (candidate.score < best.score) {
        best = { dx, dy, ...candidate };
      }
    }
  }

  const improvementPercent =
    Number.isFinite(zero.score) && zero.score > 0
      ? ((zero.score - best.score) / zero.score) * 100
      : 0;
  const likelyGlobalShift =
    Math.abs(best.dx) + Math.abs(best.dy) > 0 && improvementPercent >= 8;

  return {
    actualOffset: { x: best.dx, y: best.dy },
    suggestedCorrection: { x: -best.dx, y: -best.dy },
    zeroScore: Number(zero.score.toFixed(5)),
    bestScore: Number(best.score.toFixed(5)),
    improvementPercent: Number(improvementPercent.toFixed(2)),
    samples: best.samples,
    coverage: Number(best.coverage.toFixed(4)),
    range,
    step,
    sample,
    likelyGlobalShift,
    note: likelyGlobalShift
      ? "actual appears globally offset relative to expected; suggestedCorrection is the opposite movement"
      : "no strong global x/y offset found; inspect compare sheet and region crops",
  };
}

function copyRect(source, target, sourceRect, targetX, targetY, fallback) {
  for (let y = 0; y < sourceRect.height; y += 1) {
    for (let x = 0; x < sourceRect.width; x += 1) {
      writePixel(
        target,
        targetX + x,
        targetY + y,
        readPixel(source, sourceRect.x + x, sourceRect.y + y, fallback),
      );
    }
  }
}

function expandRect(rect, width, height, padding) {
  const x = Math.max(0, rect.x - padding);
  const y = Math.max(0, rect.y - padding);
  const right = Math.min(width, rect.x + rect.width + padding);
  const bottom = Math.min(height, rect.y + rect.height + padding);
  return {
    x,
    y,
    width: Math.max(1, right - x),
    height: Math.max(1, bottom - y),
  };
}

function makeTriptych({ expected, actual, diff, rect, gutter = 16 }) {
  const panelWidth = rect.width;
  const panelHeight = rect.height;
  const sheet = new PNG({
    width: panelWidth * 3 + gutter * 2,
    height: panelHeight,
  });
  fill(sheet, [255, 255, 255, 255]);

  copyRect(expected, sheet, rect, 0, 0, [255, 255, 255, 255]);
  copyRect(actual, sheet, rect, panelWidth + gutter, 0, [255, 255, 255, 255]);
  copyRect(diff, sheet, rect, (panelWidth + gutter) * 2, 0, [255, 255, 255, 255]);

  drawBox(sheet, { x: 0, y: 0, width: panelWidth, height: panelHeight }, [18, 73, 120, 255]);
  drawBox(
    sheet,
    { x: panelWidth + gutter, y: 0, width: panelWidth, height: panelHeight },
    [16, 130, 80, 255],
  );
  drawBox(
    sheet,
    { x: (panelWidth + gutter) * 2, y: 0, width: panelWidth, height: panelHeight },
    [220, 40, 70, 255],
  );

  return sheet;
}

function findRegions(mask, width, height, minPixels, maxRegions) {
  const visited = new Uint8Array(mask.length);
  const regions = [];
  const stack = [];

  for (let index = 0; index < mask.length; index += 1) {
    if (!mask[index] || visited[index]) continue;

    let pixels = 0;
    let minX = width;
    let minY = height;
    let maxX = 0;
    let maxY = 0;

    stack.push(index);
    visited[index] = 1;

    while (stack.length > 0) {
      const current = stack.pop();
      const x = current % width;
      const y = Math.floor(current / width);
      pixels += 1;
      if (x < minX) minX = x;
      if (x > maxX) maxX = x;
      if (y < minY) minY = y;
      if (y > maxY) maxY = y;

      const neighbors = [
        current - 1,
        current + 1,
        current - width,
        current + width,
      ];

      for (const next of neighbors) {
        if (next < 0 || next >= mask.length || visited[next] || !mask[next]) continue;
        const nx = next % width;
        const ny = Math.floor(next / width);
        if (Math.abs(nx - x) + Math.abs(ny - y) !== 1) continue;
        visited[next] = 1;
        stack.push(next);
      }
    }

    if (pixels >= minPixels) {
      regions.push({
        pixels,
        x: minX,
        y: minY,
        width: maxX - minX + 1,
        height: maxY - minY + 1,
      });
    }
  }

  regions.sort((a, b) => b.pixels - a.pixels);
  return regions.slice(0, maxRegions);
}

function summarize({
  args,
  expected,
  actual,
  width,
  height,
  unionPixels,
  diffPixels,
  comparablePixels,
  sizeOnlyPixels,
  allDiffBox,
  regions,
  shift,
}) {
  const canvasPixels = width * height;
  const diffPercent = unionPixels === 0 ? 0 : (diffPixels / unionPixels) * 100;
  return {
    expected: resolve(args.expected),
    actual: resolve(args.actual),
    diff: resolve(args.out),
    compare: args.compareOut ? resolve(args.compareOut) : null,
    regionsDir: args.regionsDir ? resolve(args.regionsDir) : null,
    expectedSize: { width: expected.width, height: expected.height },
    actualSize: { width: actual.width, height: actual.height },
    canvasSize: { width, height },
    dimensionMismatch:
      expected.width !== actual.width || expected.height !== actual.height,
    threshold: args.threshold,
    canvasPixels,
    unionPixels,
    diffPixels,
    diffPercent: Number(diffPercent.toFixed(4)),
    comparablePixels,
    sizeOnlyPixels,
    allDiffBox,
    regions,
    shift,
  };
}

const args = parseArgs(process.argv);
const expected = await readPng(args.expected);
const actual = await readPng(args.actual);
const shift = args.shiftDetect
  ? detectShift(expected, actual, args)
  : null;
const width = Math.max(expected.width, actual.width);
const height = Math.max(expected.height, actual.height);
const output = new PNG({ width, height });
const mask = new Uint8Array(width * height);

let diffPixels = 0;
let unionPixels = 0;
let sizeOnlyPixels = 0;
let minX = width;
let minY = height;
let maxX = -1;
let maxY = -1;
const comparablePixels = Math.min(expected.width, actual.width) * Math.min(expected.height, actual.height);

for (let y = 0; y < height; y += 1) {
  for (let x = 0; x < width; x += 1) {
    const index = y * width + x;
    const delta = pixelDelta(expected, actual, x, y);
    const inEitherImage = delta.expectedExists || delta.actualExists;
    const differs = delta.sizeOnly || delta.normalized > args.threshold;
    const base = grayscaleBase(expected, actual, x, y);

    if (inEitherImage) unionPixels += 1;

    if (!differs) {
      writePixel(output, x, y, base);
      continue;
    }

    diffPixels += 1;
    if (delta.sizeOnly) sizeOnlyPixels += 1;
    mask[index] = 1;
    if (x < minX) minX = x;
    if (x > maxX) maxX = x;
    if (y < minY) minY = y;
    if (y > maxY) maxY = y;

    const intensity = Math.max(0.35, Math.min(1, delta.normalized));
    const red = delta.sizeOnly ? 145 : 255;
    const green = delta.sizeOnly ? 55 : Math.round(40 * (1 - intensity));
    const blue = delta.sizeOnly ? 220 : Math.round(90 * (1 - intensity));
    writePixel(output, x, y, [red, green, blue, args.alpha]);
  }
}

const regions = findRegions(
  mask,
  width,
  height,
  args.minRegionPixels,
  args.maxRegions,
);

if (args.boxes) {
  for (const region of regions) drawBox(output, region, [0, 180, 255, 255]);
}

await mkdir(dirname(resolve(args.out)), { recursive: true });
await writeFile(resolve(args.out), PNG.sync.write(output));

const allDiffBox =
  diffPixels === 0
    ? null
    : { x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1 };

if (args.compareOut) {
  const compare = makeTriptych({
    expected,
    actual,
    diff: output,
    rect: { x: 0, y: 0, width, height },
  });
  await mkdir(dirname(resolve(args.compareOut)), { recursive: true });
  await writeFile(resolve(args.compareOut), PNG.sync.write(compare));
}

if (args.regionsDir) {
  const dir = resolve(args.regionsDir);
  await mkdir(dir, { recursive: true });
  for (let i = 0; i < regions.length; i += 1) {
    const rect = expandRect(regions[i], width, height, args.regionPadding);
    const crop = makeTriptych({ expected, actual, diff: output, rect, gutter: 10 });
    const name = `region-${String(i + 1).padStart(2, "0")}-x${rect.x}-y${rect.y}-w${rect.width}-h${rect.height}.png`;
    await writeFile(resolve(dir, name), PNG.sync.write(crop));
  }
}

const summary = summarize({
  args,
  expected,
  actual,
  width,
  height,
  unionPixels,
  diffPixels,
  comparablePixels,
  sizeOnlyPixels,
  allDiffBox,
  regions,
  shift,
});

if (args.json) {
  await mkdir(dirname(resolve(args.json)), { recursive: true });
  await writeFile(resolve(args.json), `${JSON.stringify(summary, null, 2)}\n`);
}

console.log(
  `OK ${summary.diff}: ${summary.diffPixels} px (${summary.diffPercent}%) differ, ${summary.regions.length} region(s) >= ${args.minRegionPixels}px`,
);
if (summary.dimensionMismatch) {
  console.log(
    `SIZE mismatch expected=${expected.width}x${expected.height} actual=${actual.width}x${actual.height}; size-only diff pixels=${sizeOnlyPixels}`,
  );
}
if (summary.compare) {
  console.log(`COMPARE ${summary.compare}`);
}
if (summary.regionsDir) {
  console.log(`REGION_CROPS ${summary.regionsDir}`);
}
if (summary.allDiffBox) {
  console.log(
    `BOX all x=${summary.allDiffBox.x} y=${summary.allDiffBox.y} w=${summary.allDiffBox.width} h=${summary.allDiffBox.height}`,
  );
}
if (summary.shift) {
  console.log(
    `SHIFT actualOffset x=${summary.shift.actualOffset.x} y=${summary.shift.actualOffset.y}; suggestedCorrection x=${summary.shift.suggestedCorrection.x} y=${summary.shift.suggestedCorrection.y}; improvement=${summary.shift.improvementPercent}%${summary.shift.likelyGlobalShift ? " likely-global-shift" : ""}`,
  );
}
summary.regions.forEach((region, index) => {
  console.log(
    `REGION ${index + 1} pixels=${region.pixels} x=${region.x} y=${region.y} w=${region.width} h=${region.height}`,
  );
});

if (
  (args.failOverPercent != null && summary.diffPercent > args.failOverPercent) ||
  (args.failOverPixels != null && summary.diffPixels > args.failOverPixels)
) {
  process.exit(1);
}
