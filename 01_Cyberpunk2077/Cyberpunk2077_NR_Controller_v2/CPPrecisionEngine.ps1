param([ValidateSet('Read','Apply')][string]$Action='Read',[ValidateRange(50,100)][int]$Precision=67,[ValidateRange(1,3)][int]$Passes=1,[ValidateRange(0,2)][int]$Style=0,[ValidateRange(0,1)][double]$Light=1,[ValidateRange(0,1)][double]$Colour=1,[ValidateRange(0,3)][int]$NativeFG=1,[bool]$Enabled=$true)
$ErrorActionPreference='Stop'
$configPath=Join-Path $PSScriptRoot 'tool_config.json'
$cfg=Get-Content -LiteralPath $configPath -Raw|ConvertFrom-Json
$bin=Split-Path $cfg.GameExeHint -Parent;$ini=Join-Path $bin 'OptiScaler.ini'
$settings=Join-Path $env:LOCALAPPDATA 'CD Projekt Red\Cyberpunk 2077\UserSettings.json'
function Running {@(Get-Process -Name Cyberpunk2077 -ErrorAction SilentlyContinue).Count -gt 0}
function Hash($p){(Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash.ToLowerInvariant()}
function NrKeys($text){$section=[regex]::Match($text,'(?ms)^\[DlssNr\][^\r\n]*\r?\n(.*?)(?=^\[|\z)');if(-not $section.Success){throw 'Missing NR section'};$map=@{};foreach($m in [regex]::Matches($section.Groups[1].Value,'(?m)^([A-Za-z0-9]+)=([^\r\n]*)')){$map[$m.Groups[1].Value]=$m.Groups[2].Value.Trim()};return $map}
function NativeBlock($text,$name){$matches=[regex]::Matches($text,('(?s)\{\s*"name"\s*:\s*"'+[regex]::Escape($name)+'".*?\}'));if($matches.Count -ne 1){throw ('Ambiguous/missing native setting: '+$name)};return $matches[0]}
function NativeSet($text,$name,$value,$index){$m=NativeBlock $text $name;$block=$m.Value;$valueText=$value|ConvertTo-Json -Compress;$block=[regex]::Replace($block,'("value"\s*:\s*)(?:"[^"]*"|true|false)',('${1}'+$valueText));if($null -ne $index){$block=[regex]::Replace($block,'("index"\s*:\s*)\d+',('${1}'+$index))};return $text.Substring(0,$m.Index)+$block+$text.Substring($m.Index+$m.Length)}
$text=[IO.File]::ReadAllText($ini);$native=[IO.File]::ReadAllText($settings);$keys=NrKeys $text
if($Action -eq 'Read'){
 $fg=(NativeBlock $native 'FrameGeneration').Value|ConvertFrom-Json;$mf=(NativeBlock $native 'DLSS_MultiFrameGeneration').Value|ConvertFrom-Json
 $nativeIndex=if($fg.value -eq 'Off'){0}elseif($fg.value -eq 'DLSS'){switch($mf.value){'x2'{1};'x3'{2};'x4'{3};default{throw 'Unknown native FG multiplier'}}}else{throw 'Only native DLSS FG supported by this panel'}
 [pscustomobject]@{NR=$keys;NativeFG=$nativeIndex;GameRunning=(Running);Runtime='Saved settings only; inspect fresh NR and DLSS-G logs'}|ConvertTo-Json -Depth 5;exit
}
if(Running){throw '请退出赛博朋克2077后保存。'}
if($cfg.CompatibilityBlock){throw ('Existing compatibility block: '+$cfg.CompatibilityBlock)}
if($Enabled -and $NativeFG -gt 1){throw 'NR 与 3/4 倍插帧有已知兼容风险；当前仅开放 NR+关闭/2倍。关闭 NR 后可保存原生3/4倍。'}
if((Hash $cfg.GameExeHint) -ne $cfg.GameExeSHA256){throw 'Game version changed; compatibility review required'}
foreach($p in $cfg.ExpectedHashes.PSObject.Properties){if((Hash (Join-Path $bin $p.Name)) -ne $p.Value){throw ('Unreviewed DLL: '+$p.Name)}}
foreach($p in @($ini,$settings,$configPath)){if((Get-Item -LiteralPath $p).Attributes -band [IO.FileAttributes]::ReparsePoint){throw 'Reparse point refused'}}
$culture=[Globalization.CultureInfo]::InvariantCulture
$changes=@{WorkingScale=($Precision/100.0).ToString('0.00',$culture);Passes=[string]$Passes;Style=[string]$Style;TransferStrength=$Light.ToString('0.00',$culture);ColourStrength=$Colour.ToString('0.00',$culture);Enabled=$Enabled.ToString().ToLowerInvariant()}
foreach($key in $changes.Keys){if(-not $keys.ContainsKey($key)){throw ('Missing NR key '+$key)}}
$new=[regex]::Replace($text,'(?ms)(^\[DlssNr\][^\r\n]*\r?\n)(.*?)(?=^\[|\z)',[Text.RegularExpressions.MatchEvaluator]{param($m) $body=$m.Groups[2].Value;foreach($key in $changes.Keys){$body=[regex]::Replace($body,('(?m)^'+$key+'=[^\r\n]*'),($key+'='+$changes[$key]))};$m.Groups[1].Value+$body})
$nativeNew=NativeSet $native 'FrameGeneration' $(if($NativeFG -eq 0){'Off'}else{'DLSS'}) $(if($NativeFG -eq 0){0}else{1})
$nativeNew=NativeSet $nativeNew 'DLSSFrameGen' ($NativeFG -gt 0) $null
$nativeNew=NativeSet $nativeNew 'DLSS_MultiFrameGeneration' $(if($NativeFG -eq 0){'x2'}else{'x'+($NativeFG+1)}) ([math]::Max(0,$NativeFG-1))
$null=$nativeNew|ConvertFrom-Json
$cfg.RequiredNrSettings.Passes=[string]$Passes;$cfg.RequiredNrSettings.WorkingScale=$changes.WorkingScale
$cfg.StabilityNote='Selected precision/layers are user settings, not a runtime stability certificate. Reviewed baseline: 67%, one pass, Quality, cache OFF, DLSS FG x2.'
$backup=Join-Path $cfg.BackupRoot ('precision_panel\'+(Get-Date -Format yyyyMMdd_HHmmss)+'_'+[guid]::NewGuid().ToString('N').Substring(0,6));[void][IO.Directory]::CreateDirectory($backup)
$files=@(@{Path=$ini;New=$new;Name='OptiScaler.ini'},@{Path=$settings;New=$nativeNew;Name='UserSettings.json'},@{Path=$configPath;New=($cfg|ConvertTo-Json -Depth 8);Name='tool_config.json'})
$records=@();foreach($f in $files){$item=Get-Item -LiteralPath $f.Path;$copy=Join-Path $backup $f.Name;$hash=Hash $f.Path;[IO.File]::Copy($f.Path,$copy,$false);if((Hash $copy) -ne $hash){throw 'Backup failed'};$f.Before=$hash;$f.Copy=$copy;$records+=[pscustomobject]@{OriginalPath=$f.Path;Size=$item.Length;FileVersion=$item.VersionInfo.FileVersion;SHA256=$hash;Backup=$copy}}
$records|ConvertTo-Json|Set-Content -LiteralPath (Join-Path $backup 'manifest.json') -Encoding UTF8
$committed=@()
try{foreach($f in $files){if(Running){throw 'Game started during save; cancelled'};if((Hash $f.Path) -ne $f.Before){throw 'File changed externally'};$temp=$f.Path+'.precision-'+[guid]::NewGuid().ToString('N')+'.tmp';[IO.File]::WriteAllText($temp,$f.New,[Text.UTF8Encoding]::new($false));[IO.File]::Replace($temp,$f.Path,(Join-Path $backup ('atomic-'+$f.Name)));$committed+=$f;if([IO.File]::ReadAllText($f.Path) -ne $f.New){throw 'Save verification failed'}}}
catch{if(-not(Running)){foreach($f in $committed){[IO.File]::Copy($f.Copy,$f.Path,$true)}};throw}
$result=[pscustomobject]@{Precision=$Precision;Passes=$Passes;Style=$Style;Light=$Light;Colour=$Colour;NativeFGValue=$NativeFG;Enabled=$Enabled;Backup=$backup;Runtime='UNTESTED_SELECTED_PROFILE'}
$result|ConvertTo-Json|Set-Content -LiteralPath (Join-Path $backup 'applied.json') -Encoding UTF8;$result|ConvertTo-Json
