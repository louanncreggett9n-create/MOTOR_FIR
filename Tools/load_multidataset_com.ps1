param(
  [string]$PortName='COM5',
  [int]$BaudRate=115200,
  [string]$ImageFile=(Join-Path $PSScriptRoot 'multidataset_0x1000_0x1FFFF.bin')
)
$ErrorActionPreference='Stop'
$sp=New-Object System.IO.Ports.SerialPort($PortName,$BaudRate,[System.IO.Ports.Parity]::None,8,[System.IO.Ports.StopBits]::One)
$sp.ReadTimeout=6000; $sp.WriteTimeout=6000
function Write-Byte([byte]$b){$sp.Write([byte[]]@($b),0,1)}
function Write-Slow([byte[]]$bytes,[int]$chunk=16,[int]$delay=1){for($i=0;$i -lt $bytes.Length;$i+=$chunk){$n=[Math]::Min($chunk,$bytes.Length-$i);$sp.Write($bytes,$i,$n);Start-Sleep -Milliseconds $delay}}
function Read-Exact([int]$count){$b=New-Object byte[] $count;$o=0;while($o -lt $count){$n=$sp.Read($b,$o,$count-$o);if($n-le 0){throw "serial timeout $o/$count"};$o+=$n};return ,$b}
function Read-Ack{$b=Read-Exact 1;if($b[0]-ne 0x06){throw ('NACK 0x{0:X2}' -f $b[0])}}
function Send-Erase([uint32]$addr){Write-Byte 0xA2;Start-Sleep -Milliseconds 100;$p=[BitConverter]::GetBytes($addr);Write-Slow $p 1 20;Read-Ack;Start-Sleep -Milliseconds 100}
function Send-Write([uint32]$addr,[byte[]]$data){for($try=1;$try-le 5;$try++){try{$p=New-Object byte[] 6;[BitConverter]::GetBytes($addr).CopyTo($p,0);[BitConverter]::GetBytes([uint16]$data.Length).CopyTo($p,4);Write-Byte 0xA3;Start-Sleep -Milliseconds 80;Write-Slow $p 1 20;Write-Slow $data 16 1;Read-Ack;Start-Sleep -Milliseconds 8;return}catch{if($try-eq 5){throw};Start-Sleep -Milliseconds 100}}}
function Send-Read([uint32]$addr,[uint16]$len){$p=New-Object byte[] 6;[BitConverter]::GetBytes($addr).CopyTo($p,0);[BitConverter]::GetBytes($len).CopyTo($p,4);Write-Byte 0xA4;Start-Sleep -Milliseconds 80;Write-Slow $p 1 20;Read-Ack;return ,(Read-Exact $len)}
try{
 $img=[IO.File]::ReadAllBytes($ImageFile)
 if($img.Length -ne 0x1F000){throw ('image length 0x{0:X} expected 0x1F000' -f $img.Length)}
 $sp.Open();$sp.DiscardInBuffer();$sp.DiscardOutBuffer()
 Write-Byte 0xA1;$p=Read-Exact 1;if($p[0]-ne 0xAA){throw 'PING failed'}
 Write-Byte 0xA6;Read-Ack;Start-Sleep -Milliseconds 150
 Send-Erase 0x00001000
 $base=0x00001000
 for($off=0;$off -lt $img.Length;$off+=256){$n=[Math]::Min(256,$img.Length-$off);$page=New-Object byte[] $n;[Array]::Copy($img,$off,$page,0,$n);Send-Write ([uint32]($base+$off)) $page;if(($off -band 0xFFF)-eq0){Write-Output ('WRITE 0x{0:X} / 0x{1:X}' -f ($base+$off),($base+$img.Length))}}
 Write-Output 'VERIFYING'
 for($off=0;$off -lt $img.Length;$off+=256){$n=[Math]::Min(256,$img.Length-$off);$r=Send-Read ([uint32]($base+$off)) ([uint16]$n);for($i=0;$i -lt $n;$i++){if($r[$i]-ne$img[$off+$i]){throw "verify mismatch at 0x{0:X}" -f ($base+$off+$i)}}}
 Write-Byte 0xA5;Read-Ack
 $samples=[BitConverter]::ToUInt32($img,12); Write-Output ('LOAD OK PORT='+$PortName+' IMAGE_BYTES='+$img.Length+' SLOTS=6 SAMPLES_PER_SLOT='+$samples)
}catch{Write-Error $_;exit 1}finally{if($sp.IsOpen){$sp.Close()};$sp.Dispose()}
