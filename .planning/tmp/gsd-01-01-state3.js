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

run(["state.update-progress"]);
run([
  "state.record-session",
  "--stopped-at", "Completed 01-01-PLAN.md",
  "--resume-file", "None",
]);

const commit = run([
  "commit",
  "docs(01-01): complete live 14x14 census plan",
  "--files",
  ".planning/phases/01-map-audit-redesign-contract/01-01-SUMMARY.md",
  ".planning/STATE.md",
  ".planning/ROADMAP.md",
]);

console.log("\nFINAL COMMIT ENVELOPE:");
console.log(commit);
