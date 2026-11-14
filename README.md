"# shaderacademy" 
FOR SELF-STUDY ONLY

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
[notebook/tiddlers/](./notebook/tiddlers/); commit them to keep your changes.
Stop the local server before importing or building again.

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