const { spawnSync } = require("child_process");

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
  if (r.status) process.exit(r.status);
  return r.stdout || "";
}

run([
  "state.record-metric",
  "--phase", "01",
  "--plan", "01",
  "--duration", "6min",
  "--tasks", "2",
  "--files", "1",
]);

const decisions = [
  [
    "Audit quotes live .gd constants; WORLD_MAP_FOUNDATION.md 576/23/150 are drift, not rewritten",
    "D-26: census from src/world and tests, not foundation prose",
  ],
  [
    "No camp dirt spur exists today; D-02 remains a contract invention",
    "Eight routes; none terminate at (9950, 2400)",
  ],
  [
    "Wilderness pocket 2 vs OstariSouthShell recorded; MAXIMUM_UNHOSTABLE_POCKETS stays 1",
    "D-19: name the overlap, do not move the pocket",
  ],
  [
    "Wild-atlas runtime_promotion remains forbidden_pending_human_visual_veto; no Rect2 copied into src",
    "T-01-02: audit must not promote forbidden frames",
  ],
  [
    "LAYOUT_VERSION 2 and WORLD_BUILD_SEED 0xB35E7E frozen this plan",
    "D-28: Phase 1 does not bump layout or seed",
  ],
];

for (const [summary, rationale] of decisions) {
  run([
    "state.add-decision",
    "--phase", "01",
    "--summary", summary,
    "--rationale", rationale,
  ]);
}

console.log("\nMETRIC AND DECISIONS OK");
