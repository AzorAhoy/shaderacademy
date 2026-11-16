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

test("imports only approved project files with TiddlyWiki string fields", () => {
  const manifest = JSON.parse(fs.readFileSync(
    path.join(root, "notebook", "public-content.json"), "utf8"
  ));
  for (const title of manifest.projectFiles) {
    assert.ok(byTitle.has(title), `Missing ${title}`);
  }
  assert.equal(tiddlers.length, manifest.projectFiles.length + 4);
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

test("particle guides link to their imported shaders and each other", () => {
  for (const particle of ["particle_1", "particle_2"]) {
    const guide = byTitle.get(`particles/${particle}/CODE_EXPLANATION.md`);
    assert.ok(guide);
    for (const shader of ["vert.glsl", "frag.glsl"]) {
      const title = `particles/${particle}/${shader}`;
      assert.ok(byTitle.has(title));
      assert.ok(guide.text.includes(`](#${encodeURIComponent(title)})`));
    }
  }
  assert.ok(byTitle.get("particles/particle_2/CODE_EXPLANATION.md").text.includes(
    "](#particles%2Fparticle_1%2FCODE_EXPLANATION.md)"
  ));
});

test("imports approved interactive demos as sandboxed, embedded notebook pages", () => {
  const coordinateDemo = byTitle.get("docs/coordinate-demo.html");
  const rippleDemo = byTitle.get("interactive/interact_5/wave-demo.html");
  assert.ok(coordinateDemo);
  assert.ok(rippleDemo);
  for (const demo of [coordinateDemo, rippleDemo]) {
    assert.equal(demo.type, "text/vnd.tiddlywiki");
    assert.match(demo.tags, /\[\[Interactive Demo\]\]/);
    assert.match(demo.text, /sandbox="allow-scripts"/);
    assert.match(demo.text, /src="data:text\/html;base64,/);
  }
  assert.match(coordinateDemo.text, /Axes & UV Explorer/);
  assert.match(rippleDemo.text, /Interactive Ripple Explorer/);
  for (const [demo, marker] of [
    [coordinateDemo, 'id="uv"'],
    [rippleDemo, 'id="surface"']
  ]) {
    const match = demo.text.match(/src="data:text\/html;base64,([A-Za-z0-9+/=]+)"/);
    assert.ok(match);
    assert.ok(Buffer.from(match[1], "base64").toString("utf8").includes(marker));
  }
  assert.match(byTitle.get("Interactive Demos Index").text, /tag\[Interactive Demo\]/);
});
