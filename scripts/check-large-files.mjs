import { execSync } from "node:child_process";
import fs from "node:fs";

const maxSizeKb = Number.parseInt(process.env.MAX_FILE_SIZE_KB ?? "2048", 10);
const maxBytes = maxSizeKb * 1024;

const output = execSync("git diff --cached --name-only --diff-filter=AM", {
  encoding: "utf8",
}).trim();

if (!output) {
  process.exit(0);
}

const files = output.split("\n").filter(Boolean);
const offenders = [];

for (const file of files) {
  if (!fs.existsSync(file)) {
    continue;
  }
  const { size } = fs.statSync(file);
  if (size > maxBytes) {
    offenders.push({ file, size });
  }
}

if (offenders.length === 0) {
  process.exit(0);
}

console.error(`Large file check failed (limit ${maxSizeKb} KB).`);
for (const { file, size } of offenders) {
  const sizeKb = Math.ceil(size / 1024);
  console.error(`- ${file} (${sizeKb} KB)`);
}
console.error("Use Git LFS or reduce file size. Override with MAX_FILE_SIZE_KB.");
process.exit(1);
