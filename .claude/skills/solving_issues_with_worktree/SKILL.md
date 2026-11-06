---
name: solving_issues_with_worktree
description: The process for solving an issue or bug in MINDFul.jl — each issue is fixed in its own git worktree inside the repo (`.worktrees/<topic>`) on a new branch `fix/<topic>`, documented in a git-ignored `issuedescription.md`, covered by a minimal regression test, and verified with the full test suite before the user merges it. Use this skill whenever the user asks to fix, solve or analyze an issue, a bug or a review item in MINDFul.jl ("next issue", "item 6", "fix this bug"), picks the next entry from `ISSUES.md`, or asks to merge such a fix.
---

# Solving issues with a worktree

Each issue is solved on its own branch in a worktree **inside** the repository. The user evaluates the branch, e.g. with `git -C .worktrees/<topic> diff`, or with `:Neogit cwd=.worktrees/<topic>` in Neovim, and decides when to merge.

`test/tmp/` is **not used** any more. Older analyses in `test/tmp/review/` are a read-only archive.

## Standing rules
- Always cite code as `path:line`, never a bare "line N".
- Ignore the distributed/HTTP code: `server.jl`, `ibn_distributed.jl`, `HTTPMessages.jl`, RemoteHTTPHandler, RSA/TLS.
- Julia is not on PATH; use `~/.juliaup/bin/julia`. For which environment to use, see the `mindful-environments` skill.
- Fixes follow the existing mechanics, with the smallest change that fixes the issue.
  - The user has other compilation algorithms in another repository. Don't change interface signatures (`policiesinterfaces.jl`, the `IntentCompilationAlgorithm` hooks), and keep the user's algorithm logic, e.g. existing loops and fallbacks.
  - When the behaviour of an interface function changes, list it under compatibility.
- **Never commit unless the user asks.** The user usually commits.

## 1. Pick the issue
The tracker is `ISSUES.md` at the repo root. It is git-ignored and lists issues ordered by importance, with a status column.
- Take the most important open item, or the one the user names.
- For details, read the referenced archive entry in `test/tmp/review/<area>/FINDINGS.md`.

## 2. Create the worktree
Run from the main checkout:
```
git worktree add -b fix/<topic> .worktrees/<topic> main
cp Manifest.toml .worktrees/<topic>/
cp test/Manifest.toml .worktrees/<topic>/test/
```
- The Manifests are git-ignored, so they must be copied.
- `test/Manifest.toml` has `path = ".."` for MINDFul, so tests run in the worktree load the worktree's own `src/`.
- `.worktrees/` is git-ignored, so the main checkout's `git status` stays clean.
- `issuedescription.md` must be ignored in every worktree. It is in `.gitignore` and also in `.git/info/exclude`; the latter is shared by all worktrees, so it is ignored even on a branch whose `.gitignore` predates the entry. Check with `git -C .worktrees/<topic> check-ignore issuedescription.md`.
- **All edits happen in the worktree.** Never edit `src/` or the tests of the main checkout for an issue.

## 3. Write `.worktrees/<topic>/issuedescription.md`
It is git-ignored and never committed. Sections:
1. **Problem**: what goes wrong, observed vs. expected, with concrete numbers or return codes.
2. **Where in the source**: every relevant `path:line`, with the code quoted.
3. **Why it is wrong**: the reasoning, e.g. the invariant or the documented contract it violates.
4. **Solution**: what was changed and why this way, as `path:line` in the worktree. Mention a better but more invasive alternative only if it matters.
5. **Compatibility**: which behaviour changes for other code or algorithms, and what the user's other repository should check.
6. **Tests**: what the new test checks, that it fails on `main` and passes on the branch, and the full-suite result.

Keep it readable: short paragraphs and lists, no padding.

## 4. Reproduce and fix
- Reproduce scripts and logs go into the **session scratchpad**, never into the repo or `test/tmp/`.
  - A script starts with `include("<repo>/test/initialize.jl")`.
  - Run it with `~/.juliaup/bin/julia --project=test <script>`; run it from the worktree to load the worktree's `src`.
- Apply the fix in the worktree.

## 5. Tests: as few as needed
The test suite is already large, so add the **smallest** test that would have caught the issue.
- Prefer adding a few `@test`s to an existing `test/testsuite/*.jl` file that covers the same area.
- Create a new file only when no existing file fits. A new file needs an `include` in `test/runtests.jl`, inside a `@testset ExtendedTestSet "<file>.jl"` like the others.
- Avoid loops over many algorithms or configurations unless that variation is what the issue is about.
- Confirm the test **fails against main's `src`**, e.g. by running it from the main checkout or with the fix reverted, and passes on the branch.

## 6. Verify
Run the full suite from the worktree, in the background (about 5 minutes):
```
~/.juliaup/bin/julia --project=test test/runtests.jl > <scratchpad>/fullsuite_<topic>.log 2>&1; echo "exit $?"
```
Report the exit code and the summary of every affected test file. If something unrelated fails, say so; don't hide it.

## 7. Report to the user
- The branch and the worktree path, and how to view the changes: `git -C .worktrees/<topic> diff`, or `:Neogit cwd=...`.
- A short summary of the fix with `path:line`, and any compatibility notes.
- The test results.
- That `issuedescription.md` holds the full explanation.

Then wait for the user to evaluate.

## 8. Merge (only when the user says so)
1. Commit on the branch inside the worktree. End the message with the attribution line from the system reminder.
2. In the main checkout, run `git merge --ff-only fix/<topic>`. If that is not possible, ask the user.
3. Run the full suite on main.
4. Set the item's status in `ISSUES.md` to `FIXED (<commit>)`.
5. Offer to clean up with `git worktree remove .worktrees/<topic>` and `git branch -d fix/<topic>`. Do it only if the user agrees.
