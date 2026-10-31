$ErrorActionPreference = "Continue"
$hosts  = "$env:SystemRoot\System32\drivers\etc\hosts"
$repo   = "C:\Users\15035\Projects\LumiGen"
$result = "C:\Users\15035\Projects\fix-result.txt"
$log    = New-Object System.Collections.Generic.List[string]

function Say($t) { $log.Add($t); Write-Host $t }

Say "=== LumiGen fix run $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ==="
Say ("admin = " + ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))

# ---- 1. 备份 + 解除 hosts 屏蔽 ----
try {
    $backup = Join-Path $env:USERPROFILE ("hosts-backup-" + (Get-Date -Format "yyyyMMdd-HHmmss") + ".txt")
    Copy-Item $hosts $backup -Force -ErrorAction Stop
    Say "backup ok: $backup"
} catch { Say "backup FAIL: $($_.Exception.Message)" }

try {
    $patterns = @('github\.com$','githubusercontent\.com$','githubassets\.com$','githubapp\.com$','github\.io$','github\.dev$','huggingface\.co$')
    $lines = [System.IO.File]::ReadAllLines($hosts)
    $new = New-Object System.Collections.Generic.List[string]
    $killed = 0
    foreach ($l in $lines) {
        $t = $l.Trim()
        if ($t -eq "" -or $t.StartsWith("#")) { $new.Add($l); continue }
        $p = $t -split '\s+'
        if ($p.Count -ge 2 -and $p[0] -eq "127.0.0.1") {
            $hit = $false
            foreach ($pat in $patterns) { if ($p[1] -match $pat) { $hit = $true; break } }
            if ($hit) { $new.Add("# [lumigen] $l"); $killed++; continue }
        }
        $new.Add($l)
    }
    [System.IO.File]::WriteAllLines($hosts, $new, (New-Object System.Text.UTF8Encoding($false)))
    Say "hosts: commented out $killed lines"
} catch { Say "hosts write FAIL: $($_.Exception.Message)" }

ipconfig /flushdns | Out-Null
Start-Sleep -Seconds 1

# ---- 2. 验证 ----
$ips = (Resolve-DnsName github.com -Type A -ErrorAction SilentlyContinue | Where-Object { $_.IPAddress } | Select-Object -First 2).IPAddress -join ", "
Say "github.com -> $ips"
$ok = Test-NetConnection github.com -Port 443 -InformationLevel Quiet -WarningAction SilentlyContinue
Say "tcp 443 = $ok"

# ---- 3. 推送 ----
Set-Location $repo
git add -A 2>$null
git -c user.name="LumiGen" -c user.email="lumigen@local" commit -m "LumiGen update" 2>$null
git remote remove origin 2>$null
git remote add origin "https://github.com/nxcdsl/nxcdsl.git"
git branch -M main
$push = git push -u origin main 2>&1
$code = $LASTEXITCODE
Say "git push exit = $code"
foreach ($line in $push) { Say "  $line" }

Say "=== end ==="
$log | Set-Content -Path $result -Encoding UTF8
Write-Host ""
Write-Host "结果已写入 $result" -ForegroundColor Green
Start-Sleep -Seconds 3
