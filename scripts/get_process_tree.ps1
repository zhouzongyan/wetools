param(
    [Parameter(Mandatory=$true)]
    [int]$ProcessId
)

$ErrorActionPreference = 'Stop'
try {
    $process = Get-CimInstance Win32_Process | Where-Object ProcessId -eq $ProcessId
    $parent = Get-CimInstance Win32_Process | Where-Object ProcessId -eq $process.ParentProcessId
    [PSCustomObject]@{
        ProcessId = $process.ProcessId;
        ParentProcessId = $process.ParentProcessId;
        ParentName = if($parent){$parent.Name}else{'N/A'};
        CommandLine = if($process.CommandLine){$process.CommandLine}else{'N/A'};
    } | ConvertTo-Json -Compress
} catch {
    Write-Error $_.Exception.Message
    exit 1
} 