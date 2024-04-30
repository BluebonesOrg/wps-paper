# PowerShell >= 5.0
$FILE = $MyInvocation.MyCommand.Path
$JSADDON_DIR = "$env:APPDATA/kingsoft/wps/jsaddons"
$XML_PATH = Join-Path $JSADDON_DIR "publish.xml"
$ADDON_NAME = $null
$NAME = $null
$VERSION = $null

function Get-AddonInfo($Path) {
    $text = Get-Content -Path $Path -Raw
    $nameMatch = [regex]::Match($text, "name: '([^ ]+?)'")
    $versionMatch = [regex]::Match($text, "version: '([^ ]+?)'")
    if ($nameMatch -and $versionMatch) {
        $name = $nameMatch.Groups[1].Value
        $version = $versionMatch.Groups[1].Value
        Write-Host "��ȡ���ƺͰ汾��: $name, $version"
        return $name, $version
    }
    else {
        throw "��ȡ���ƺͰ汾��ʧ��"
    }
}
function Copy-Dir($OldDir, $NewDir) {
    Remove-Dir
    $ignorePatterns = @(".git\", "README.md")
    if (Test-Path ".gitignore") {
        $ignorePatterns += Get-Content ".gitignore"
    }
    Copy-Item -Path $OldDir -Destination $NewDir -Recurse -Force -Exclude $ignorePatterns
    Write-Host "�� $OldDir ���Ƶ� $NewDir"
}
function Add-XML() {
    if (-not (Test-Path $XML_PATH)) {
        Set-Content -Path $XML_PATH -Value "<jsplugins>`n</jsplugins>"
    }
    $xml = [xml](Get-Content $XML_PATH)
    $nodes = $xml.SelectNodes("//jsplugin[@name=""$NAME""]")
    foreach ($node in $nodes) {
        $xml.DocumentElement.RemoveChild($node)
    }
    $newNode = $xml.CreateElement("jsplugin")
    $newNode.SetAttribute("name", $NAME)
    $newNode.SetAttribute("type", "wps")
    $newNode.SetAttribute("url", "https://api.github.com/repos/Cubxx/wps-paper/zipball")
    $newNode.SetAttribute("version", $VERSION)
    $xml.DocumentElement.AppendChild($newNode)
    Write-Host "���ע����Ϣ $($newNode.OuterXml)"
    $xml.Save($XML_PATH)
}
function Remove-Dir() {
    $dirs = Get-ChildItem -Path $JSADDON_DIR -Directory | Where-Object {
        ($_.Name -like "$($NAME)_*") -and (Test-Path $_.FullName -PathType Container)
    }
    if ($dirs.Count -eq 0) {
        Write-Host "�Ҳ������ļ��У�����ɾ��"
        return
    }
    foreach ($e in $dirs) {
        Remove-Item -Path $e.FullName -Recurse -Force
        Write-Host "��ɾ�����ļ���: $($e.Name)"
    }
}
function Remove-XML() {
    if (-not (Test-Path $XML_PATH)) {
        Write-Host "�Ҳ���ע����Ϣ������ɾ��"
        return
    }
    $xml = [xml](Get-Content $XML_PATH)
    $nodes = $xml.SelectNodes("//jsplugin[@name=""$NAME""]")
    if ($nodes.Count -eq 0) {
        Write-Host "�Ҳ���ע����Ϣ������ɾ��"
        return
    }
    foreach ($node in $nodes) {
        $xml.DocumentElement.RemoveChild($node)
        Write-Host "��ɾ��ע����Ϣ $($node.OuterXml)"
    }
    $xml.Save($XML_PATH)
}
function Select-Option {
    param(
        [string]$title,
        [array]$options,
        [string]$optionTitle
    )

    Write-Host $title
    for ($i = 0; $i -lt $options.Count; $i++) {
        Write-Host "  $($i + 1). $(if ($optionTitle) { $options[$i].($optionTitle) } else { $options[$i] })"
    }
    $selection = Read-Host "Enter number (1-$($options.Count))"
    $option = $options[$selection - 1]

    if ($option) {
        return $option
    }
    else {
        Write-Error "Invalid number"
        return Select-Option $title $options
    }
}
function Install-Addon($srcDir) {
    if (-not (Test-Path $JSADDON_DIR)) {
        mkdir $JSADDON_DIR
    }
    $targetDir = Join-Path $JSADDON_DIR $ADDON_NAME
    Copy-Dir $srcDir $targetDir
    Add-XML
    Write-Host "$ADDON_NAME ��װ�ɹ�, ��ǰ�ļ��п�ɾ��"
}
function Update-Addon() {
    $tempFile = 'temp.js'
    Invoke-RestMethod 'https://raw.kkgithub.com/Cubxx/wps-paper/main/config.js' -OutFile $tempFile 
    $NEW_NAME, $NEW_VERSION = Get-AddonInfo $tempFile
    if ($NEW_VERSION -eq $VERSION) {
        Write-Host "��ǰ�汾 $VERSION �������°汾"
    }
    else {
        $tempZip = 'temp.zip'
        Invoke-WebRequest 'https://api.kkgithub.com/repos/Cubxx/wps-paper/zipball' -OutFile $tempZip
        $targetDir = Join-Path $env:TEMP $NEW_NAME
        Expand-Archive $tempZip $targetDir -Force

        $global:NAME, $global:VERSION = $NEW_NAME, $NEW_VERSION
        $global:ADDON_NAME = $global:NAME + '_' + $global:VERSION
        $srcDir = (Get-ChildItem -Path $targetDir -Directory | Select-Object -First 1).FullName 
        Install-Addon $srcDir
        
        Remove-Item $tempZip
        Remove-Item $targetDir -Recurse -Force
    }
    Remove-Item $tempFile
    Write-Host "$ADDON_NAME ���³ɹ�, ��ǰ�ļ��п�ɾ��"
}
function Uninstall-Addon() {
    Remove-Dir $JSADDON_DIR
    Remove-XML
    Write-Host "$ADDON_NAME ж�سɹ�, ��ǰ�ļ��п�ɾ��"
}

try {
    if ($JSADDON_DIR -in $FILE) {
        throw "�޷��ڵ�ǰ�ļ����²���"
    }
    $option = Select-Option "��ӭʹ�� WPS �����װ��" @(
        @{title = "��װ"; fn = { Install-Addon (Split-Path -Path $FILE -Parent) } }, 
        @{title = "���£���Ҫ������"; fn = { Update-Addon } }, 
        @{title = "ж��"; fn = { Uninstall-Addon } }
    ) "title"
    $NAME, $VERSION = Get-AddonInfo "config.js"
    $ADDON_NAME = $NAME + '_' + $VERSION
    & $option.fn
}
catch {
    Write-Error $_
}
Read-Host "��������˳�"