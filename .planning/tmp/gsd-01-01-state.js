const { spawnSync } = require("child_process");
const path = require("path");

const GSD = "C:\\Users\\heikk\\.claude\\gsd-core\\bin\\gsd-tools.cjs";
const ROOT = "C:\\Users\\heikk\\Desktop\\Claude\\gpt_peli";

function run(args) {
  const r = spawnSync("node", [GSD, "query", ...args], {
    cwd: ROOT,
    encoding: "utf8",
  });
  process.stdout.write(`\n--- ${args.join(" ")} ---\n`);
  process.stdout.write(r.stdout || "");
  if (r.stderr) process.stderr.write(r.stderr);
  if (r.status) {
    process.exit(r.status);
  }
  return r.stdout || "";
}

run(["state.advance-plan"]);
run(["state.update-progress"]);
run(["state.record-metric", "01", "01", "6", "2", "1"]);

const decisions = [
  "Audit quotes live .gd constants; WORLD_MAP_FOUNDATION.md 576/23/150 are drift, not rewritten",
  "No camp dirt spur exists today; D-02 remains a contract invention",
  "Wilderness pocket 2 vs OstariSouthShell recorded; MAXIMUM_UNHOSTABLE_POCKETS stays 1",
  "Wild-atlas runtime_promotion remains forbidden_pending_human_visual_veto; no Rect2 copied into src",
  "LAYOUT_VERSION 2 and WORLD_BUILD_SEED 0xB35E7E frozen this plan",
];
for (const d of decisions) {
  run(["state.add-decision", d]);
}

run([
  "state.record-session",
  "",
  "Completed 01-01-PLAN.md",
  "None",
]);

run(["roadmap.update-plan-progress", "01"]);

console.log("\nSTATE UPDATES OK");
