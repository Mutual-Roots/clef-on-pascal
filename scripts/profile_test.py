#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""End-to-end test of the llama-swap profiles paar, flash and 27b-solo for Clef
(configs/llama-swap/config.yaml). Talks only to llama-swap (LLAMA_SWAP_URL, default
http://127.0.0.1:8470) and reads nvidia-smi. Prints one line per step; times are wall-clock seconds.

Usage: profile_test.py [paar] [flash] [27b-solo] [back]     (default: all four phases)
Run gputrace.sh alongside to record clock and power.
Switching profiles changes what is loaded; run it only when nothing else uses llama-swap.
The sample text is German on purpose: the token counts in the report depend on it.
"""
import json
import os
import subprocess
import sys
import threading
import time
import urllib.error
import urllib.request
from datetime import datetime, timezone

BASE = os.environ.get('LLAMA_SWAP_URL', 'http://127.0.0.1:8470').rstrip('/')
STATE = ('Mieterin schreibt am Montagmorgen: Seit gestern Abend ist die Heizung in der ganzen Wohnung kalt, '
         'im Bad tropft zudem Wasser aus der Decke. Ich habe ein Baby zu Hause. Bitte schnell melden. ')
QUESTIONS = {
    'dringend': {'type': 'noul', 'instructions': 'Ist das Anliegen dringend (Gefahr oder Schaden heute)?'},
    'kategorie': {'type': 'choice', 'instructions': 'Welche Kategorie passt am besten?',
                  'criteria': {'heizung': 'Heizung oder Warmwasser', 'wasserschaden': 'Wasserschaden oder Leck',
                               'miete': 'Miete, Nebenkosten, Zahlung', 'sonstiges': 'Alles andere'}},
}


def now():
    return datetime.now(timezone.utc).strftime('%H:%M:%SZ')


def http(method, path, body=None, timeout=900):
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(BASE + path, data=data, method=method,
                                 headers={'Content-Type': 'application/json'} if data else {})
    t0 = time.time()
    try:
        with urllib.request.urlopen(req, timeout=timeout) as r:
            st, out = r.status, r.read().decode()
    except urllib.error.HTTPError as e:
        st, out = e.code, e.read().decode()
    return st, out, time.time() - t0


def decide(model, rep=1):
    st, out, dt = http('POST', '/v1/systemone', {'model': model, 'state': STATE * rep, 'questions': QUESTIONS})
    try:
        j = json.loads(out)
    except ValueError:
        j = {'raw': out[:200]}
    tok = (j.get('usage') or {}).get('input_tokens')
    ans = j.get('answers')
    if ans:
        short = f"dringend={ans['dringend']['noul']:.3f} kategorie={ans['kategorie']['choice']}"
    else:
        short = json.dumps(j.get('error', j), ensure_ascii=False)[:180]
    tps = f'{tok / dt:.0f}' if tok and st == 200 else '-'
    return st, dt, tok, tps, short, j.get('model')


def vram():
    return subprocess.run(['nvidia-smi', '--query-gpu=memory.used,pstate,clocks.sm,power.draw',
                           '--format=csv,noheader'], capture_output=True, text=True).stdout.strip()


def running():
    st, out, _ = http('GET', '/running')
    try:
        return [(m['model'], m['state']) for m in json.loads(out)['running']]
    except (ValueError, KeyError):
        return out[:200]


def log(step, **kw):
    print(f'[{now()}] {step}: ' + ' '.join(f'{k}={v}' for k, v in kw.items()), flush=True)


def show_decide(step, model, rep=1):
    st, dt, tok, tps, short, m = decide(model, rep)
    log(step, model=model, served_by=m, status=st, wall_s=f'{dt:.2f}', input_tok=tok, tok_per_s=tps, result=short)
    return st, dt


def set_profile(p):
    st, out, dt = http('PUT', '/api/profiles/active', {'name': p})
    log('profile_put', profile=p, status=st, body=out.strip()[:160])
    return st


def phase_state(label):
    st, out, _ = http('GET', '/health')
    log(label, health=f'{st}:{out.strip()}', running=running(), gpu=vram())


def concurrent(models, rep):
    res = {}

    def run(m):
        res[m] = decide(m, rep)
    ths = [threading.Thread(target=run, args=(m,)) for m in models]
    t0 = time.time()
    for t in ths:
        t.start()
    for t in ths:
        t.join()
    total = time.time() - t0
    for m in models:
        st, dt, tok, tps, short, sb = res[m]
        log('paar_concurrent', model=m, status=st, wall_s=f'{dt:.2f}', input_tok=tok, tok_per_s=tps)
    log('paar_concurrent_total', wall_s=f'{total:.2f}')


def main():
    phases = sys.argv[1:] or ['paar', 'flash', '27b-solo', 'back']
    if 'paar' in phases:
        phase_state('paar_start')
        show_decide('paar_warm', 'clef-schnell')
        show_decide('paar_warm', 'clef-gross')
        show_decide('paar_near_max', 'clef-schnell', 33)
        show_decide('paar_near_max', 'clef-gross', 33)
        show_decide('paar_over_max_expect_500', 'clef-schnell', 45)
        concurrent(['clef-schnell', 'clef-gross'], 33)
        phase_state('paar_end')
    if 'flash' in phases:
        set_profile('flash')
        st, first = show_decide('flash_first_incl_swap', 'clef-schnell')
        st, second = show_decide('flash_second', 'clef-schnell')
        log('flash_swap_estimate', swap_s=f'{first - second:.2f}')
        show_decide('flash_gross_expect_404', 'clef-gross')
        show_decide('flash_near_max_8192', 'clef-schnell', 159)
        phase_state('flash_end')
    if '27b-solo' in phases:
        set_profile('27b-solo')
        st, first = show_decide('solo_first_incl_swap', 'clef-gross')
        st, second = show_decide('solo_second', 'clef-gross')
        log('solo_swap_estimate', swap_s=f'{first - second:.2f}')
        show_decide('solo_schnell_expect_404', 'clef-schnell')
        show_decide('solo_near_max', 'clef-gross', 33)
        phase_state('solo_end')
    if 'back' in phases:
        set_profile('paar')
        st, a = show_decide('back_schnell_first_incl_swap', 'clef-schnell')
        st, b = show_decide('back_gross_first_incl_load', 'clef-gross')
        st, c = show_decide('back_schnell_second', 'clef-schnell')
        st, d = show_decide('back_gross_second', 'clef-gross')
        log('back_swap_estimate', schnell_s=f'{a - c:.2f}', gross_s=f'{b - d:.2f}')
        phase_state('back_end')


if __name__ == '__main__':
    main()
