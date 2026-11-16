const assert = require("node:assert/strict");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { test } = require("node:test");
const { buildNotebook } = require("./build-notebook.cjs");
const { importNotebook, approvedFile } = require("./import-notebook.cjs");

test("publishes approved content without unapproved files, notes, or system tiddlers", () => {
  const sourceRoot = path.resolve(__dirname, "..");
  const fixture = fs.mkdtempSync(path.join(os.tmpdir(), "shaderacademy-public-test-"));
  try {
    const manifest = JSON.parse(fs.readFileSync(
      path.join(sourceRoot, "notebook", "public-content.json"), "utf8"
    ));
    for (const name of [
      ...manifest.projectFiles,
      ...manifest.notebookFiles.map((entry) => entry.path)
    ]) {
      const destination = path.join(fixture, ...name.split("/"));
      fs.mkdirSync(path.dirname(destination), { recursive: true });
      fs.copyFileSync(path.join(sourceRoot, ...name.split("/")), destination);
    }
    const manifestPath = path.join(fixture, "notebook", "public-content.json");
    const writeManifest = () => fs.writeFileSync(manifestPath, JSON.stringify(manifest));
    writeManifest();
    fs.writeFileSync(path.join(fixture, "g_buffer", "unapproved.md"),
      "UNAPPROVED_SOURCE_SENTINEL");
    fs.writeFileSync(path.join(fixture, "notebook", "tiddlers", "private.json"),
      JSON.stringify([
        { title: "Private note", tags: "Private", text: "PRIVATE_NOTE_SENTINEL" },
        { title: "$:/private/system", text: "PRIVATE_SYSTEM_SENTINEL" },
        { title: "Unapproved note", text: "UNAPPROVED_NOTE_SENTINEL" }
      ]));
    const publicNotePath = "notebook/tiddlers/public-note.json";
    const publicNoteFile = path.join(fixture, ...publicNotePath.split("/"));
    fs.writeFileSync(publicNoteFile, JSON.stringify([
      { title: "Approved note", tags: "[[Study Note]]", text: "APPROVED_NOTE_SENTINEL" }
    ]));
    manifest.notebookFiles.push({ path: publicNotePath, titles: ["Approved note"] });
    writeManifest();

    const imported = importNotebook(fixture);
    assert.ok(!imported.some((tiddler) => tiddler.title.includes("unapproved")));
    const output = path.join(fixture, "dist", "index.html");
    buildNotebook(fixture, output);
    const html = fs.readFileSync(output, "utf8");
    assert.ok(html.includes("APPROVED_NOTE_SENTINEL"));
    for (const marker of [
      "UNAPPROVED_SOURCE_SENTINEL", "PRIVATE_NOTE_SENTINEL",
      "PRIVATE_SYSTEM_SENTINEL", "UNAPPROVED_NOTE_SENTINEL"
    ]) {
      assert.ok(!html.includes(marker), `Leaked ${marker}`);
    }
    assert.ok(html.includes('"title":"GLOSSARY.md"'));
    assert.ok(html.includes('"title":"Interactive Demos Index"'));
    assert.ok(html.includes('"title":"docs/coordinate-demo.html"'));
    assert.ok(html.includes('"title":"interactive/interact_5/wave-demo.html"'));
    assert.ok(html.includes("sandbox"));
    assert.ok(html.includes("data:text/html;base64,"));

    const unexpectedArtifact = path.join(fixture, "dist", "unapproved.txt");
    fs.writeFileSync(unexpectedArtifact, "UNAPPROVED_ARTIFACT_SENTINEL");
    assert.throws(() => buildNotebook(fixture, output), /unapproved files/);
    fs.unlinkSync(unexpectedArtifact);

    fs.writeFileSync(publicNoteFile, JSON.stringify([
      { title: "Approved note", tags: "Private", text: "PRIVATE_NOTE_SENTINEL" }
    ]));
    assert.throws(() => buildNotebook(fixture, output), /cannot be published/);

    fs.writeFileSync(publicNoteFile, JSON.stringify([
      { title: "$:/private/system", text: "PRIVATE_SYSTEM_SENTINEL" }
    ]));
    manifest.notebookFiles.at(-1).titles = ["$:/private/system"];
    writeManifest();
    assert.throws(() => buildNotebook(fixture, output), /cannot be published/);
    assert.throws(() => approvedFile(fixture, sourceRoot), /relative strings/);
    assert.throws(() => approvedFile(fixture, ".."), /inside the repository/);
  } finally {
    fs.rmSync(fixture, { recursive: true, force: true });
  }
});
