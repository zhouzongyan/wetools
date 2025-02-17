$ErrorActionPreference = 'Stop'
try {
    # 获取所有进程信息
    $processes = wmic process get ProcessId,Name,WorkingSetSize /format:csv | ConvertFrom-Csv

    # 获取所有 TCP 连接信息
    $connections = Get-NetTCPConnection -ErrorAction SilentlyContinue | 
        Group-Object -Property OwningProcess |
        Select-Object @{Name='ProcessId';Expression={$_.Name}}, 
                     @{Name='Ports';Expression={($_.Group | Select-Object -ExpandProperty LocalPort) -join ', '}}

    $result = @()
    foreach ($p in $processes) {
        $ports = ($connections | Where-Object { $_.ProcessId -eq $p.ProcessId }).Ports
        $result += @{
            'Name' = $p.Name
            'Id' = $p.ProcessId
            'Memory' = [math]::Round($p.WorkingSetSize / 1KB, 2)
            'Ports' = if ($ports) { $ports } else { 'None' }
        }
    }

    $json = ConvertTo-Json -InputObject $result
    Write-Output $json
} catch {
    Write-Error $_.Exception.Message
    exit 1
} 