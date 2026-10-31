$ErrorActionPreference = "Continue"
$repo = "C:\Users\15035\Projects\LumiGen"
$hosts = "$env:SystemRoot\System32\drivers\etc\hosts"

# ---------- 0. 提权 ----------
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host ""
    Write-Host "  需要管理员权限来改 hosts 文件。" -ForegroundColor Yellow
    Write-Host "  马上弹出【用户账户控制】窗口，请点「是」。" -ForegroundColor Yellow
    Write-Host ""
    Start-Sleep -Seconds 2
    Start-Process powershell -Verb RunAs -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-NoExit", "-File", "`"$PSCommandPath`"")
    exit
}

Write-Host ""
Write-Host "===== 1/4  备份 hosts =====" -ForegroundColor Cyan
$backup = Join-Path $env:USERPROFILE ("hosts-backup-" + (Get-Date -Format "yyyyMMdd-HHmmss") + ".txt")
Copy-Item $hosts $backup -Force
Write-Host "  已备份到: $backup" -ForegroundColor Green

Write-Host ""
Write-Host "===== 2/4  解除 GitHub / HuggingFace 的屏蔽 =====" -ForegroundColor Cyan
$patterns = @(
    'github\.com$', 'githubusercontent\.com$', 'githubassets\.com$', 'githubapp\.com$',
    'github\.io$', 'github\.dev$', 'huggingface\.co$', 'hf\.co$'
)
$lines = [System.IO.File]::ReadAllLines($hosts)
$new = New-Object System.Collections.Generic.List[string]
$killed = 0
foreach ($l in $lines) {
    $t = $l.Trim()
    if ($t -eq "" -or $t.StartsWith("#")) { $new.Add($l); continue }
    $parts = $t -split '\s+'
    if ($parts.Count -ge 2 -and $parts[0] -eq "127.0.0.1") {
        $domain = $parts[1]
        $hit = $false
        foreach ($p in $patterns) { if ($domain -match $p) { $hit = $true; break } }
        if ($hit) { $new.Add("# [lumigen 解除] $l"); $killed++; continue }
    }
    $new.Add($l)
}
[System.IO.File]::WriteAllLines($hosts, $new, (New-Object System.Text.UTF8Encoding($false)))
Write-Host "  注释掉了 $killed 行屏蔽规则" -ForegroundColor Green
ipconfig /flushdns | Out-Null

Write-Host ""
Write-Host "===== 3/4  测试 GitHub =====" -ForegroundColor Cyan
Start-Sleep -Seconds 1
$ips = (Resolve-DnsName github.com -Type A -ErrorAction SilentlyContinue | Where-Object { $_.IPAddress } | Select-Object -First 2).IPAddress -join ", "
Write-Host "  github.com -> $ips"
$ok = Test-NetConnection github.com -Port 443 -InformationLevel Quiet -WarningAction SilentlyContinue
if ($ok) { Write-Host "  443 通了，很好" -ForegroundColor Green }
else { Write-Host "  443 还是不通（可能还有别的拦截软件），把窗口截图发我" -ForegroundColor Red }

Write-Host ""
Write-Host "===== 4/4  推送代码 =====" -ForegroundColor Cyan
Set-Location $repo
git add -A 2>$null
git -c user.name="LumiGen" -c user.email="lumigen@local" commit -m "LumiGen update" 2>$null
git remote remove origin 2>$null
git remote add origin "https://github.com/nxcdsl/nxcdsl.git"
git branch -M main
git push -u origin main

Write-Host ""
if ($LASTEXITCODE -eq 0) {
    Write-Host "  推送成功！云端编译会自动开始。" -ForegroundColor Green
    Start-Sleep -Seconds 1
    Start-Process "https://github.com/nxcdsl/nxcdsl/actions"
} else {
    Write-Host "  推送失败（退出码 $LASTEXITCODE）" -ForegroundColor Red
}

Write-Host ""
Write-Host "按任意键关闭..." -ForegroundColor DarkGray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
