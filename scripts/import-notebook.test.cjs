const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { execFileSync } = require("node:child_process");
const { test } = require("node:test");

const root = path.resolve(__dirname, "..");
execFileSync(process.execPath, [path.join(__dirname, "import-notebook.cjs")]);
const tiddlers = JSON.parse(fs.readFileSync(
  path.join(root, "notebook", "tiddlers", "generated-project.json"), "utf8"
));
const byTitle = new Map(tiddlers.map((tiddler) => [tiddler.title, tiddler]));

test("imports all supported project files with TiddlyWiki string fields", () => {
  function check(directory) {
    for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
      const file = path.join(directory, entry.name);
      if (entry.isDirectory()) {
        check(file);
      } else if (entry.isFile() && /\.(md|glsl|ts)$/.test(entry.name)) {
        const title = path.relative(root, file).split(path.sep).join("/");
        assert.ok(byTitle.has(title), `Missing ${title}`);
      }
    }
  }
  for (const directory of ["g_buffer", "materials", "procedural_mesh_basics"]) {
    check(path.join(root, directory));
  }
  assert.equal(byTitle.size, tiddlers.length);
  for (const tiddler of tiddlers) {
    for (const [field, value] of Object.entries(tiddler)) {
      assert.equal(typeof value, "string", `${tiddler.title}: ${field}`);
    }
  }
  assert.match(byTitle.get("GLOSSARY.md").tags, /\[\[Guide\]\]/);
});

test("rewrites repository links and retains fenced code", () => {
  const guide = byTitle.get("CODE_SNIPPETS.md").text;
  assert.match(guide, /\]\(#GLOSSARY\.md\)/);
  assert.match(guide, /\]\(#materials%2Flight_7%2Ffrag\.glsl\)/);
  const original = fs.readFileSync(path.join(root, "CODE_SNIPPETS.md"), "utf8");
  const codeBlocks = (text) => text.replace(/\r\n/g, "\n")
    .match(/```[\s\S]*?```/g);
  assert.deepEqual(codeBlocks(guide), codeBlocks(original));
});

test("wraps shader source verbatim in a fenced code block", () => {
  const title = "g_buffer/gbuffer_5/frag.glsl";
  const original = fs.readFileSync(
    path.join(root, ...title.split("/")), "utf8"
  );
  assert.ok(byTitle.get(title).text.includes(`\n${original}\n`));
  assert.match(byTitle.get(title).text, /```glsl/);
  assert.match(byTitle.get("G-Buffer Index").text, /<li><\$link/);
});
