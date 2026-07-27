import assert from "node:assert/strict";
import test from "node:test";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import delegatesExtension from "../index.js";

test("extension registers explicit commands and no model-facing tools", () => {
  const commands = new Set<string>();
  let renderers = 0;
  let tools = 0;
  const api = {
    registerCommand(name: string) {
      commands.add(name);
    },
    registerEntryRenderer() {
      renderers++;
    },
    registerTool() {
      tools++;
    },
    on() {},
  } as unknown as ExtensionAPI;
  delegatesExtension(api);
  assert.deepEqual([...commands].sort(), [
    "delegate-agent",
    "delegate-agy",
    "delegate-attach",
    "delegate-claude",
    "delegate-codex",
    "delegate-result",
    "delegate-search",
    "delegate-status",
    "delegate-stop",
  ]);
  assert.equal(renderers, 1);
  assert.equal(tools, 0);
});
