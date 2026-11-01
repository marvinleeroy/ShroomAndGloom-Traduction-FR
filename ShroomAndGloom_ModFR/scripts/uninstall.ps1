param([string]$GameDir)
. (Join-Path $PSScriptRoot 'common.ps1')

$ModDir = Split-Path -Parent $PSScriptRoot
Write-Host ""
Write-Host "=== Shroom and Gloom - Mod de traduction francaise : DESINSTALLATION ===" -ForegroundColor Magenta

try {
    $GameDir = Find-GameDir $GameDir $ModDir
    if (-not $GameDir) { throw "Dossier du jeu introuvable. Relance avec : uninstall.ps1 -GameDir ""C:\chemin\vers\Shroom and Gloom""" }
    Write-Ok "Jeu trouve : $GameDir"
    Assert-GameClosed $GameDir

    $data    = Join-Path $GameDir 'Shroom and Gloom_Data'
    $aa      = Join-Path $data 'StreamingAssets\aa'
    $bundle  = Join-Path $aa ('StandaloneWindows64\' + $BundleFile)
    $catalog = Join-Path $aa 'catalog.json'
    $res     = Join-Path $data 'resources.assets'
    $backup  = Join-Path $GameDir $BackupName

    if (-not (Test-Path -LiteralPath $backup)) { throw "Aucune sauvegarde trouvee ($BackupName). Utilise Steam > Verifier l'integrite des fichiers." }

    Write-Step "Restauration du bundle FR et du catalogue d'origine"
    Copy-Item -LiteralPath (Join-Path $backup $BundleFile)   -Destination $bundle  -Force
    Copy-Item -LiteralPath (Join-Path $backup 'catalog.json') -Destination $catalog -Force
    Write-Ok "Fichiers restaures"

    Write-Step "Remise du filtre de langues d'origine"
    $prev = Set-LanguageFilterFlag $res 1
    Write-Ok "GameFlags.DisableUnsupportedLanguages : $prev -> 1"

    Remove-Item -LiteralPath $backup -Recurse -Force
    Write-Host ""
    Write-Host "Desinstallation terminee : le jeu est revenu a son etat d'origine." -ForegroundColor Green
    exit 0
} catch {
    Write-Host ""
    Write-Host "ERREUR : $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "En dernier recours : Steam > Proprietes > Fichiers installes > Verifier l'integrite des fichiers du jeu."
    exit 1
}
