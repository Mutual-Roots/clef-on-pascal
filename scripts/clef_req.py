#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Send one Clef decision request (POST /v1/systemone) and print status, wall time and body.

Usage: clef_req.py BASE_URL MODEL [VARIANT] [STATE_REPEAT] [QTYPE]
  BASE_URL      llama-swap (http://127.0.0.1:8470) or a single llama-server
  VARIANT       noul | choice | mixed (default mixed)
  STATE_REPEAT  repeats the state text (long-input test); about 49 tokens per repeat
  QTYPE         type of the category question: choice (default) or score
The sample text is German on purpose: it is the input used for the measurements, and the token
counts in the report depend on it.
"""
import json
import sys
import time
import urllib.error
import urllib.request

if len(sys.argv) < 3:
    raise SystemExit(__doc__)
base, model = sys.argv[1], sys.argv[2]
variant = sys.argv[3] if len(sys.argv) > 3 else 'mixed'
rep = int(sys.argv[4]) if len(sys.argv) > 4 else 1
QTYPE = sys.argv[5] if len(sys.argv) > 5 else 'choice'

state_one = ('Mieterin schreibt am Montagmorgen: Seit gestern Abend ist die Heizung in der ganzen Wohnung kalt, '
             'im Bad tropft zudem Wasser aus der Decke. Ich habe ein Baby zu Hause. Bitte schnell melden. ')
state = state_one * rep

q_noul = {'type': 'noul', 'instructions': 'Ist das Anliegen dringend (Gefahr oder Schaden heute)?'}
q_choice = {'type': QTYPE, 'instructions': 'Welche Kategorie passt am besten?',
            'criteria': {'heizung': 'Heizung oder Warmwasser',
                         'wasserschaden': 'Wasserschaden oder Leck',
                         'miete': 'Miete, Nebenkosten, Zahlung',
                         'sonstiges': 'Alles andere'}}
qs = {'noul': {'dringend': q_noul}, 'choice': {'kategorie': q_choice},
      'mixed': {'dringend': q_noul, 'kategorie': q_choice}}[variant]
body = {'model': model, 'state': state, 'questions': qs}
data = json.dumps(body).encode()
req = urllib.request.Request(base.rstrip('/') + '/v1/systemone', data=data,
                             headers={'Content-Type': 'application/json'})
t0 = time.time()
try:
    with urllib.request.urlopen(req, timeout=900) as r:
        status, out = r.status, r.read().decode()
except urllib.error.HTTPError as e:
    status, out = e.code, e.read().decode()
dt = time.time() - t0
print(f'status={status} wall_s={dt:.2f} state_chars={len(state)}')
try:
    print(json.dumps(json.loads(out), ensure_ascii=False)[:3000])
except ValueError:
    print(out[:3000])
