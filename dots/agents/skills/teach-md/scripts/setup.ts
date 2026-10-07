#!/usr/bin/env bun
import { existsSync, mkdirSync, readFileSync, readdirSync, appendFileSync, writeFileSync } from "node:fs";
import { join, resolve } from "node:path";

if (Bun.argv.length > 3) {
  console.error("Usage: bun setup.ts [teaching-workspace]");
  process.exit(1);
}

const workspace = resolve(Bun.argv[2] ?? process.cwd());
const configDir = join(workspace, ".vitepress");
const configPath = join(configDir, "config.mjs");
const config = `import { withMermaid } from "vitepress-plugin-mermaid";

export default withMermaid({
  title: "Learning workspace",
  vite: {
    server: { host: "127.0.0.1" },
  },
});
`;

try {
  // A customized config needs a deliberate merge, not a second competing config.
  if (existsSync(configDir)) {
    for (const name of readdirSync(configDir).filter(name => name.startsWith("config."))) {
      const path = join(configDir, name);
      if (path !== configPath || readFileSync(path, "utf8") !== config) {
        throw new Error(`Preserving existing ${path}. Merge Mermaid and localhost settings manually before continuing.`);
      }
    }
  }

  const packagePath = join(workspace, "package.json");
  if (existsSync(packagePath)) {
    const manifest = JSON.parse(readFileSync(packagePath, "utf8"));
    if (!manifest || typeof manifest !== "object" || Array.isArray(manifest)) {
      throw new Error(`${packagePath} must contain a JSON object.`);
    }
  }

  mkdirSync(workspace, { recursive: true });
  if (!existsSync(packagePath)) {
    writeFileSync(packagePath, '{"private": true}\n', { flag: "wx" });
  }

  // Stay on VitePress 1 until the Mermaid plugin supports VitePress 2.
  const install = Bun.spawnSync([
    process.execPath, "add", "--dev",
    "vitepress@1.6.4", "vitepress-plugin-mermaid@2.0.17", "mermaid@11",
  ], { cwd: workspace, stdout: "inherit", stderr: "inherit" });
  if (install.exitCode !== 0) {
    throw new Error("Dependency installation failed. Fix the Bun error above and rerun setup.");
  }

  mkdirSync(configDir, { recursive: true });
  if (!existsSync(configPath)) writeFileSync(configPath, config, { flag: "wx" });

  const ignorePath = join(workspace, ".gitignore");
  const ignored = existsSync(ignorePath) ? readFileSync(ignorePath, "utf8") : "";
  const entries = ["/node_modules/", "/.vitepress/cache/", "/.vitepress/dist/"];
  const missing = entries.filter(entry => !ignored.split(/\r?\n/).includes(entry));
  if (missing.length) {
    appendFileSync(ignorePath, (ignored && !ignored.endsWith("\n") ? "\n" : "") + missing.join("\n") + "\n");
  }

  console.log(`Ready: ${workspace}\nFrom this workspace, run: bunx --bun vitepress dev . --open /lessons/<lesson-name>.html`);
} catch (error) {
  console.error(`Setup failed: ${error instanceof Error ? error.message : error}`);
  process.exit(1);
}
