# One-click blog publish (PowerShell). Commit -> push main -> wait & report deploy.
#
# Usage (in PowerShell):
#   cd C:\Users\yuyu1\kikyoyuyu.github.io
#   .\publish.ps1                 # default commit message (timestamped)
#   .\publish.ps1 "add post: xxx" # custom commit message
#
# If blocked by execution policy, run once:
#   Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
# Or run with a one-time bypass:
#   powershell -ExecutionPolicy Bypass -File .\publish.ps1 "your message"
#
# NOTE: ASCII-only on purpose. Windows PowerShell 5.1 mis-reads non-BOM UTF-8,
# so any Chinese here would break parsing. The published article keeps Chinese.

param(
    [string]$Message = "Update site: $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
)

$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

$proxy     = "http://userproxy.visa.com:80"
$ownerRepo = "yyonearth/yyonearth.github.io"
$siteUrl   = "https://yyonearth.github.io/"

# 1) Commit only if there are changes
$changes = git status --porcelain
if ([string]::IsNullOrWhiteSpace($changes)) {
    Write-Host "WARN  No local changes; nothing to commit." -ForegroundColor Yellow
} else {
    Write-Host "Commit: $Message"
    git add -A
    git commit -m $Message
}

# 2) Push (git already routes github.com via the Visa proxy)
Write-Host "Pushing to main ..."
git push origin main

# 3) Read token from git credential cache
$cred = "protocol=https`nhost=github.com`n`n" | git credential fill 2>$null
$tok  = ($cred | Where-Object { $_ -like 'password=*' }) -replace '^password=', ''
if ([string]::IsNullOrWhiteSpace($tok)) {
    Write-Host "INFO  No GitHub token found; skipping deploy check. Verify later: $siteUrl" -ForegroundColor Cyan
    exit 0
}

$headers = @{ Authorization = "Bearer $tok"; Accept = "application/vnd.github+json"; "User-Agent" = "publish-ps" }
function Invoke-GH($url) { Invoke-RestMethod -Uri $url -Headers $headers -Proxy $proxy -TimeoutSec 30 }

# 4) Poll latest run on main
Write-Host "Waiting for GitHub Actions deploy (up to ~3 min) ..."
for ($i = 1; $i -le 18; $i++) {
    Start-Sleep -Seconds 10
    try {
        $run = (Invoke-GH "https://api.github.com/repos/$ownerRepo/actions/runs?branch=main&per_page=1").workflow_runs[0]
        if (-not $run) { continue }
        Write-Host ("   [{0:D2}] status={1} conclusion={2}" -f $i, $run.status, $run.conclusion)
        if ($run.status -eq "completed") {
            if ($run.conclusion -eq "success") {
                Write-Host "OK  Deploy succeeded. Live: $siteUrl" -ForegroundColor Green
                Write-Host "    (intranet may block it; verify on phone/non-intranet browser)"
            } else {
                Write-Host "FAIL  Build failed (conclusion=$($run.conclusion)). Logs:" -ForegroundColor Red
                Write-Host "    https://github.com/$ownerRepo/actions/runs/$($run.id)"
            }
            exit 0
        }
    } catch {
        Write-Host "   [$i] query error, retrying ..." -ForegroundColor DarkGray
    }
}

Write-Host "Timeout: build may still be running. Check:" -ForegroundColor Yellow
Write-Host "    https://github.com/$ownerRepo/actions"
