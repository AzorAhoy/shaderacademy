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

test("snippet topic index scrolls to every anchored section in the notebook", () => {
  const guide = byTitle.get("CODE_SNIPPETS.md").text;
  for (const id of [...Array.from({ length: 23 }, (_, index) => String(index + 1)), "checklist"]) {
    assert.ok(guide.includes(`<a id="snippet-${id}"></a>`), `Missing anchor ${id}`);
    assert.ok(guide.includes(`$message="tm-scroll" selector="#snippet-${id}"`), `Missing link ${id}`);
  }
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
  for (const particle of ["particle_1", "particle_2", "particle_4", "particle_5", "particle_6"]) {
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
  for (const [source, target] of [
    ["particle_4", "particle_2"],
    ["particle_5", "particle_6"],
    ["particle_6", "particle_5"]
  ]) {
    assert.ok(byTitle.get(`particles/${source}/CODE_EXPLANATION.md`).text.includes(
      `](#${encodeURIComponent(`particles/${target}/CODE_EXPLANATION.md`)})`
    ));
  }
});

test("transform guides link to their imported vertex and fragment shaders", () => {
  for (let lesson = 1; lesson <= 10; lesson++) {
    const base = `transforms/transform_${lesson}`;
    const guide = byTitle.get(`${base}/CODE_EXPLANATION.md`);
    assert.ok(guide, `Missing ${base} guide`);
    assert.ok(guide.text.includes("](#transforms%2Ftransform-demo.html)"));
    for (const shader of ["vert.glsl", "frag.glsl"]) {
      const title = `${base}/${shader}`;
      assert.ok(byTitle.has(title), `Missing ${title}`);
      assert.ok(guide.text.includes(`](#${encodeURIComponent(title)})`));
    }
  }
});

test("reference guides link to the transformation lessons and explorer", () => {
  for (const [guide, targets] of [
    ["CODE_SNIPPETS.md", ["transforms/README.md", "transforms/transform_8/CODE_EXPLANATION.md"]],
    ["COORDINATE_CONVENTIONS.md", ["transforms/transform-demo.html", "transforms/transform_10/CODE_EXPLANATION.md"]],
    ["GLOSSARY.md", ["transforms/README.md", "transforms/transform_8/vert.glsl"]]
  ]) {
    const text = byTitle.get(guide).text;
    for (const target of targets) {
      assert.ok(byTitle.has(target), `Missing ${target}`);
      assert.ok(text.includes(`](#${encodeURIComponent(target)})`), `${guide} does not link to ${target}`);
    }
  }
});

test("scanline guide links to its imported shaders", () => {
  const guide = byTitle.get("uv/uv_4/CODE_EXPLANATION.md");
  assert.ok(guide);
  for (const shader of ["vert.glsl", "frag.glsl"]) {
    const title = `uv/uv_4/${shader}`;
    assert.ok(byTitle.has(title));
    assert.ok(guide.text.includes(`](#${encodeURIComponent(title)})`));
  }
});

test("height-map guide links to its imported shaders", () => {
  const base = "procedural_mountains/height_map_3";
  const guide = byTitle.get(`${base}/CODE_EXPLANATION.md`);
  assert.ok(guide);
  for (const shader of ["vert.glsl", "frag.glsl"]) {
    const title = `${base}/${shader}`;
    assert.ok(byTitle.has(title));
    assert.ok(guide.text.includes(`](#${encodeURIComponent(title)})`));
  }
});

test("updated references link to approved examples and embed the lathe illustration", () => {
  const snippets = byTitle.get("CODE_SNIPPETS.md").text;
  const glossary = byTitle.get("GLOSSARY.md").text;
  for (const title of [
    "image_transitions/image_transition_1/frag.glsl",
    "procedural_mesh_basics/lathe_1/scene.ts",
    "procedural_mesh_basics/lathe_1/CODE_EXPLANATION.md"
  ]) {
    assert.ok(byTitle.has(title), `Missing ${title}`);
    assert.ok(snippets.includes(`](#${encodeURIComponent(title)})`));
  }
  assert.ok(glossary.includes("](#image_transitions%2Fimage_transition_1%2Ffrag.glsl)"));
  const illustrationTitle = "procedural_mesh_basics/lathe_1/radius-profile.svg";
  const illustration = byTitle.get(illustrationTitle);
  assert.equal(illustration.type, "image/svg+xml");
  const guide = byTitle.get("procedural_mesh_basics/lathe_1/CODE_EXPLANATION.md").text;
  assert.ok(guide.includes(`<$image source="${illustrationTitle}" alt="Plot of the radius function`));
  assert.ok(illustration.text.includes("<svg "));
  assert.ok(guide.includes(`](#${encodeURIComponent(illustrationTitle)})`));
});

test("imports approved interactive demos as sandboxed, embedded notebook pages", () => {
  const coordinateDemo = byTitle.get("docs/coordinate-demo.html");
  const rippleDemo = byTitle.get("interactive/interact_5/wave-demo.html");
  const transformDemo = byTitle.get("transforms/transform-demo.html");
  assert.ok(coordinateDemo);
  assert.ok(rippleDemo);
  assert.ok(transformDemo);
  assert.ok(byTitle.get("transforms/README.md").text.includes("](#transforms%2Ftransform-demo.html)"));
  for (const demo of [coordinateDemo, rippleDemo, transformDemo]) {
    assert.equal(demo.type, "text/vnd.tiddlywiki");
    assert.match(demo.tags, /\[\[Interactive Demo\]\]/);
    assert.match(demo.text, /sandbox="allow-scripts"/);
    assert.match(demo.text, /src="data:text\/html;base64,/);
  }
  assert.match(coordinateDemo.text, /Axes & UV Explorer/);
  assert.match(rippleDemo.text, /Interactive Ripple Explorer/);
  assert.match(transformDemo.text, /Transformation Explorer/);
  for (const [demo, marker] of [
    [coordinateDemo, 'id="uv"'],
    [rippleDemo, 'id="surface"'],
    [transformDemo, 'id="after"']
  ]) {
    const match = demo.text.match(/src="data:text\/html;base64,([A-Za-z0-9+/=]+)"/);
    assert.ok(match);
    assert.ok(Buffer.from(match[1], "base64").toString("utf8").includes(marker));
  }
  assert.match(byTitle.get("Interactive Demos Index").text, /tag\[Interactive Demo\]/);
});
