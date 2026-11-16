const fs = require("node:fs");
const path = require("node:path");

const root = path.resolve(__dirname, "..");
const supported = new Set([".md", ".glsl", ".ts", ".html"]);
const interactiveDemos = {
  "docs/coordinate-demo.html": {
    title: "Axes & UV Explorer",
    description: "Explore how UV coordinates map to points on 3D surfaces.",
    height: 2100,
    guide: "[[3D axes and UV coordinate conventions|COORDINATE_CONVENTIONS.md]]"
  },
  "interactive/interact_5/wave-demo.html": {
    title: "Interactive Ripple Explorer",
    description: "Move the ripple center, adjust the wave controls, and compare the shader's wave and falloff views.",
    height: 2150,
    guide: "[[Step-by-step ripple shader explanation|interactive/interact_5/CODE_EXPLANATION.md]]"
  }
};

function approvedFile(root, relativePath) {
  if (typeof relativePath !== "string" || path.isAbsolute(relativePath)) {
    throw new Error("Public content paths must be repository-relative strings.");
  }
  const file = fs.realpathSync(path.resolve(root, relativePath));
  const relative = path.relative(fs.realpathSync(root), file);
  if (relative === ".." || relative.startsWith(`..${path.sep}`) ||
      path.isAbsolute(relative) || !fs.statSync(file).isFile()) {
    throw new Error("Public content must resolve to a file inside the repository.");
  }
  return file;
}

function importNotebook(root) {
  function titleFor(file) {
    return path.relative(root, file).split(path.sep).join("/");
  }

  const manifest = JSON.parse(fs.readFileSync(
    path.join(root, "notebook", "public-content.json"), "utf8"
  ));
  if (!Array.isArray(manifest.projectFiles)) {
    throw new Error("Public content manifest requires a projectFiles array.");
  }
  const files = manifest.projectFiles.map((name) => {
    const file = approvedFile(root, name);
    if (!supported.has(path.extname(file))) {
      throw new Error("Approved project files must be Markdown, GLSL, TypeScript, or a supported HTML demo.");
    }
    return file;
  });
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
    const source = fs.readFileSync(file, "utf8");
    if (path.extname(file) === ".html") {
      const demo = interactiveDemos[title];
      if (!demo) {
        throw new Error(`HTML project file is not a supported interactive demo: ${title}`);
      }
      const embeddedSource = source.replace(
        /<a href="(?:\.{1,2}\/)[^"]*">([\s\S]*?)<\/a>/g,
        "$1"
      );
      const embeddedData = Buffer.from(embeddedSource, "utf8").toString("base64");
      return {
        title,
        type: "text/vnd.tiddlywiki",
        tags: "[[Interactive Demo]] [[Reference]]",
        "source-path": title,
        text: `! ${demo.title}\n\n${demo.description}\n\n` +
          `<iframe title="${demo.title}" sandbox="allow-scripts" ` +
          `style="width: 100%; height: ${demo.height}px; border: 0; border-radius: 12px;" ` +
          `src="data:text/html;base64,${embeddedData}"></iframe>\n\n` +
          `Open the related guide: ${demo.guide}\n`
      };
    }

    const markdown = path.extname(file) === ".md";
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
    ["Interactive Demo", "Interactive Demos Index"],
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

  return tiddlers;
}

if (require.main === module) {
  const tiddlers = importNotebook(root);
  const output = path.join(root, "notebook", "tiddlers", "generated-project.json");
  fs.writeFileSync(output, `${JSON.stringify(tiddlers, null, 2)}\n`, "utf8");
  console.log(`Imported ${tiddlers.length - 4} approved project files and 4 indexes.`);
}

module.exports = { importNotebook, approvedFile };
