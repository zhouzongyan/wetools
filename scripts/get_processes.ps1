$ErrorActionPreference = 'Stop'
try {
    $processes = Get-Process | ForEach-Object {
        $ports = @()
        $netstat = netstat -ano | Select-String -Pattern "\s+$($_.Id)$"
        foreach($line in $netstat) {
            if($line -match "\s+(TCP|UDP)\s+([^\s]+)") {
                $ports += $matches[2]
            }
        }
        [PSCustomObject]@{
            Name = $_.Name;
            Id = $_.Id;
            Memory = [math]::Round($_.WorkingSet64/1KB,2);
            Ports = if($ports.Count -gt 0){$ports -join ", "}else{"None"};
        }
    }
    $processes | ConvertTo-Json -Compress
} catch {
    Write-Error $_.Exception.Message
    exit 1
} 