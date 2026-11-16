"# shaderacademy" 
FOR SELF-STUDY ONLY

## Coordinate reference

See [3D axes and UV coordinate conventions](./COORDINATE_CONVENTIONS.md) for
Y-up geometry, per-face cube UVs, lathe unwrapping, and renderer-dependent settings.
Open the [interactive axes and UV explorer](./docs/coordinate-demo.html) locally
in a browser; it needs no dependencies or server. The notebook also includes
sandboxed interactive previews of this explorer and the
[ripple effect demo](./interactive/interact_5/wave-demo.html).

## TiddlyWiki notebook

The [notebook](./notebook/) combines the project guides, glossary, reusable snippets,
and GLSL/TypeScript source into a searchable TiddlyWiki site.

### Local editing

Requires Node.js 20 or newer. From the repository root:

```powershell
npm ci
npm run notebook:serve
```

Open <http://127.0.0.1:8080/>. New study notes are saved in
[notebook/tiddlers/](./notebook/tiddlers/). These notes are not published by default.
Stop the local server before importing or building again.

**Private notes must not be committed to a public repository.** Keep sensitive
notes outside the repository; the publication allowlist does not make tracked
files or Git history private.

Edit imported documentation and source in their original files. The importer
refreshes them on startup/build; editing imported tiddlers in the wiki does not
update the original files, and those edits will be overwritten on the next import.

### Build and publish

```powershell
npm run notebook:test
npm run notebook:build
```

This creates a self-contained `dist/index.html`. The
[GitHub Pages workflow](./.github/workflows/notebook-pages.yml) builds and publishes
it on pushes to the default branch, or when run manually on that branch.
In **Settings > Pages**, select **GitHub Actions** as the build source.
The deployment workflow reports the resulting Pages URL.

The published site does not save changes back to GitHub. Use the local editor
and commit authored tiddlers, or edit the source documents through the repository.
See the notebook's **Notebook Guide** tiddler for navigation and editing details.

### Approving public content

Only content explicitly listed in [public-content.json](./notebook/public-content.json)
is imported or published. New source files and study notes are excluded until approved.
The build uses an isolated notebook containing approved tiddlers and bundled runtime
plugins, not the entire local notebook.
It also rejects unexpected files in the publication output directory so they
cannot accidentally enter the Pages upload.

- Add reviewed source/document paths to `projectFiles`.
- Add reviewed `.tid` or `.json` note files to `notebookFiles`, with an exact list of
  the tiddler titles they contain.
- Tiddlers tagged `Private` or `Confidential`, and custom `$:/` system tiddlers,
  are rejected even if their file is listed. The three existing site settings
  are the only allowed authored system tiddlers.
- Review the complete contents, including metadata and embedded attachments,
  before approving or changing an approved file. Approval is not a secret scanner.
- Run tests and build, inspect the output, then commit only public content.

Previously published content or files in Git history remain accessible until
separately removed; this safeguard only controls future notebook builds.