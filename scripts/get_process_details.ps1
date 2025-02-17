$ErrorActionPreference = 'Stop'
$ProcessId = $args[0]

try {
    $process = wmic process where "ProcessId=$ProcessId" get CommandLine,Priority,ThreadCount,HandleCount,CreationDate,ExecutablePath /format:csv | ConvertFrom-Csv
    $memory = wmic process where "ProcessId=$ProcessId" get WorkingSetSize,VirtualSize /format:csv | ConvertFrom-Csv
    
    if (!$process -or !$memory) {
        throw "Process not found"
    }

    $info = @{
        'CPU' = 'N/A';
        'ThreadCount' = $(if ($process.ThreadCount) { $process.ThreadCount } else { 'N/A' });
        'HandleCount' = $(if ($process.HandleCount) { $process.HandleCount } else { 'N/A' });
        'WorkingSet' = $(if ($memory.WorkingSetSize) { [math]::Round($memory.WorkingSetSize / 1MB, 2) } else { 'N/A' });
        'VirtualMemory' = $(if ($memory.VirtualSize) { [math]::Round($memory.VirtualSize / 1MB, 2) } else { 'N/A' });
        'Priority' = $(if ($process.Priority) { $process.Priority } else { 'N/A' });
        'StartTime' = $(if ($process.CreationDate) { 
            try {
                [Management.ManagementDateTimeConverter]::ToDateTime($process.CreationDate).ToString('yyyy-MM-dd HH:mm:ss')
            } catch {
                'N/A'
            }
        } else { 'N/A' });
        'Path' = $(if ($process.ExecutablePath) { $process.ExecutablePath } else { 'N/A' });
        'CommandLine' = $(if ($process.CommandLine) { $process.CommandLine } else { 'N/A' })
    }
    
    $json = $info | ConvertTo-Json
    Write-Output $json
} catch {
    Write-Error $_.Exception.Message
    exit 1
} 