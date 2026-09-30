#!/usr/bin/env node
"use strict";

const { spawnSync } = require("child_process");
const fs = require("fs");
const path = require("path");
const os = require("os");

const GSD_TOOLS = path.join(os.homedir(), ".claude", "gsd-core", "bin", "gsd-tools.cjs");
const cwd = process.cwd();
const outDir = path.join(cwd, ".planning", "tmp");
fs.mkdirSync(outDir, { recursive: true });

function run(args, outName) {
  const result = spawnSync(process.execPath, [GSD_TOOLS, ...args], {
    cwd,
    encoding: "utf8",
    maxBuffer: 20 * 1024 * 1024,
    windowsHide: true,
  });
  const payload = {
    args,
    status: result.status,
    signal: result.signal,
    error: result.error ? String(result.error) : null,
    stdout: result.stdout || "",
    stderr: result.stderr || "",
  };
  const dest = path.join(outDir, outName);
  fs.writeFileSync(dest, JSON.stringify(payload, null, 2), "utf8");
  return payload;
}

const jobs = [
  [["query", "init.plan-phase", "1"], "init-plan-phase.json"],
  [["query", "agent-skills", "gsd-phase-researcher"], "agent-skills-researcher.json"],
  [["query", "agent-skills", "gsd-planner"], "agent-skills-planner.json"],
  [["query", "agent-skills", "gsd-plan-checker"], "agent-skills-checker.json"],
  [["query", "config-get", "context_window"], "config-context-window.json"],
  [["query", "config-get", "workflow.mvp_mode"], "config-mvp-mode.json"],
  [["query", "roadmap.get-phase", "1"], "roadmap-phase-1.json"],
  [["query", "phase.mvp-mode", "1", "--pick", "active"], "phase-mvp-mode.json"],
  [["loop", "render-hooks", "plan:pre", "--raw"], "plan-pre-hooks.json"],
  [["query", "config-get", "workflow.discuss_mode"], "config-discuss-mode.json"],
  [["query", "config-get", "workflow.plan_chunked"], "config-plan-chunked.json"],
];

for (const [args, outName] of jobs) {
  run(args, outName);
}

console.log("WROTE", jobs.length, "results to", outDir);
