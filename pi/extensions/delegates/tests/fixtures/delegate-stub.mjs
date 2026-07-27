#!/usr/bin/env node
import { spawn } from "node:child_process";
import { appendFileSync, writeFileSync } from "node:fs";

const args = process.argv.slice(2);
const command = args[0];

if (command === "large") {
  process.stdout.write("x".repeat(128 * 1024));
  process.stderr.write("e".repeat(128 * 1024));
} else if (command === "sleep") {
  setTimeout(() => process.stdout.write("done\n"), 30_000);
} else if (command === "tree") {
  const child = spawn(process.execPath, [new URL(import.meta.url).pathname, "ignore"], {
    detached: false,
    stdio: "ignore",
  });
  if (process.env.STUB_PID_FILE) writeFileSync(process.env.STUB_PID_FILE, String(child.pid));
  process.on("SIGTERM", () => {});
  setInterval(() => {}, 1000);
} else if (command === "ignore") {
  process.on("SIGTERM", () => {});
  setInterval(() => {}, 1000);
} else if (command === "index") {
  if (process.env.STUB_ARGS_FILE) appendFileSync(process.env.STUB_ARGS_FILE, `${JSON.stringify(args)}\n`);
  process.stdout.write("indexed\n");
  process.exit(process.env.STUB_FAIL === "1" ? 2 : 0);
} else if (command === "search") {
  if (process.env.STUB_ARGS_FILE) appendFileSync(process.env.STUB_ARGS_FILE, `${JSON.stringify(args)}\n`);
  process.stdout.write("delegate search match\n");
} else if (args.includes("stream-json")) {
  process.stdout.write(`${JSON.stringify({ type: "system", session_id: "s" })}\n`);
  process.stdout.write(`${JSON.stringify({ type: "assistant", message: { content: [{ type: "text", text: "partial" }] } })}\n`);
  process.stdout.write(`${JSON.stringify({ type: "future_event", value: 1 })}\n`);
  process.stdout.write("{not json}\n");
  process.stdout.write(`${JSON.stringify({ type: "result", subtype: "success", is_error: false, result: "final cursor answer" })}\n`);
} else {
  let input = "";
  process.stdin?.setEncoding("utf8");
  process.stdin?.on("data", (chunk) => (input += chunk));
  process.stdin?.on("end", () => process.stdout.write(input || args.at(-1) || "ok"));
}
