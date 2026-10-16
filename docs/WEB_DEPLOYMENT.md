# Godot Web Deployment

## Public site

- GitHub Pages URL: <https://jcodes101.github.io/Halloween_Game_Project3_COMP440/>
- Repository: <https://github.com/jcodes101/Halloween_Game_Project3_COMP440>
- Pages source: GitHub Actions (`build_type: workflow`), configured for the repository after approval.

The URL is the intended public destination. The initial production artifact has been built and passed a local HTTP asset smoke test. The public URL should be treated as deployed only after the Actions `Build and deploy Godot Web game` run completes and the live files are checked; see the deployment status at the end of this file.

## How deployment works

`.github/workflows/deploy-web.yml` runs on pushes to `main` and on manual `workflow_dispatch`. It installs Godot 4.7.2 on Ubuntu, prepares the matching single-threaded Web export templates, imports resources, runs the frontend, house, monster, Familiar, and legacy integration verification suites, then exports and checks `index.html`, `index.js`, `index.wasm`, and `index.pck`. The workflow publishes an artifact with GitHub's Pages actions. It does not commit generated build files to the source branch.

The build job has read-only repository contents permission. The deploy job receives only Pages write and OIDC identity-token permissions. A concurrency group prevents overlapping Pages deploys. The workflow creates `.nojekyll` in the generated artifact.

`tools/download_godot_web_templates.py` retrieves the version marker and only the debug/release no-thread Web template archives from the official Godot template package using validated byte ranges. This avoids downloading the approximately 1.28 GB all-platform package. The script verifies the version, ZIP CRCs, and presence of WebAssembly payloads.

## Export configuration

- Godot: 4.7.2 stable.
- Preset: `Web` in `export_presets.cfg`.
- Renderer: the existing Compatibility renderer, which uses the browser's WebGL 2 path.
- Thread support: disabled (`variant/thread_support=false`); no cross-origin isolation headers are needed for the Web build.
- Resource mode: all runtime resources, excluding `design/**`, `docs/**`, and `handoff/**`.
- Build output: `web-build/index.html` locally; the CI artifact is written to runner temporary storage.
- `/web-build/` is Git-ignored so local output is not accidentally committed.

The latest local production export contained:

| File | Size |
| --- | ---: |
| `index.html` | 5,444 bytes |
| `index.js` | 279,815 bytes |
| `index.wasm` | 39,514,754 bytes |
| `index.pck` | 45,189,848 bytes |
| **Core loader, runtime, and game data** | **84,989,861 bytes (~81.1 MiB)** |

The PCK includes runtime resources required by the active game. The size is an uncompressed file-size measurement, not a measured browser transfer or memory footprint.

## Build locally

1. Install Godot 4.7.2 stable and matching export templates.
2. Import the project once in Godot or run:

   ```powershell
   Godot_v4.7.2-stable_win64_console.exe --headless --path . --editor --quit --import
   ```

3. Export from the project root:

   ```powershell
   Godot_v4.7.2-stable_win64_console.exe --headless --path . --export-release Web web-build/index.html
   ```

4. Serve `web-build/` using HTTP. Do not open the HTML file directly with `file://`.

For a smaller local template setup, `python tools/download_godot_web_templates.py --version 4.7.2 --output <Godot-user-data>/export_templates/4.7.2.stable` downloads the official no-thread templates. On Windows, Godot's user template directory is normally `%APPDATA%\Godot\export_templates\4.7.2.stable`.

## Deployment triggers and status

- Push to `main`: build, test, export, and deploy.
- GitHub Actions **Run workflow**: manually start the same pipeline from the Actions tab.
- Run history: <https://github.com/jcodes101/Halloween_Game_Project3_COMP440/actions/workflows/deploy-web.yml>
- Pages settings: repository **Settings → Pages**, source should be **GitHub Actions**.

Initial inspection found that the site's root was a Jekyll placeholder, while an older Web export lived under `/docs/`. That export was stale relative to current `main`; it was not used as the new deployment artifact. The Pages source has been switched to Actions, so the current site updates after a successful workflow deployment.

**Status for this update:** the local production export and local HTTP checks passed. The first Actions deployment and live GitHub Pages response must be verified after the commit is pushed. Update this paragraph with the Actions run result, deployed revision, and live asset checks after that verification.

## Browser considerations

- The browser needs WebGL 2 and WebAssembly. The Compatibility renderer and no-thread export are used to avoid the multi-threaded build's cross-origin isolation requirement.
- Browsers generally unlock audio after a user gesture. Start the game with a click/key and check that browser audio is permitted.
- Mouse look uses browser pointer lock; a user click is normally required before capture. Esc may release pointer lock, so check the game's menu/resume flow after release.
- Browser keyboard input depends on the game canvas having focus. Click the canvas if keys do not reach the game.
- Fullscreen and pointer lock are browser-mediated and require user interaction.
- GitHub Pages paths are case-sensitive. Preserve the exact resource path casing used by Godot.
- The project uses no web extension/native plugin export and no multi-threaded WebAssembly setting was found. The local Web export completed without missing-resource errors.
- Actual WebGL rendering, keyboard/mouse play, audio playback, and gameplay memory use still require a browser session. Headless Godot and HTTP asset checks cannot establish those behaviors.
- The local runtime-plus-game payload is about 81.1 MiB before transport compression; first-load time depends on network and browser cache.

## Troubleshooting

1. Check the latest workflow run and identify whether failure occurred in template preparation, Godot import, a verification suite, export, artifact upload, or deploy.
2. Confirm the Pages source remains GitHub Actions and that the workflow has `pages: write` and `id-token: write` on its deploy job.
3. Confirm all four core files are in the artifact and the deployed URL serves them with HTTP 200. `index.wasm` should use a WebAssembly MIME type.
4. For a blank canvas, inspect browser console/network errors, verify WebGL 2 support, then hard-reload to clear an old cached loader/PCK pair.
5. If audio is silent, click the game canvas and check browser autoplay settings and the in-game Music/Master levels.
6. If mouse look fails, click the canvas to grant focus/pointer lock and use the pause/resume flow after releasing it.
7. Re-run the export with the same Godot version and Web templates; desktop exports use the existing separate Windows preset and are not replaced by this workflow.

## Validation record

For the local source revision audited on 2026-10-15:

- Frontend: 32 checks, 0 failures.
- House: 157 checks, 0 failures.
- Monster: 51 assertions, 0 failures.
- Familiar behavior: 79 passed, 0 failed.
- Legacy integration: 25 passed, 0 failed.
- Headless main-menu launch: exit 0.
- Production Web export: core HTML, JavaScript, WebAssembly, and PCK files generated.
- Local HTTP smoke test: all four core files returned HTTP 200; `index.wasm` was served as `application/wasm`.
- Automated browser playthrough: not run; no browser automation/runtime was available in this environment.

Godot also reported that this sandbox could not write its per-user `user://logs` directory and could not read the Windows root certificate store. These environment warnings did not cause the listed validation commands to fail. The monster navigation bake reports agent-size rounding warnings. The integration and house test harnesses reported ObjectDB/resource shutdown warnings after all assertions passed.

## Official references

- [Godot 4.7 exporting projects](https://docs.godotengine.org/en/4.7/tutorials/export/exporting_projects.html)
- [Godot 4.7 exporting for the Web](https://docs.godotengine.org/en/4.7/tutorials/export/exporting_for_web.html)
- [GitHub Pages publishing sources](https://docs.github.com/en/pages/getting-started-with-github-pages/configuring-a-publishing-source-for-your-github-pages-site)
- [GitHub Pages deployment workflow](https://docs.github.com/en/pages/getting-started-with-github-pages/using-custom-workflows-with-github-pages)
