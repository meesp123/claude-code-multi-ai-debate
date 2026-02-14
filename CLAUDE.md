# claude-code-multi-ai-debate

## About
Multi-AI debate skill for Claude Code. Uses Claude Code agent teams to orchestrate structured debates between internal agents (advocate, critic) and external AI CLIs (codex, pi, gemini, qwen, kimi).

## Structure
- `.claude/commands/debate.md` — Main slash command skill
- `.claude/agents/debate-*.md` — Agent definitions (advocate, critic, proxy)
- `scripts/invoke-ai.ps1` — PowerShell script for calling external AI CLIs

## Usage
```
/debate <topic> [--files <path>] [--with <cli1,cli2>] [--preset <balanced|deep|quick>] [--rounds <2|3>]
```

## Platform
- Windows + PowerShell 5.1+
- Claude Code with agent team support
