# Example Debates

## Example 1: REST vs GraphQL (Internal Only)

### Command
```
/debate Should we use REST or GraphQL for our API --rounds 2
```

### What happens
1. Claude Code spawns **advocate** + **critic** (no external CLIs)
2. Advocate proposes (e.g., "GraphQL for flexibility and reduced over-fetching")
3. Critic challenges (e.g., "REST is simpler, better caching, more mature tooling")
4. Advocate responds to challenges
5. Lead synthesizes DECISION

### Expected output
Lead produces a structured DECISION with:
- Recommendation with confidence level
- Key arguments from each side
- Consensus points and remaining trade-offs
- Concrete next step

---

## Example 2: Database Indexing (With External AI)

### Command
```
/debate Database indexing strategy for user queries --files src/db/queries.ts --with codex,gemini --preset balanced
```

### What happens
1. Claude Code spawns **advocate** + **critic** + **proxy-codex** + **proxy-gemini**
2. All agents receive the file context from `src/db/queries.ts`
3. Advocate proposes an indexing strategy based on code analysis
4. Critic + codex + gemini all independently challenge the proposal
5. Advocate responds with evidence
6. Lead synthesizes DECISION incorporating 4 perspectives

---

## Example 3: Deep Architecture Decision

### Command
```
/debate Should we migrate from monolith to microservices --with codex,gemini,pi --preset deep --rounds 3
```

### What happens
1. `deep` preset: advocate=opus, critic=sonnet, codex+pi use gpt-5.2 with xhigh effort
2. **Round 1**: Advocate PROPOSAL (with WebSearch evidence)
3. **Round 2**: Critic + 3 external AIs CHALLENGE
4. **Context Refresh**: Lead updates technical context with Round 2 findings
5. **Round 3**: All parties REBUTTAL with final arguments
6. Lead synthesizes comprehensive DECISION

### Timing
- Internal agents: ~2-5 min each round
- codex (gpt-5.2 + xhigh): ~10-30 min per round
- Total: ~30-60 min for a deep 3-round debate

---

## Example 4: Quick Design Decision

### Command
```
/debate Tabs vs spaces for the project --preset quick --rounds 2
```

### What happens
- Quick preset with internal agents only
- Fast 2-round debate (~5 min total)
- Good for low-stakes design decisions

---

## Tips

- **Start simple**: Try internal-only debates first (`/debate topic --rounds 2`)
- **Add CLIs gradually**: Start with one external CLI (`--with codex`), then add more
- **Use `--files`**: Agents give much better analysis when they can read your actual code
- **Deep for big decisions**: Use `--preset deep --rounds 3` for architecture-level choices
- **Check CLI auth**: If a proxy times out, the CLI might need re-authentication
