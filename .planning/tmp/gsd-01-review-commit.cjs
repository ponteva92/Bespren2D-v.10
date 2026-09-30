#!/usr/bin/env node
"use strict";

const { spawnSync } = require("child_process");
const fs = require("fs");
const path = require("path");
const os = require("os");

const GSD_TOOLS = path.join(os.homedir(), ".claude", "gsd-core", "bin", "gsd-tools.cjs");
const cwd = process.cwd();
const reviewRel = path.join(
  ".planning",
  "phases",
  "01-map-audit-redesign-contract",
  "01-REVIEW.md"
);

const result = spawnSync(
  process.execPath,
  [
    GSD_TOOLS,
    "query",
    "commit",
    "docs(phase-01): code review skipped — markdown-only CONT-01 census/contract/proof",
    "--files",
    reviewRel,
  ],
  {
    cwd,
    encoding: "utf8",
    maxBuffer: 20 * 1024 * 1024,
    windowsHide: true,
  }
);

const payload = {
  status: result.status,
  signal: result.signal,
  error: result.error ? String(result.error) : null,
  stdout: result.stdout || "",
  stderr: result.stderr || "",
};

fs.mkdirSync(path.join(cwd, ".planning", "tmp"), { recursive: true });
fs.writeFileSync(
  path.join(cwd, ".planning", "tmp", "gsd-01-review-commit.json"),
  JSON.stringify(payload, null, 2),
  "utf8"
);

process.stdout.write(result.stdout || "");
process.stderr.write(result.stderr || "");
process.exit(result.status == null ? 1 : result.status);
