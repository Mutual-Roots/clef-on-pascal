# Messdaten Clef / CUDA / Vulkan, GTX 1080 Ti (19./20.10.2026)

Zusammengefuehrt aus Logs und Tabellen des Messordners. Nur Lesen, in diesem Lauf keine Messung. Zeiten sind UTC. "== label HH:MM:SSZ" in den Logs ist UTC. Die Takt-CSVs sind CEST (UTC+2) und wurden im Skript um 2 h auf UTC umgerechnet; das gilt nur fuer Laeufe ohne Log-Label.
Der Tag 2026-10-19 fuer die Log-Labels ist Annahme aus dem Messzeitraum (Labels 23:02Z bis 23:58Z), im Log nicht je Zeile belegt.
Zeilen in messungen.csv: 61 (eine Zeile je Lauf und Testspalte; Ollama-Prefill als eigene Zeilen).

## Spalten
- datum_utc: Startzeit aus dem Log-Label, sonst aus der ersten Takt-Zeile (umgerechnet). Leer, wenn keine Quelle. cuda-20261019/: nur Datum.
- lauf_id: Pfad im Messordner mit "-" statt "/". Bei bench-580.md zusaetzlich -faN (Schalter fa).
- backend: aus der Tabelle. B-27b-cpu als CPU gefuehrt (siehe Fehlgeschlagen).
- t_s, streuung: avg_ts bzw. +- aus der Tabelle; im Power-Sweep avg_ts und stddev_ts aus der CSV.
- vram_mib: VRAM-Spitze aus dem Log, zugeordnet ueber das Label davor. Leer, wenn kein Label.
- sm_mhz, leistung_w: Median ueber alle Samples der Takt-Datei des Laufs (ganze Datei, kein Schnitt auf das Benchmark-Fenster). Nur Richtwert, weil Leerlauf- und Pausenphasen enthalten sind. Power-Sweep: Median ueber pl*.csv.
- leistungsgrenze_w: nur belegt (A2: 250 W laut A2.takt.csv; Power-Sweep: Grenze des Punkts).
- x_zustand und treiber: siehe unten. llama_cpp_build: b11739 (0ce8cd114) laut Messskript bzw. CSV-Kopf; Ollama-Zeilen ohne Build-Angabe.
- quelle: Pfad relativ zum Messordner.

## x_zustand
Nur belegte Werte, sonst unbekannt:
- greeter-lang: boost-x/1-greeter-lange und boost-x/4-x-nach-120s (Log: sddm=active, xorg=1).
- greeter-frisch: boost-x/3-x-frisch-20s (sddm=active, xorg=1, 20 s nach Start).
- kein-x: boost-x/2-ohne-x (sddm=inactive, xorg=0); power-sweep (Log-Kopf "sddm=inactive").
- unbekannt: alle uebrigen. paar/ und vulkan-cuda/ haben nur den Logkopf "Sitzungen seat0: sddm/greeter", ohne Verlauf. Bei A2 widerspruechlich (siehe unten). Bei A-flash-gpu, B, C, D, repeat/ und cuda-20261019/ fehlt ein Sitzungsvermerk.

## Treiber
- 550.163.01: cuda-20261019/ausgangsmessung-550.txt und die Ollama-Zeilen (forschungsrunde-20261019).
- 580.178.04: cuda-20261019/bench-580* und vulkan-cuda.log (Kopf "Treiber: 580.178.04").
- Fuer die clef-bench-Laeufe (19.10. 23:02Z bis 23:56Z) ist 580 belegt, wenn auch nicht je Lauf vermerkt: Umstieg auf 580 ab 19:41Z laut cuda-20261019/nach-580.txt, Boot um 20:03Z ohne Neustart danach, das Paketprotokoll zeigt nach 20:52Z keine Treiberaenderung.

## Bedingungen
- llama-bench -p 512,2048 -b 2048 -ub 2048 -n 0 -r 2 laut Messskript. Nicht jede Tabelle zeigt alle Spalten; fehlende Spalten sind leer, nicht erfunden.
- Leistungsgrenze: Standard 250 W (power-sweep.log Kopf "Standardgrenze=250 W"; A2.takt.csv "power.limit 250.00 W"). Fuer die uebrigen Laeufe nicht protokolliert. Das Profil 175 W ist nur als Sweep-Punkt belegt, nicht als Messstand.
- Power-Sweep 125 bis 250 W, Start 2026-10-19 23:56:31Z (power-sweep.log Z.1). Restore auf 250 W per trap (power-sweep.log Z.10). Alle Punkte tragen die Startzeit als datum_utc.
- fa-Schalter (cuda-20261019/bench-580.md): fa1 nicht schneller als fa0.

## Stoerfaktoren
- Takt-Deckel: repeat/takt-1..3 haben im Median 1480 MHz (pp512 854 bis 855 t/s). boost-x 1 bei 1480 MHz (pp2048 874.73). boost-x 2 bis 4 und A2 bei 1746 MHz (boost-x pp2048 999.36 bis 1003.21, A2 pp512 992.46). Ursache des Deckels nicht belegt. Die Takt-Spalte ist deshalb fuer Vergleiche nur begrenzt aussagekraeftig.
- Paar-Laeufe: 27B lief parallel zu den Flash-Laeufen. PAAR-flash-1 bis 5: pp512 446.28 bis 562.41 t/s. PAAR-flash-6: pp512 597.90, pp2048 873.79 (laut paar.log lief das 27B am Ende dieses Laufs nicht mehr: "27B lief am Ende noch: nein").
- vulkan-cuda: Vulkan- und CUDA-Flash-q8 im selben Durchlauf (Werte in der Tabelle).
- Ollama-Prefill (forschungsrunde-20261019): qwen3.5 9B Q4_K_M, anderes Modell und anderer Pfad. Nicht mit den llama-bench-Werten vergleichbar.

## Fehlgeschlagen oder ohne Messwert (keine Zeile in messungen.csv)
- cuda-20261019/ausgangsmessung-550.txt Z.2: Abbruch rc=134, PTX unsupported toolchain. Nur die CPU-Zeile ist gemessen.
- cuda-20261019/bench-gpu-550.txt: Core-Dump, keine Werte. cuda-20261019/bench-580.err: Logfragment eines Fehllaufs.
- vulkan-cuda/V-qwen9b-q4 und C-qwen9b-q4: rc=1, Ladefehler "key qwen35.rope.dimension_sections has wrong array length; expected 4, got 3" (Ollama-Blob). Keine Messwerte.
- B-27b-cpu: Tabelle zeigt backend CUDA bei ngl 0; bench.log meldet "failed to initialize CUDA: no CUDA-capable device is detected". Als CPU gefuehrt (Build-Backend, nicht Laufzeitgeraet).
- Dateien ohne Tabellenzeile (Skript-Pruefung OHNE_TABELLE): vulkan-cuda-C-qwen9b-q4, vulkan-cuda-V-qwen9b-q4

## Widersprueche und offene Punkte
- A2: a2.log Z.27 Label "A2-flash-gpu-ohne-plasma" 23:13:12Z. a2.log meldet "Hauptmessung: inactive 23:12:50Z" und direkt danach eine Sitzung auf seat0 (Kennung 18). Der Plasma-Status ist damit nicht eindeutig; x_zustand unbekannt. Die Zuordnung A2.txt zu diesem Label erfolgt ueber den Namen (Vermutung).
- A-flash-gpu (23:02:56Z): kein Sitzungsvermerk. VRAM: bench.log-Spitze 9178 MiB, A-flash-gpu.vram0 zeigt 294 MiB. 294 entspricht dem B-27b-cpu-Wert in bench.log. Widerspruch, ungeklaert.
- repeat/ und cuda-20261019/: kein Sitzungsvermerk. cuda-20261019/ nur mit Datum.
- PAAR-Laeufe: keine Log-Zeit je Lauf; datum_utc leer, wenn keine Quelle.
- Leistungsgrenze fuer Laeufe ausser A2 und Sweep nicht protokolliert.
- CPU-Vergleich: cuda-20261019/ausgangsmessung-550.txt Z.4 clef 9B Q8_0 pp512 54.64 (Treiber 550) und B-27b-cpu pp512 19.57 (Treiber 580, 23:03:09Z) betreffen verschiedene Modelle (9B Q8_0 gegen 27B Q4_K - Medium). Kein Widerspruch; es gibt keinen 9B-Q8_0-CPU-Lauf im Clef-Bench zum Gegenpruefen.
- Ollama-Prefill (anderes Modell, Treiber 550, anderer Pfad) nicht vergleichbar mit llama-bench.
