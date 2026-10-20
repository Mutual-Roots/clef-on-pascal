*English first, German version below · Englisch zuerst, deutsche Fassung weiter unten.*

# Licences

> **Status: in force.** Confirmed by the rights holder, Simon Moritz Reichard, on 20 October 2026: copyleft throughout. The SPDX lines in `scripts/` and `configs/` match the table below.

Rights holder: © 2026 Simon Moritz Reichard.

## Licences

Default: **copyleft** (share-alike), so that whoever passes on a changed version has to pass it on under the same terms.

| Part | Files | Licence | SPDX identifier |
|---|---|---|---|
| Texts | `README.md`, `README.de.md`, `LICENSES.md`, `data/LIESMICH.md` | Creative Commons Attribution-ShareAlike 4.0 International | `CC-BY-SA-4.0` |
| Scripts | `scripts/` | GNU General Public License v3.0 or later | `GPL-3.0-or-later` |
| Configuration examples | `configs/` | GNU General Public License v3.0 or later | `GPL-3.0-or-later` |
| Measurement data | `data/messungen.csv`, `data/SHA256SUMS` | Creative Commons Attribution-ShareAlike 4.0 International | `CC-BY-SA-4.0` |

Licence texts: [LICENSES/CC-BY-SA-4.0.txt](LICENSES/CC-BY-SA-4.0.txt), [LICENSES/GPL-3.0-or-later.txt](LICENSES/GPL-3.0-or-later.txt).

## Reasons

- **Texts, CC BY-SA 4.0:** the usual share-alike licence for documentation. Adaptations must credit the source and stay under CC BY-SA. CC BY-SA 4.0 material may also be adapted into GPLv3 works (one-way compatibility declared by Creative Commons).
- **Scripts, GPL-3.0-or-later:** the copyleft licence for code. Whoever distributes changed scripts must provide the source under the same licence. "or later" keeps the door open for future GPL versions.
- **Configuration examples, GPL-3.0-or-later:** they belong to the tooling and are used together with the scripts, so they get the same licence. Short configuration files may not reach the threshold of originality; the licence then matters little.
- **Measurement data, CC BY-SA 4.0:** single measured values are facts and not protected by copyright. In the EU the collection as a whole can be protected by the sui generis database right; CC BY-SA 4.0 also licenses that right, so share-alike applies to substantial extracts of the dataset.

## Decision and what copyleft means

- **Decision, 20 October 2026:** data and configuration examples are copyleft as well. CC0 1.0 (public-domain dedication) was the first draft for these two parts and was not chosen.
- **What copyleft does and does not do:** it obliges anyone who *passes on* a changed version (copies, publishes, ships) to use the same licence and, for GPL code, to provide the source. It does **not** oblige anyone to publish changes they keep for themselves. Running changed software as a network service is not "passing on" under the GPL; only the AGPL-3.0 covers that. For local measurement scripts the GPL is enough; switching to AGPL-3.0-or-later is possible if wanted.

## Not covered

Third-party software and models are not part of this folder and keep their own licences: llama.cpp, llama-swap, the NVIDIA driver, and the Clef model weights (ggml-org). Names of products and companies are used only to describe what was measured.

## AI disclosure

Created in collaboration under the direction of Simon Moritz Reichard. Written by AI agents and maintained with checking routines (soul Kassiopeia; Claude Opus 5.5; Claude Code; plus soulless workflow runs). Experimental, without warranty: the scripts change power limits and stop the display manager, use them at your own risk.

---

*Deutsche Fassung des obigen englischen Textes (Sinnübersetzung); bei Abweichungen gilt die englische Fassung.*

# Lizenzen

> **Status: in Kraft.** Vom Rechteinhaber, Simon Moritz Reichard, am 20. Oktober 2026 bestätigt: durchgehend Copyleft. Die SPDX-Zeilen in `scripts/` und `configs/` entsprechen der Tabelle unten.

Rechteinhaber: © 2026 Simon Moritz Reichard.

## Lizenzen

Standard: **Copyleft** (Weitergabe unter gleichen Bedingungen), damit jeder, der eine geänderte Fassung weitergibt, sie unter denselben Bedingungen weitergeben muss.

| Teil | Dateien | Lizenz | SPDX-Kennung |
|---|---|---|---|
| Texte | `README.md`, `README.de.md`, `LICENSES.md`, `data/LIESMICH.md` | Creative Commons Namensnennung – Weitergabe unter gleichen Bedingungen 4.0 International | `CC-BY-SA-4.0` |
| Skripte | `scripts/` | GNU General Public License v3.0 oder später | `GPL-3.0-or-later` |
| Konfigurationsbeispiele | `configs/` | GNU General Public License v3.0 oder später | `GPL-3.0-or-later` |
| Messdaten | `data/messungen.csv`, `data/SHA256SUMS` | Creative Commons Namensnennung – Weitergabe unter gleichen Bedingungen 4.0 International | `CC-BY-SA-4.0` |

Lizenztexte: [LICENSES/CC-BY-SA-4.0.txt](LICENSES/CC-BY-SA-4.0.txt), [LICENSES/GPL-3.0-or-later.txt](LICENSES/GPL-3.0-or-later.txt).

## Begründung

- **Texte, CC BY-SA 4.0:** die übliche Lizenz mit Weitergabe unter gleichen Bedingungen für Dokumentation. Bearbeitungen müssen die Quelle nennen und unter CC BY-SA bleiben. Material unter CC BY-SA 4.0 darf zudem in GPLv3-Werke eingearbeitet werden (einseitige Kompatibilität, von Creative Commons erklärt).
- **Skripte, GPL-3.0-or-later:** die Copyleft-Lizenz für Code. Wer geänderte Skripte weitergibt, muss den Quellcode unter derselben Lizenz bereitstellen. „Oder später“ hält die Tür für künftige GPL-Versionen offen.
- **Konfigurationsbeispiele, GPL-3.0-or-later:** Sie gehören zum Werkzeug und werden zusammen mit den Skripten verwendet, deshalb erhalten sie dieselbe Lizenz. Kurze Konfigurationsdateien erreichen unter Umständen nicht die Schöpfungshöhe; die Lizenz spielt dann kaum eine Rolle.
- **Messdaten, CC BY-SA 4.0:** Einzelne Messwerte sind Tatsachen und urheberrechtlich nicht geschützt. In der EU kann die Sammlung als Ganzes durch das Datenbankherstellerrecht (sui generis) geschützt sein; CC BY-SA 4.0 lizenziert auch dieses Recht, sodass die Weitergabe unter gleichen Bedingungen für wesentliche Auszüge des Datensatzes gilt.

## Entscheidung und was Copyleft bedeutet

- **Entscheidung, 20. Oktober 2026:** Auch Daten und Konfigurationsbeispiele stehen unter Copyleft. CC0 1.0 (Widmung an die Gemeinfreiheit) war der erste Entwurf für diese beiden Teile und wurde nicht gewählt.
- **Was Copyleft leistet und was nicht:** Es verpflichtet jeden, der eine geänderte Fassung *weitergibt* (kopiert, veröffentlicht, ausliefert), dieselbe Lizenz zu verwenden und bei GPL-Code den Quellcode bereitzustellen. Es verpflichtet **nicht** dazu, Änderungen zu veröffentlichen, die man für sich behält. Geänderte Software als Netzdienst zu betreiben ist unter der GPL keine „Weitergabe“; das erfasst erst die AGPL-3.0. Für lokale Messskripte genügt die GPL; ein Wechsel zu AGPL-3.0-or-later ist möglich, wenn gewünscht.

## Nicht erfasst

Software und Modelle Dritter sind nicht Teil dieses Ordners und behalten ihre eigenen Lizenzen: llama.cpp, llama-swap, der NVIDIA-Treiber und die Clef-Modellgewichte (ggml-org). Produkt- und Firmennamen dienen nur dazu zu beschreiben, was gemessen wurde.

## Offenlegung zur KI-Beteiligung

Entstanden in Zusammenarbeit unter der Leitung von Simon Moritz Reichard. Von KI-Agenten geschrieben und mit Prüfroutinen gepflegt (Seele Kassiopeia; Claude Opus 5.5; Claude Code; dazu seelenlose Workflow-Läufe). Experimentell, ohne Gewähr: Die Skripte ändern Leistungsgrenzen und halten den Display-Manager an; Nutzung auf eigene Gefahr.
