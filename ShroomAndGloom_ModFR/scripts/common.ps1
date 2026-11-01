# Fonctions partagées du mod FR de Shroom and Gloom (PowerShell 5.1+)
$ErrorActionPreference = 'Stop'

$script:BundleFile   = 'localization-string-tables-french(fr)_assets_all.bundle'
$script:BundleName   = 'bae21e4b930f76cd3359f77bc5c65721'   # nom interne du bundle FR dans le catalogue Addressables
$script:BackupName   = '_ModFR_sauvegarde'
# Signature de l'objet GameFlags dans resources.assets : longueur du nom (9) + "GameFlags" + alignement
$script:GFSignature  = [byte[]](0x09,0,0,0) + [Text.Encoding]::ASCII.GetBytes('GameFlags') + [byte[]](0,0,0)
$script:GFSigOffset  = 28    # position de la signature dans l'objet
$script:GFFlagOffset = 104   # GameFlags.DisableUnsupportedLanguages (bool aligné sur 4 octets)
$script:GFFloatA     = 192   # RestSpecialCardDelay = 1.0 (contrôle de structure)
$script:GFFloatB     = 208   # EndTurnSpecialCardDelay = 1.0 (contrôle de structure)

if (-not ('ModFR.Bytes' -as [type])) {
Add-Type -TypeDefinition @'
namespace ModFR {
  public static class Bytes {
    public static int[] FindAll(byte[] hay, byte[] needle) {
      var res = new System.Collections.Generic.List<int>();
      for (int i = 0; i <= hay.Length - needle.Length; i++) {
        int j = 0; while (j < needle.Length && hay[i + j] == needle[j]) j++;
        if (j == needle.Length) res.Add(i);
      }
      return res.ToArray();
    }
    public static int LastIndexOf(byte[] hay, byte[] needle, int before) {
      for (int i = before - needle.Length; i >= 0; i--) {
        int j = 0; while (j < needle.Length && hay[i + j] == needle[j]) j++;
        if (j == needle.Length) return i;
      }
      return -1;
    }
  }
}
'@
}

function Write-Step($msg)  { Write-Host "  > $msg" -ForegroundColor Cyan }
function Write-Ok($msg)    { Write-Host "  [OK] $msg" -ForegroundColor Green }
function Write-Warn2($msg) { Write-Host "  [!] $msg" -ForegroundColor Yellow }

function Test-GameDir([string]$dir) {
    return ($dir -and (Test-Path -LiteralPath (Join-Path $dir 'Shroom and Gloom.exe')) -and
            (Test-Path -LiteralPath (Join-Path $dir 'Shroom and Gloom_Data')))
}

function Find-GameDir([string]$hint, [string]$modDir) {
    $candidates = @()
    if ($hint) { $candidates += $hint }
    $candidates += (Split-Path -Parent $modDir)
    $candidates += (Split-Path -Parent (Split-Path -Parent $modDir))
    try {
        $steam = (Get-ItemProperty -Path 'HKCU:\Software\Valve\Steam' -Name SteamPath -ErrorAction Stop).SteamPath
        $libs = @($steam)
        $vdf = Join-Path $steam 'steamapps\libraryfolders.vdf'
        if (Test-Path -LiteralPath $vdf) {
            foreach ($m in [regex]::Matches((Get-Content -LiteralPath $vdf -Raw), '"path"\s+"([^"]+)"')) {
                $libs += ($m.Groups[1].Value -replace '\\\\', '\')
            }
        }
        foreach ($l in $libs) { $candidates += (Join-Path $l 'steamapps\common\Shroom and Gloom') }
    } catch { }
    foreach ($c in $candidates) { if (Test-GameDir $c) { return (Resolve-Path -LiteralPath $c).Path } }
    return $null
}

function Assert-GameClosed([string]$gameDir) {
    $exe = (Join-Path $gameDir 'Shroom and Gloom.exe')
    $running = Get-Process -Name 'Shroom and Gloom' -ErrorAction SilentlyContinue |
        Where-Object { -not $_.Path -or ($_.Path -ieq $exe) }
    if ($running) {
        throw "Le jeu est en cours d'execution. Ferme Shroom and Gloom puis relance le script."
    }
}

# Met le CRC du bundle FR a 0 (= pas de verification) dans catalog.json, sans changer la longueur des donnees.
# $restore = $true remet la valeur d'origine $originalCrc.
function Set-CatalogCrc([string]$catalogPath, [string]$newDigits) {
    $text = [IO.File]::ReadAllText($catalogPath)
    $m = [regex]::Match($text, '"m_ExtraDataString":"([^"]+)"')
    if (-not $m.Success) { throw "catalog.json : m_ExtraDataString introuvable." }
    $bytes = [Convert]::FromBase64String($m.Groups[1].Value)
    $nameBytes = [Text.Encoding]::Unicode.GetBytes($script:BundleName)
    $hits = [ModFR.Bytes]::FindAll($bytes, $nameBytes)
    if ($hits.Count -ne 1) { throw "catalog.json : bundle francais introuvable (version du jeu differente ?)." }
    $key = [Text.Encoding]::Unicode.GetBytes('"m_Crc":')
    $k = [ModFR.Bytes]::LastIndexOf($bytes, $key, $hits[0])
    if ($k -lt 0) { throw "catalog.json : champ m_Crc introuvable." }
    $start = $k + $key.Length
    $end = $start
    while ([char][BitConverter]::ToUInt16($bytes, $end) -ne ',') { $end += 2 }
    $old = [Text.Encoding]::Unicode.GetString($bytes, $start, $end - $start)
    $len = ($end - $start) / 2
    if ($newDigits.Length -gt $len) { throw "catalog.json : valeur CRC trop longue." }
    $new = $newDigits.PadRight($len, ' ')   # les espaces sont du JSON valide
    [Text.Encoding]::Unicode.GetBytes($new).CopyTo($bytes, $start)
    $newB64 = [Convert]::ToBase64String($bytes)
    $text = $text.Substring(0, $m.Groups[1].Index) + $newB64 + $text.Substring($m.Groups[1].Index + $m.Groups[1].Length)
    [IO.File]::WriteAllText($catalogPath, $text, (New-Object Text.UTF8Encoding($false)))
    return $old.Trim()
}

# Ecrit la valeur (0 ou 1) du flag GameFlags.DisableUnsupportedLanguages apres controle de structure.
function Set-LanguageFilterFlag([string]$resourcesPath, [byte]$value) {
    $bytes = [IO.File]::ReadAllBytes($resourcesPath)
    $hits = [ModFR.Bytes]::FindAll($bytes, $script:GFSignature)
    if ($hits.Count -ne 1) { throw "resources.assets : objet GameFlags introuvable ou ambigu ($($hits.Count)). Version du jeu differente ?" }
    $obj = $hits[0] - $script:GFSigOffset
    $one = [byte[]](0,0,0x80,0x3F)
    foreach ($o in @($script:GFFloatA, $script:GFFloatB)) {
        for ($i = 0; $i -lt 4; $i++) { if ($bytes[$obj + $o + $i] -ne $one[$i]) { throw "resources.assets : structure GameFlags inattendue. Patch annule par securite." } }
    }
    $pos = $obj + $script:GFFlagOffset
    $cur = $bytes[$pos]
    if (($cur -ne 0 -and $cur -ne 1) -or $bytes[$pos+1] -ne 0 -or $bytes[$pos+2] -ne 0 -or $bytes[$pos+3] -ne 0) {
        throw "resources.assets : valeur du flag inattendue. Patch annule par securite."
    }
    if ($cur -eq $value) { return $cur }
    $fs = [IO.File]::Open($resourcesPath, 'Open', 'ReadWrite', 'None')
    try { $fs.Position = $pos; $fs.WriteByte($value) } finally { $fs.Close() }
    return $cur
}
