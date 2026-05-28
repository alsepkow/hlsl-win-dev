# Agent Instructions

Instructions for AI coding agents (GitHub Copilot CLI, Codex, etc.) working in
this development tree. These rules apply to every repo checked out beneath
`F:\hlsl-win-dev` (DirectXShaderCompiler, llvm-project, offload-test-suite,
offload-golden-images, and any future additions).

## Pull requests require explicit approval

**Never open or edit pull requests without an explicit instruction from me in
the current turn.**

Specifically, you must NOT run any of the following without me asking for it,
by name, in the message you are currently responding to:

- `gh pr create` (in any form, including `--web`, `--draft`, or via the API)
- `gh pr edit` (title, body, base, reviewers, labels, draft state, etc.)
- `gh pr ready` / `gh pr merge` / `gh pr close` / `gh pr reopen`
- Any equivalent REST or GraphQL call against the `pulls` endpoint
- Any MCP or scripted helper that wraps the above

"Explicit" means a direct instruction such as "open a PR", "create a draft PR",
"update the PR description", "mark it ready for review". A general request like
"fix this bug" or "push the change" is **not** authorization to open or edit a
PR.

If you believe a PR action is the obvious next step, **stop and ask first**.

## What you may do without asking

- `git commit` on local branches.
- `git push` (non-force, fast-forward) to my fork (`origin`) on branches I
  own. Pushing a branch does not open a PR.
- `git fetch`, `git pull`, `git rebase`, `git merge` on local branches.
- Read-only `gh` commands: `gh pr view`, `gh pr list`, `gh pr diff`,
  `gh run view`, `gh run list`, `gh api` for GET requests, etc.

## Do not force-push without explicit approval

**Never force-push (`--force` or `--force-with-lease`) without an explicit
instruction from me in the current turn.** This applies to every branch,
on every remote, including my own fork.

Force-pushing rewrites history that may already be visible to reviewers
(via an open PR, a shared link, or someone's local checkout), so it has
the same disruptive effect as editing a PR out from under reviewers —
that's why this rule mirrors the "do not open/edit PRs without approval"
rule above.

What this means in practice:

- A first-time push of a new topic branch is fine (no history to rewrite).
- A normal fast-forward push that just adds new commits on top of the
  existing remote tip is fine.
- Any push that requires `--force` / `--force-with-lease` — after
  `git commit --amend`, `git rebase`, `git reset`, or any history rewrite
  — needs an explicit "force-push it" / "amend and push" instruction from
  me **for that specific push**. A prior approval doesn't carry over to
  subsequent pushes.

If you've rewritten history and need to push, **stop and ask first**.

## Do not rewrite history without explicit approval

**Never amend, squash, rebase, or otherwise rewrite commit history without
an explicit instruction from me in the current turn.** This applies to
every branch, including ones that are still local and haven't been pushed.

Specifically, you must NOT run any of the following without me asking for
it, by name, in the message you are currently responding to:

- `git commit --amend` (changing message, adding files, or anything else —
  even on a commit you just made yourself).
- `git rebase` in any form (interactive or non-interactive, `-i` with
  `squash`/`fixup`/`reword`, plain `git rebase <base>`, etc.).
- `git merge --squash`.
- `git reset --soft <older-commit>` / `git reset --hard <older-commit>`
  followed by re-committing (squash or rewrite via reset).
- `gh pr merge --squash` / `gh pr merge --rebase`.
- Any other workflow that alters existing commit objects or collapses
  multiple commits into fewer.

The reasoning is the same as for force-push and PR edits: history rewrites
disrupt anyone reviewing or building on top of the branch, and they often
imply a follow-up force-push. If you think amending, squashing, or
rebasing would improve the history, **stop and ask first**.

Acceptable phrasings to request approval:

> "Want me to amend the tip commit to fix the typo and force-push?"
> "Want me to squash these 3 commits into one before pushing?"
> "OK to rebase this branch onto the latest upstream/main?"

Wait for an explicit yes before doing it.

## Build before pushing

**Before `git push`-ing any branch that contains code changes, verify the
affected component builds successfully.** A green build is a precondition for
pushing.

What "build" means depends on the change:

- C/C++ changes in `llvm-project`, `offload-test-suite`, or
  `DirectXShaderCompiler`: build the smallest target that exercises the
  changed code (e.g. the specific binary or unit-test executable), not the
  whole tree, unless the change is genuinely cross-cutting.
- PowerShell / scripting changes in `hlsl-win-dev` itself: run the script
  end-to-end on the affected code path (or `Invoke-ScriptAnalyzer` if no
  runnable path exists).
- Pure documentation / markdown / `.gitignore` / `AGENTS.md` / CI YAML edits
  with no code impact: no build needed. Use judgment — if in doubt, build.

If you also have tests directly covering the change, run those after the
build (smallest targeted test selector that covers the change).

### When a build is impractical

If the affected build target takes hours, requires hardware you don't have
access to, or is otherwise impractical to run in the current session, **stop
and ask** before pushing. Do not silently skip the build. Acceptable phrasings
to request an exception:

> "The full link of `clang` would take ~40 minutes here — OK to push without
> a local build and rely on CI?"

Wait for an explicit yes before pushing.

### Build failures

If the build fails, **do not push**. Fix the failure (or revert the change)
and re-build. Only push once the build is green.

## Run clang-format before pushing (mirror CI)

The LLVM / DXC / offload-test-suite PR CI runs the
`llvm-project/llvm/utils/git/code-format-helper.py` script, which invokes
`git-clang-format` against the PR's merge-base with the base branch.
**Run the equivalent locally before pushing any branch with C/C++ changes**,
so the PR doesn't bounce on formatting.

### Per-repo clang-format version

Match the version pinned in the repo's `pr-code-format` workflow exactly —
output differs between major versions, and CI is strict:

| Repo                       | clang-format version | Source of truth                                   |
| -------------------------- | -------------------- | ------------------------------------------------- |
| `llvm-project`             | 19.1.6               | `.github/workflows/pr-code-format.yml` (container `ghcr.io/llvm/ci-ubuntu-24.04-format`) |
| `offload-test-suite`       | 19.1.6               | `.github/workflows/pr-code-format.yml`            |
| `DirectXShaderCompiler`    | 17.0.1               | `.github/workflows/clang-format-checker.yml`      |

If the workflow file pins a different version than the table above, **the
workflow file wins** — re-check it before running. Use a versioned binary
(`clang-format-19`, `clang-format-17`) or a venv'd install so you don't
silently pick up a system version.

### How to run it (the CI equivalent)

From the repo root, on your topic branch:

```sh
# 1. Identify the merge-base with the branch you intend to PR against
#    (usually origin/main, sometimes upstream/main).
MERGE_BASE=$(git merge-base upstream/main HEAD)

# 2. Show what clang-format would change on the diff between merge-base and HEAD.
git clang-format --binary clang-format-19 --diff "$MERGE_BASE"

# 3. If the diff is non-empty, apply it:
git clang-format --binary clang-format-19 "$MERGE_BASE"
```

For an exact mirror of the CI script (useful when you want to confirm CI
will be happy):

```sh
python llvm-project/llvm/utils/git/code-format-helper.py \
  --start-rev "$(git merge-base upstream/main HEAD)" \
  --end-rev HEAD \
  --changed-files "$(git diff --name-only "$(git merge-base upstream/main HEAD)" HEAD | paste -sd, -)"
```

If neither command produces a diff, formatting is clean and you can push.

### Handling formatting changes

- If the formatter only touches lines you modified, fold the fix into the
  same commit (`git add -u && git commit --amend` — allowed because it's
  amending the tip commit from this session, not a squash).
- If the formatter wants to reformat lines you did **not** modify (drive-by
  reformatting of nearby code), **stop and ask** — those changes don't
  belong in the PR by default.
- Never push with a non-empty `git clang-format --diff` output without my
  explicit approval.

- Never push to `upstream` remotes (e.g. `llvm/*`). Only push to `origin`
  (my fork).
- Never push to `main` / `master` on any remote.
- When I do authorize a force-push, prefer `--force-with-lease` over
  `--force`.

## Writing style (commits & PR descriptions)

- Keep commit messages and PR descriptions concise — usually 1–2 sentences
  in the body. Prefer a broad, high-level overview ("what changed and why,
  in one breath") over an enumeration of individual details. This applies
  to **every individual commit**, not just the PR description, because
  reviewers skim `git log` and need each subject + body to be quick to
  read. Long explanations of the investigation, alternatives considered,
  validation steps, etc. belong in the chat, not in the commit or PR. If
  the reviewer needs more, they can ask.
- Include the standard trailer on agent-authored commits:
  `Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>`
- Match the surrounding repo's conventions for subject style (e.g.
  `[component] Short summary` in llvm-project / offload-test-suite).

### AI attribution

When attributing AI assistance in a commit trailer or PR description:

- Use only the model name and version, nothing else.
  - Good: `Assisted by Claude Opus 4.7`, `Assisted-by: Claude Opus 4.7`
  - Bad: `Assisted by Claude Opus 4.7 (High reasoning)(Internal only)`,
    `Assisted by Claude Opus 4.7 (claude-opus-4.7-high)`,
    `Assisted by Claude Opus 4.7 — model ID claude-opus-4.7-high`
- Never include internal-only qualifiers, model IDs, reasoning-mode tags,
  context-window variants, or any other parenthetical decoration.
- Do **not** add a horizontal rule (`---`) before the attribution line in
  PR descriptions. Just place the attribution as the final line, separated
  from the body by a single blank line.
