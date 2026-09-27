#!/usr/bin/env python3
"""Elenca tutte le frasi italiane scritte dentro il codice.

A COSA SERVE
------------
La traduzione dell'app e' stata rimandata di proposito: tradurre adesso
vorrebbe dire scrivere due volte le frasi del motore adattivo, che ancora non
esistono. Il rischio, pero', e' che il giorno che si traduce diventi una
caccia al tesoro in cinquanta file.

Questo script toglie quel rischio. Produce l'elenco completo - file, riga,
testo - in un colpo solo, quindi tradurre resta un lavoro meccanico invece
che archeologico. Va rilanciato quando serve: non c'e' niente da tenere
aggiornato a mano.

    python3 tool/estrai_frasi.py           # riepilogo
    python3 tool/estrai_frasi.py --csv     # tabella completa

LA CONVENZIONE, FINCHE' NON SI TRADUCE
--------------------------------------
Le frasi restano dove sono, scritte in chiaro accanto al codice che le usa.
E' piu' leggibile di un dizionario di chiavi (`t('forma.indice.debole')` non
dice niente a chi legge), e finche' la lingua e' una sola non costa niente.
Quello che NON si deve fare e' costruire una frase incollando pezzi:

    'Calcolato su ' + n + ' prestazioni'      NO: in altre lingue l'ordine
                                                  delle parole cambia
    'Calcolato su $n prestazioni'             SI: e' una frase sola

Cosi' il giorno della traduzione ogni riga di questo elenco e' una riga da
tradurre, intera, senza doverla ricostruire.
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# Una stringa e' "da tradurre" se contiene almeno tre lettere di fila e non e'
# un percorso, una chiave tecnica o un identificatore.
TESTO = re.compile(r"'((?:[^'\\\n]|\\.){3,})'")
TECNICA = re.compile(r"^[a-z_0-9.:%\-/\\\$\{\}]+$")
PAROLA = re.compile(r"[A-Za-zàèéìòù]{3}")


def pulisci(src):
    src = re.sub(r'//[^\n]*', '', src)
    return re.sub(r'/\*.*?\*/', '', src, flags=re.S)


def frasi():
    out = []
    for base in ('lib',):
        for dirpath, _, names in os.walk(os.path.join(ROOT, base)):
            for name in sorted(names):
                if not name.endswith('.dart'):
                    continue
                path = os.path.join(dirpath, name)
                with open(path, encoding='utf-8') as handle:
                    raw = handle.read()
                code = pulisci(raw)
                for m in TESTO.finditer(code):
                    testo = m.group(1)
                    if '.dart' in testo or testo.startswith('package:'):
                        continue
                    if TECNICA.match(testo) or not PAROLA.search(testo):
                        continue
                    riga = code[:m.start()].count('\n') + 1
                    out.append((os.path.relpath(path, ROOT), riga, testo))
    return out


def main():
    tutte = frasi()
    if '--csv' in sys.argv:
        print('file;riga;testo')
        for path, riga, testo in tutte:
            print('%s;%d;%s' % (path, riga, testo.replace(';', ',')))
        return

    per_file = {}
    for path, _, _ in tutte:
        per_file[path] = per_file.get(path, 0) + 1

    composte = [t for _, _, t in tutte if '$' in t]

    print('=' * 62)
    print('Frasi da tradurre: %d in %d file' % (len(tutte), len(per_file)))
    print('Di cui con numeri o variabili dentro: %d' % len(composte))
    print('=' * 62)
    print('\nI file piu\' carichi:\n')
    for path, n in sorted(per_file.items(), key=lambda x: -x[1])[:12]:
        print('  %-48s %4d' % (path, n))
    print('\nPer la tabella completa: python3 tool/estrai_frasi.py --csv')


if __name__ == '__main__':
    main()
