Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'

$stdout = "dev_stdout.log"
$stderr = "dev_stderr.log"
Remove-Item $stdout, $stderr -ErrorAction SilentlyContinue

function Get-DescendantProcessIds {
    param([int]$ParentId)
    $children = Get-CimInstance Win32_Process -Filter "ParentProcessId=$ParentId" -ErrorAction SilentlyContinue
    foreach ($child in $children) {
        $child.ProcessId
        Get-DescendantProcessIds -ParentId $child.ProcessId
    }
}

function Invoke-Endpoint {
    param([string]$Url)
    try {
        $resp = Invoke-WebRequest -Uri $Url -Method Get -SkipHttpErrorCheck -TimeoutSec 10
        $body = [string]$resp.Content
        if ($null -eq $body) { $body = "" }
        if ($body.Length -gt 240) { $body = $body.Substring(0, 240) }
        [pscustomobject]@{ url = $Url; status = [int]$resp.StatusCode; bodySnippet = $body }
    }
    catch {
        $status = "ERROR"
        $body = $_.Exception.Message
        if ($_.Exception.Response) {
            try { $status = [int]$_.Exception.Response.StatusCode } catch {}
            try {
                $stream = $_.Exception.Response.GetResponseStream()
                if ($stream) {
                    $reader = [System.IO.StreamReader]::new($stream)
                    $raw = $reader.ReadToEnd()
                    if ($raw) { $body = $raw }
                }
            }
            catch {}
        }
        if ($null -eq $body) { $body = "" }
        if ($body.Length -gt 240) { $body = $body.Substring(0, 240) }
        [pscustomobject]@{ url = $Url; status = $status; bodySnippet = $body }
    }
}

$proc = Start-Process -FilePath "npm.cmd" -ArgumentList "run dev" -WorkingDirectory (Get-Location).Path -RedirectStandardOutput $stdout -RedirectStandardError $stderr -PassThru
$deadline = (Get-Date).AddSeconds(120)
$started = $false
$startupLine = $null

while ((Get-Date) -lt $deadline -and -not $started) {
    $proc.Refresh()
    if (Test-Path $stdout) {
        $content = Get-Content $stdout -Raw -ErrorAction SilentlyContinue
        if ($content -match "Server running on port") {
            $started = $true
            $startupLine = ($content -split "`r?`n" | Where-Object { $_ -match "Server running on port" } | Select-Object -Last 1)
            break
        }
    }
    if ($proc.HasExited) { break }
}

$healthResults = @(
    Invoke-Endpoint -Url "http://localhost:3000/health"
    Invoke-Endpoint -Url "http://localhost:3000/api/health"
)

$idsToStop = New-Object System.Collections.Generic.HashSet[int]
if ($proc -and -not $proc.HasExited) { [void]$idsToStop.Add($proc.Id) }
if ($proc) {
    $desc = Get-DescendantProcessIds -ParentId $proc.Id | Sort-Object -Unique
    foreach ($id in $desc) { [void]$idsToStop.Add([int]$id) }
}
$portPids = Get-NetTCPConnection -LocalPort 3000 -State Listen -ErrorAction SilentlyContinue | Select-Object -ExpandProperty OwningProcess -Unique
foreach ($portPid in $portPids) { [void]$idsToStop.Add([int]$portPid) }

$stopped = @()
foreach ($id in ($idsToStop | Sort-Object -Descending -Unique)) {
    try {
        Stop-Process -Id $id -ErrorAction Stop
        $stopped += $id
    }
    catch {}
}

$stdoutTail = if (Test-Path $stdout) { (Get-Content $stdout -Tail 30 -ErrorAction SilentlyContinue) -join "`n" } else { "" }
$stderrTail = if (Test-Path $stderr) { (Get-Content $stderr -Tail 30 -ErrorAction SilentlyContinue) -join "`n" } else { "" }

$result = [pscustomobject]@{
    started = $started
    startupLog = $startupLine
    processId = $proc.Id
    processExitedEarly = $proc.HasExited
    processExitCode = if ($proc.HasExited) { $proc.ExitCode } else { $null }
    healthChecks = $healthResults
    stoppedProcessIds = $stopped
    stdoutTail = $stdoutTail
    stderrTail = $stderrTail
}

$result | ConvertTo-Json -Depth 6
