# Running the harness on your host or agent

The harness is a set of scripts plus a contract. What changes between hosts
is who launches the agent and whether the subagent runtime is available. Every
path below is relative to the repository root, never absolute.

## What works everywhere

All of this needs only `bash`, `git` and `node`:

- `scripts/spec` (new, lint, approve, start, verify), `scripts/route`,
  `scripts/rmaestro`, `scripts/verify`.
- `scripts/rutas` (list, lint, log, stats) and `scripts/diagrama`.
- `.githooks/` (pre-commit, commit-msg): enable them with
  `git config core.hooksPath .githooks`.
- `config/`, `templates/` and the tests under `tests/`.

## Pick your host

| You use | Do this |
|---|---|
| **Claude Code desktop app** | Open the repository, run `/rmaestro <id>` in the chat. The subagent workflows run through `scripts/ruta`. Permissions are granted by you in the app; `.claude/settings.json` has the versioned allow and deny lists. |
| **A terminal with `claude`** | `scripts/rmaestro <id>` prints the mode; then follow `templates/MODE.md.<mode>` in an interactive `claude` session started in the worktree. |
| **Headless (CI, cron, a remote box)** | `scripts/ruta directo <id>` or `scripts/ruta exhaustivo <id> --fase plan` then `--fase impl --plan <json>`. It runs `claude -p` once, reads the workflow output file and logs the run to `sessions/rutas.jsonl`. Use `--dry-run` first to see the exact command. Needs the `claude` binary on `PATH` and a login. |
| **Another agent (any CLI or IDE)** | Point it at `AGENTS.md`, then run the scripts by hand: `scripts/rmaestro new "<title>"`, edit the spec, `scripts/spec lint <id>`, `scripts/rmaestro <id>`, implement, `scripts/verify <id>`. The contract does not depend on the agent, only on the scripts and the checks. |

## Parallel sessions

One spec per worktree. Create it with `the worktree helper (not in this snapshot) new "<title>"` (a
worktree with its own branch, named after the spec) or with
`git worktree add` by hand. The agent works only in its worktree and branch;
merging into `main` is always yours.

## What to try first on a new host

1. `bash scripts/bootstrap` creates `.state/` and installs the git hooks.
2. `scripts/rutas --lint` checks agents, workflows and profiles.
3. Open a spec that is already `verified` and run `scripts/rmaestro <id>`: if it
   prints a `MODO=` line, the core works on that host.

If a step that launches subagents does not work, it is a missing adapter in
that host, not a bug in the contract: implement the spec yourself under
`AGENTS.md`, which explicitly allows it.
