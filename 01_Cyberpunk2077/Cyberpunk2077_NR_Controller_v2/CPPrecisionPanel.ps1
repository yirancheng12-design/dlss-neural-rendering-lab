param([switch]$SelfTest)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[Windows.Forms.Application]::EnableVisualStyles()
$form=New-Object Windows.Forms.Form
$form.Text='赛博朋克2077 NR 精度控制台 v2';$form.Size=New-Object Drawing.Size(600,690);$form.StartPosition='CenterScreen';$form.FormBorderStyle='FixedDialog';$form.MaximizeBox=$false
$form.Font=New-Object Drawing.Font('Microsoft YaHei UI',10)
function Label($text,$y){$l=New-Object Windows.Forms.Label;$l.Text=$text;$l.Location=New-Object Drawing.Point(24,$y);$l.Size=New-Object Drawing.Size(290,28);$form.Controls.Add($l)}
function Number($y,$min,$max,$step,$digits){$n=New-Object Windows.Forms.NumericUpDown;$n.Location=New-Object Drawing.Point(330,$y);$n.Size=New-Object Drawing.Size(210,28);$n.Minimum=$min;$n.Maximum=$max;$n.Increment=$step;$n.DecimalPlaces=$digits;$form.Controls.Add($n);return $n}
Label 'NR 模型精度（%，不改变游戏分辨率）' 30
$precision=Number 28 50 100 1 0
Label '光影混合强度（0–1）' 80;$light=Number 78 0 1 0.05 2
Label '色彩混合强度（0–1）' 130;$colour=Number 128 0 1 0.05 2
Label 'NR 风格' 180
$style=New-Object Windows.Forms.ComboBox;$style.Location=New-Object Drawing.Point(330,178);$style.Size=New-Object Drawing.Size(210,28);$style.DropDownStyle='DropDownList';$style.Items.AddRange(@('默认／最强','自然','电影'));$form.Controls.Add($style)
Label 'NR 处理层数（1–3 层）' 230;$passes=Number 228 1 3 1 0
Label '原生 DLSS 插帧倍率' 280
$fg=New-Object Windows.Forms.ComboBox;$fg.Location=New-Object Drawing.Point(330,278);$fg.Size=New-Object Drawing.Size(210,28);$fg.DropDownStyle='DropDownList';$fg.Items.AddRange(@('关闭','2 倍','3 倍','4 倍'));$form.Controls.Add($fg)
$enabled=New-Object Windows.Forms.CheckBox;$enabled.Text='启用 Neural Rendering';$enabled.Location=New-Object Drawing.Point(24,328);$enabled.Size=New-Object Drawing.Size(290,28);$form.Controls.Add($enabled)
$status=New-Object Windows.Forms.Label;$status.Location=New-Object Drawing.Point(24,370);$status.Size=New-Object Drawing.Size(535,100);$form.Controls.Add($status)
$note=New-Object Windows.Forms.Label;$note.Text="高精度、多层 NR 会增加 GPU 负载，存在已知崩溃风险。`n保存为永久配置；实际 NR 与插帧需由运行日志验证。`nNR 配合3/4倍插帧有已知冲突，启用NR时仅开放关闭/2倍。";$note.Location=New-Object Drawing.Point(24,550);$note.Size=New-Object Drawing.Size(540,75);$form.Controls.Add($note)
function Button($text,$x,$y,$width){$b=New-Object Windows.Forms.Button;$b.Text=$text;$b.Location=New-Object Drawing.Point($x,$y);$b.Size=New-Object Drawing.Size($width,36);$form.Controls.Add($b);return $b}
$apply=Button '备份并永久保存' 24 490 160;$refresh=Button '读取当前配置' 200 490 160;$logs=Button '打开日志目录' 376 490 160
function RefreshPanel{
 $s=(& (Join-Path $PSScriptRoot 'CPPrecisionEngine.ps1') -Action Read)|ConvertFrom-Json
 $precision.Value=[decimal]([double]$s.NR.WorkingScale*100)
 $passes.Value=if($s.NR.Passes -eq 'auto'){1}else{[int]$s.NR.Passes}
 $light.Value=if($s.NR.TransferStrength -eq 'auto'){1}else{[decimal]$s.NR.TransferStrength}
 $colour.Value=if($s.NR.ColourStrength -eq 'auto'){1}else{[decimal]$s.NR.ColourStrength}
 $style.SelectedIndex=if($s.NR.Style -eq 'auto'){0}else{[int]$s.NR.Style};$fg.SelectedIndex=[int]$s.NativeFG
 $enabled.Checked=$s.NR.Enabled -eq 'true';$apply.Enabled=-not $s.GameRunning
 $status.Text=if($s.GameRunning){"游戏运行中：禁止保存。`n下方显示已保存参数，不代表当前运行值。`n退出游戏后点击「读取当前配置」再调整。"}else{"游戏未运行：可以保存；下次启动赛博朋克2077生效。`n实际运行状态：尚未在此面板中验证。"}
 $status.Text+="`n已保存："+$precision.Value+'% ／ '+$passes.Value+' 层 ／ 插帧 '+$fg.Text
}
$refresh.Add_Click({try{RefreshPanel}catch{[Windows.Forms.MessageBox]::Show($_.Exception.Message,'读取失败')|Out-Null}})
$apply.Add_Click({try{
 $result=& (Join-Path $PSScriptRoot 'CPPrecisionEngine.ps1') -Action Apply -Precision ([int]$precision.Value) -Passes ([int]$passes.Value) -Style $style.SelectedIndex -Light ([double]$light.Value) -Colour ([double]$colour.Value) -NativeFG $fg.SelectedIndex -Enabled $enabled.Checked
 $r=$result|ConvertFrom-Json;RefreshPanel
 [Windows.Forms.MessageBox]::Show(('保存成功。下次正常启动游戏后生效。'+"`n备份："+$r.Backup),'NR 配置')|Out-Null
}catch{[Windows.Forms.MessageBox]::Show($_.Exception.Message,'保存失败')|Out-Null}})
$logs.Add_Click({$c=Get-Content -LiteralPath (Join-Path $PSScriptRoot 'tool_config.json') -Raw|ConvertFrom-Json;Start-Process explorer.exe -ArgumentList ('"'+(Split-Path $c.GameExeHint -Parent)+'"')})
RefreshPanel
if($SelfTest){Write-Output ('Panel initialized: precision='+$precision.Value+', passes='+$passes.Value+', nativeFG='+$fg.SelectedIndex);$form.Dispose();exit}
[void]$form.ShowDialog()
