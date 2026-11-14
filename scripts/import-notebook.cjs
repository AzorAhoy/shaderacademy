const fs = require("node:fs");
const path = require("node:path");

const root = path.resolve(__dirname, "..");
const contentRoots = ["g_buffer", "materials", "procedural_mesh_basics"];
const rootGuides = ["README.md", "GLOSSARY.md", "CODE_SNIPPETS.md"];
const supported = new Set([".md", ".glsl", ".ts"]);

function collect(directory) {
  return fs.readdirSync(directory, { withFileTypes: true })
    .sort((a, b) => a.name.localeCompare(b.name, "en"))
    .flatMap((entry) => {
      const fullPath = path.join(directory, entry.name);
      if (entry.isDirectory()) {
        return collect(fullPath);
      }
      return entry.isFile() && supported.has(path.extname(entry.name))
        ? [fullPath]
        : [];
    });
}

function titleFor(file) {
  return path.relative(root, file).split(path.sep).join("/");
}

const files = [
  ...rootGuides.map((file) => path.join(root, file)),
  ...contentRoots.flatMap((directory) => collect(path.join(root, directory)))
];
const titles = new Set(files.map(titleFor));

function convertLink(target, sourceFile) {
  if (/^(?:[a-z][a-z0-9+.-]*:|\/\/)/i.test(target)) {
    return target;
  }
  const pathname = target.split("#")[0];
  const file = pathname
    ? path.resolve(path.dirname(sourceFile), decodeURIComponent(pathname))
    : sourceFile;
  const title = titleFor(file);
  return titles.has(title) ? `#${encodeURIComponent(title)}` : target;
}

function convertMarkdown(text, file) {
  let inFence = false;
  let fenceChar;
  let fenceLength;
  return text.split(/\r?\n/).map((line) => {
    const fence = line.match(/^ {0,3}(`{3,}|~{3,})/);
    if (fence) {
      if (!inFence) {
        inFence = true;
        fenceChar = fence[1][0];
        fenceLength = fence[1].length;
      } else if (fence[1][0] === fenceChar && fence[1].length >= fenceLength) {
        inFence = false;
      }
      return line;
    }
    if (inFence) {
      return line;
    }
    return line.replace(
      /(?<!!)\[([^\]\n]+)\]\(([^)\s]+)\)/g,
      (_, label, target) => `[${label}](${convertLink(target, file)})`
    );
  }).join("\n");
}

function categoryFor(title) {
  if (title.startsWith("g_buffer/")) return "G-Buffer";
  if (title.startsWith("materials/")) return "Materials";
  if (title.startsWith("procedural_mesh_basics/")) return "Procedural Mesh";
  return "Reference";
}

const tiddlers = files.map((file) => {
  const title = titleFor(file);
  const markdown = path.extname(file) === ".md";
  const source = fs.readFileSync(file, "utf8");
  const language = path.extname(file) === ".glsl" ? "glsl" : "typescript";
  const longestRun = Math.max(2, ...Array.from(
    source.matchAll(/`+/g), (match) => match[0].length
  ));
  const fence = "`".repeat(longestRun + 1);
  return {
    title,
    type: "text/markdown",
    tags: `[[${markdown ? "Guide" : "Source Code"}]] [[${categoryFor(title)}]]`,
    "source-path": title,
    text: markdown
      ? convertMarkdown(source, file)
      : `# ${title}\n\n\`\`${title}\`\`\n\n${fence}${language}\n${source}\n${fence}\n`
  };
});

for (const [category, title] of [
  ["G-Buffer", "G-Buffer Index"],
  ["Materials", "Materials Index"],
  ["Procedural Mesh", "Procedural Mesh Index"]
]) {
  tiddlers.push({
    title,
    tags: "Navigation",
    type: "text/vnd.tiddlywiki",
    text: `! ${category}\n\n<ul>\n<$list filter="[tag[${category}]sort[title]]">\n<li><$link to=<<currentTiddler>>><$view field="title"/></$link></li>\n</$list>\n</ul>\n`
  });
}

const allTitles = tiddlers.map((tiddler) => tiddler.title);
if (new Set(allTitles).size !== allTitles.length) {
  throw new Error("Duplicate imported notebook titles.");
}

const output = path.join(root, "notebook", "tiddlers", "generated-project.json");
fs.writeFileSync(output, `${JSON.stringify(tiddlers, null, 2)}\n`, "utf8");
console.log(`Imported ${files.length} project files and 3 indexes into the notebook.`);
