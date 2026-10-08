# Git workflow for the partner

Repository: https://github.com/jcodes101/Halloween_Game_Project3_COMP440

## Start from the published handoff

If you do not have a local copy:

```powershell
git clone https://github.com/jcodes101/Halloween_Game_Project3_COMP440.git
cd Halloween_Game_Project3_COMP440
```

With a clean working tree, start an environment work branch:

```powershell
git switch main
git pull --ff-only origin main
git switch -c environment-house-partner
```

If you already have uncommitted work, preserve it before switching branches. Do not reset or discard it.

## Save a completed checkpoint

```powershell
git status --short
git add <specific-files-or-folders-you-changed>
git diff --cached --stat
git commit -m "Build house layout"
git push -u origin environment-house-partner
```

Replace the placeholder with actual paths. Keep `memory/`, download archives, Godot caches, and credentials out of commits. Review staged files before committing. The existing `.gitignore` excludes `memory/` and `downloads/`; add appropriate Godot cache exclusions when the project is created.

## Publish to main

Prefer a GitHub pull request from `environment-house-partner` into `main`, with layout screenshots and a short account of actual playtesting. Merge after the team's required review.

If the team allows a direct merge and your working tree is clean:

```powershell
git switch main
git pull --ff-only origin main
git merge environment-house-partner
git push origin main
```

If Git reports conflicts or branch protection blocks the push, resolve conflicts with the team or use the required pull request process. Do not force-push `main`.
