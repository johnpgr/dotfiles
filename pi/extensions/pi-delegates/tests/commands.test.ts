import assert from "node:assert/strict";
import test from "node:test";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import delegatesExtension from "../index.ts";

test("extension registers explicit commands and delegate tools", () => {
    const commands = new Set<string>();
    const tools = new Set<string>();
    let renderers = 0;
    const api = {
        registerCommand(name: string) {
            commands.add(name);
        },
        registerEntryRenderer() {
            renderers++;
        },
        registerTool(definition: { name: string }) {
            tools.add(definition.name);
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
    assert.deepEqual([...tools].sort(), [
        "delegate_cancel",
        "delegate_check",
        "delegate_list",
        "delegate_spawn",
        "delegate_wait",
    ]);
    assert.equal(renderers, 1);
});
