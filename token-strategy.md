# Token strategy — graphify + phase discipline

Every systemic task on this machine (a bug fix or feature that spans several projects) follows the phase order below.

## Phase discipline

1. **Blast radius (0 LLM tokens):** Answer code-structure questions with graphify queries FIRST, not with Read/Grep exploration: `graphify query` / `graphify path` (with MCP installed: `query_graph`, `get_neighbors`, `shortest_path`, `get_pr_impact`). For cross-repo impact, query the global graph. If the impact of uncommitted, freshly merged or freshly pulled changes is being analysed, run `graphify update .` FIRST — git hooks do not fire on pull/merge, so the graph is stale.
2. **Targeted discovery:** Read only the modules the graph points at. Use `model: haiku` or `model: sonnet` for discovery subagents; never give discovery subagents Edit/Write.
3. **Implementation:** No workflow, the session's current model, effort high.
4. **Verification:** ultracode/workflow ONLY in this phase — adversarial review, multi-perspective verify, /code-review. Do NOT open a workflow for discovery or implementation; in discovery, multiple agents rediscover the same structure N times.

## Proactive suggestions (Claude suggests these to the user)

- **At the start of a task**, suggest model + effort by task type: mechanical/repetitive work → sonnet + low-medium; systemic analysis/implementation → current model + high; verification round → the `ultracode` keyword in the message. Do NOT suggest a model/effort change MID-session — both are part of the cache key and a change invalidates the whole cache; defer the suggestion to the next /clear boundary.
- When it becomes clear the session went down the wrong path: suggest **/rewind** (double Esc), not /compact — it returns to an already cached prefix and is cheaper.
- When moving to unrelated work: suggest **/clear**.
- When context has grown in a long session: suggest running **/context** and report what is consuming it; if needed suggest `/compact <focus instruction>`.
- If the user complains about tokens or efficiency: remind them of **/usage** (current) and **/insights** (pattern analysis).

## Standing rules

- When starting a systemic task, even if the user did not ask: BEFORE implementation, scan cross-repo impact from the global graph (`graphify query "<symbol>" --graph ~/.graphify/global-graph.json`) and briefly report the list of affected repositories. If an affected repository is outside the session's reach, suggest adding it with /add-dir.
- A question with a deterministic answer (who imports it, who calls it, which module/repo is affected, who owns the path) is never answered by LLM file reading — use graphify, ast-grep or the language toolchain (`go list`, `cargo tree -i`, `depcruise --reaches`).
- Mechanical bulk rewrites are done outside the LLM with `ast-grep --rewrite`; Claude only reviews the diff.
- Subagent briefs are terse and imperative; an output contract (format + length limit) is mandatory.
