param([switch]$SelfTest)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[Windows.Forms.Application]::EnableVisualStyles()
$script:Cfg=Get-Content -LiteralPath (Join-Path $PSScriptRoot 'tool_config.json') -Raw|ConvertFrom-Json
$script:Exe=$script:Cfg.GameExeHint
$script:Bin=Split-Path $script:Exe -Parent
$script:Ini=Join-Path $script:Bin 'OptiScaler.ini'
$script:Log=Join-Path $script:Bin 'OptiScaler.log'
$script:Backend=Join-Path $PSScriptRoot 'DLSS5Control.ps1'
$script:Busy=$false
$script:EditingLoaded=$false
function New-Label($text,$x,$y,$w,$h){$c=New-Object Windows.Forms.Label;$c.Text=$text;$c.SetBounds($x,$y,$w,$h);return $c}
$script:Form=New-Object Windows.Forms.Form
$Form.Text='赛博朋克 2077 · NR 调试面板'
$Form.ClientSize=New-Object Drawing.Size(960,780)
$Form.StartPosition='CenterScreen';$Form.Font=New-Object Drawing.Font('Microsoft YaHei UI',10)
$Form.FormBorderStyle='FixedSingle';$Form.MaximizeBox=$false;$Form.AutoScaleMode='Dpi'
$title=New-Label 'NEURAL RENDERING  /  本地调试' 20 16 900 30
$title.Font=New-Object Drawing.Font('Microsoft YaHei UI',15,[Drawing.FontStyle]::Bold)
$Form.Controls.Add($title)
$script:Status=New-Object Windows.Forms.TextBox
$Status.Multiline=$true;$Status.ReadOnly=$true;$Status.SetBounds(20,56,920,135);$Status.BackColor=[Drawing.Color]::FromArgb(243,246,250)
$Form.Controls.Add($Status)
$script:WriteButtons=New-Object 'Collections.Generic.List[Windows.Forms.Button]'
function Add-Button($text,$x,$y,$w,$action,$writes=$false){
 $b=New-Object Windows.Forms.Button;$b.Text=$text;$b.SetBounds($x,$y,$w,36);$b.Add_Click($action);$Form.Controls.Add($b)
 if($writes){$WriteButtons.Add($b)};return $b
}
function Read-NR {
 if(-not(Test-Path -LiteralPath $Ini)){return @{}}
 $text=Get-Content -LiteralPath $Ini -Raw
 $s=[regex]::Match($text,'(?ms)^\[DlssNr\]\s*\r?\n(?<body>.*?)(?=^\[|\z)')
 $map=@{};foreach($m in [regex]::Matches($s.Groups['body'].Value,'(?m)^([A-Za-z0-9]+)\s*=\s*([^\r\n;]+)')){$map[$m.Groups[1].Value]=$m.Groups[2].Value.Trim()};return $map
}
function Strength-Percent($value){
 if(-not$value-or$value-eq'auto'){return 100}
 $v=0.0;if(-not[double]::TryParse($value,[Globalization.NumberStyles]::Float,[Globalization.CultureInfo]::InvariantCulture,[ref]$v)){return 100}
 return [int][math]::Round([math]::Min(100,[math]::Max(0,100*$v)))
}
function Refresh-Panel {
 if($Busy){return}
 try{
  $p=Get-Process -Name Cyberpunk2077 -ErrorAction SilentlyContinue|Select-Object -First 1
  $script:Cfg=Get-Content -LiteralPath (Join-Path $PSScriptRoot 'tool_config.json') -Raw|ConvertFrom-Json
  $nr=Read-NR;$installed=$nr.Count-gt0;$tail=@();$currentLog=$false;$loaded=$false
  if(Test-Path -LiteralPath $Log){
   $tail=@(Get-Content -LiteralPath $Log -Tail 90)
   if($p){
    $head=Get-Content -LiteralPath $Log -TotalCount 1
    $m=[regex]::Match([string]$head,'^\[(\d\d:\d\d:\d\d\.\d{6})\].*OptiScaler.*loaded')
    if($m.Success){$t=[datetime]::ParseExact($m.Groups[1].Value,'HH:mm:ss.ffffff',[Globalization.CultureInfo]::InvariantCulture);$stamp=$p.StartTime.Date.Add($t.TimeOfDay);$currentLog=[math]::Abs(($stamp-$p.StartTime).TotalSeconds)-le5}
   }
  }
  if($p){try{$loaded=@($p.Modules|Where-Object {$_.FileName-eq(Join-Path $Bin 'winmm.dll')}).Count-gt0}catch{}}
  $runtime='UNKNOWN：启动游戏并等待 NR 执行日志'
  if(-not$p){$runtime='未运行；历史日志不作为当前生效证据'}
  elseif($nr.Enabled-eq'false'){$runtime='OFF（配置关闭）'}
  elseif($currentLog-and($tail-match'DLSS-NR cost:|DLSS-NR composition:')){$runtime='本次日志有 NR 执行记录；不是实时逐帧计数'}
  if(-not$installed){$runtime='已恢复原版；非官方 NR 未安装，重新开启已封锁'}
  elseif($Cfg.CompatibilityBlock){$runtime='重复崩溃：NR 调试与开启已封锁'}
  $gameState=if($p){'运行中（配置写入已锁定）'}else{'未运行'}
  $Status.Text="游戏：$gameState    NR 配置：$($nr.Enabled)    OptiScaler 已加载：$loaded`r`n运行证据：$runtime`r`nDLSS Quality · 模型比例 $($nr.WorkingScale) · 单次处理 $($nr.Passes) · 缓存 $($nr.CacheEnabled)`r`n游戏位置：$Exe`r`n刷新时间：$(Get-Date -Format 'HH:mm:ss')"
  if(-not$installed){$Status.Text="游戏：$gameState`r`n社区 NR：已卸载，重新开启及调参已封锁`r`n运行证据：$runtime`r`n游戏位置：$Exe`r`n原生 DLSS 文件保留。刷新时间：$(Get-Date -Format 'HH:mm:ss')"}
  if($installed-and$Cfg.PSObject.Properties.Name-contains'RequiredFrameGenerationOff'-and$Cfg.RequiredFrameGenerationOff){$Status.Text+="`r`n兼容配置：NR 开启时必须关闭原生帧生成 / MFG。";$Message.Text='当前 NR 方案关闭帧生成以避开已发生的冲突；帧率可能降低。'}
  if($installed-and$Cfg.PSObject.Properties.Name-contains'AllowFrameGenerationX2'-and$Cfg.AllowFrameGenerationX2){$Status.Text+="`r`n兼容配置：NR 可配合 DLSS 2× 帧生成；不开放 3× / 4×。";$Message.Text='保持 Quality、原强度、缓存关闭。2× 监测通过，仍非长期稳定保证。'}
  foreach($b in $WriteButtons){$b.Enabled=(-not[bool]$p)-and(($b.Text-eq'启动游戏')-or($installed-and-not$Cfg.CompatibilityBlock))}
  $DetailSlider.Enabled=$installed-and-not[bool]$p-and-not$Cfg.CompatibilityBlock
  $ColourSlider.Enabled=$DetailSlider.Enabled
  if(-not$installed){$Message.Text='已撤下不稳定的社区 NR。当前启动原版游戏；日志及备份保留。'}
  if(-not$EditingLoaded){$DetailSlider.Value=Strength-Percent $nr.TransferStrength;$ColourSlider.Value=Strength-Percent $nr.ColourStrength;$script:EditingLoaded=$true}
  $DetailValue.Text=($DetailSlider.Value.ToString()+'%');$ColourValue.Text=($ColourSlider.Value.ToString()+'%')
  if($Filter.Checked){$tail=@($tail|Where-Object {$_-match'DLSS-NR|\[E\]|Device removed|DEVICE_HUNG|history reset'})}
  $LogBox.Text=($tail-join"`r`n");$LogBox.SelectionStart=$LogBox.Text.Length;$LogBox.ScrollToCaret()
 }catch{$Message.Text='状态读取失败：'+$_.Exception.Message}
}
function Run-Control([string]$action,[switch]$defaults){
 if($Busy){return}
 $script:Busy=$true;$Form.UseWaitCursor=$true
 try{
  $launchArgs=@('-NoProfile','-STA','-File',$Backend,'-Action',$action)
  if($action-eq'Strength'){
   if($defaults){$launchArgs+='-DefaultStrength'}else{$launchArgs+=@('-Detail',($DetailSlider.Value/100.0).ToString('0.00',[Globalization.CultureInfo]::InvariantCulture),'-Colour',($ColourSlider.Value/100.0).ToString('0.00',[Globalization.CultureInfo]::InvariantCulture))}
  }
  $result=& powershell.exe @launchArgs 2>&1
  if($LASTEXITCODE-ne0){throw ($result|Out-String)}
  $Message.Text=if($action-eq'Strength'){'已备份并保存。下次启动游戏生效；画面效果需实测。'}else{'操作完成：'+$action}
  if($action-eq'Strength'){$script:EditingLoaded=$false}
 }catch{$Message.Text='操作已停止：'+$_.Exception.Message;[void][Windows.Forms.MessageBox]::Show($Message.Text,'NR 调试面板','OK','Warning')}
 finally{$script:Busy=$false;$Form.UseWaitCursor=$false;Refresh-Panel}
}
$null=Add-Button '开启 NR' 20 203 140 {Run-Control 'ON'} $true
$null=Add-Button '关闭 NR' 176 203 140 {Run-Control 'OFF'} $true
$null=Add-Button '启动游戏' 332 203 140 {Run-Control 'Launch'} $true
$null=Add-Button '打开完整日志' 488 203 140 {if(Test-Path -LiteralPath $Log){Start-Process notepad.exe -ArgumentList ('"'+$Log+'"')}}
$null=Add-Button '打开备份' 644 203 140 {Start-Process explorer.exe -ArgumentList ('"'+$Cfg.BackupRoot+'"')}
$null=Add-Button '刷新状态' 800 203 140 {Refresh-Panel}
$g=New-Object Windows.Forms.GroupBox;$g.Text='画面混合强度';$g.SetBounds(20,255,920,185);$Form.Controls.Add($g)
$g.Controls.Add((New-Label 'NR 光影 / 细节影响' 18 29 260 24))
$g.Controls.Add((New-Label '模型色彩影响' 475 29 260 24))
$script:DetailValue=New-Label '100%' 338 29 90 24;$g.Controls.Add($DetailValue)
$script:ColourValue=New-Label '100%' 795 29 90 24;$g.Controls.Add($ColourValue)
$script:DetailSlider=New-Object Windows.Forms.TrackBar;$DetailSlider.Minimum=0;$DetailSlider.Maximum=100;$DetailSlider.TickFrequency=10;$DetailSlider.SmallChange=5;$DetailSlider.LargeChange=10;$DetailSlider.SetBounds(15,57,415,48);$g.Controls.Add($DetailSlider)
$script:ColourSlider=New-Object Windows.Forms.TrackBar;$ColourSlider.Minimum=0;$ColourSlider.Maximum=100;$ColourSlider.TickFrequency=10;$ColourSlider.SmallChange=5;$ColourSlider.LargeChange=10;$ColourSlider.SetBounds(472,57,415,48);$g.Controls.Add($ColourSlider)
$DetailSlider.Add_ValueChanged({$DetailValue.Text=$DetailSlider.Value.ToString()+'%'})
$ColourSlider.Add_ValueChanged({$ColourValue.Text=$ColourSlider.Value.ToString()+'%'})
$g.Controls.Add((New-Label '100% 为原强度。超过原强度的 135% 测试曾 GPU 挂起，暂不开放。' 18 109 870 24))
$g.Controls.Add((New-Label '调整混合强度不等于改变光追、分辨率或模型处理次数；0% 也不等于关闭 NR 计算。' 18 140 880 24))
$null=Add-Button '备份并应用强度' 20 450 190 {Run-Control 'Strength'} $true
$null=Add-Button '恢复原强度' 226 450 190 {Run-Control 'Strength' -defaults} $true
$null=Add-Button '移除 Mod / 恢复原版' 644 450 296 {
 if([Windows.Forms.MessageBox]::Show('退出游戏后，此操作把新增 Mod 文件移入备份区，恢复游戏原版。继续？','恢复原版','YesNo','Question')-eq'Yes'){Run-Control 'Restore'}
} $true
$script:Message=New-Label '配置修改前自动备份；游戏运行时只读。编辑缓存与多次处理暂不开放。' 20 496 920 38;$Form.Controls.Add($Message)
$script:Filter=New-Object Windows.Forms.CheckBox;$Filter.Text='只显示 NR 与错误日志';$Filter.Checked=$true;$Filter.SetBounds(20,538,340,26);$Filter.Add_CheckedChanged({Refresh-Panel});$Form.Controls.Add($Filter)
$script:LogBox=New-Object Windows.Forms.RichTextBox;$LogBox.ReadOnly=$true;$LogBox.WordWrap=$false;$LogBox.SetBounds(20,570,920,190);$LogBox.Font=New-Object Drawing.Font('Consolas',9);$LogBox.BackColor=[Drawing.Color]::FromArgb(22,28,38);$LogBox.ForeColor=[Drawing.Color]::FromArgb(203,224,238);$Form.Controls.Add($LogBox)
$script:Timer=New-Object Windows.Forms.Timer;$Timer.Interval=3000;$Timer.Add_Tick({Refresh-Panel})
$Form.Add_Shown({Refresh-Panel;$Timer.Start()})
$Form.Add_FormClosed({$Timer.Stop();$Timer.Dispose()})
if($SelfTest){Refresh-Panel;[pscustomobject]@{Controls=$Form.Controls.Count;Status=$Status.Text;Buttons=@($WriteButtons|Select-Object Text,Enabled);DetailSliderEnabled=$DetailSlider.Enabled;ColourSliderEnabled=$ColourSlider.Enabled}|ConvertTo-Json -Depth 4;$Form.Dispose();return}
[Windows.Forms.Application]::Run($Form)
