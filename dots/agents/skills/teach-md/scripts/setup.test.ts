import { afterEach, beforeEach, expect, test } from "bun:test";
import { mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync, existsSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

let workspace: string;
beforeEach(() => { workspace = mkdtempSync(join(tmpdir(), "teach-md setup ")); });
afterEach(() => { rmSync(workspace, { recursive: true, force: true }); });

function setup() {
  return Bun.spawnSync([process.execPath, join(import.meta.dir, "setup.ts"), workspace], {
    stdout: "pipe", stderr: "pipe",
  });
}

test("setup preserves workspace content, reruns cleanly, and builds Markdown with Bun", () => {
  writeFileSync(join(workspace, "package.json"), JSON.stringify({
    name: "my-course", scripts: { check: "echo existing" },
    dependencies: { picocolors: "1.1.1" },
  }));
  writeFileSync(join(workspace, ".gitignore"), "keep-me");
  writeFileSync(join(workspace, "MISSION.md"), "My existing mission\n");

  const first = setup();
  expect(first.exitCode, first.stderr.toString()).toBe(0);
  const config = readFileSync(join(workspace, ".vitepress/config.mjs"), "utf8");
  const ignore = readFileSync(join(workspace, ".gitignore"), "utf8");
  const second = setup();
  expect(second.exitCode, second.stderr.toString()).toBe(0);
  expect(readFileSync(join(workspace, ".vitepress/config.mjs"), "utf8")).toBe(config);
  expect(readFileSync(join(workspace, ".gitignore"), "utf8")).toBe(ignore);
  expect(ignore).toBe("keep-me\n/node_modules/\n/.vitepress/cache/\n/.vitepress/dist/\n");
  expect(readFileSync(join(workspace, "MISSION.md"), "utf8")).toBe("My existing mission\n");
  const manifest = JSON.parse(readFileSync(join(workspace, "package.json"), "utf8"));
  expect(manifest.scripts.check).toBe("echo existing");
  expect(manifest.dependencies.picocolors).toBe("1.1.1");
  expect(manifest.devDependencies.vitepress).toContain("1.6.4");
  expect(existsSync(join(workspace, "bun.lock"))).toBe(true);

  mkdirSync(join(workspace, "lessons"));
  mkdirSync(join(workspace, "reference"));
  writeFileSync(join(workspace, "reference/example.md"), "# Reference\n");
  writeFileSync(join(workspace, "lessons/example.md"), `# Example

\`\`\`ts
const answer: number = 42;
\`\`\`

\`\`\`mermaid
flowchart TD
  Start --> Stop
\`\`\`

[Reference](../reference/example.md)
`);
  const build = Bun.spawnSync([process.execPath, "x", "--bun", "vitepress", "build", "."], {
    cwd: workspace, stdout: "pipe", stderr: "pipe",
  });
  expect(build.exitCode, build.stderr.toString()).toBe(0);
  const html = readFileSync(join(workspace, ".vitepress/dist/lessons/example.html"), "utf8");
  expect(html).toContain("language-ts");
  expect(html).toContain("--shiki-light:");
  expect(html).toContain('class="mermaid"');
  expect(html).toMatch(/href="(?:\.\/)?\.\.\/reference\/example\.html"/);
}, 120_000);

test("custom config is refused before changing the package or adding another config", () => {
  mkdirSync(join(workspace, ".vitepress"));
  const custom = 'export default { title: "Keep this" };\n';
  writeFileSync(join(workspace, ".vitepress/config.ts"), custom);
  const result = setup();
  expect(result.exitCode).not.toBe(0);
  expect(result.stderr.toString()).toContain("Preserving existing");
  expect(readFileSync(join(workspace, ".vitepress/config.ts"), "utf8")).toBe(custom);
  expect(existsSync(join(workspace, ".vitepress/config.mjs"))).toBe(false);
  expect(existsSync(join(workspace, "package.json"))).toBe(false);
});

test("invalid package.json is preserved and setup fails", () => {
  writeFileSync(join(workspace, "package.json"), "not JSON\n");
  expect(setup().exitCode).not.toBe(0);
  expect(readFileSync(join(workspace, "package.json"), "utf8")).toBe("not JSON\n");
  expect(existsSync(join(workspace, ".vitepress"))).toBe(false);
});
