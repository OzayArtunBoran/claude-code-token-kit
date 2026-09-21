# claude-code-token-kit

Cut Claude Code token spend on multi-repository work without giving up review quality.

The idea is simple: **questions that have a deterministic answer should not be answered by an LLM reading files.**
"Who imports this?", "which repos does this change reach?" and "who calls this function?" are graph queries, not
reasoning tasks. This kit moves discovery and impact analysis onto a local code graph
([Graphify](https://github.com/Graphify-Labs/graphify), tree-sitter AST, zero LLM tokens) and reserves the expensive
multi-agent mode for the one phase where it pays for itself: verification.

> Extracted from the setup I have been running on my own Linux servers since August 2026, where a typical task is a
> systemic bug fix or feature touching several interlinked services at once. Host names and project names have been
> replaced with placeholders; nothing else was changed.

## What it installs

| File | What it does | Where it ends up |
|---|---|---|
| `token-strategy.md` | Phase discipline plus a short set of proactive suggestions Claude makes to the user | appended to `~/.claude/CLAUDE.md` (guarded by a marker, so it is added once) |
| `settings-merge.json` | `effortLevel: high`, `subagentPromptCacheTtl: 1h`, `workflowSizeGuideline: medium` | merged into `~/.claude/settings.json` (existing keys, hooks included, are preserved; a timestamped backup is written first) |
| `install.sh` | Installs the Graphify CLI, the rule block and the settings, then per repository: graph extraction, Claude Code hook, git hooks, registration in a global cross-repo graph | run on the machine where Claude Code runs |

## The four phases

1. **Blast radius — 0 LLM tokens.** Structural questions go to `graphify query` / `graphify path` first. Cross-repo
   impact is read from the global graph.
2. **Targeted discovery.** Read only the modules the graph points at. Discovery subagents run on a cheaper model and
   never receive edit tools.
3. **Implementation.** No workflow, the session's current model, high effort.
4. **Verification.** Multi-agent review, adversarial verification and `/code-review` happen here and only here. In
   discovery, several agents just rediscover the same structure N times.

## Install

```bash
git clone https://github.com/OzayArtunBoran/claude-code-token-kit.git
```

```bash
./claude-code-token-kit/install.sh ~/code/service-a ~/code/service-b
```

On a remote machine, copy the directory over and run the same command through `ssh -t`. The script is idempotent:
to add a repository later, run it again with just that path.

## Design decisions

- **The default model is left alone.** `model` is not set, so "Default" resolves to the best available model, which is
  what systemic work needs. Pin it yourself if you prefer.
- **The multi-agent mode is not switched on by default.** It is session-scoped rather than a persistent setting, and
  the strategy only uses it in the verification phase, where typing the keyword in the message is enough.
- **No model or effort suggestions mid-session.** Both are part of the prompt-cache key; changing either one in the
  middle of a session throws the whole cache away. The rules pin that suggestion to the start of a task or to the next
  `/clear` boundary.
- **MCP is optional.** Graphify's primary Claude Code integration is a skill plus a PreToolUse hook (written by
  `graphify claude install`). The hook redirects Claude to `graphify query` before it reaches for Read/Grep, and that
  applies to subagents too.
- **The rule block is deliberately short** (about 30 lines). Long generated context files raise inference cost without
  raising task success: see Gloaguen et al., *Evaluating AGENTS.md: Are Repository-Level Context Files Helpful for
  Coding Agents?* (ETH Zurich, [arXiv:2602.11988](https://arxiv.org/abs/2602.11988)).
- **The honest limit.** Rules in `CLAUDE.md` are context, not a guarantee. Claude follows them most of the time, but
  fully deterministic behaviour only comes from a hook. That is why the deterministic part of this kit lives in
  Graphify's hook and only the judgement calls live in the rule block. *Instruction files steer; hooks enforce.*

## Cross-linked repositories

In my setup five repositories (an authentication service, an admin panel, two application services and a landing page)
are linked to each other through `.claude/settings.local.json` → `permissions.additionalDirectories`: a session started
in any one of them can reach the other four. Those files are kept out of version control through `.git/info/exclude`.
To add a repository, add its path to the `settings.local.json` of each of the others.

## After installing

- **Measure it.** For the first two weeks compare `/usage` per session before and after, and check `/insights` for
  patterns. I am not publishing a savings figure here because I do not have one that would survive scrutiny yet.
- **Use `git gpull` instead of `git pull`.** Git hooks do not fire on pull or merge, so the graph goes stale; the alias
  runs `graphify update .` afterwards.
- **Upgrades.** Graphify is pre-1.0 and ships releases often. After upgrading the package, re-run
  `graphify claude install && graphify hook install` in every repository.
  - venv install: `~/.graphify-venv/bin/pip install -U "graphifyy[mcp]"`
  - uv install: `uv tool upgrade graphifyy`
- The PyPI package is **`graphifyy`** (double y); the command is `graphify`.

## License

MIT
