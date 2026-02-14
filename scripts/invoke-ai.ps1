param(
    [Parameter(Mandatory)]
    [ValidateSet('codex', 'pi', 'gemini', 'qwen', 'kimi')]
    [string]$CLI,

    [Parameter(Mandatory)]
    [string]$PromptFile,

    [Parameter(Mandatory)]
    [string]$OutFile,

    [string]$Model,

    [ValidateSet('low', 'medium', 'high', 'xhigh', '')]
    [string]$ReasoningEffort,

    [int]$TimeoutSec = 300
)

if (-not (Test-Path $PromptFile)) {
    Write-Error "Prompt file not found: $PromptFile"
    exit 1
}

# F015: Derive stderr capture file from OutFile (same directory, same lifecycle)
$ErrFile = [IO.Path]::ChangeExtension($OutFile, '.err')

# v3: PowerShell-native pipe function using -EncodedCommand to avoid ALL quoting/escaping issues
# Replaces unreliable `cmd /c type file | cli` which failed for 4/5 pipe-based CLIs
function Start-PipelineCli {
    param(
        [string]$PipelineCommand,
        [string]$OutFile,
        [string]$ErrFile
    )
    # PS 5.1: > defaults to UTF-16LE. Fix by setting Out-File default encoding + Console output encoding
    $fullCmd = "`$PSDefaultParameterValues['Out-File:Encoding'] = 'utf8'; [Console]::OutputEncoding = [System.Text.Encoding]::UTF8; $PipelineCommand > '$OutFile' 2> '$ErrFile'"
    $bytes = [System.Text.Encoding]::Unicode.GetBytes($fullCmd)
    $encoded = [Convert]::ToBase64String($bytes)
    return Start-Process -FilePath 'powershell' `
        -ArgumentList "-NoProfile -EncodedCommand $encoded" `
        -NoNewWindow -PassThru
}

switch ($CLI) {
    'codex' {
        # codex uses `exec - < file` redirect (not pipe) — reliable via cmd /c
        $flags = '--dangerously-bypass-approvals-and-sandbox --color never'
        if ($Model) { $flags += " --model $Model" }
        if ($ReasoningEffort) { $flags += " --config model_reasoning_effort=`"$ReasoningEffort`"" }
        $proc = Start-Process -FilePath 'cmd' `
            -ArgumentList "/c codex exec $flags -o `"$OutFile`" - < `"$PromptFile`" > NUL 2>`"$ErrFile`"" `
            -NoNewWindow -PassThru
    }
    'pi' {
        $flags = '-p --provider openai-codex --no-session --tools "read,grep,find,ls"'
        if ($Model) { $flags += " --model $Model" }
        if ($ReasoningEffort) { $flags += " --thinking $ReasoningEffort" }
        $proc = Start-PipelineCli `
            -PipelineCommand "Get-Content '$PromptFile' -Raw -Encoding UTF8 | pi $flags" `
            -OutFile $OutFile -ErrFile $ErrFile
    }
    'gemini' {
        $flags = '--yolo -o text'
        if ($Model) { $flags += " -m $Model" }
        $proc = Start-PipelineCli `
            -PipelineCommand "Get-Content '$PromptFile' -Raw -Encoding UTF8 | gemini $flags" `
            -OutFile $OutFile -ErrFile $ErrFile
    }
    'qwen' {
        $flags = '--yolo -o text --web-search-default'
        if ($Model) { $flags += " -m $Model" }
        $proc = Start-PipelineCli `
            -PipelineCommand "Get-Content '$PromptFile' -Raw -Encoding UTF8 | qwen $flags" `
            -OutFile $OutFile -ErrFile $ErrFile
    }
    'kimi' {
        $flags = '--yolo --quiet'
        if ($Model) { $flags += " -m $Model" }
        if ($ReasoningEffort) { $flags += " --thinking" }
        # kimi (Python) needs PYTHONIOENCODING=utf-8 to avoid charmap codec crash
        $proc = Start-PipelineCli `
            -PipelineCommand "`$env:PYTHONIOENCODING = 'utf-8'; Get-Content '$PromptFile' -Raw -Encoding UTF8 | kimi $flags" `
            -OutFile $OutFile -ErrFile $ErrFile
    }
}

if (-not $proc.WaitForExit($TimeoutSec * 1000)) {
    $proc | Stop-Process -Force
    $msg = "TIMEOUT: $CLI did not respond within ${TimeoutSec}s"
    # F015: Append stderr to timeout message for diagnostics
    if ((Test-Path $ErrFile) -and (Get-Item $ErrFile).Length -gt 0) {
        $stderr = Get-Content $ErrFile -Raw -Encoding UTF8
        $msg += "`n`nSTDERR:`n$stderr"
    }
    $msg | Set-Content $OutFile -Encoding UTF8
    Write-Warning "$CLI timed out after ${TimeoutSec}s"
    exit 1
}

# B009: Guard against null ExitCode (pipe chains may not propagate exit codes reliably)
if ($null -ne $proc.ExitCode -and $proc.ExitCode -ne 0) {
    Write-Warning "$CLI exited with code $($proc.ExitCode)"
    exit $proc.ExitCode
}

# F015: Post-execution stderr diagnostics (warn only, never alter control flow)
if ((Test-Path $ErrFile) -and (Get-Item $ErrFile).Length -gt 0) {
    $stderr = Get-Content $ErrFile -Raw -Encoding UTF8
    # P1: 429 diagnostic marking
    if ($stderr -match '429|rate.limit|too.many.requests|quota.exceeded|resource.exhausted') {
        Write-Warning "RATE_LIMITED: $CLI stderr contains rate-limit indicators"
        Write-Warning "stderr: $($stderr.Substring(0, [Math]::Min(500, $stderr.Length)))"
    } else {
        Write-Warning "STDERR_NONEMPTY: $CLI wrote to stderr (may be benign warnings)"
        Write-Warning "stderr: $($stderr.Substring(0, [Math]::Min(500, $stderr.Length)))"
    }
}

if (Test-Path $OutFile) {
    $size = (Get-Item $OutFile).Length
    Write-Output "OK: $CLI output written to $OutFile ($size bytes)"
} else {
    Write-Error "$CLI completed but no output file was created"
    exit 1
}
