# claude-code-multi-ai-debate

Multi-AI structured debate skill for [Claude Code](https://claude.com/claude-code).
Orchestrates a team of Claude Code agents (advocate, critic, proxy) to debate any
technical topic, optionally bringing in external AI perspectives from 5 different
CLI tools.

> **Platform**: Developed and tested on **Windows 11 + PowerShell 5.1+**.
> Internal-only debates (no `--with` flag) work on all platforms.
> External CLI integration (`--with`) requires PowerShell (Windows native or `pwsh` on Mac/Linux).

## Features

- **Structured 3-round debate**: PROPOSAL → CHALLENGE → REBUTTAL → DECISION
- **Multi-AI perspectives**: Bring in codex, pi, gemini, qwen, kimi via CLI
- **Internal-only mode**: Debate with just advocate + critic (no external CLI needed)
- **Verify-Before-Cite**: Agents must Grep-verify any numbers before citing
- **WebSearch integration**: Agents search the web for evidence before arguing
- **Configurable presets**: quick (5 min), balanced (15 min), deep (30 min)
- **READY handshake**: Agents confirm tool availability before debate starts
- **Word count enforcement**: 300-word limit with self-check + proxy truncation

---

## Prerequisites

### 1. Claude Code (Required)

[Claude Code](https://claude.com/claude-code) is Anthropic's official CLI for Claude. You need it to run this skill.

**Install Claude Code:**
```powershell
# Via npm (requires Node.js 18+)
npm install -g @anthropic-ai/claude-code

# Verify installation
claude --version
```

First-time setup:
```powershell
claude    # Opens Claude Code, follow login prompts
```

You need a **Claude Pro/Max subscription** for agent team features (multiple agents running simultaneously).

### Enable Agent Teams (Required)

Agent teams are **experimental and disabled by default**. Add this to your `~/.claude/settings.json`:

```json
{
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  }
}
```

Or set it temporarily via environment variable:
```powershell
$env:CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS = "1"
```

> **Display mode** (optional): On macOS/Linux with tmux or iTerm2, agent teams can show in split panes. On Windows, teammates run in-process (use `Shift+Up/Down` to switch between them).

### 2. Node.js (Required for Claude Code + most external CLIs)

```powershell
# Check if installed
node --version    # Need 18+

# If not installed — use winget (Windows)
winget install OpenJS.NodeJS.LTS
```

### 3. Git (Required)

```powershell
git --version     # Need 2.x+

# If not installed
winget install Git.Git
```

### 4. Python 3.10+ (Only if using kimi CLI)

```powershell
python --version

# If not installed
winget install Python.Python.3.12
```

---

## Installation

### Option 1: Manual Copy (Recommended for first-time)

1. **Clone this repo:**
```powershell
git clone https://github.com/meesp123/claude-code-multi-ai-debate.git
cd claude-code-multi-ai-debate
```

2. **Copy skill files to your project's `.claude/` directory:**
```powershell
# Replace $YOUR_PROJECT with your actual project path
Copy-Item .claude\commands\debate.md $YOUR_PROJECT\.claude\commands\ -Force
Copy-Item .claude\agents\debate-advocate.md $YOUR_PROJECT\.claude\agents\ -Force
Copy-Item .claude\agents\debate-critic.md $YOUR_PROJECT\.claude\agents\ -Force
Copy-Item .claude\agents\debate-proxy.md $YOUR_PROJECT\.claude\agents\ -Force
```

3. **Copy the invoke-ai script** (needed for external CLI calls):
```powershell
# Create directory if it doesn't exist
New-Item -ItemType Directory -Path "$HOME\.claude\scripts" -Force
Copy-Item scripts\invoke-ai.ps1 "$HOME\.claude\scripts\invoke-ai.ps1" -Force
```

4. **Restart Claude Code** or start a new session. Type `/debate` to verify.

### Option 2: Global Installation (available in ALL projects)

```powershell
# Create directories
New-Item -ItemType Directory -Path "$HOME\.claude\commands" -Force
New-Item -ItemType Directory -Path "$HOME\.claude\agents" -Force
New-Item -ItemType Directory -Path "$HOME\.claude\scripts" -Force

# Copy all files
Copy-Item .claude\commands\debate.md "$HOME\.claude\commands\" -Force
Copy-Item .claude\agents\debate-*.md "$HOME\.claude\agents\" -Force
Copy-Item scripts\invoke-ai.ps1 "$HOME\.claude\scripts\" -Force
```

---

## Setting Up External AI CLIs (Optional)

You only need these if you want to use `--with codex,gemini,...` to bring in external AI perspectives. Without them, `/debate` still works with internal advocate + critic agents.

### Quick Setup Table

| CLI | Install Command | Auth Command | Verify |
|--------|-------------------------------------|-------------|-----------------|
| codex | `npm i -g @openai/codex` | `codex auth` | `codex --version` |
| gemini | `npm i -g @anthropic-ai/claude-code` | `gemini auth` | `gemini --version` |
| qwen | `npm i -g qwen-cli` | `qwen auth` | `qwen --version` |
| kimi | `pip install kimi-cli` | `kimi auth` | `kimi --version` |

> **Note**: CLI package names and auth methods may change. See [docs/cli-setup.md](docs/cli-setup.md) for the latest detailed instructions.

### Verify Your Setup

```powershell
# Test which CLIs are available
codex --version 2>$null && Write-Host "codex: OK" || Write-Host "codex: NOT INSTALLED"
gemini --version 2>$null && Write-Host "gemini: OK" || Write-Host "gemini: NOT INSTALLED"
qwen --version 2>$null && Write-Host "qwen: OK" || Write-Host "qwen: NOT INSTALLED"
kimi --version 2>$null && Write-Host "kimi: OK" || Write-Host "kimi: NOT INSTALLED"
```

---

## Claude Code Agent Team — How It Works

This skill uses Claude Code's **agent team** feature. Here's what you need to know:

### What is an Agent Team?

Claude Code can spawn multiple AI agents that work together. Each agent has:
- A **role** (advocate, critic, proxy)
- Its own **tools** (Read, Grep, WebSearch, etc.)
- The ability to **send messages** to other agents

### Agent Roles in /debate

| Agent | Role | Model | What it does |
|-------|------|-------|-------------|
| **Lead** (you) | Moderator | Your current model | Orchestrates phases, synthesizes DECISION |
| **Advocate** | Proposer | Sonnet | Proposes and defends a solution |
| **Critic** | Challenger | Sonnet | Finds weaknesses, suggests alternatives |
| **Proxy** ×N | Bridge | Haiku | Calls external AI CLIs, relays their opinions |

### Communication Flow

```
┌─────────────┐     ┌──────────────┐     ┌──────────────┐
│  Advocate    │     │   Critic     │     │  Proxy ×N    │
│ (proposes)   │     │ (challenges) │     │ (external AI)│
└──────┬───────┘     └──────┬───────┘     └──────┬───────┘
       │                    │                    │
       └────────────┬───────┘────────────────────┘
                    │
              ┌─────┴─────┐
              │   Lead     │
              │(orchestrate│
              │ + decide)  │
              └────────────┘
```

### 6-Phase Protocol

1. **Phase 1**: Parse topic + assemble context
2. **Phase 2**: Spawn agent team + wait for READY handshake
3. **Phase 3**: Advocate PROPOSAL (with WebSearch + code analysis)
4. **Phase 4**: Critic + external AIs CHALLENGE the proposal
5. **Phase 5**: Advocate RESPONSE + Critic REBUTTAL
6. **Phase 6**: Lead synthesizes all perspectives → DECISION

---

## Usage

### Basic (internal agents only — no external CLI needed)

```
/debate Should we use REST or GraphQL for our API --rounds 2
```

### With external AI

```
/debate Database indexing strategy --files src/db/queries.ts --with codex,gemini
```

### Full options

```
/debate <topic> [--files <path1,path2>] [--with <cli1,cli2>] [--preset <quick|balanced|deep>] [--rounds <2|3>] [--effort <low|medium|high|xhigh>]
```

### Parameters

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| `<topic>` | Yes | — | The debate topic (free text) |
| `--files` | No | — | Source files for agents to analyze |
| `--with` | No | — | External CLIs to include (comma-separated) |
| `--preset` | No | `balanced` | Timeout/depth preset |
| `--rounds` | No | `2` | Number of debate rounds (2 or 3) |
| `--effort` | No | `high` | Reasoning effort for external CLIs |

### Presets

| Preset | Rounds | Timeout | Best for |
|----------|--------|---------|---------------------------|
| `quick` | 2 | 5 min | Simple design decisions |
| `balanced` | 2 | 15 min | Most technical debates |
| `deep` | 3 | 30 min | Architecture decisions |

---

## Platform Support

| Platform | Internal Debate | External CLI (`--with`) | Notes |
|-----------|---------------|----------------------|-------------------------------|
| Windows 11 | ✅ Full | ✅ Full | Primary development platform |
| macOS | ✅ Full | ⚠️ Needs `pwsh` | `brew install powershell` |
| Linux | ✅ Full | ⚠️ Needs `pwsh` | Install PowerShell Core |

---

## Troubleshooting

### "/debate" not recognized
- Make sure `debate.md` is in `.claude/commands/` (project or `$HOME\.claude\commands\`)
- Restart Claude Code session

### External CLI timeout
- Increase `--preset deep` for longer timeouts
- Check CLI auth: `codex auth` / `gemini auth`

### Agent team not spawning
- Need Claude Pro or Max subscription for agent teams
- Check Claude Code version: `claude --version`

### Encoding errors (kimi)
- Set `$env:PYTHONIOENCODING = 'utf-8'` in your PowerShell profile

---

## Contributing

Contributions welcome! Here's how:

1. Fork this repo
2. Create a feature branch: `git checkout -b feature/my-feature`
3. Make your changes
4. Commit: `git commit -m "feat: description"`
5. Push: `git push origin feature/my-feature`
6. Create a PR: `gh pr create --fill`

### Commit Message Convention

- `feat:` — New feature
- `fix:` — Bug fix
- `docs:` — Documentation only
- `refactor:` — Code change that neither fixes a bug nor adds a feature

---

## License

[MIT](LICENSE)

## Acknowledgments

Built with [Claude Code](https://claude.com/claude-code) by Anthropic.
