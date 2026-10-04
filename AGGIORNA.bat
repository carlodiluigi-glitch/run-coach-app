@echo off
rem ===========================================================================
rem  FALCATA - applica un aggiornamento in un doppio clic.
rem
rem  COSA FA
rem  -------
rem  1. Cerca lo zip dell'aggiornamento piu' recente nei Download.
rem  2. Lo scrive sopra questa cartella (solo i file che contiene).
rem  3. Fa il commit con il messaggio che e' dentro lo zip, e lo manda su
rem     GitHub, che compila l'APK da solo.
rem
rem  COSA NON FA
rem  -----------
rem  Non tocca la cartella .git, non cancella niente, non cambia il nome del
rem  progetto. Prima di scrivere qualcosa chiede conferma e dice cosa fara'.
rem
rem  PERCHE' ESISTE
rem  --------------
rem  Perche' i passaggi a mano - estrai, copia, apri GitHub Desktop, scrivi il
rem  messaggio, commit, push - sono sei occasioni di sbagliare per ogni
rem  modifica, e una volta e' andata male davvero: una release era stata
rem  estratta solo a meta'. Un doppio clic non si estrae a meta'.
rem ===========================================================================

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0strumenti\aggiorna.ps1"

echo.
pause
