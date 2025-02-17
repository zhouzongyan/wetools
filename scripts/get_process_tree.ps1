$ErrorActionPreference = 'Stop'
$ProcessId = $args[0]

try {
    $process = wmic process where "ProcessId=$ProcessId" get ParentProcessId,CommandLine /format:csv | ConvertFrom-Csv
    $parent = wmic process where "ProcessId=$($process.ParentProcessId)" get Name /format:csv | ConvertFrom-Csv
    
    $info = @{
        ProcessId = $ProcessId
        ParentProcessId = if ($process.ParentProcessId) { $process.ParentProcessId } else { "N/A" }
        ParentName = if ($parent.Name) { $parent.Name } else { "N/A" }
        CommandLine = if ($process.CommandLine) { $process.CommandLine } else { "N/A" }
    }
    
    $json = $info | ConvertTo-Json
    Write-Output $json
} catch {
    Write-Error $_.Exception.Message
    exit 1
} 