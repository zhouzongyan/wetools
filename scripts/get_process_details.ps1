param(
    [Parameter(Mandatory=$true)]
    [int]$ProcessId
)

$ErrorActionPreference = 'Stop'
try {
    $process = Get-Process -Id $ProcessId
    $info = [PSCustomObject]@{
        CPU = if($process.CPU){$process.CPU}else{0};
        ThreadCount = $process.Threads.Count;
        HandleCount = $process.HandleCount;
        WorkingSet = [math]::Round($process.WorkingSet64/1MB, 2);
        VirtualMemory = [math]::Round($process.VirtualMemorySize64/1MB, 2);
        Priority = $process.PriorityClass;
        StartTime = if($process.StartTime){$process.StartTime.ToString('yyyy-MM-dd HH:mm:ss')}else{'N/A'};
        Path = if($process.Path){$process.Path}else{'N/A'};
    }
    $info | ConvertTo-Json -Compress
} catch {
    Write-Error $_.Exception.Message
    exit 1
} 