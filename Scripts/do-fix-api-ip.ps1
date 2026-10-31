$ErrorActionPreference = "Continue"
$hosts  = "$env:SystemRoot\System32\drivers\etc\hosts"
$result = "C:\Users\15035\Projects\fix-result.txt"
$log    = New-Object System.Collections.Generic.List[string]
function Say($t) { $log.Add($t); Write-Host $t }

Say "=== fix api ip $(Get-Date -Format 'HH:mm:ss') ==="
$ip = "20.205.243.168"
try {
    $lines = [System.IO.File]::ReadAllLines($hosts)
    $out = New-Object System.Collections.Generic.List[string]
    $done = $false
    foreach ($l in $lines) {
        if ($l -match "^\s*[\d\.]+\s+api\.github\.com\s*$") {
            $out.Add("$ip api.github.com"); $done = $true
        } else { $out.Add($l) }
    }
    if (-not $done) { $out.Add("$ip api.github.com") }
    [System.IO.File]::WriteAllLines($hosts, $out, (New-Object System.Text.UTF8Encoding($false)))
    ipconfig /flushdns | Out-Null
    Say "hosts api.github.com -> $ip"
} catch { Say "hosts write FAIL: $($_.Exception.Message)" }

Start-Sleep -Seconds 1
$ips = (Resolve-DnsName api.github.com -Type A -ErrorAction SilentlyContinue | Where-Object { $_.IPAddress } | Select-Object -First 2).IPAddress -join ", "
Say "resolve api.github.com = $ips"

$h = @{ "User-Agent" = "lumigen-agent" }
try {
    $r = Invoke-RestMethod "https://api.github.com/repos/nxcdsl/nxcdsl/actions/runs?per_page=2" -Headers $h -TimeoutSec 25
    Say "api ok, runs=$($r.total_count)"
    foreach ($run in $r.workflow_runs) { Say "  #$($run.run_number) $($run.status)/$($run.conclusion) $($run.created_at)" }
} catch { Say "api FAIL: $($_.Exception.Message)" }

Say "=== end ==="
$log | Set-Content -Path $result -Encoding UTF8
Start-Sleep -Seconds 1
