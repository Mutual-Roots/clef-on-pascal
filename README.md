[Deutsch: README.de.md](README.de.md)

# LLM prefill on a GTX 1080 Ti (Pascal) in 2026: CUDA on driver 580, Vulkan, power and clocks

*Measurement report, 19–20 October 2026. Experimental, no warranty. Licences and authorship: [LICENSES.md](LICENSES.md).*

A GTX 1080 Ti (Pascal, compute capability 6.1, 11 GiB) still does useful prompt processing (prefill) with quantized mid-size models if the software stack fits. We measured one such card serving two Clef decision models (encoder-style, prefill only) with llama.cpp: the driver it needs, CUDA against Vulkan, power limits, an unexpected clock cap, and a 27B model next to a 9B model in 11 GiB.

Throughput, VRAM, clock and power values come from [data/messungen.csv](data/messungen.csv) (61 rows) or from the llama-swap end-to-end tests below. A few other observations (JIT start times, driver and Ollama log lines, clock-event reasons, build errors) come from run logs that are not part of this folder. Ratios, percentages, tokens per joule and the 64-block projection are derived from measured values, not measured themselves.

## Key findings

- **Driver 570 or newer is required** for the prebuilt llama.cpp CUDA 12.8 binaries: they carry sm_61 only as PTX. Driver 550 aborts every GPU run; with 580.178.04 Clef-Flash 9B Q8_0 reaches about 1000 t/s (pp512 1001.48, pp2048 1001.43).
- **CUDA is about 6× faster than Vulkan** (same llama.cpp release, same model): 875.13 against 141.58 t/s at pp2048.
- **175 W is the efficiency optimum:** 875.63 t/s at 171.5 W (5.11 tok/J) against 996.69 t/s at 244.7 W (4.07 tok/J) at the default 250 W limit; 88 % of the throughput for 70 % of the power (derived).
- **A 1480 MHz clock cap** appeared in a controlled run where the login screen's X server had been running for a long time: 874.73 instead of 1001.50 t/s at pp2048 (−12.7 %). Cause unconfirmed; at 175 W it costs nothing (derived).
- **A 27B model that does not fit runs nearly as fast with the weights in RAM and the GPU computing** (`-ngl 0`) as with half of its blocks in VRAM: 216.68 against 234.00 t/s at pp2048, with 1352 against 10402 MiB VRAM; CPU-only: 19.17 t/s.
- **Both models fit together:** Clef-Flash fully on the GPU plus Clef 27B with `-ngl 0` used 10038 MiB under load, served through llama-swap.

## Hardware and software

| Part | Value |
|---|---|
| GPU | NVIDIA GeForce GTX 1080 Ti, 11 GiB, compute capability 6.1, PCIe 3.0 x16 |
| CPU, RAM | AMD Ryzen 5 7500F (6 cores), 64 GB |
| OS | Debian 13 (trixie), kernel 6.12 series |
| Driver | NVIDIA 580.178.04 (550.163.01 for the baseline) |
| llama.cpp | b11739 (0ce8cd114), prebuilt release binaries for CUDA 12.8 and Vulkan |
| Serving | llama-swap v265 in front of llama-server |
| Models | Clef-Flash 9B Q8_0 (32 blocks), Clef 27B Q4_K_M (64 blocks), GGUF from ggml-org |
| Display | SDDM greeter on X11; the first series (runs A-flash-gpu, B, C, D) most likely ran with a locked KDE Plasma session logged in (see Method and limits) |

Debian 13's regular archive ships only the 550 driver (550.163.01; backports not checked). We installed 580.178.04 from NVIDIA's debian12 CUDA repository as locally downloaded, hash-checked packages, because trixie's apt rejects the repository key's SHA-1 binding. The packages are pinned and held: without the pin apt picks a newer branch without Pascal support. These steps will become **nvidia-legacy-580-installer** (planned, not yet published): <https://github.com/Mutual-Roots/nvidia-legacy-580-installer>. Run `dpkg --verify` afterwards; on our system removing Debian's nvidia alternatives deleted several freshly unpacked files, the nouveau blacklist among them.

## Why driver 570 or newer

The prebuilt CUDA 12.8 binaries contain native code (SASS) only for sm_86, sm_89 and sm_120; Pascal's sm_61 is shipped as PTX only, which the driver JIT-compiles at load time. A driver only compiles PTX from toolkits it knows, and CUDA 12.8 belongs to the R570 branch. With 550.163.01 every GPU run aborted with `the provided PTX was compiled with an unsupported toolchain`, even with `-ngl 0`, because some operations still run on CUDA. Only the CPU-only run worked: 54.64 t/s at pp512, about 18× slower than the GPU later (derived). According to NVIDIA, R580 is the last branch for Pascal and CUDA 13 dropped sm_61, so Pascal stays on driver 580 with CUDA 12.x.

Give every GPU process a persistent JIT cache with a large limit; we used `CUDA_CACHE_PATH=<cache dir>/nv-computecache` and `CUDA_CACHE_MAXSIZE=4294967296` and did not check the driver defaults. After the driver change the first start took 22 s for the JIT compilation, the second 3 s (cache 47 MB); throughput was the same, 1005.86 and 996.85 t/s (pp512, runs jit1 and jit2). Flash attention brought nothing: `-fa 1` 992.36 and 1000.13 t/s, `-fa 0` 1001.48 and 1001.43 t/s (pp512, pp2048).

A native sm_61 build (`-DCMAKE_CUDA_ARCHITECTURES=61`, CUDA 12.x) would run without JIT; none was built or measured. A first attempt with CUDA 12.9 on Debian 13 failed before llama.cpp was compiled: the toolkit lacked cuBLAS, and nvcc rejected glibc 2.41's math headers (glibc declares `sinpi`, `cospi`, `sinpif` and `cospif` `noexcept`; CUDA 12.9's `crt/math_functions.h` does not). With those four declarations patched in a private toolkit copy, CMake configured for sm_61 and then stopped at the missing cuBLAS.

## CUDA against Vulkan

Same llama.cpp release (CUDA and Vulkan release binaries), same GGUF, same parameters (`-p 512,2048 -b 2048 -ub 2048 -n 0 -r 2 -ngl 99`), driver 580, back to back:

| Backend | pp512 t/s | pp2048 t/s | VRAM peak |
|---|---|---|---|
| Vulkan | 134.34 | 141.58 | 8813 MiB |
| CUDA | 853.18 | 875.13 | 8997 MiB |

CUDA is 6.35× faster at pp512 and 6.18× at pp2048 (derived). The CUDA values match the capped 1480 MHz state below; uncapped CUDA reaches about 1000 t/s, so the true gap may be larger (clocks were not recorded here). A qwen 9B blob taken from Ollama failed to load in both builds (`rope.dimension_sections has wrong array length`); no data.

## Ollama on Pascal

Ollama 0.30.8 also needs driver 570 or newer for CUDA on this card. On driver 550 it logged `NVIDIA driver too old … required_driver="570 or newer"` and fell back to Vulkan. On driver 580 its startup log shows it skipping its `cuda_v13` libraries (built for compute capability 7.5 and newer) and then selecting its `cuda_v12` libraries (`library=CUDA compute=6.1 libdirs=ollama,cuda_v12`). The Ollama prefill rows in the data (qwen3.5 9B Q4_K_M on driver 550: 191 t/s Vulkan, 63 t/s CPU) therefore show the Vulkan fallback; they are not comparable with llama-bench. Ollama on CUDA was not measured.

## The 1480 MHz cap

Identical CUDA runs landed near 875 or near 1000 t/s at pp2048; the clock trace showed 1480 MHz against 1746 MHz. A probe (`bench_boost_x.sh`) stopped and restarted the display manager under control:

| State | SM clock (median) | pp2048 t/s |
|---|---|---|
| greeter running for a long time | 1480 MHz | 874.73 |
| no X server | 1746 MHz | 1001.50 |
| X restarted 20 s before | 1746 MHz | 999.36 |
| X restarted 120 s before | 1746 MHz | 1003.21 |

Three repeat runs with unlogged session state also ran at 1480 MHz (874.09 to 874.95 t/s). 1480 MHz is the card's reference base clock: the card ran at base clock without boosting, and under load the trace showed no active clock-event reason (no power, thermal or application limit).

**Hypothesis, unconfirmed:** the cap starts when the X server blanks the display via DPMS after an idle period. Test: disable DPMS on the greeter (`xset -dpms`) and repeat the long-greeter run.

At the 175 W profile the card runs at 1480 MHz anyway (875.63 t/s), so the cap only matters above 175 W (derived; cap and 175 W limit together were not measured); of the profiles below, that is `spiele` (250 W). Record the clock with every run and compare only runs in the same clock state.

## Power sweep: 175 W

Without X server, Clef-Flash Q8_0, pp2048, three repetitions per point, limit set with `nvidia-smi -pl`. Power and clock are medians over each point's trace; tok/J is derived.

| Limit | t/s | Power (median) | SM clock | tok/J |
|---|---|---|---|---|
| 125 W | 548.29 | 124.3 W | 898 MHz | 4.41 |
| 150 W | 732.74 | 149.3 W | 1240 MHz | 4.91 |
| **175 W** | **875.63** | **171.5 W** | **1480 MHz** | **5.11** |
| 200 W | 925.23 | 191.3 W | 1582 MHz | 4.84 |
| 225 W | 961.66 | 218.4 W | 1670 MHz | 4.40 |
| 250 W | 996.69 | 244.7 W | 1746 MHz | 4.07 |

Efficiency peaks at 175 W. 125 W is slower and less efficient than 150 W, so the profiles allow 150 to 250 W. The llama-swap tests ran at 175 W: P2, 1480 MHz, median 155 W under load, peaks up to 179.8 W with the power-cap reason set at times. With both models loaded and idle the card stayed in P2 at about 55 W for about 20 s, then went through P5 to P8 at 9 W.

## A 27B model on 11 GiB

Clef 27B Q4_K_M has 64 blocks and does not fit into 11 GiB. Measured with llama-bench:

| Setup | `-ngl` | VRAM peak | pp512 t/s | pp2048 t/s |
|---|---|---|---|---|
| CPU only (CUDA hidden) | 0 | 294 MiB (display) | 19.57 | 19.17 |
| GPU as compute engine, weights in RAM | 0 | 1352 MiB | 149.94 | 216.68 |
| 16 of 64 blocks in VRAM | 16 | 6272 MiB | 166.00 | 224.93 |
| 24 of 64 blocks in VRAM | 24 | 8338 MiB | 175.81 | 229.36 |
| 32 of 64 blocks in VRAM | 32 | 10402 MiB | 186.96 | 234.00 |
| Projection: all 64 blocks in VRAM (does not fit) | 64 | – | ≈ 248 | ≈ 254 |

With `-ngl 0` llama.cpp still runs each batch's large matrix multiplications on the GPU and streams the weights over PCIe ("op offload"): 11.3× faster than CPU-only at pp2048 for about 1 GiB of VRAM. Time per token falls linearly with the resident blocks (largest deviation from the line: 0.0009 ms/token at pp2048, 0.009 at pp512); extending the line to 64 blocks gives the projection (derived). The projection assumes the line continues past 32 blocks. So `-ngl 0` already reaches about 85 % of the projected all-in-VRAM throughput at pp2048, but 61 % at pp512, presumably because large batches spread the weight transfer over more tokens (not measured). Half of the blocks in VRAM buy 8 % at pp2048 (25 % at pp512) for about 8.8 GiB more VRAM. Replicates before the pair test (ngl 0: 150.22, 216.80; ngl 32: 187.02, 234.07) agree within 0.2 %. Clocks were not logged; the first series most likely ran with a locked Plasma session logged in, the replicates with only the greeter.

## Running both models: the pair

With llama-bench, the 27B (`-ngl 0`) ran in the background while Clef-Flash ran in a loop. In the five Flash runs that fully overlapped the 27B, Flash reached 464.24 to 583.05 t/s at pp2048 and the 27B 122.71 t/s; the sixth, during which the 27B finished, gave 873.79. Relative to solo runs (875.10, 216.80) and with the mean of the five overlapping Flash runs (491.81), the shares add up to about 1.13 (derived): running both at once uses the card better than taking turns.

End to end through llama-swap ([configs/llama-swap/config.yaml](configs/llama-swap/config.yaml)), profile `paar`, 175 W, inputs of 1660 tokens near the limit. These are single test runs with `scripts/profile_test.py`; they are not in the CSV, and their console output was not kept (the GPU trace and the service log were):

| | Clef-Flash (`clef-schnell`) | Clef 27B (`clef-gross`) |
|---|---|---|
| one at a time | 876 t/s | 210 t/s |
| both at once | 481 t/s | 170 t/s |
| short request, 316 tokens | 0.39 s | 2.76 s |

Here the shares add up to 1.36 (derived). Both loaded: 9872 MiB idle, 10038 MiB under load; from service start `/health` answered after 0.27 s and both models were ready after 4.9 s. Profile `flash` runs Flash alone with inputs up to 8192 tokens (6952 tokens in 8.6 s, 808 t/s; 10512 MiB; switch about 3.0 s). Profile `27b-solo` keeps 32 blocks of the 27B on the GPU (230 t/s; short request 2.02 s; 10196 MiB; switch about 3.9 s).

Clef needs the whole input in one physical batch, so `-c = -b = -ub` is the maximum input length; above it llama-server answers HTTP 500 ("input (N tokens) is too large"). A killed model process was reloaded with the next request (2.65 s); after `kill -9` of llama-swap, systemd cleaned up, restarted it, and the pair was ready after 11.2 s.

## Recommended profiles

| Kind | Profile | Use |
|---|---|---|
| power (`gpu-power`) | `ki-effizient`, 175 W | default for AI work, best tokens per joule |
| power | `spiele`, 250 W | games, full boost; unload the models first (`POST /api/models/unload`) |
| power | `leise`, 150 W | quiet: 73.5 % of the throughput at 61 % of the power (derived) |
| models (llama-swap) | `paar` | default: both models, inputs up to 2048 tokens |
| models | `flash` | Flash only, inputs up to 8192 tokens |
| models | `27b-solo` | not recommended: 230 against 210 t/s (+10 %) for about 8.8 GiB more VRAM |

## Method and limits

- One card, one host, one model family, one llama.cpp release; no repetition on other days or cards, no ambient-temperature control.
- Prefill only: Clef is an encoder-style decision model, generation was not measured (`-n 0`). Results do not carry over to generation speed.
- One to four llama-bench repetitions per point (mostly two; three in the sweep and the cap probe); ± in the data is llama-bench's standard deviation.
- Clocks are logged for A2, the repeat runs, the cap probe and the power sweep. Session state is logged for the cap probe, the sweep and A2, and at the start of the Vulkan/CUDA and pair series (greeter only). Power and clock columns are medians over whole traces, idle phases included: guide values. Medians over the load samples alone give the same clocks for A2, the repeat runs and the cap probe, and differ by at most 38 MHz in the sweep.
- The first series (A-flash-gpu, B, C, D; 23:02–23:12 UTC) most likely ran with a locked KDE Plasma session logged in: the A2 log lists that session's processes (Plasma, screen locker) at 23:12:50 UTC, five seconds after the series ended, and its 294 MiB display baseline matches them; with only the greeter the baseline was 110 MiB. The data keep `x_zustand` as unknown.
- VRAM values are card totals including the display baseline (294 MiB before the first series, 110 MiB before the pair). The `.vram0` files of `bench_clef.sh` hold that baseline, not a peak, which explains the 294 against 9178 MiB entry listed as unresolved in data/LIESMICH.md.
- Driver 580.178.04 is logged for the Vulkan/CUDA series. For the other clef-bench runs it follows from the system state: booted at 20:03 UTC on driver 580 with no reboot since, and no driver package change after 20:52 UTC. The day of the log labels matches the file timestamps.
- Run A2 ("ohne-plasma", kept as unknown in the data): its log shows the desktop logout finished 20 s before the run, with a freshly restarted greeter, matching the "X restarted 20 s before" state.

## Reproduce

1. Install driver 580; check `nvidia-smi --query-gpu=name,driver_version,compute_cap --format=csv`.
2. Get the llama.cpp b11739 release binaries (CUDA 12.8, Vulkan) and the GGUFs (ggml-org/Clef-Flash-GGUF revision 8aa35d1cc7e1, ggml-org/Clef-GGUF revision 0d00bcc5bb45).
3. Set the paths; the scripts stop with a message if one is missing:

```sh
export LLAMA_CUDA_BIN=/path/to/llama.cpp-cuda/bin        # contains llama-bench
export LLAMA_CUDA_LIBPATH=/path/to/cudart-bundle         # optional
export LLAMA_VULKAN_BIN=/path/to/llama.cpp-vulkan/bin
export CLEF_FLASH_GGUF=/path/to/Clef-Flash-Q8_0.gguf
export CLEF_27B_GGUF=/path/to/Clef-Q4_K_M.gguf
```

4. Measure only without a logged-in desktop on seat0 (`loginctl list-sessions`) and with a trace running (`scripts/gputrace.sh start trace.csv`). Run IDs match `lauf_id` in the data.

```sh
bash scripts/bench_cuda_baseline.sh out/baseline "$CLEF_FLASH_GGUF"
bash scripts/bench_clef.sh out/clef
bash scripts/bench_vulkan_cuda.sh out/vulkan-cuda flash-q8="$CLEF_FLASH_GGUF"
bash scripts/bench_flash_repeat.sh out/repeat 3
bash scripts/bench_boost_x.sh out/boost-x             # stops and restarts the display manager (sudo -n)
bash scripts/bench_power_sweep.sh out/power-sweep     # sets power limits (sudo -n nvidia-smi -pl)
bash scripts/bench_clef_pair.sh out/paar
```

`bench_clef_a2.sh` logs out a KDE Plasma session before measuring; read its header first.

5. Power profiles (root):

```sh
sudo install -D -m 0755 scripts/gpu_power.sh /usr/local/lib/fordiverse-gpu/gpu_power.sh
sudo install -m 0755 scripts/gpu-power /usr/local/bin/gpu-power
sudo install -D -m 0644 configs/gpu-power/gpu-power.conf.example /etc/fordiverse/gpu/gpu.conf
sudo install -m 0644 configs/gpu-power/fordiverse-gpu-power.service configs/gpu-power/fordiverse-gpu-power@.service /etc/systemd/system/
sudo systemctl daemon-reload && sudo systemctl enable --now fordiverse-gpu-power.service
gpu-power list; gpu-power status; gpu-power spiele
```

6. llama-swap: put `configs/llama-swap/config.yaml` and a filled-in `host.env` (from `host.env.example`) into `~/.config/fordiverse/llama-swap/`, install the unit example, start it, run `python3 scripts/profile_test.py`. Single request: `python3 scripts/clef_req.py http://127.0.0.1:8470 clef-schnell`.

## Files

| Path | Content |
|---|---|
| `data/messungen.csv` | 61 measurement rows |
| `data/LIESMICH.md`, `data/SHA256SUMS` | provenance, conflicts, failed runs (German); checksums |
| `configs/llama-swap/` | tested llama-swap config, host.env template, systemd user unit |
| `configs/gpu-power/` | power profiles and their two systemd units |
| `scripts/` | measurement and helper scripts, shellcheck-clean |
| `LICENSES.md`, `LICENSES/` | licences and licence texts |

Columns of `messungen.csv` (German names): `datum_utc` start, `lauf_id` run ID, `modell`, `quant`, `backend`, `ngl`, `test`, `t_s` tokens/s, `streuung` ±, `vram_mib` VRAM peak, `sm_mhz` median SM clock, `leistung_w` median power, `leistungsgrenze_w` power limit where logged, `x_zustand` display state (`unbekannt` unknown, `kein-x` no X, `greeter-frisch` greeter just started, `greeter-lang` greeter running long), `treiber` driver, `llama_cpp_build`, `quelle` source file.

## Authorship

Rights holder: Simon Moritz Reichard. Created in collaboration under his direction; written by AI agents and maintained with checking routines (soul Kassiopeia; Claude Opus 5.5; Claude Code; plus soulless workflow runs). Experimental, no warranty. Licences: texts and data CC BY-SA 4.0, scripts and configuration examples GPL-3.0-or-later ([LICENSES.md](LICENSES.md)).
