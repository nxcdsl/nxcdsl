$ErrorActionPreference = "Continue"
$hosts  = "$env:SystemRoot\System32\drivers\etc\hosts"
$repo   = "C:\Users\15035\Projects\LumiGen"
$result = "C:\Users\15035\Projects\fix-result.txt"
$log    = New-Object System.Collections.Generic.List[string]
function Say($t) { $log.Add($t); Write-Host $t }

Say "=== LumiGen pin-ip run $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ==="
Say ("admin = " + ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))

$candidates = @("20.205.243.166", "140.82.112.3", "140.82.113.3", "20.27.177.113", "140.82.121.3")

# 先把上一次加的 pin 行清掉
$lines = [System.IO.File]::ReadAllLines($hosts)
$clean = New-Object System.Collections.Generic.List[string]
foreach ($l in $lines) { if ($l -notmatch "^#?\s*[\d\.]+\s+github\.com\s*$" -and $l -notmatch "^\s*[\d\.]+\s+api\.github\.com\s*$") { $clean.Add($l) } }
[System.IO.File]::WriteAllLines($hosts, $clean, (New-Object System.Text.UTF8Encoding($false)))

$chosen = $null
foreach ($ip in $candidates) {
    $tcp = Test-NetConnection -ComputerName $ip -Port 443 -InformationLevel Quiet -WarningAction SilentlyContinue
    Say "try $ip tcp443=$tcp"
    if (-not $tcp) { continue }

    $tmp = New-Object System.Collections.Generic.List[string]
    foreach ($l in [System.IO.File]::ReadAllLines($hosts)) { $tmp.Add($l) }
    $tmp.Add("$ip github.com")
    $tmp.Add("$ip www.github.com")
    [System.IO.File]::WriteAllLines($hosts, $tmp, (New-Object System.Text.UTF8Encoding($false)))
    ipconfig /flushdns | Out-Null
    Start-Sleep -Milliseconds 800

    $probe = git ls-remote "https://github.com/nxcdsl/nxcdsl.git" 2>&1
    $code = $LASTEXITCODE
    Say "try $ip ls-remote exit=$code"
    if ($code -eq 0) { $chosen = $ip; Say "CHOSEN $ip"; break }
    else { foreach ($x in $probe) { Say "    $x" } }
}

if (-not $chosen) {
    Say "no working ip found"
} else {
    # 顺手把 api.github.com 也指向同一个 IP 段（用于拉日志/状态）
    $apiIp = $chosen
    $tmp = New-Object System.Collections.Generic.List[string]
    foreach ($l in [System.IO.File]::ReadAllLines($hosts)) { $tmp.Add($l) }
    $tmp.Add("$apiIp api.github.com")
    [System.IO.File]::WriteAllLines($hosts, $tmp, (New-Object System.Text.UTF8Encoding($false)))
    ipconfig /flushdns | Out-Null

    Set-Location $repo
    git add -A 2>$null
    git -c user.name="LumiGen" -c user.email="lumigen@local" commit -m "LumiGen update" 2>$null
    git remote remove origin 2>$null
    git remote add origin "https://github.com/nxcdsl/nxcdsl.git"
    git branch -M main
    $push = git push -u origin main 2>&1
    $code = $LASTEXITCODE
    Say "git push exit = $code"
    foreach ($x in $push) { Say "  $x" }
}

Say "=== end ==="
$log | Set-Content -Path $result -Encoding UTF8
Write-Host ""
Write-Host "结果已写入 $result" -ForegroundColor Green
Start-Sleep -Seconds 2
