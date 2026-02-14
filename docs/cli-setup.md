# External CLI Setup Guide

This guide covers how to install and configure external AI CLIs for use with `/debate --with`.

## Prerequisites

- **Node.js 18+** (for npm-based CLIs)
- **Python 3.10+** (for kimi only)

---

## codex (OpenAI)

OpenAI's coding agent CLI.

1. **Install**: `npm install -g @openai/codex`
2. **Auth**: `codex auth` (opens browser for OAuth)
3. **Verify**: `codex --version`

### Notes
- Default model: `gpt-5.3-codex`
- Supports `--model` and reasoning effort via `--config`
- Uses file redirect (not pipe) — most reliable CLI

---

## pi (OpenAI-compatible)

Lightweight wrapper for OpenAI models with tool support.

1. **Install**: `npm install -g @anthropic-ai/claude-code` (may be bundled) or check the pi CLI's own repo
2. **Auth**: Set `OPENAI_API_KEY` environment variable, or run `pi auth`
3. **Verify**: `pi --version`

### Notes
- Default model: `gpt-5.3-codex`
- Supports `--thinking` for reasoning effort levels
- Uses pipe input (`Get-Content | pi`)

---

## gemini (Google)

Google's Gemini CLI.

1. **Install**: `npm install -g @anthropic-ai/claude-code` (may be bundled) or `npm install -g gemini-cli`
2. **Auth**: `gemini auth` (Google OAuth)
3. **Verify**: `gemini --version`

### Notes
- Default model: `gemini-2.5-pro`
- `--yolo` flag skips confirmation prompts
- May trigger 429 rate limits on heavy use

---

## qwen (Alibaba)

Alibaba's Qwen coding CLI.

1. **Install**: `npm install -g qwen-cli`
2. **Auth**: `qwen auth` (Alibaba Cloud OAuth)
3. **Verify**: `qwen --version`

### Notes
- Default model: `coder-model` (alias)
- Free tier only supports default model; other models need API key
- `--web-search-default` enables built-in web search
- Prompts must be in English (Windows encoding limitation)

---

## kimi (Moonshot)

Moonshot's Kimi CLI (Python-based).

1. **Install**: `pip install kimi-cli`
2. **Auth**: `kimi auth` (browser OAuth)
3. **Verify**: `kimi --version`

### Windows-specific setup
Set the encoding environment variable to avoid charmap codec errors:
```powershell
# Add to your PowerShell profile ($PROFILE)
$env:PYTHONIOENCODING = 'utf-8'
```

### Notes
- `--thinking` flag enables extended reasoning
- `--quiet` flag suppresses progress output
- Prompts must be in English (Windows encoding limitation)

---

## Verifying All CLIs

Quick check script:

```powershell
@('codex', 'pi', 'gemini', 'qwen', 'kimi') | ForEach-Object {
    $cli = $_
    try {
        & $cli --version 2>$null | Out-Null
        Write-Host "$cli : OK" -ForegroundColor Green
    } catch {
        Write-Host "$cli : NOT INSTALLED" -ForegroundColor Yellow
    }
}
```

> **Note**: You don't need all CLIs installed. `/debate` works with any subset — just pass the ones you have to `--with`.
