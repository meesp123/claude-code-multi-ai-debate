# Architecture

## System Overview

The `/debate` skill orchestrates a structured multi-AI debate using Claude Code's agent team feature. A Lead agent (your Claude Code session) coordinates advocate, critic, and proxy agents through a 6-phase protocol.

## Agent Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Claude Code Session                      │
│                        (Lead Agent)                          │
│  - Parses arguments                                         │
│  - Assembles technical context                              │
│  - Orchestrates phases                                      │
│  - Synthesizes DECISION                                     │
└──────────┬──────────────┬──────────────┬────────────────────┘
           │              │              │
    DM (ACTION:)    DM (ACTION:)   DM (ACTION:)
           │              │              │
    ┌──────▼──────┐ ┌─────▼──────┐ ┌────▼────────┐
    │  Advocate   │ │   Critic   │ │  Proxy ×N   │
    │  (Sonnet)   │ │  (Sonnet)  │ │  (Haiku)    │
    │             │ │            │ │             │
    │ - Proposes  │ │ - Challenges│ │ - Calls CLI │
    │ - Defends   │ │ - Rebuts   │ │ - Relays    │
    │ - WebSearch │ │ - WebSearch│ │ - Truncates │
    └──────┬──────┘ └─────┬──────┘ └────┬────────┘
           │              │              │
           └──── broadcast (to all) ─────┘
                         │
              ┌──────────▼──────────┐
              │   External AI CLIs  │
              │  codex │ pi │ gemini│
              │  qwen  │ kimi      │
              └─────────────────────┘
```

## Communication Protocol

### Message Types
- **DM (Direct Message)**: Lead → specific agent. Contains `ACTION:` prefix to trigger work.
- **Broadcast**: Agent → all team members. Used for sharing proposals, challenges, and opinions.
- **READY**: Agent → Lead. Startup confirmation with tool availability report.

### DM-Action Rule
Agents **only act** when they receive a DM with `ACTION:` prefix. Broadcasts are informational — agents read them but don't take action.

## 6-Phase Protocol

### Phase 1: Parse + Context Assembly
```
User input → Parse arguments → Read --files → Extract technical context → Report setup
```

Key output: `{technical_context}` — a ≤15-line factual summary of the project, shared with external AIs.

**Context Assembly Rules**:
- Include: stack info, data conventions, architecture patterns
- Exclude: behavioral rules, workflow instructions, conclusions
- Anti-anchoring: facts only (WHAT), never conclusions (WHY/HOW)

### Phase 2: Team Setup + READY Handshake
```
TeamCreate → Spawn advocate + critic + proxy×N (parallel) → Wait for READY from all
```

Each agent sends `READY:{role}` with its tool list. Lead tracks a checklist. 60s timeout with 1 retry.

### Phase 3: PROPOSAL (Round 1)
```
Lead DM advocate (ACTION:PROPOSAL) → advocate WebSearch → advocate broadcast PROPOSAL
```

### Phase 4: CHALLENGE (Round 2)
```
Lead broadcast summary → Lead DM critic + proxies (ACTION:CHALLENGE, parallel)
→ Wait for all challenges → Lead DM advocate (ACTION:RESPOND)
```

**Shared Context Block**: All challengers receive the same context. No per-CLI customization.

**Progressive Wait**: If N-1 challenges arrive and the last proxy times out, advocate can start responding to available challenges.

### Phase 4.9: Context Refresh (rounds ≥ 3 only)
```
Collect new facts from CHALLENGE round → Update {technical_context} → Update {shared_context_block}
```

New facts tagged with `[R2 发现]`.

### Phase 5: REBUTTAL (Round 3, rounds ≥ 3 only)
```
Lead DM all members (ACTION:REBUTTAL/FINAL_SUMMARY, parallel) → Wait for final comments
```

### Phase 6: DECISION + Cleanup
```
Lead synthesizes DECISION → Shutdown agents → Report completion → (Optional) Cleanup on user request
```

## External CLI Integration

### invoke-ai.ps1 Flow

```
┌─────────┐     ┌───────────────┐     ┌──────────────┐
│  Proxy   │     │ invoke-ai.ps1 │     │ External CLI  │
│  Agent   │     │  (PowerShell) │     │(codex/gemini/ │
│          │     │               │     │ pi/qwen/kimi) │
└────┬─────┘     └───────┬───────┘     └──────┬───────┘
     │                   │                    │
     │ Write prompt.md   │                    │
     │──────────────────>│                    │
     │                   │ pipe/redirect      │
     │                   │───────────────────>│
     │                   │                    │
     │                   │    response        │
     │                   │<───────────────────│
     │                   │                    │
     │ Read response.md  │ Write response.md  │
     │<──────────────────│                    │
     │                   │                    │
     │ Broadcast (≤200w) │                    │
     └───────────────────┘                    │
```

### CLI Input Methods
- **codex**: File redirect (`exec - < file`) via `cmd /c`
- **pi, gemini, qwen, kimi**: Pipe (`Get-Content | cli`) via PowerShell `-EncodedCommand`

### Encoding
- PowerShell 5.1 defaults to UTF-16LE; the script forces UTF-8 via `$PSDefaultParameterValues` and `[Console]::OutputEncoding`
- kimi (Python) requires `PYTHONIOENCODING=utf-8`

## Timeout Strategy

| CLI + Model | TimeoutSec | Rationale |
|---|---|---|
| pi gpt-5.2 + xhigh | 900 | Extended reasoning |
| codex gpt-5.2 + xhigh | 1800 | Slowest combination |
| codex/pi default | 600 | Standard |
| gemini/qwen/kimi | 300 | Fast CLIs |

Progressive wait kicks in at TimeoutSec; hard cutoff at TimeoutSec × 1.5.

## Word Count Enforcement

| Stage | Limit | Enforced by |
|---|---|---|
| PROPOSAL | 300 words | Advocate self-check |
| CHALLENGE | 300 words | Critic/Lead check |
| CLI Response | 200 words | Prompt instruction + Proxy truncation |
| REBUTTAL | 200 words | Agent self-check |
| FINAL_SUMMARY | 200 words | Advocate self-check |

Lead performs spot-checks on broadcasts >400 words and requests re-submission.

## File Structure (per debate)

```
.scratchpad/debate-{timestamp}/
├── proxy-codex-r2-prompt.md
├── proxy-codex-r2-response.md
├── proxy-codex-r2-response.err
├── proxy-gemini-r2-prompt.md
├── proxy-gemini-r2-response.md
├── proxy-codex-r3-prompt.md     (if rounds=3)
├── proxy-codex-r3-response.md   (if rounds=3)
└── ...

~/.claude/teams/debate-{timestamp}/
├── inboxes/                      (agent messages)
└── ...
```
