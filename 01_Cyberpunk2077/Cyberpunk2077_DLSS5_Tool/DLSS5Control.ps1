[CmdletBinding()]
param([ValidateSet('Menu','ON','OFF','Status','Launch','Restore','Logs','Strength')][string]$Action='Menu',[ValidateRange(0,1)][double]$Detail=1,[ValidateRange(0,1)][double]$Colour=1,[switch]$DefaultStrength)
$ErrorActionPreference='Stop'
Set-StrictMode -Version 2
$Config=Get-Content -LiteralPath (Join-Path $PSScriptRoot 'tool_config.json') -Raw|ConvertFrom-Json
$Backup=[IO.Path]::GetFullPath($Config.BackupRoot)
$Baseline=Get-Content -LiteralPath (Join-Path $Backup 'baseline.json') -Raw|ConvertFrom-Json
$Allowed=@('winmm.dll','nvngx.dll_dlssnr.dll','nvngx_dlssnr.dll','OptiScaler.ini','OptiScaler-NR-install-manifest.json')
function Plain([string]$Path){
    $p=[IO.Path]::GetFullPath($Path)
    while($p){
        if((Test-Path -LiteralPath $p)-and((Get-Item -LiteralPath $p -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)){throw "Reparse point refused: $p"}
        $up=[IO.Directory]::GetParent($p);if($null-eq$up){break};$p=$up.FullName
    }
}
function Within([string]$Path,[string]$Root){
    if(-not([IO.Path]::GetFullPath($Path).StartsWith(([IO.Path]::GetFullPath($Root).TrimEnd('\')+'\'),[StringComparison]::OrdinalIgnoreCase))){throw "Path escaped expected directory: $Path"}
}
function Hash([string]$Path){(Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()}
function Stopped {if(Get-Process -Name Cyberpunk2077 -ErrorAction SilentlyContinue){throw 'Game is running. Close it before ON/OFF/Restore.'}}
function Save-Object([string]$Path){
    Plain $Path;Plain $Backup
    $hash=Hash $Path;$object=Join-Path $Backup ('objects\'+$hash)
    Within $object $Backup;Plain $object
    if(-not(Test-Path -LiteralPath $object)){[IO.File]::Copy($Path,$object,$false)}
    if((Hash $object)-ne$hash){throw 'Backup verification failed'}
    return $object
}
function Find-Game {
    $candidates=[Collections.Generic.List[string]]::new()
    if($Config.GameExeHint){$candidates.Add($Config.GameExeHint)}
    $candidates.Add((Join-Path (Split-Path $PSScriptRoot -Parent) 'Cyberpunk 2077\bin\x64\Cyberpunk2077.exe'))
    $steamRoots=@()
    foreach($reg in @('HKCU:\Software\Valve\Steam','HKLM:\SOFTWARE\WOW6432Node\Valve\Steam')){
        $value=Get-ItemProperty -LiteralPath $reg -ErrorAction SilentlyContinue
        if($value){foreach($prop in @('SteamPath','InstallPath')){if($value.PSObject.Properties.Name -contains $prop){$steamRoots+=[string]$value.$prop}}}
    }
    foreach($root in @($steamRoots|Select-Object -Unique)){
        $libraries=@($root);$vdf=Join-Path $root 'steamapps\libraryfolders.vdf'
        if(Test-Path -LiteralPath $vdf){foreach($m in [regex]::Matches([IO.File]::ReadAllText($vdf),'"path"\s+"([^"]+)"')){$libraries+=$m.Groups[1].Value.Replace('\\','\')}}
        foreach($library in $libraries){
            $manifest=Join-Path $library 'steamapps\appmanifest_1091500.acf'
            if(Test-Path -LiteralPath $manifest){$m=[regex]::Match([IO.File]::ReadAllText($manifest),'"installdir"\s+"([^"]+)"');if($m.Success){$candidates.Add((Join-Path $library ('steamapps\common\'+$m.Groups[1].Value+'\bin\x64\Cyberpunk2077.exe')))}}
        }
    }
    foreach($key in @('HKLM:\SOFTWARE\GOG.com\Games\1423049311','HKLM:\SOFTWARE\WOW6432Node\GOG.com\Games\1423049311')){
        $value=Get-ItemProperty -LiteralPath $key -ErrorAction SilentlyContinue
        if($value -and $value.PSObject.Properties.Name -contains 'path'){$candidates.Add((Join-Path $value.path 'bin\x64\Cyberpunk2077.exe'))}
    }
    $epic=Join-Path $env:ProgramData 'Epic\EpicGamesLauncher\Data\Manifests'
    if(Test-Path -LiteralPath $epic){foreach($file in Get-ChildItem -LiteralPath $epic -Filter '*.item' -File){try{$j=Get-Content -LiteralPath $file.FullName -Raw|ConvertFrom-Json;if($j.DisplayName-match'Cyberpunk'){$candidates.Add((Join-Path $j.InstallLocation 'bin\x64\Cyberpunk2077.exe'))}}catch{}}}
    $found=@($candidates|Where-Object{Test-Path -LiteralPath $_ -PathType Leaf}|ForEach-Object{[IO.Path]::GetFullPath($_)}|Sort-Object -Unique)
    if($found.Count-eq0){throw 'No installed Cyberpunk2077.exe found in hint, Steam, GOG or Epic records.'}
    $preferred=@($found|Where-Object{$_ -eq $Config.GameExeHint})
    if($preferred.Count-eq1){return $preferred[0]}
    if($found.Count-ne1){throw 'Multiple installations found; stop for review.'}
    return $found[0]
}
$Exe=Find-Game
$Bin=Split-Path $Exe -Parent
$Root=Split-Path (Split-Path $Bin -Parent) -Parent
$Ini=Join-Path $Bin 'OptiScaler.ini'
Plain $Exe;Plain $Backup
if($Root-ne$Baseline.GameRoot){throw 'Installation moved or differs from reviewed backup. Stop for review.'}
function Check-Identity {
    if((Hash $Exe)-ne$Config.GameExeSHA256){throw 'Game version/hash changed since review. ON is blocked until compatibility is reviewed.'}
    foreach($name in @('winmm.dll','nvngx.dll_dlssnr.dll','nvngx_dlssnr.dll')){
        $file=Join-Path $Bin $name
        if(-not(Test-Path -LiteralPath $file)){throw "Mod component missing: $name"}
        Plain $file
        if((Hash $file)-ne$Config.ExpectedHashes.$name){throw "Unreviewed mod binary: $name"}
    }
    $sig=Get-AuthenticodeSignature -LiteralPath (Join-Path $Bin 'nvngx_dlssnr.dll')
    if($sig.Status-ne'Valid'-or$sig.SignerCertificate.Subject-notmatch'NVIDIA Corporation'){throw 'NR model NVIDIA signature invalid.'}
}
function Read-State {
    if(-not(Test-Path -LiteralPath $Ini)){return 'ORIGINAL_OR_NOT_INSTALLED'}
    $m=[regex]::Match([IO.File]::ReadAllText($Ini),'(?ms)^\[DlssNr\]\s*\r?\n(?<body>.*?)(?=^\[|\z)')
    $key=[regex]::Match($m.Groups['body'].Value,'(?mi)^Enabled\s*=\s*(true|false)\s*$')
    if(-not$key.Success){return 'UNKNOWN'}
    if($key.Groups[1].Value-eq'true'){return 'ON'}else{return 'OFF'}
}
function Check-NRProfile {
    if($Config.PSObject.Properties.Name -notcontains 'RequiredNrSettings'){return}
    $section=[regex]::Match([IO.File]::ReadAllText($Ini),'(?ms)^\[DlssNr\]\s*\r?\n(?<body>.*?)(?=^\[|\z)')
    if(-not$section.Success){throw 'NR section missing.'}
    foreach($prop in $Config.RequiredNrSettings.PSObject.Properties){
        $keys=[regex]::Matches($section.Groups['body'].Value,('(?mi)^'+[regex]::Escape($prop.Name)+'\s*=\s*([^\r\n]+)'))
        if($prop.Name-in@('TransferStrength','ColourStrength')-and$keys.Count-eq1){
            $v=$keys[0].Groups[1].Value.Trim();$number=0.0
            if($v-eq'auto'){continue}
            if([double]::TryParse($v,[Globalization.NumberStyles]::Float,[Globalization.CultureInfo]::InvariantCulture,[ref]$number)-and-not[double]::IsNaN($number)-and$number-ge0-and$number-le1){continue}
            throw 'NR strength above 100% is blocked after the GPU hang. Use default or a value from 0 to 1.'
        }
        if($keys.Count-ne1-or$keys[0].Groups[1].Value.Trim()-ne[string]$prop.Value){throw ('Untested NR profile: '+$prop.Name+'. Restore the reviewed cache-OFF profile before ON/Launch.')}
    }
    $settings=Join-Path $env:LOCALAPPDATA 'CD Projekt Red\Cyberpunk 2077\UserSettings.json'
    $mode=[regex]::Match([IO.File]::ReadAllText($settings),'"name"\s*:\s*"DLSS"\s*,\s*"type"\s*:\s*"string_list"\s*,\s*"is_dynamic"\s*:\s*true\s*,\s*"value"\s*:\s*"([^"]+)"')
    if(-not$mode.Success-or$mode.Groups[1].Value-ne'Quality'){throw 'Only DLSS Quality was retested with this repair. Restore Quality before ON/Launch.'}
    if($Config.PSObject.Properties.Name-contains'RequiredFrameGenerationOff'-and$Config.RequiredFrameGenerationOff){
        $native=[IO.File]::ReadAllText($settings)
        $fg=[regex]::Match($native,'"name"\s*:\s*"FrameGeneration"\s*,\s*"type"\s*:\s*"string_list"\s*,\s*"is_dynamic"\s*:\s*true\s*,\s*"value"\s*:\s*"([^"]+)"')
        $dlssfg=[regex]::Match($native,'"name"\s*:\s*"DLSSFrameGen"\s*,\s*"type"\s*:\s*"bool"\s*,\s*"value"\s*:\s*(true|false)')
        if(-not$fg.Success-or$fg.Groups[1].Value-ne'Off'-or-not$dlssfg.Success-or$dlssfg.Groups[1].Value-ne'false'){throw 'NR profile requires native frame generation OFF. The previous NR + FG combination repeatedly crashed.'}
    }
    if($Config.PSObject.Properties.Name-contains'AllowFrameGenerationX2'-and$Config.AllowFrameGenerationX2){
        $native=[IO.File]::ReadAllText($settings)
        $fg=[regex]::Match($native,'"name"\s*:\s*"FrameGeneration"\s*,\s*"type"\s*:\s*"string_list"\s*,\s*"is_dynamic"\s*:\s*true\s*,\s*"value"\s*:\s*"([^"]+)"')
        $dlssfg=[regex]::Match($native,'"name"\s*:\s*"DLSSFrameGen"\s*,\s*"type"\s*:\s*"bool"\s*,\s*"value"\s*:\s*(true|false)')
        $multi=[regex]::Match($native,'"name"\s*:\s*"DLSS_MultiFrameGeneration"\s*,\s*"type"\s*:\s*"string_list"\s*,\s*"is_dynamic"\s*:\s*false\s*,\s*"value"\s*:\s*"([^"]+)"')
        $off=$fg.Success-and$fg.Groups[1].Value-eq'Off'-and$dlssfg.Success-and$dlssfg.Groups[1].Value-eq'false'
        $x2=$fg.Success-and$fg.Groups[1].Value-eq'DLSS'-and$dlssfg.Success-and$dlssfg.Groups[1].Value-eq'true'-and$multi.Success-and$multi.Groups[1].Value-eq'x2'
        if(-not$off-and-not$x2){throw 'NR allows native FG OFF or DLSS x2 only. MFG x3/x4 are blocked after previous crashes.'}
    }
}
function Show-Status {
    $state=Read-State;$p=Get-Process Cyberpunk2077 -ErrorAction SilentlyContinue
    $optiscaler=$false;$model=$false;$mods=@()
    if($p){try{$mods=@($p.Modules|Where-Object{$_.ModuleName-match'winmm|nvngx|sl\.|d3d12|dxgi'}|ForEach-Object{[pscustomobject]@{Name=$_.ModuleName;Path=$_.FileName}});$optiscaler=@($mods|Where-Object{$_.Path-eq(Join-Path $Bin 'winmm.dll')}).Count-gt0;$model=@($mods|Where-Object{$_.Path-eq(Join-Path $Bin 'nvngx_dlssnr.dll')}).Count-gt0}catch{}}
    [pscustomobject]@{GameEXE=$Exe;GameVersion=(Get-Item -LiteralPath $Exe).VersionInfo.ProductVersion;RequestedNR=$state;GameRunning=[bool]$p;OptiScalerLoadedNow=$optiscaler;NRModelDLLLoadedNow=$model;DLSS5_RUNTIME_STATUS='UNKNOWN - inspect current-run evaluate/model logs; DLL loading alone is insufficient';CompatibilityBlock=$Config.CompatibilityBlock;Modules=$mods;Backup=$Backup}|ConvertTo-Json -Depth 6
}
function Set-NR([string]$State){
    Stopped
    if($State-eq'ON'-and$Config.CompatibilityBlock){throw ('ON blocked: '+$Config.CompatibilityBlock)}
    Check-Identity
    if($State-eq'ON'){Check-NRProfile}
    if((Read-State)-eq$State){Write-Output "Already $State; no file write and no duplicate backup.";return}
    Plain $Ini
    $object=Save-Object $Ini;$oldHash=Hash $Ini;$text=[IO.File]::ReadAllText($Ini)
    $section=[regex]::Match($text,'(?ms)^\[DlssNr\]\s*\r?\n(?<body>.*?)(?=^\[|\z)')
    if(-not$section.Success){throw 'NR configuration section missing.'}
    $body=$section.Groups['body'].Value
    if([regex]::Matches($body,'(?m)^Enabled\s*=').Count-ne1){throw 'Ambiguous NR configuration.'}
    $value=if($State-eq'ON'){'true'}else{'false'}
    $newbody=[regex]::Replace($body,'(?m)^Enabled\s*=[^\r\n]*',('Enabled='+$value))
    $new=$text.Substring(0,$section.Groups['body'].Index)+$newbody+$text.Substring($section.Groups['body'].Index+$body.Length)
    $pending=Join-Path $Backup ('pending_'+[guid]::NewGuid().ToString('N'))
    Within $pending $Backup;Plain $pending
    [IO.File]::WriteAllText($pending,$new,[Text.UTF8Encoding]::new($false))
    Stopped
    if((Hash $Ini)-ne$oldHash){throw 'INI changed during the transaction.'}
    try{[IO.File]::Replace($pending,$Ini,[NullString]::Value);if((Read-State)-ne$State){throw 'Post-write state verification failed.'}}
    catch{[IO.File]::Copy($object,$Ini,$true);throw}
    $event=[ordered]@{Time=[DateTimeOffset]::Now.ToString('o');Action=$State;OriginalPath=$Ini;BeforeSHA256=$oldHash;AfterSHA256=(Hash $Ini);BackupObject=$object}
    [IO.File]::AppendAllText((Join-Path $Backup 'switch_history.jsonl'),(($event|ConvertTo-Json -Compress)+[Environment]::NewLine),[Text.UTF8Encoding]::new($false))
    Write-Output "NR requested $State. Runtime effect remains unverified until game evaluation succeeds. Original INI saved by SHA256."
}
function Restore-Original {
    Stopped
    $items=@()
    foreach($name in $Allowed){
        $path=Join-Path $Bin $name;Within $path $Bin;Plain $path
        if(Test-Path -LiteralPath $path){
            if($name-like'*.dll'-and(Hash $path)-ne$Config.ExpectedHashes.$name){throw "Changed DLL; stop to avoid moving another mod: $name"}
            $object=Save-Object $path
            $items+=[pscustomobject]@{Name=$name;Source=$path;SHA256=(Hash $path);BackupObject=$object}
        }
    }
    # Only this mod's log, absent at baseline, is included. No game cache/save folder is touched.
    $log=Join-Path $Bin 'OptiScaler.log'
    if(Test-Path -LiteralPath $log){$object=Save-Object $log;$items+=[pscustomobject]@{Name='OptiScaler.log';Source=$log;SHA256=(Hash $log);BackupObject=$object}}
    if($items.Count-eq0){Write-Output 'Already original: none of this installation remains.';return}
    $destination=Join-Path $Backup ('removed_mod_'+[DateTime]::Now.ToString('yyyyMMdd_HHmmss')+'_'+[guid]::NewGuid().ToString('N').Substring(0,6))
    Within $destination $Backup;Plain $destination
    foreach($item in $items){Within $item.Source $Bin;Within (Join-Path $destination $item.Name) $destination;Plain (Join-Path $destination $item.Name)}
    Stopped
    [void][IO.Directory]::CreateDirectory($destination)
    $moved=@()
    try{
        foreach($item in $items){Stopped;if((Hash $item.Source)-ne$item.SHA256){throw 'File changed before restoration.'};$target=Join-Path $destination $item.Name;if(Test-Path -LiteralPath $target){throw 'Destination exists.'};Move-Item -LiteralPath $item.Source -Destination $target;$moved+=$item;if((Hash $target)-ne$item.SHA256){throw 'Move hash verification failed.'}}
    }catch{
        foreach($item in $moved){$target=Join-Path $destination $item.Name;Within $target $destination;Within $item.Source $Bin;Plain $target;Plain $item.Source;if(-not(Test-Path -LiteralPath $item.Source)){Move-Item -LiteralPath $target -Destination $item.Source}}
        throw
    }
    [IO.File]::WriteAllText((Join-Path $destination 'restoration.json'),($items|ConvertTo-Json -Depth 6),[Text.UTF8Encoding]::new($false))
    Write-Output "Original restored. Added mod files preserved in $destination. Original binaries/settings/saves untouched."
}
function Set-Strength {
    Stopped
    if($Config.CompatibilityBlock){throw ('NR tuning blocked: '+$Config.CompatibilityBlock)}
    Check-Identity;Check-NRProfile;Plain $Ini
    $object=Save-Object $Ini;$oldHash=Hash $Ini;$text=[IO.File]::ReadAllText($Ini)
    $section=[regex]::Match($text,'(?ms)^\[DlssNr\]\s*\r?\n(?<body>.*?)(?=^\[|\z)')
    if(-not$section.Success){throw 'NR section missing.'}
    $body=$section.Groups['body'].Value
    $values=@{TransferStrength=$Detail.ToString('0.00',[Globalization.CultureInfo]::InvariantCulture);ColourStrength=$Colour.ToString('0.00',[Globalization.CultureInfo]::InvariantCulture)}
    if($DefaultStrength){$values=@{TransferStrength='auto';ColourStrength='auto'}}
    foreach($key in $values.Keys){
        if([regex]::Matches($body,('(?m)^'+$key+'\s*=')).Count-ne1){throw 'Ambiguous strength setting.'}
        $body=[regex]::Replace($body,('(?m)^'+$key+'\s*=[^\r\n]*'),($key+'='+$values[$key]))
    }
    $new=$text.Substring(0,$section.Groups['body'].Index)+$body+$text.Substring($section.Groups['body'].Index+$section.Groups['body'].Length)
    if($new-eq$text){Write-Output 'Already default/current strength; no file write.';return}
    $temp=Join-Path $Backup ('pending_strength_'+[guid]::NewGuid().ToString('N'));[IO.File]::WriteAllText($temp,$new,[Text.UTF8Encoding]::new($false))
    Stopped;if((Hash $Ini)-ne$oldHash){throw 'Configuration changed during preparation.'}
    try{[IO.File]::Replace($temp,$Ini,[NullString]::Value);Check-NRProfile;if([IO.File]::ReadAllText($Ini)-ne$new){throw 'Strength write verification failed.'}}catch{[IO.File]::Copy($object,$Ini,$true);throw}
    $event=[ordered]@{Time=[DateTimeOffset]::Now.ToString('o');Action='Strength';Path=$Ini;Before=$oldHash;After=(Hash $Ini);Backup=$object;Values=$values}
    [IO.File]::AppendAllText((Join-Path $Backup 'switch_history.jsonl'),(($event|ConvertTo-Json -Compress)+[Environment]::NewLine),[Text.UTF8Encoding]::new($false))
    Write-Output 'Strength saved and backed up. Start the game to verify the visual result.'
}
function Run-Action([string]$Choice){
    switch($Choice){
        'ON'{Set-NR 'ON'}
        'OFF'{Set-NR 'OFF'}
        'Status'{Show-Status}
        'Strength'{Set-Strength}
        'Launch'{Stopped;if((Read-State)-eq'ON'){if($Config.CompatibilityBlock){throw 'Known incompatibility: switch NR OFF or restore original first.'};Check-Identity;Check-NRProfile};Start-Process -FilePath $Exe -WorkingDirectory $Bin}
        'Restore'{Restore-Original}
        'Logs'{Start-Process -FilePath 'explorer.exe' -ArgumentList ('"'+$Bin+'"');if(Test-Path -LiteralPath (Join-Path $Bin 'OptiScaler.log')){Start-Process -FilePath 'notepad.exe' -ArgumentList ('"'+(Join-Path $Bin 'OptiScaler.log')+'"')}}
    }
}
if($Action-ne'Menu'){Run-Action $Action;return}
while($true){
    if($Config.CompatibilityBlock){
        Write-Host "`n赛博朋克 2077 | 社区 NR 已因重复崩溃停用" -ForegroundColor Yellow
        Write-Host '这是工具保护提示，不是游戏崩溃。原生 DLSS 保留。'
        Write-Host "[1] 开启 NR：已禁用`n[2] 关闭 NR：已移除，无需操作`n[3] 查看状态`n[4] 启动原版游戏`n[5] 恢复原版（已完成时不作更改）`n[6] 打开记录位置`n[0] 退出"
    }else{
        Write-Host "`nCyberpunk2077 DLSS5 Tool | requested state: $(Read-State)"
        if($Config.PSObject.Properties.Name-contains'RequiredFrameGenerationOff'-and$Config.RequiredFrameGenerationOff){Write-Host '已验证的 NR 配置要求：Quality、原强度、缓存关闭、原生帧生成关闭。' -ForegroundColor Yellow}
        if($Config.PSObject.Properties.Name-contains'AllowFrameGenerationX2'-and$Config.AllowFrameGenerationX2){Write-Host 'NR 可配合 DLSS 2× 帧生成；禁止 3× / 4×。Quality、原强度、缓存关闭。' -ForegroundColor Yellow}
        Write-Host "[1] DLSS 5 ON`n[2] DLSS 5 OFF`n[3] Current status`n[4] Launch Cyberpunk 2077`n[5] Restore original`n[6] Open logs`n[0] Exit"
    }
    $choice=Read-Host 'Select'
    if($choice-eq'0'){break}
    if($Config.CompatibilityBlock-and$choice-in@('1','2')){Write-Host 'NR 已停用；请选择 [4] 启动原版。不会重新安装或开启社区 NR。' -ForegroundColor Yellow;continue}
    $map=@{'1'='ON';'2'='OFF';'3'='Status';'4'='Launch';'5'='Restore';'6'='Logs'}
    if($map.ContainsKey($choice)){try{Run-Action $map[$choice]}catch{Write-Host ('Stopped: '+$_.Exception.Message) -ForegroundColor Red}}
}
