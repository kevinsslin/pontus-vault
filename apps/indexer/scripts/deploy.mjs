import { spawnSync } from "node:child_process";
import { createRequire } from "node:module";

const require = createRequire(import.meta.url);
const pkg = require("../package.json");

const nameAndVersion =
  process.env.GOLDSKY_SUBGRAPH_NAME || `pontus-vault/${pkg.version}`;

const res = spawnSync(
  "goldsky",
  ["subgraph", "deploy", nameAndVersion, "--path", "."],
  { stdio: "inherit" },
);

process.exit(res.status ?? 1);

