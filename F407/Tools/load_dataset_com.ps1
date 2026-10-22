param(
  [string]$PortName='COM5',
  [int]$BaudRate=115200,
  [Parameter(Mandatory=$true)][string]$DataFile,
  [Parameter(Mandatory=$true)][string]$HeaderFile
)
$sp=New-Object System.IO.Ports.SerialPort($PortName,$BaudRate,[System.IO.Ports.Parity]::None,8,[System.IO.Ports.StopBits]::One)
$sp.ReadTimeout=6000; $sp.WriteTimeout=6000
function Write-Byte([byte]$b){$sp.Write([byte[]]@($b),0,1)}
function Write-Slow([byte[]]$bytes,[int]$chunk=16,[int]$delay=1){for($i=0;$i -lt $bytes.Length;$i+=$chunk){$n=[Math]::Min($chunk,$bytes.Length-$i);$sp.Write($bytes,$i,$n);Start-Sleep -Milliseconds $delay}}
function Read-Exact([int]$count){$b=New-Object byte[] $count;$o=0;while($o -lt $count){$n=$sp.Read($b,$o,$count-$o);if($n-le 0){throw "serial timeout $o/$count"};$o+=$n};return ,$b}
function Read-Ack{$b=Read-Exact 1;if($b[0]-ne 0x06){throw ('NACK 0x{0:X2}' -f $b[0])}}
function Send-Erase([uint32]$addr){Write-Byte 0xA2;Start-Sleep -Milliseconds 50;$p=[BitConverter]::GetBytes($addr);Write-Slow $p 2 1;Read-Ack;Start-Sleep -Milliseconds 50}
function Send-Write([uint32]$addr,[byte[]]$data){$p=New-Object byte[] 6;[BitConverter]::GetBytes($addr).CopyTo($p,0);[BitConverter]::GetBytes([uint16]$data.Length).CopyTo($p,4);Write-Byte 0xA3;Start-Sleep -Milliseconds 50;Write-Slow $p 2 1;Write-Slow $data 16 1;Read-Ack;Start-Sleep -Milliseconds 50}
function Send-Read([uint32]$addr,[uint16]$len){$p=New-Object byte[] 6;[BitConverter]::GetBytes($addr).CopyTo($p,0);[BitConverter]::GetBytes($len).CopyTo($p,4);Write-Byte 0xA4;Start-Sleep -Milliseconds 50;Write-Slow $p 2 1;Read-Ack;return ,(Read-Exact $len)}
try{
 $data=[IO.File]::ReadAllBytes($DataFile);$header=[IO.File]::ReadAllBytes($HeaderFile)
 if($header.Length -ne 64){throw 'header must be 64 bytes'}
 if(($data.Length%2)-ne 0){throw 'data must be 16-bit samples'}
 $sp.Open();$sp.DiscardInBuffer();$sp.DiscardOutBuffer();$sp.DtrEnable=$true
 Write-Byte 0xA1;$p=Read-Exact 1;if($p[0]-ne 0xAA){throw 'PING failed'}
 Write-Byte 0xA6;Read-Ack;Start-Sleep -Milliseconds 100
 Send-Erase 0x00001000
 for($addr=0x00002000;$addr -lt 0x00012000;$addr+=0x1000){Send-Erase ([uint32]$addr)}
 Send-Write 0x00001000 $header
 for($off=0;$off -lt $data.Length;$off+=256){$n=[Math]::Min(256,$data.Length-$off);$page=New-Object byte[] $n;[Array]::Copy($data,$off,$page,0,$n);Send-Write ([uint32](0x00002000+$off)) $page}
 $h2=Send-Read 0x00001000 64
 if(-not [System.Linq.Enumerable]::SequenceEqual([byte[]]$h2,[byte[]]$header)){throw 'header verify failed'}
 for($off=0;$off -lt $data.Length;$off+=256){$n=[Math]::Min(256,$data.Length-$off);$r=Send-Read ([uint32](0x00002000+$off)) ([uint16]$n);for($i=0;$i -lt $n;$i++){if($r[$i]-ne $data[$off+$i]){throw "verify mismatch at $($off+$i)"}}}
 Write-Byte 0xA5;Read-Ack
 Write-Output ('LOAD OK PORT='+$PortName+' SAMPLES='+($data.Length/2)+' BYTES='+$data.Length)}catch{Write-Error $_;exit 1}finally{if($sp.IsOpen){$sp.Close()};$sp.Dispose()}
