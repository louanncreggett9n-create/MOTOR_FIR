$ErrorActionPreference='Stop'
$names=@('H','UNBAL','MISAL','BF','BOW','BROKEN')
function Open-F407 {
  $sp=New-Object System.IO.Ports.SerialPort COM5,115200,None,8,One
  $sp.ReadTimeout=2000; $sp.Open(); return $sp
}
function Select-Slot([int]$slot){
  $sp=Open-F407; try { $sp.DiscardInBuffer(); $sp.Write([byte[]](0xC0),0,1); Start-Sleep -Milliseconds 20; $sp.Write([byte[]]([byte]$slot),0,1); Start-Sleep -Milliseconds 80; $a=$sp.ReadByte(); if($a -ne 6){throw "slot $slot ack=$a"} } finally { if($sp.IsOpen){$sp.Close()};$sp.Dispose() }
}
function Trigger-Scan {
  $sp=New-Object System.IO.Ports.SerialPort COM7,2000000,None,8,One
  try { $sp.Open(); $sp.DiscardInBuffer(); $sp.Write([byte[]](0x53),0,1); Start-Sleep -Milliseconds 200 } finally { if($sp.IsOpen){$sp.Close()};$sp.Dispose() }
}
function F407-DcTest {
  $sp=Open-F407; try { $sp.DiscardInBuffer(); $sp.Write([byte[]](0xB2),0,1); Start-Sleep -Milliseconds 100; $a=$sp.ReadByte(); if($a -ne 6){throw "dc ack=$a"} } finally { if($sp.IsOpen){$sp.Close()};$sp.Dispose() }
}
$log=@()
for($s=0;$s -lt 6;$s++){
  Select-Slot $s; Start-Sleep -Milliseconds 500; Trigger-Scan
  $msg="SLOT=$s NAME=$($names[$s]) TIME=$(Get-Date -Format 'HH:mm:ss')"
  Write-Output $msg; $log+=$msg
  Start-Sleep -Seconds 6
}
F407-DcTest; Start-Sleep -Milliseconds 500; Trigger-Scan
$msg="UNKNOWN DC_TEST TIME=$(Get-Date -Format 'HH:mm:ss')"; Write-Output $msg; $log+=$msg
Start-Sleep -Seconds 6
Select-Slot 0
$msg="RESTORE=SLOT0 H TIME=$(Get-Date -Format 'HH:mm:ss')"; Write-Output $msg; $log+=$msg
$log | Set-Content -LiteralPath (Join-Path $PSScriptRoot 'guided_acceptance_scan.log') -Encoding UTF8
Write-Output 'GUIDED_SCAN_DONE'