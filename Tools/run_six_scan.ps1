param(
  [string]$ComF407='COM5',
  [string]$ComFpga='COM7',
  [int]$StartSlot=0,
  [int]$EndSlot=5
)
$ErrorActionPreference='Stop'
$outDir=$PSScriptRoot
$names=@('H','UNBAL','MISAL','BF','BOW','BROKEN')
function Send-Select([int]$slot){
  $sp=New-Object System.IO.Ports.SerialPort $ComF407,115200,None,8,One
  $sp.ReadTimeout=2000
  $sp.Open(); $sp.DiscardInBuffer(); $ack=$null
  for($try=1;$try -le 5 -and $ack -ne 6;$try++){
    $sp.Write([byte[]](0xC0),0,1); Start-Sleep -Milliseconds 10
    $sp.Write([byte[]]([byte]$slot),0,1)
    $sw=[Diagnostics.Stopwatch]::StartNew()
    while($sw.ElapsedMilliseconds -lt 2000 -and $sp.BytesToRead -lt 1){Start-Sleep -Milliseconds 1}
    if($sp.BytesToRead -gt 0){$ack=$sp.ReadByte()} else {$ack=$null}
    if($ack -ne 6){Start-Sleep -Milliseconds 100}
  }
  $sp.Close()
  if($ack -ne 6){throw "slot $slot select failed ack=$ack"}
}
function Capture-Scan([string]$tag){
  $sp=New-Object System.IO.Ports.SerialPort $ComFpga,2000000,None,8,One
  $raw=New-Object System.Collections.Generic.List[byte]
  $sp.Open(); $sp.DiscardInBuffer()
  $sp.Write([byte[]](0x53),0,1); Start-Sleep -Milliseconds 100
  $sw=[Diagnostics.Stopwatch]::StartNew()
  while($sw.ElapsedMilliseconds -lt 100000){
    $n=$sp.BytesToRead
    if($n -gt 0){$t=New-Object byte[] $n;$g=$sp.Read($t,0,$n);for($i=0;$i -lt $g;$i++){$raw.Add($t[$i])}}
    else{Start-Sleep -Milliseconds 5}
  }
  $sp.Close()
  $rawPath=Join-Path $outDir ("scan_slot_{0}_raw.bin" -f $tag)
  [IO.File]::WriteAllBytes($rawPath,$raw.ToArray())
  $all=New-Object System.Collections.Generic.List[object]
  for($i=0;$i -lt ($raw.Count-9);){
    if($raw[$i] -eq 0xAB){
      $idx=[int]$raw[$i+1]
      $xr=($raw[$i+2]-shl16)-bor($raw[$i+3]-shl8)-bor$raw[$i+4]
      if($xr-band0x800000){$xr-=0x1000000}
      $xi=($raw[$i+5]-shl16)-bor($raw[$i+6]-shl8)-bor$raw[$i+7]
      if($xi-band0x800000){$xi-=0x1000000}
      $st=[int]$raw[$i+8]; $sm=[int]$raw[$i+9]
      $calc=(0xAB+$idx+$raw[$i+2]+$raw[$i+3]+$raw[$i+4]+$raw[$i+5]+$raw[$i+6]+$raw[$i+7]+$st)-band255
      if($calc -eq $sm){
        $all.Add([pscustomobject]@{Idx=$idx;Xr=$xr;Xi=$xi;Mag=[math]::Abs($xr)+[math]::Abs($xi);Status=$st})
        $i+=10; continue
      }
    }
    $i++
  }
  $best=@()
  for($i=0;$i -lt $all.Count;$i++){
    if($all[$i].Idx -ne 0){continue}
    $run=@(); $expect=0; $end=$i
    for($j=$i;$j -lt $all.Count;$j++){
      if($all[$j].Idx -eq $expect){
        $run+=$all[$j]; $expect++; $end=$j+1
        if($expect -eq 128){break}
      }
    }
    if($run.Count -eq 128){
      $summary=$null
      for($k=$end;$k -lt $all.Count;$k++){
        if($all[$k].Status -ne 5){$summary=$all[$k];break}
      }
      $candidate=$run
      if($null -ne $summary){$candidate=$run+$summary}
      if($candidate.Count -gt $best.Count){$best=$candidate}
    }
  }
  $jsonPath=Join-Path $outDir ("scan_slot_{0}_frames.json" -f $tag)
  $best|ConvertTo-Json -Compress|Set-Content -LiteralPath $jsonPath -Encoding UTF8
  if($best.Count -lt 128){throw "slot $tag incomplete scan frames=$($best.Count) candidates=$($all.Count)"}
  if($best.Count -ge 129){$summary=$best[128]}
  else {$summary=$best|Sort-Object Mag -Descending|Select-Object -First 1; $summary|Add-Member -NotePropertyName Status -NotePropertyValue 0x80 -Force}
  return [pscustomobject]@{Tag=$tag;Frames=$best.Count;SummaryBin=$summary.Idx;SummaryXr=$summary.Xr;SummaryXi=$summary.Xi;SummaryStatus=$summary.Status;RawBytes=$raw.Count;RawFile=$rawPath;JsonFile=$jsonPath}
}
$rows=@()
for($slot=$StartSlot;$slot -le $EndSlot;$slot++){
  Write-Output ("SCAN_START slot={0} name={1} {2}" -f $slot,$names[$slot],(Get-Date -Format 'HH:mm:ss'))
  Send-Select $slot
  Start-Sleep -Milliseconds 300
  $r=Capture-Scan ("{0}_{1}" -f $slot,$names[$slot])
  $r|Add-Member -NotePropertyName Slot -NotePropertyValue $slot
  $r|Add-Member -NotePropertyName Name -NotePropertyValue $names[$slot]
  $rows+=$r
  Write-Output ("SCAN_DONE slot={0} name={1} bin={2} xr={3} xi={4} status=0x{5:X2}" -f $slot,$names[$slot],$r.SummaryBin,$r.SummaryXr,$r.SummaryXi,$r.SummaryStatus)
}
Send-Select 0
$rows|ConvertTo-Json -Depth 4|Set-Content -LiteralPath (Join-Path $outDir ("six_scan_summary_{0}_{1}.json" -f $StartSlot,$EndSlot)) -Encoding UTF8
$rows|Select-Object Slot,Name,SummaryBin,SummaryXr,SummaryXi,SummaryStatus,Frames,RawBytes|Format-Table -AutoSize