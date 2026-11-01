param([string]$GameDir)
. (Join-Path $PSScriptRoot 'common.ps1')

$ModDir = Split-Path -Parent $PSScriptRoot
Write-Host ""
Write-Host "=== Shroom and Gloom - Mod de traduction francaise : INSTALLATION ===" -ForegroundColor Magenta

try {
    $GameDir = Find-GameDir $GameDir $ModDir
    if (-not $GameDir) { throw "Dossier du jeu introuvable. Relance avec : install.ps1 -GameDir ""C:\chemin\vers\Shroom and Gloom""" }
    Write-Ok "Jeu trouve : $GameDir"
    Assert-GameClosed $GameDir

    $data     = Join-Path $GameDir 'Shroom and Gloom_Data'
    $aa       = Join-Path $data 'StreamingAssets\aa'
    $bundle   = Join-Path $aa ('StandaloneWindows64\' + $BundleFile)
    $catalog  = Join-Path $aa 'catalog.json'
    $res      = Join-Path $data 'resources.assets'
    $newBundle = Join-Path $ModDir ('data\' + $BundleFile)
    $backup   = Join-Path $GameDir $BackupName

    foreach ($p in @($bundle, $catalog, $res, $newBundle)) {
        if (-not (Test-Path -LiteralPath $p)) { throw "Fichier manquant : $p" }
    }

    # 1. Sauvegarde des originaux (une seule fois, pour ne jamais ecraser les vrais originaux)
    if (-not (Test-Path -LiteralPath $backup)) {
        Write-Step "Sauvegarde des fichiers d'origine dans $BackupName"
        New-Item -ItemType Directory -Path $backup | Out-Null
        Copy-Item -LiteralPath $bundle  -Destination (Join-Path $backup $BundleFile)
        Copy-Item -LiteralPath $catalog -Destination (Join-Path $backup 'catalog.json')
    } else {
        Write-Warn2 "Sauvegarde deja presente (reinstallation) : conservee telle quelle."
    }

    # 2. Textes francais
    Write-Step "Installation des textes francais"
    Copy-Item -LiteralPath $newBundle -Destination $bundle -Force
    Write-Ok "Bundle de localisation FR installe"

    # 3. Catalogue Addressables : desactive le controle CRC du seul bundle FR (sinon il serait rejete)
    Write-Step "Mise a jour du catalogue Addressables"
    $oldCrc = Set-CatalogCrc $catalog '0'
    if ($oldCrc -ne '0') { Set-Content -LiteralPath (Join-Path $backup 'crc_origine.txt') -Value $oldCrc -Encoding ASCII }
    Write-Ok "Controle CRC du bundle FR desactive (ancien CRC : $oldCrc)"

    # 4. Deverrouillage du francais dans le menu des langues
    Write-Step "Deverrouillage de la langue francaise dans les options"
    $prev = Set-LanguageFilterFlag $res 0
    Write-Ok "GameFlags.DisableUnsupportedLanguages : $prev -> 0"

    Write-Host ""
    Write-Host "Installation terminee !" -ForegroundColor Green
    Write-Host "Lance le jeu, puis Options > LANGUAGE > French (fr)."
    Write-Host "Si le jeu demarre deja en francais (Windows en francais), tout est bon."
    Write-Host "Apres une mise a jour Steam du jeu, relance simplement installation_traduction_fr.bat."
    exit 0
} catch {
    Write-Host ""
    Write-Host "ERREUR : $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Aucun fichier n'a ete laisse dans un etat partiel non sauvegarde. En cas de doute : Steam > Proprietes > Fichiers installes > Verifier l'integrite."
    exit 1
}
