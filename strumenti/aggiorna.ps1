# ============================================================================
#  FALCATA - applica un aggiornamento e lo manda su GitHub.
#
#  Si lancia da AGGIORNA.bat, nella cartella del progetto. Non si lancia a
#  mano e non serve saperlo usare: chiede una conferma e fa il resto.
#
#  REGOLE CHE NON ROMPE, MAI
#  -------------------------
#  - Non tocca la cartella .git (la storia del progetto).
#  - Non cancella file: scrive solo quelli che sono nello zip.
#  - Non cambia il nome del progetto ne' l'identificativo Android. Se lo
#    cambiasse, Android considererebbe Falcata un'altra app e tutte le corse
#    registrate sul telefono sparirebbero.
#  - Se qualcosa non torna si ferma prima di scrivere, e dice cosa.
# ============================================================================

$ErrorActionPreference = 'Stop'

function Riga($testo) { Write-Host $testo }
function Ok($testo)   { Write-Host $testo -ForegroundColor Green }
function Att($testo)  { Write-Host $testo -ForegroundColor Yellow }
function Err($testo)  { Write-Host $testo -ForegroundColor Red }

Riga ''
Riga '=============================================='
Riga '  Falcata - aggiornamento'
Riga '=============================================='
Riga ''

# ---------------------------------------------------------------- la cartella
$repo = Split-Path -Parent $PSScriptRoot
$pubspec = Join-Path $repo 'pubspec.yaml'

if (-not (Test-Path $pubspec)) {
  Err 'Qui non c-e il progetto Falcata (manca pubspec.yaml).'
  Err 'Questo file va lasciato dentro la cartella run_coach_app.'
  exit 1
}
if (-not ((Get-Content $pubspec -Raw) -match 'name:\s*run_coach_app')) {
  Err 'Questa cartella contiene un altro progetto. Mi fermo.'
  exit 1
}
if (-not (Test-Path (Join-Path $repo '.git'))) {
  Err 'Questa cartella non e collegata a GitHub (manca .git).'
  Err 'Aprila una volta in GitHub Desktop con File - Add local repository.'
  exit 1
}

$versionePrima = ((Get-Content $pubspec -Raw) -split "`n" |
  Where-Object { $_ -match '^version:' } | Select-Object -First 1) -replace 'version:\s*', ''
Riga ("Cartella : " + $repo)
Riga ("Versione : " + $versionePrima.Trim())
Riga ''

# ------------------------------------------------------------------- lo zip
# Si guarda nei Download, sul Desktop e nella cartella stessa: lo zip puo'
# essere finito in uno qualunque dei tre.
$posti = @(
  (Join-Path $env:USERPROFILE 'Downloads'),
  (Join-Path $env:USERPROFILE 'Desktop'),
  $repo
) | Where-Object { Test-Path $_ }

$zip = Get-ChildItem -Path $posti -Filter '*.zip' -File -ErrorAction SilentlyContinue |
  Where-Object { $_.Name -match 'falcata|run_coach|modifiche' } |
  Sort-Object LastWriteTime -Descending |
  Select-Object -First 1

if (-not $zip) {
  Err 'Nessuno zip di aggiornamento trovato.'
  Riga ''
  Riga 'Cercato in:'
  foreach ($p in $posti) { Riga ("  " + $p) }
  Riga ''
  Riga 'Lo zip deve avere "falcata" nel nome. Scaricalo e rilancia.'
  exit 1
}

Riga ("Aggiornamento trovato:")
Riga ("  " + $zip.Name)
Riga ("  scaricato il " + $zip.LastWriteTime)
Riga ''

# --------------------------------------------------------- cosa c-e dentro
$tmp = Join-Path $env:TEMP ('falcata-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tmp | Out-Null

try {
  Expand-Archive -LiteralPath $zip.FullName -DestinationPath $tmp -Force

  # Lo zip puo' avere una cartella sola in cima ("run_coach_app/..."): in quel
  # caso si entra, altrimenti i file finirebbero un livello troppo in alto.
  #
  # ATTENZIONE, QUI CI SI SBAGLIA FACILE
  # ------------------------------------
  # Non basta "c-e una cartella sola": uno zip giusto che contiene solo lib/ e
  # il messaggio del commit ha anche lui una cartella sola, e scendere dentro
  # lib/ scriverebbe i file nella radice del progetto. Una prova l-ha fatto
  # davvero.
  #
  # Quindi si riconosce la radice dal NOME di quello che c-e dentro: se in cima
  # si vede almeno una delle cartelle vere del progetto, quella e la radice e
  # non si scende.
  $attesi = @(
    'lib', 'test', 'android', 'ios', '.github', 'strumenti',
    'pubspec.yaml', 'AGGIORNA.bat', 'analysis_options.yaml'
  )
  $radice = $tmp
  for ($giro = 0; $giro -lt 3; $giro++) {
    $dentro = @(Get-ChildItem -Path $radice)
    $riconosciuto = $dentro | Where-Object { $attesi -contains $_.Name }
    if ($riconosciuto) { break }

    $cartelle = @($dentro | Where-Object { $_.PSIsContainer })
    if ($cartelle.Count -ne 1) { break }
    $radice = $cartelle[0].FullName
  }

  if (-not (@(Get-ChildItem -Path $radice) |
            Where-Object { $attesi -contains $_.Name })) {
    Err 'Questo zip non somiglia a un aggiornamento di Falcata:'
    Err 'in cima non c-e ne lib, ne test, ne pubspec.yaml.'
    Riga 'Non scrivo niente. Controlla di aver scaricato lo zip giusto.'
    exit 1
  }

  # Il messaggio del commit viaggia dentro lo zip: non va piu' inventato.
  $messaggio = $null
  $fileMsg = Join-Path $radice '_messaggio.txt'
  if (Test-Path $fileMsg) {
    $messaggio = (Get-Content $fileMsg -Raw).Trim()
    Remove-Item $fileMsg -Force
  }

  $daScrivere = Get-ChildItem -Path $radice -Recurse -File |
    Where-Object { $_.FullName -notmatch '\\\.git\\' }

  if ($daScrivere.Count -eq 0) {
    Err 'Lo zip e vuoto. Mi fermo.'
    exit 1
  }

  Riga ("File da aggiornare: " + $daScrivere.Count)
  foreach ($f in $daScrivere) {
    $rel = $f.FullName.Substring($radice.Length).TrimStart('\')
    Riga ("  " + $rel)
  }
  Riga ''
  if ($messaggio) {
    Riga 'Messaggio del commit:'
    Riga ("  " + $messaggio)
    Riga ''
  }

  # ------------------------------------------------- l-identita dell-app
  #
  # L-UNICO ERRORE DA CUI NON SI TORNA.
  #
  # Android riconosce un-app dal suo identificativo. Se cambia, il telefono la
  # considera un-altra app: si installa accanto, e tutte le corse registrate
  # restano dentro la vecchia, senza modo di riprenderle. Non e un bug da
  # correggere dopo - e un archivio perso.
  #
  # Quindi se uno zip tocca i file dove quell-identificativo e scritto, si
  # controlla che sia ancora quello giusto. Un controllo che non scattera mai e
  # il controllo giusto da avere.
  $identita = @{
    'pubspec.yaml'                              = 'name:\s*run_coach_app'
    'android\app\build.gradle'                  = 'com\.runcoachapp\.run_coach_app'
    'android\app\src\main\AndroidManifest.xml'  = 'run_coach_app'
  }
  foreach ($chiave in $identita.Keys) {
    $f = Join-Path $radice $chiave
    if (-not (Test-Path $f)) { continue }
    if (-not ((Get-Content $f -Raw) -match $identita[$chiave])) {
      Err 'FERMO TUTTO.'
      Riga ''
      Err ("In " + $chiave + " il nome dell-app non e piu run_coach_app.")
      Riga ''
      Riga 'Se scrivessi questo file, Android considererebbe Falcata un-altra'
      Riga 'app e tutte le corse che hai registrato non si vedrebbero piu.'
      Riga 'Non ho scritto niente. Questo zip e da buttare.'
      exit 1
    }
  }

  $risposta = Read-Host 'Scrivo questi file e mando su GitHub? (s/n)'
  if ($risposta -ne 's' -and $risposta -ne 'S') {
    Att 'Annullato. Non ho scritto niente.'
    exit 0
  }

  # ------------------------------------------------------------- si scrive
  foreach ($f in $daScrivere) {
    $rel = $f.FullName.Substring($radice.Length).TrimStart('\')
    $dest = Join-Path $repo $rel
    $cartella = Split-Path -Parent $dest
    if (-not (Test-Path $cartella)) {
      New-Item -ItemType Directory -Path $cartella -Force | Out-Null
    }
    Copy-Item -LiteralPath $f.FullName -Destination $dest -Force
  }
  Ok ("Scritti " + $daScrivere.Count + " file.")
  Riga ''
}
finally {
  if (Test-Path $tmp) { Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue }
}

# --------------------------------------------------------------------- git
# git puo' non essere nel PATH: GitHub Desktop porta il suo, e va benissimo.
#
# Ogni pezzo va messo dentro un controllo: una variabile d-ambiente che non
# esiste fa morire Join-Path, e il programma si fermerebbe DOPO aver scritto i
# file, nel punto peggiore in cui fermarsi. Succede davvero: su un computer
# senza la cartella dei programmi a 32 bit la riga saltava.
$git = $null
$candidati = New-Object System.Collections.Generic.List[string]

$inPath = Get-Command git -ErrorAction SilentlyContinue
if ($inPath) { $candidati.Add($inPath.Source) }

foreach ($base in @($env:ProgramFiles, ${env:ProgramFiles(x86)})) {
  if ($base) { $candidati.Add((Join-Path $base 'Git\cmd\git.exe')) }
}

# Quello che porta con se GitHub Desktop: e dentro una cartella col numero di
# versione, che cambia a ogni aggiornamento, quindi si cerca.
if ($env:LOCALAPPDATA) {
  $desktop = Join-Path $env:LOCALAPPDATA 'GitHubDesktop'
  if (Test-Path $desktop) {
    $trovato = Get-ChildItem -Path $desktop -Filter 'git.exe' -Recurse `
      -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($trovato) { $candidati.Add($trovato.FullName) }
  }
}

foreach ($c in $candidati) {
  if ($c -and (Test-Path $c)) { $git = $c; break }
}

if (-not $git) {
  Att 'I file sono aggiornati, ma non trovo git su questo computer.'
  Riga ''
  Riga 'Finisci da GitHub Desktop:'
  Riga '  1. aprilo (vedra i file cambiati da solo)'
  if ($messaggio) { Riga ('  2. nel Summary scrivi: ' + $messaggio) }
  else            { Riga '  2. nel Summary scrivi due parole su cosa cambia' }
  Riga '  3. Commit to main, poi Push origin'
  exit 0
}

if (-not $messaggio) { $messaggio = 'Aggiornamento Falcata' }

Riga 'Mando su GitHub...'
Push-Location $repo
try {
  & $git add -A
  if ($LASTEXITCODE -ne 0) { throw 'git add non e andato a buon fine.' }

  $cambiati = & $git status --porcelain
  if (-not $cambiati) {
    Att 'Nessun cambiamento da mandare: era gia tutto aggiornato.'
    exit 0
  }

  & $git commit -m $messaggio
  if ($LASTEXITCODE -ne 0) { throw 'git commit non e andato a buon fine.' }

  & $git push
  if ($LASTEXITCODE -ne 0) {
    Err 'Il push non e andato. Apri GitHub Desktop e premi Push origin.'
    exit 1
  }
}
catch {
  Err ("Qualcosa non e andato: " + $_.Exception.Message)
  Att 'I file sono scritti. Finisci da GitHub Desktop (Commit e Push).'
  exit 1
}
finally {
  Pop-Location
}

Riga ''
Ok 'Fatto. GitHub sta compilando l-APK.'
Riga ''
Riga 'Fra qualche minuto lo trovi qui, dal telefono:'
Riga '  github.com/carlodiluigi-glitch/run-coach-app/releases'
Riga ''
Riga 'La compilazione si guarda qui:'
Riga '  github.com/carlodiluigi-glitch/run-coach-app/actions'
