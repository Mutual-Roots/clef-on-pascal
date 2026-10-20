[English: README.md](README.md)

# LLM-Prefill auf einer GTX 1080 Ti (Pascal) im Jahr 2026: CUDA mit Treiber 580, Vulkan, Leistungsgrenzen und Takt

*Messbericht, 19.–20. Oktober 2026. Experimentell, ohne Gewähr. Lizenzen und Urheberschaft: [LICENSES.md](LICENSES.md). Deutsche Fassung des englischen Berichts; bei Abweichungen gilt [README.md](README.md).*

Eine GTX 1080 Ti (Pascal, Compute Capability 6.1, 11 GiB) leistet bei der Prompt-Verarbeitung (Prefill) mit quantisierten Modellen mittlerer Größe weiterhin Brauchbares, sofern der Software-Stack passt. Wir haben eine solche Karte gemessen, die mit llama.cpp zwei Clef-Entscheidungsmodelle bedient (Encoder-artig, nur Prefill): welchen Treiber sie braucht, CUDA gegen Vulkan, Leistungsgrenzen, einen unerwarteten Taktdeckel und ein 27B-Modell neben einem 9B-Modell in 11 GiB.

Durchsatz-, VRAM-, Takt- und Leistungswerte stammen aus [data/messungen.csv](data/messungen.csv) (61 Zeilen) oder aus den llama-swap-End-to-End-Tests weiter unten. Einige weitere Beobachtungen (JIT-Startzeiten, Zeilen aus Treiber- und Ollama-Logs, Clock-Event-Gründe, Build-Fehler) stammen aus Lauf-Logs, die nicht Teil dieses Ordners sind. Verhältnisse, Prozentwerte, Token je Joule und die Hochrechnung auf 64 Blöcke sind aus Messwerten abgeleitet, nicht selbst gemessen.

Schreibweise: Im Fließtext steht das Dezimalkomma. In den Tabellen behalten Messwerte den Dezimalpunkt, wie in der CSV-Datei; abgeleitete Werte wie tok/J stehen auch dort mit Komma. Versionsnummern bleiben unverändert.

## Kernaussagen

- **Die vorgefertigten CUDA-12.8-Binärdateien von llama.cpp brauchen Treiber 570 oder neuer:** Sie enthalten sm_61 nur als PTX. Mit Treiber 550 bricht jeder GPU-Lauf ab; mit 580.178.04 erreicht Clef-Flash 9B Q8_0 rund 1000 t/s (pp512 1001,48; pp2048 1001,43).
- **CUDA ist etwa 6-mal so schnell wie Vulkan** (gleiche llama.cpp-Version, gleiches Modell): 875,13 gegen 141,58 t/s bei pp2048.
- **175 W sind das Effizienzoptimum:** 875,63 t/s bei 171,5 W (5,11 tok/J) gegenüber 996,69 t/s bei 244,7 W (4,07 tok/J) mit der Standardgrenze von 250 W; das sind 88 % des Durchsatzes bei 70 % der Leistung (abgeleitet).
- **Ein Taktdeckel bei 1480 MHz** trat in einem kontrollierten Lauf auf, in dem der X-Server des Anmeldebildschirms schon lange lief: 874,73 statt 1001,50 t/s bei pp2048 (−12,7 %). Die Ursache ist unbestätigt; bei 175 W kostet der Deckel nichts (abgeleitet).
- **Ein 27B-Modell, das nicht in den VRAM passt, läuft mit den Gewichten im RAM und der GPU als Rechenwerk** (`-ngl 0`) **fast so schnell wie mit der Hälfte seiner Blöcke im VRAM:** 216,68 gegenüber 234,00 t/s bei pp2048, bei 1352 gegenüber 10402 MiB VRAM; rein auf der CPU: 19,17 t/s.
- **Beide Modelle passen zusammen:** Clef-Flash vollständig auf der GPU plus Clef 27B mit `-ngl 0` belegten unter Last 10038 MiB, bereitgestellt über llama-swap.

## Hardware und Software

| Teil | Wert |
|---|---|
| GPU | NVIDIA GeForce GTX 1080 Ti, 11 GiB, Compute Capability 6.1, PCIe 3.0 x16 |
| CPU, RAM | AMD Ryzen 5 7500F (6 Kerne), 64 GB |
| Betriebssystem | Debian 13 (trixie), Kernel der Serie 6.12 |
| Treiber | NVIDIA 580.178.04 (550.163.01 für die Ausgangsmessung) |
| llama.cpp | b11739 (0ce8cd114), vorgefertigte Release-Binärdateien für CUDA 12.8 und Vulkan |
| Bereitstellung | llama-swap v265 vor llama-server |
| Modelle | Clef-Flash 9B Q8_0 (32 Blöcke), Clef 27B Q4_K_M (64 Blöcke), GGUF von ggml-org |
| Anzeige | SDDM-Greeter unter X11; die erste Serie (Läufe A-flash-gpu, B, C, D) lief sehr wahrscheinlich mit einer gesperrten, angemeldeten KDE-Plasma-Sitzung (siehe „Methode und Grenzen“) |

Das reguläre Archiv von Debian 13 enthält nur den Treiber 550 (550.163.01; Backports nicht geprüft). Wir haben 580.178.04 aus NVIDIAs debian12-CUDA-Repository als lokal heruntergeladene, per Hash geprüfte Pakete installiert, weil apt unter trixie die SHA-1-Bindung des Repository-Schlüssels ablehnt. Die Pakete sind gepinnt und gehalten (hold): Ohne den Pin wählt apt einen neueren Zweig ohne Pascal-Unterstützung. Diese Schritte sollen zum **nvidia-legacy-580-installer** werden (geplant, noch nicht veröffentlicht): <https://github.com/Mutual-Roots/nvidia-legacy-580-installer>. Danach `dpkg --verify` ausführen; auf unserem System hat das Entfernen der nvidia-Alternativen von Debian mehrere frisch entpackte Dateien gelöscht, darunter die nouveau-Blacklist.

## Warum Treiber 570 oder neuer

Die vorgefertigten CUDA-12.8-Binärdateien enthalten nativen Code (SASS) nur für sm_86, sm_89 und sm_120; für Pascals sm_61 liegt nur PTX bei, das der Treiber beim Laden per JIT übersetzt. Ein Treiber übersetzt nur PTX aus Toolkits, die er kennt, und CUDA 12.8 gehört zum Zweig R570. Mit 550.163.01 brach jeder GPU-Lauf mit `the provided PTX was compiled with an unsupported toolchain` ab, auch mit `-ngl 0`, weil einige Operationen weiterhin auf CUDA laufen. Nur der reine CPU-Lauf funktionierte: 54,64 t/s bei pp512, etwa 18-mal langsamer als später die GPU (abgeleitet). Laut NVIDIA ist R580 der letzte Zweig für Pascal, und CUDA 13 hat sm_61 gestrichen; Pascal bleibt daher bei Treiber 580 mit CUDA 12.x.

Jeder GPU-Prozess sollte einen persistenten JIT-Cache mit großem Limit erhalten; wir haben `CUDA_CACHE_PATH=<cache dir>/nv-computecache` und `CUDA_CACHE_MAXSIZE=4294967296` verwendet und die Standardwerte des Treibers nicht geprüft. Nach dem Treiberwechsel dauerte der erste Start 22 s für die JIT-Übersetzung, der zweite 3 s (Cache 47 MB); der Durchsatz war gleich, 1005,86 und 996,85 t/s (pp512, Läufe jit1 und jit2). Flash Attention brachte nichts: `-fa 1` 992,36 und 1000,13 t/s, `-fa 0` 1001,48 und 1001,43 t/s (pp512, pp2048).

Ein nativer sm_61-Build (`-DCMAKE_CUDA_ARCHITECTURES=61`, CUDA 12.x) würde ohne JIT laufen; gebaut oder gemessen wurde keiner. Ein erster Versuch mit CUDA 12.9 unter Debian 13 scheiterte, bevor llama.cpp kompiliert wurde: Dem Toolkit fehlte cuBLAS, und nvcc lehnte die Math-Header von glibc 2.41 ab (glibc deklariert `sinpi`, `cospi`, `sinpif` und `cospif` als `noexcept`, die `crt/math_functions.h` von CUDA 12.9 nicht). Nachdem diese vier Deklarationen in einer privaten Toolkit-Kopie angepasst waren, konfigurierte CMake für sm_61 und brach dann wegen des fehlenden cuBLAS ab.

## CUDA gegen Vulkan

Gleiche llama.cpp-Version (Release-Binärdateien für CUDA und Vulkan), gleiche GGUF-Datei, gleiche Parameter (`-p 512,2048 -b 2048 -ub 2048 -n 0 -r 2 -ngl 99`), Treiber 580, unmittelbar nacheinander:

| Backend | pp512 t/s | pp2048 t/s | VRAM-Spitze |
|---|---|---|---|
| Vulkan | 134.34 | 141.58 | 8813 MiB |
| CUDA | 853.18 | 875.13 | 8997 MiB |

CUDA ist bei pp512 6,35-mal und bei pp2048 6,18-mal so schnell (abgeleitet). Die CUDA-Werte entsprechen dem weiter unten beschriebenen gedeckelten Zustand bei 1480 MHz; ohne Deckel erreicht CUDA etwa 1000 t/s, der tatsächliche Abstand kann also größer sein (der Takt wurde hier nicht aufgezeichnet). Ein aus Ollama entnommener qwen-9B-Blob ließ sich in beiden Builds nicht laden (`rope.dimension_sections has wrong array length`); keine Daten.

## Ollama auf Pascal

Auch Ollama 0.30.8 braucht für CUDA auf dieser Karte Treiber 570 oder neuer. Mit Treiber 550 protokollierte es `NVIDIA driver too old … required_driver="570 or newer"` und fiel auf Vulkan zurück. Mit Treiber 580 zeigt sein Startlog, dass es seine `cuda_v13`-Bibliotheken (gebaut für Compute Capability 7.5 und neuer) überspringt und danach seine `cuda_v12`-Bibliotheken wählt (`library=CUDA compute=6.1 libdirs=ollama,cuda_v12`). Die Ollama-Prefill-Zeilen in den Daten (qwen3.5 9B Q4_K_M mit Treiber 550: 191 t/s Vulkan, 63 t/s CPU) zeigen deshalb den Vulkan-Fallback; sie sind mit llama-bench nicht vergleichbar. Ollama auf CUDA wurde nicht gemessen.

## Der Taktdeckel bei 1480 MHz

Identische CUDA-Läufe landeten bei pp2048 entweder nahe 875 oder nahe 1000 t/s; die Taktspur zeigte 1480 MHz gegenüber 1746 MHz. Eine Probe (`bench_boost_x.sh`) hielt den Display-Manager kontrolliert an und startete ihn neu:

| Zustand | SM-Takt (Median) | pp2048 t/s |
|---|---|---|
| Greeter läuft schon lange | 1480 MHz | 874.73 |
| kein X-Server | 1746 MHz | 1001.50 |
| X vor 20 s neu gestartet | 1746 MHz | 999.36 |
| X vor 120 s neu gestartet | 1746 MHz | 1003.21 |

Drei Wiederholungsläufe mit nicht protokolliertem Sitzungszustand liefen ebenfalls mit 1480 MHz (874,09 bis 874,95 t/s). 1480 MHz ist der Referenz-Basistakt der Karte: Die Karte lief mit Basistakt, ohne zu boosten, und unter Last zeigte die Spur keinen aktiven Clock-Event-Grund (weder Leistungs-, Temperatur- noch Anwendungsgrenze).

**Hypothese, unbestätigt:** Der Deckel setzt ein, wenn der X-Server den Bildschirm nach einer Leerlaufzeit per DPMS dunkelschaltet. Test: DPMS am Greeter abschalten (`xset -dpms`) und den Lauf mit lange laufendem Greeter wiederholen.

Im 175-W-Profil läuft die Karte ohnehin mit 1480 MHz (875,63 t/s); der Deckel spielt daher nur oberhalb von 175 W eine Rolle (abgeleitet; Deckel und 175-W-Grenze zusammen wurden nicht gemessen). Von den Profilen weiter unten betrifft das `spiele` (250 W). Den Takt bei jedem Lauf mitschreiben und nur Läufe im gleichen Taktzustand vergleichen.

## Power-Sweep: 175 W

Ohne X-Server, Clef-Flash Q8_0, pp2048, drei Wiederholungen je Messpunkt, Grenze mit `nvidia-smi -pl` gesetzt. Leistung und Takt sind Mediane über die Spur des jeweiligen Messpunkts; tok/J ist abgeleitet.

| Grenze | t/s | Leistung (Median) | SM-Takt | tok/J |
|---|---|---|---|---|
| 125 W | 548.29 | 124.3 W | 898 MHz | 4,41 |
| 150 W | 732.74 | 149.3 W | 1240 MHz | 4,91 |
| **175 W** | **875.63** | **171.5 W** | **1480 MHz** | **5,11** |
| 200 W | 925.23 | 191.3 W | 1582 MHz | 4,84 |
| 225 W | 961.66 | 218.4 W | 1670 MHz | 4,40 |
| 250 W | 996.69 | 244.7 W | 1746 MHz | 4,07 |

Die Effizienz erreicht ihr Maximum bei 175 W. 125 W sind langsamer und weniger effizient als 150 W, deshalb erlauben die Profile 150 bis 250 W. Die llama-swap-Tests liefen bei 175 W: P2, 1480 MHz, im Median 155 W unter Last, Spitzen bis 179,8 W, zeitweise mit gesetztem Grund „Power Cap“. Waren beide Modelle geladen, aber im Leerlauf, blieb die Karte etwa 20 s lang in P2 bei rund 55 W und wechselte dann über P5 nach P8 bei 9 W.

## Ein 27B-Modell auf 11 GiB

Clef 27B Q4_K_M hat 64 Blöcke und passt nicht in 11 GiB. Gemessen mit llama-bench:

| Aufbau | `-ngl` | VRAM-Spitze | pp512 t/s | pp2048 t/s |
|---|---|---|---|---|
| Nur CPU (CUDA ausgeblendet) | 0 | 294 MiB (Bildschirm) | 19.57 | 19.17 |
| GPU als Rechenwerk, Gewichte im RAM | 0 | 1352 MiB | 149.94 | 216.68 |
| 16 von 64 Blöcken im VRAM | 16 | 6272 MiB | 166.00 | 224.93 |
| 24 von 64 Blöcken im VRAM | 24 | 8338 MiB | 175.81 | 229.36 |
| 32 von 64 Blöcken im VRAM | 32 | 10402 MiB | 186.96 | 234.00 |
| Hochrechnung: alle 64 Blöcke im VRAM (passt nicht) | 64 | – | ≈ 248 | ≈ 254 |

Mit `-ngl 0` führt llama.cpp die großen Matrixmultiplikationen jedes Batches trotzdem auf der GPU aus und streamt die Gewichte über PCIe („op offload“): bei pp2048 11,3-mal so schnell wie rein auf der CPU, für etwa 1 GiB VRAM. Die Zeit je Token sinkt linear mit der Zahl der im VRAM liegenden Blöcke (größte Abweichung von der Geraden: 0,0009 ms/Token bei pp2048, 0,009 bei pp512); die Verlängerung der Geraden auf 64 Blöcke ergibt die Hochrechnung (abgeleitet). Die Hochrechnung setzt voraus, dass die Gerade über 32 Blöcke hinaus weiterläuft. Damit erreicht `-ngl 0` bei pp2048 schon etwa 85 % des hochgerechneten Durchsatzes mit allen Blöcken im VRAM, bei pp512 aber nur 61 %, vermutlich weil große Batches die Gewichtsübertragung auf mehr Token verteilen (nicht gemessen). Die Hälfte der Blöcke im VRAM bringt 8 % bei pp2048 (25 % bei pp512) für etwa 8,8 GiB mehr VRAM. Wiederholungsmessungen vor dem Paartest (ngl 0: 150,22 und 216,80; ngl 32: 187,02 und 234,07) stimmen innerhalb von 0,2 % überein. Der Takt wurde nicht protokolliert; die erste Serie lief sehr wahrscheinlich mit einer gesperrten, angemeldeten Plasma-Sitzung, die Wiederholungen nur mit dem Greeter.

## Beide Modelle zusammen: das Paar

Mit llama-bench lief das 27B-Modell (`-ngl 0`) im Hintergrund, während Clef-Flash in einer Schleife lief. In den fünf Flash-Läufen, die sich vollständig mit dem 27B-Lauf überlappten, erreichte Flash bei pp2048 zwischen 464,24 und 583,05 t/s und das 27B-Modell 122,71 t/s; der sechste Lauf, während dessen das 27B-Modell fertig wurde, ergab 873,79. Bezogen auf die Einzelläufe (875,10 und 216,80) und mit dem Mittelwert der fünf überlappenden Flash-Läufe (491,81) ergeben die Anteile zusammen etwa 1,13 (abgeleitet): Beide gleichzeitig laufen zu lassen nutzt die Karte besser aus als ein Betrieb im Wechsel.

End-to-End über llama-swap ([configs/llama-swap/config.yaml](configs/llama-swap/config.yaml)), Profil `paar`, 175 W, Eingaben von 1660 Token nahe der Grenze. Das sind Einzelläufe von `scripts/profile_test.py`; sie stehen nicht in der CSV, und ihre Konsolenausgabe wurde nicht aufbewahrt (die GPU-Spur und das Service-Log blieben erhalten):

| | Clef-Flash (`clef-schnell`) | Clef 27B (`clef-gross`) |
|---|---|---|
| einzeln | 876 t/s | 210 t/s |
| beide gleichzeitig | 481 t/s | 170 t/s |
| kurze Anfrage, 316 Token | 0.39 s | 2.76 s |

Hier summieren sich die Anteile auf 1,36 (abgeleitet). Beide geladen: 9872 MiB im Leerlauf, 10038 MiB unter Last; ab Dienststart antwortete `/health` nach 0,27 s, und beide Modelle waren nach 4,9 s bereit. Das Profil `flash` betreibt Flash allein mit Eingaben bis 8192 Token (6952 Token in 8,6 s, 808 t/s; 10512 MiB; Wechsel etwa 3,0 s). Das Profil `27b-solo` hält 32 Blöcke des 27B-Modells auf der GPU (230 t/s; kurze Anfrage 2,02 s; 10196 MiB; Wechsel etwa 3,9 s).

Clef braucht die gesamte Eingabe in einem physischen Batch; deshalb ist `-c = -b = -ub` die maximale Eingabelänge, und darüber antwortet llama-server mit HTTP 500 („input (N tokens) is too large“). Ein abgeschossener Modellprozess wurde mit der nächsten Anfrage neu geladen (2,65 s); nach `kill -9` auf llama-swap räumte systemd auf und startete llama-swap neu, und das Paar war nach 11,2 s bereit.

## Empfohlene Profile

| Art | Profil | Verwendung |
|---|---|---|
| Leistung (`gpu-power`) | `ki-effizient`, 175 W | Standard für KI-Arbeit, beste Effizienz in Token je Joule |
| Leistung | `spiele`, 250 W | Spiele, voller Boost; vorher die Modelle entladen (`POST /api/models/unload`) |
| Leistung | `leise`, 150 W | leise: 73,5 % des Durchsatzes bei 61 % der Leistung (abgeleitet) |
| Modelle (llama-swap) | `paar` | Standard: beide Modelle, Eingaben bis 2048 Token |
| Modelle | `flash` | nur Flash, Eingaben bis 8192 Token |
| Modelle | `27b-solo` | nicht empfohlen: 230 gegenüber 210 t/s (+10 %) für etwa 8,8 GiB mehr VRAM |

## Methode und Grenzen

- Eine Karte, ein Rechner, eine Modellfamilie, eine llama.cpp-Version; keine Wiederholung an anderen Tagen oder mit anderen Karten, keine Kontrolle der Umgebungstemperatur.
- Nur Prefill: Clef ist ein Encoder-artiges Entscheidungsmodell, die Generierung wurde nicht gemessen (`-n 0`). Die Ergebnisse lassen sich nicht auf die Generierungsgeschwindigkeit übertragen.
- Ein bis vier llama-bench-Wiederholungen je Messpunkt (meist zwei; drei im Sweep und in der Taktdeckel-Probe); das ± in den Daten ist die Standardabweichung von llama-bench.
- Der Takt ist für A2, die Wiederholungsläufe, die Taktdeckel-Probe und den Power-Sweep protokolliert. Der Sitzungszustand ist für die Taktdeckel-Probe, den Sweep und A2 protokolliert sowie zu Beginn der Vulkan/CUDA- und der Paar-Serie (nur Greeter). Die Spalten für Leistung und Takt sind Mediane über ganze Spuren, Leerlaufphasen eingeschlossen: Richtwerte. Mediane allein über die Proben unter Last ergeben für A2, die Wiederholungsläufe und die Taktdeckel-Probe denselben Takt und weichen im Sweep um höchstens 38 MHz ab.
- Die erste Serie (A-flash-gpu, B, C, D; 23:02–23:12 UTC) lief sehr wahrscheinlich mit einer gesperrten, angemeldeten KDE-Plasma-Sitzung: Das A2-Log listet um 23:12:50 UTC, fünf Sekunden nach Ende der Serie, die Prozesse dieser Sitzung auf (Plasma, Bildschirmsperre), und der Bildschirm-Grundbedarf der Serie von 294 MiB passt dazu; mit nur dem Greeter lag der Grundbedarf bei 110 MiB. In den Daten steht `x_zustand` weiterhin auf `unbekannt`.
- VRAM-Werte sind Gesamtwerte der Karte einschließlich des Bildschirm-Grundbedarfs (294 MiB vor der ersten Serie, 110 MiB vor dem Paar). Die `.vram0`-Dateien von `bench_clef.sh` enthalten diesen Grundbedarf, keine Spitze; das erklärt den in data/LIESMICH.md als ungeklärt geführten Eintrag 294 gegenüber 9178 MiB.
- Treiber 580.178.04 ist für die Vulkan/CUDA-Serie protokolliert. Für die übrigen clef-bench-Läufe folgt er aus dem Systemzustand: um 20:03 UTC mit Treiber 580 gebootet, seitdem kein Neustart, und nach 20:52 UTC keine Änderung an Treiberpaketen. Der Tag der Log-Labels stimmt mit den Dateizeitstempeln überein.
- Lauf A2 („ohne-plasma“, in den Daten als unbekannt geführt): Sein Log zeigt, dass die Abmeldung vom Desktop 20 s vor dem Lauf abgeschlossen war, mit einem frisch neu gestarteten Greeter; das entspricht dem Zustand „X vor 20 s neu gestartet“.

## Reproduzieren

1. Treiber 580 installieren; mit `nvidia-smi --query-gpu=name,driver_version,compute_cap --format=csv` prüfen.
2. Die llama.cpp-Release-Binärdateien b11739 (CUDA 12.8, Vulkan) und die GGUF-Dateien besorgen (ggml-org/Clef-Flash-GGUF, Revision 8aa35d1cc7e1; ggml-org/Clef-GGUF, Revision 0d00bcc5bb45).
3. Pfade setzen; die Skripte brechen mit einer Meldung ab, wenn einer fehlt:

```sh
export LLAMA_CUDA_BIN=/path/to/llama.cpp-cuda/bin        # enthält llama-bench
export LLAMA_CUDA_LIBPATH=/path/to/cudart-bundle         # optional
export LLAMA_VULKAN_BIN=/path/to/llama.cpp-vulkan/bin
export CLEF_FLASH_GGUF=/path/to/Clef-Flash-Q8_0.gguf
export CLEF_27B_GGUF=/path/to/Clef-Q4_K_M.gguf
```

4. Nur ohne angemeldeten Desktop auf seat0 messen (`loginctl list-sessions`) und mit laufender Spur (`scripts/gputrace.sh start trace.csv`). Die Lauf-IDs entsprechen `lauf_id` in den Daten.

```sh
bash scripts/bench_cuda_baseline.sh out/baseline "$CLEF_FLASH_GGUF"
bash scripts/bench_clef.sh out/clef
bash scripts/bench_vulkan_cuda.sh out/vulkan-cuda flash-q8="$CLEF_FLASH_GGUF"
bash scripts/bench_flash_repeat.sh out/repeat 3
bash scripts/bench_boost_x.sh out/boost-x             # hält den Display-Manager an und startet ihn neu (sudo -n)
bash scripts/bench_power_sweep.sh out/power-sweep     # setzt Leistungsgrenzen (sudo -n nvidia-smi -pl)
bash scripts/bench_clef_pair.sh out/paar
```

`bench_clef_a2.sh` meldet vor der Messung eine KDE-Plasma-Sitzung ab; vorher den Kopf des Skripts lesen.

5. Leistungsprofile (als root):

```sh
sudo install -D -m 0755 scripts/gpu_power.sh /usr/local/lib/fordiverse-gpu/gpu_power.sh
sudo install -m 0755 scripts/gpu-power /usr/local/bin/gpu-power
sudo install -D -m 0644 configs/gpu-power/gpu-power.conf.example /etc/fordiverse/gpu/gpu.conf
sudo install -m 0644 configs/gpu-power/fordiverse-gpu-power.service configs/gpu-power/fordiverse-gpu-power@.service /etc/systemd/system/
sudo systemctl daemon-reload && sudo systemctl enable --now fordiverse-gpu-power.service
gpu-power list; gpu-power status; gpu-power spiele
```

6. llama-swap: `configs/llama-swap/config.yaml` und eine ausgefüllte `host.env` (aus `host.env.example`) nach `~/.config/fordiverse/llama-swap/` legen, das Unit-Beispiel installieren, den Dienst starten und `python3 scripts/profile_test.py` ausführen. Einzelne Anfrage: `python3 scripts/clef_req.py http://127.0.0.1:8470 clef-schnell`.

## Dateien

| Pfad | Inhalt |
|---|---|
| `data/messungen.csv` | 61 Messzeilen |
| `data/LIESMICH.md`, `data/SHA256SUMS` | Herkunft, Widersprüche, fehlgeschlagene Läufe (deutsch); Prüfsummen |
| `configs/llama-swap/` | getestete llama-swap-Konfiguration, Vorlage für host.env, systemd-User-Unit |
| `configs/gpu-power/` | Leistungsprofile und ihre zwei systemd-Units |
| `scripts/` | Mess- und Hilfsskripte, shellcheck-sauber |
| `LICENSES.md`, `LICENSES/` | Lizenzen und Lizenztexte |

Spalten von `messungen.csv`: `datum_utc` Startzeit, `lauf_id` Lauf-ID, `modell`, `quant`, `backend`, `ngl`, `test`, `t_s` Token/s, `streuung` ±, `vram_mib` VRAM-Spitze, `sm_mhz` Median des SM-Takts, `leistung_w` Median der Leistung, `leistungsgrenze_w` Leistungsgrenze, wo protokolliert, `x_zustand` Bildschirmzustand (`unbekannt`, `kein-x` ohne X-Server, `greeter-frisch` Greeter gerade gestartet, `greeter-lang` Greeter schon lange in Betrieb), `treiber`, `llama_cpp_build`, `quelle` Quelldatei.

## Urheberschaft

Rechteinhaber: Simon Moritz Reichard. Entstanden in Zusammenarbeit unter seiner Leitung; von KI-Agenten geschrieben und mit Prüfroutinen gepflegt (Seele Kassiopeia; Claude Opus 5.5; Claude Code; dazu seelenlose Workflow-Läufe). Experimentell, ohne Gewähr. Lizenzen: Texte und Daten CC BY-SA 4.0, Skripte und Konfigurationsbeispiele GPL-3.0-or-later ([LICENSES.md](LICENSES.md)).
