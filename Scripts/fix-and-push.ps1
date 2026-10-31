$ErrorActionPreference = "Continue"
$repo = "C:\Users\15035\Projects\LumiGen"

# ---- 0. 需要管理员权限才能改 DNS ----
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host ""
    Write-Host "  需要管理员权限来修 DNS。" -ForegroundColor Yellow
    Write-Host "  马上会弹出一个【用户账户控制】窗口，请点「是」。" -ForegroundColor Yellow
    Write-Host ""
    Start-Sleep -Seconds 2
    Start-Process powershell -Verb RunAs -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-NoExit", "-File", "`"$PSCommandPath`"")
    exit
}

Write-Host ""
Write-Host "===== 1/3  修复 DNS（把 WLAN 的 DNS 换成公共 DNS）=====" -ForegroundColor Cyan
try {
    Set-DnsClientServerAddress -InterfaceAlias "WLAN" -ServerAddresses @("223.5.5.5", "119.29.29.29")
    Clear-DnsClientCache
    Write-Host "  DNS 已改成 223.5.5.5 / 119.29.29.29" -ForegroundColor Green
} catch {
    Write-Host "  改 DNS 失败：$($_.Exception.Message)" -ForegroundColor Red
}
Start-Sleep -Seconds 2
$ips = (Resolve-DnsName github.com -Type A -ErrorAction SilentlyContinue | Where-Object { $_.IPAddress } | Select-Object -First 2).IPAddress -join ", "
Write-Host "  github.com 现在解析到: $ips"

Write-Host ""
Write-Host "===== 2/3  测试能不能连上 GitHub =====" -ForegroundColor Cyan
$ok = Test-NetConnection github.com -Port 443 -InformationLevel Quiet -WarningAction SilentlyContinue
if ($ok) { Write-Host "  443 端口通了" -ForegroundColor Green }
else { Write-Host "  443 不通（如果这里失败，请告诉我，换别的办法）" -ForegroundColor Red }

Write-Host ""
Write-Host "===== 3/3  推送代码 =====" -ForegroundColor Cyan
Set-Location $repo
git add -A 2>$null
git -c user.name="LumiGen" -c user.email="lumigen@local" commit -m "LumiGen update" 2>$null
git remote remove origin 2>$null
git remote add origin "https://github.com/nxcdsl/nxcdsl.git"
git branch -M main
git push -u origin main

Write-Host ""
if ($LASTEXITCODE -eq 0) {
    Write-Host "  推送成功！编译会自动开始，5 分钟后来看结果。" -ForegroundColor Green
    Start-Sleep -Seconds 1
    Start-Process "https://github.com/nxcdsl/nxcdsl/actions"
} else {
    Write-Host "  推送失败（退出码 $LASTEXITCODE）。把窗口截图发我。" -ForegroundColor Red
}

Write-Host ""
Write-Host "按任意键关闭这个窗口..." -ForegroundColor DarkGray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
