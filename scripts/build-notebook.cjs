const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { execFileSync } = require("node:child_process");
const { importNotebook, approvedFile } = require("./import-notebook.cjs");

function buildNotebook(root, output) {
  const outputDirectory = path.dirname(output);
  if (fs.existsSync(outputDirectory) && fs.readdirSync(outputDirectory)
    .some((name) => name !== path.basename(output))) {
    throw new Error("Publication output directory contains unapproved files.");
  }
  const manifest = JSON.parse(fs.readFileSync(
    path.join(root, "notebook", "public-content.json"), "utf8"
  ));
  if (!Array.isArray(manifest.notebookFiles)) {
    throw new Error("Public content manifest requires a notebookFiles array.");
  }

  const tw = require("tiddlywiki/boot/boot.js").TiddlyWiki();
  tw.boot.argv = [];
  tw.boot.boot();

  const tiddlers = importNotebook(root);
  const allowedSettings = new Set([
    "$:/SiteTitle", "$:/SiteSubtitle", "$:/DefaultTiddlers"
  ]);
  for (const entry of manifest.notebookFiles) {
    if (!Array.isArray(entry.titles) || entry.titles.length === 0 ||
        entry.titles.some((title) => typeof title !== "string")) {
      throw new Error("Each public notebook file needs an explicit list of titles.");
    }
    const file = approvedFile(root, entry.path);
    if (![".tid", ".json"].includes(path.extname(file))) {
      throw new Error("Public notebook files must be .tid or .json.");
    }
    const loaded = tw.loadTiddlersFromFile(file).tiddlers;
    if (loaded.length !== entry.titles.length ||
        loaded.some((tiddler) => !entry.titles.includes(tiddler.title))) {
      throw new Error("Public notebook file titles do not match the approved list.");
    }
    for (const tiddler of loaded) {
      const tags = tw.utils.parseStringArray(tiddler.tags || "");
      if (tags.some((tag) => /^(private|confidential)$/i.test(tag)) ||
          (tiddler.title.startsWith("$:/") && !allowedSettings.has(tiddler.title))) {
        throw new Error("Private-tagged notes and custom system tiddlers cannot be published.");
      }
      tiddlers.push(tiddler);
    }
  }
  if (new Set(tiddlers.map((tiddler) => tiddler.title)).size !== tiddlers.length) {
    throw new Error("Public notebook contains duplicate tiddler titles.");
  }

  const staging = fs.mkdtempSync(path.join(os.tmpdir(), "shaderacademy-public-"));
  try {
    fs.mkdirSync(path.join(staging, "tiddlers"));
    fs.writeFileSync(path.join(staging, "tiddlers", "public.json"),
      JSON.stringify(tiddlers), "utf8");
    fs.writeFileSync(path.join(staging, "tiddlywiki.info"), JSON.stringify({
      plugins: ["tiddlywiki/markdown", "tiddlywiki/highlight"],
      themes: ["tiddlywiki/vanilla", "tiddlywiki/snowwhite"]
    }), "utf8");
    execFileSync(process.execPath, [
      require.resolve("tiddlywiki/tiddlywiki.js"),
      staging, "--output", staging,
      "--rendertiddler", "$:/core/save/all", "index.html", "text/plain"
    ], { stdio: "pipe" });
    fs.mkdirSync(path.dirname(output), { recursive: true });
    fs.copyFileSync(path.join(staging, "index.html"), output);
  } finally {
    fs.rmSync(staging, { recursive: true, force: true });
  }
  console.log(`Published ${tiddlers.length} explicitly approved tiddlers.`);
}

if (require.main === module) {
  const root = path.resolve(__dirname, "..");
  buildNotebook(root, path.join(root, "dist", "index.html"));
}

module.exports = { buildNotebook };
