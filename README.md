# DVD_A1 — 4-bit Array Multiplier from RTL to GDSII (SKY130, open-source tools)

A registered 4-bit × 4-bit unsigned array multiplier (16 AND gates, 12 full adders, 16 flip-flops,
2-cycle latency) taken through RTL simulation, Yosys synthesis, OpenSTA timing analysis and the
LibreLane place-and-route flow to a GDSII layout on the SkyWater SKY130 process (`sky130_fd_sc_hd`).

## Team

| Name | Roll number |
|------|-------------|
| Jay Daulatkar | 2023102044 |
| Parth Tokekar | 2023102041 |

## Contents

1. [Results at a glance](#1-results-at-a-glance)
2. [Repository structure](#2-repository-structure)
3. [Setup on Ubuntu (Linux)](#3-setup-on-ubuntu-linux)
4. [Setup on Windows 10/11](#4-setup-on-windows-1011)
5. [Starting the tool container](#5-starting-the-tool-container)
6. [Running the flow — every command, in order](#6-running-the-flow--every-command-in-order)
7. [Viewing the waveform and the layout](#7-viewing-the-waveform-and-the-layout)
8. [Troubleshooting](#8-troubleshooting)
9. [Report](#9-report)

---

## 1. Results at a glance

| Part | Result |
|------|--------|
| A — RTL | `PASS: 256 vectors checked, 0 errors`; error test (`sum = a ^ b`): `FAIL: 256 vectors checked, 95 errors` |
| B — Synthesis | 61 cells (16 × `dfrtp_1`), 756.976 µm², flip-flops 400.384 µm² = 52.89 %; gate-level simulation PASS |
| C — STA (tt corner) | WNS 7.21 ns at T = 10 ns → Tmin = 2.79 ns, Fmax = 358.42 MHz; slack at 2.79 ns = +0.003 ns |
| D — Place & route | CLOCK_PERIOD 8.0 ns after 10 runs; setup slack +0.396 ns; post-route Fmax 131.51 MHz; 1883 instances; 0 DRC, 0 LVS |

Example used for the waveform (roll number **2023102044**, Jay Daulatkar): last digit 4, so
A = 4 + 5 = **9**, B = **7**, A × B = **63**.

## 2. Repository structure

```
DVD_A1/
|-- README.md
|-- rtl/
|   |-- full_adder.v              1-bit full adder (assign statements)
|   `-- mult_array.v              registered 4x4 array multiplier, 12 full_adder instances
|-- tb/
|   `-- tb_mult.v                 exhaustive self-checking testbench (256 vectors, reset check, mult.vcd)
|-- synth/
|   |-- synth.tcl                 Yosys script (7 steps of Part B)
|   |-- mult_array_netlist.v      generated gate-level netlist
|   `-- mult_array_stat.rpt       generated cell/area report
|-- sta/
|   |-- sta.tcl                   OpenSTA script (7 steps of Part C), period from env variable T
|   `-- mult_array_timing.rpt     generated critical-path report (T = 2.79 ns)
|-- pnr/
|   |-- config.json               LibreLane configuration
|   |-- metrics.json              copied from the final run
|   `-- mult_array.gds            copied from the final run
`-- report/
    `-- report.pdf                results tables, screenshots, answers to the questions
```

All tools come from one Docker image, **IIC-OSIC-TOOLS** (`hpretl/iic-osic-tools`), which contains
Icarus Verilog, GTKWave, Yosys, OpenSTA, LibreLane (OpenROAD, Magic, KLayout, Netgen) and the
SKY130 PDK. Versions used: Icarus Verilog 14.0 (devel), Yosys 0.70, OpenSTA 3.1.0, KLayout 0.30.12,
GTKWave 3.3.116.

**Requirements:** 64-bit PC, ≥ 8 GB RAM (16 GB recommended), ≥ 25 GB free disk space (the image is a
~4 GB download and much larger unpacked), internet connection for the first download.

---

## 3. Setup on Ubuntu (Linux)

Tested on Ubuntu 22.04 / 24.04. Run these in a normal terminal.

**Step 1 — install Docker and Git**

```sh
sudo apt update
sudo apt install -y docker.io git x11-xserver-utils
sudo systemctl enable --now docker
sudo usermod -aG docker $USER          # lets you run docker without sudo
newgrp docker                          # or log out and log in again
docker run --rm hello-world            # must print "Hello from Docker!"
```

**Step 2 — get this repository**

```sh
mkdir -p ~/eda/designs
cd ~/eda/designs
git clone https://github.com/jaydaulatkar/DVD_A1.git
cd DVD_A1
```

**Step 3 — download the tool image (one time, ~4 GB)**

```sh
docker pull hpretl/iic-osic-tools:2026.10
```

All committed results were produced with this exact image release:

| Item | Version |
|---|---|
| Image | `hpretl/iic-osic-tools:2026.10`, digest `sha256:306585de35d198e70ea58950f77147c86f56c698726a19afea9f1c83009557be` |
| Icarus Verilog | 14.0 (devel) s20260301-579-g15d870a5 |
| Yosys | 0.70 (git 28ba3cb92) |
| OpenSTA | 3.1.0 (80fbbb2945) |
| LibreLane | 3.1.0.dev3 |
| KLayout / Magic / Netgen | 0.30.12 / 8.3 / 1.5.324 |
| PDK | `sky130A` from `/foss/pdks` in the image, library `sky130_fd_sc_hd` |

To be certain of the same image even if the `2026.10` tag were ever moved, pull it by digest:
`docker pull hpretl/iic-osic-tools@sha256:306585de35d198e70ea58950f77147c86f56c698726a19afea9f1c83009557be`.
A newer image (e.g. `latest`) will also run the flow, but cell choices, slack and wirelength may
then differ slightly from the committed numbers.

Continue with [Section 5](#5-starting-the-tool-container).

---

## 4. Setup on Windows 10/11

The tools only run on Linux, so on Windows they run inside **WSL 2** (Windows Subsystem for Linux),
either with Docker installed inside Ubuntu (Option A, recommended) or with Docker Desktop (Option B).
Both need WSL 2 working first.

**Step 1 — enable virtualization in the BIOS/UEFI**

Task Manager → Performance → CPU must show *Virtualization: Enabled*. If not, enable *Intel VT-x* /
*AMD-V (SVM)* in the BIOS setup.

**Step 2 — install WSL 2 with Ubuntu 24.04**

Open **PowerShell as Administrator** and run:

```powershell
wsl --install -d Ubuntu-24.04
```

Restart Windows when asked. After the restart, Ubuntu opens and asks for a new Linux user name and
password. Check that WSL 2 is used:

```powershell
wsl -l -v          # Ubuntu-24.04 ... VERSION 2
wsl --status
```

If `wsl --install` or `wsl --status` says *"Virtual Machine Platform"* is not enabled, or enabling it fails
with error `0x80073712` / `14098` ("component store has been corrupted"), Windows itself must be repaired
first — see [Troubleshooting](#8-troubleshooting).

### Option A (recommended) — Docker Engine inside Ubuntu on WSL 2

Open the **Ubuntu** app (Start menu) and run exactly the Ubuntu steps of
[Section 3](#3-setup-on-ubuntu-linux) inside it. On WSL use `sudo service docker start` if
`systemctl` is not available.

Notes for WSL:

- Clone the repository into the Linux home folder (`~/eda/designs/DVD_A1`), **not** under `/mnt/c/...`:
  the Linux file system is much faster and file permissions behave correctly.
- From Windows Explorer the folder is reachable as `\\wsl$\Ubuntu-24.04\home\<user>\eda\designs\DVD_A1`.
- Windows 11 includes **WSLg**, so GTKWave and KLayout windows open directly on the Windows desktop.

### Option B — Docker Desktop

1. Install Docker Desktop: <https://www.docker.com/products/docker-desktop>.
2. Docker Desktop → *Settings* → *General*: enable *Use the WSL 2 based engine*;
   *Settings* → *Resources* → *WSL integration*: enable *Ubuntu-24.04*;
   *Settings* → *Resources*: give it at least 8 GB memory and 4 CPUs.
3. Open the **Ubuntu** app and continue with Steps 2–3 of [Section 3](#3-setup-on-ubuntu-linux)
   (clone + `docker pull`); the `docker` command inside Ubuntu now talks to Docker Desktop.

Continue with [Section 5](#5-starting-the-tool-container) (all following commands are typed in the Ubuntu terminal).

---

## 5. Starting the tool container

Run from the repository folder (`cd ~/eda/designs/DVD_A1`). Choose one way.

**Way 1 — terminal with GUI windows (Ubuntu desktop, or Windows 11 + WSLg)**

```sh
xhost +SI:localuser:$(whoami)          # Ubuntu desktop only: allow the container to open windows
docker run --rm -it --user $(id -u):$(id -g) \
  -e DISPLAY=$DISPLAY -v /tmp/.X11-unix:/tmp/.X11-unix \
  -v $PWD:/foss/designs/DVD_A1 \
  hpretl/iic-osic-tools:2026.10 --skip bash
```

**Way 2 — terminal only (no GUI; GTKWave/KLayout then cannot open)**

```sh
docker run --rm -it --user $(id -u):$(id -g) -v $PWD:/foss/designs/DVD_A1 \
  hpretl/iic-osic-tools:2026.10 --skip bash
```

**Way 3 — full Linux desktop in the web browser (VNC mode, as in the assignment PDF)**

```sh
cd ~/eda
git clone --depth=1 https://github.com/iic-jku/iic-osic-tools.git
cd iic-osic-tools
DOCKER_TAG=2026.10 DESIGNS=$HOME/eda/designs ./start_vnc.sh
```

Then open <http://localhost> in a browser (the start script prints the URL and password; see the
IIC-OSIC-TOOLS README), open a terminal on that desktop and run `cd /foss/designs/DVD_A1`.

**Inside the container — select the SKY130 PDK and check the tools** (needed in every new shell):

```sh
cd /foss/designs/DVD_A1
export PDK=sky130A                     # the image defaults to another PDK (same effect as: sak-pdk sky130A)
export STD_CELL_LIBRARY=sky130_fd_sc_hd

iverilog -V | head -1                  # Icarus Verilog version 14.0 (devel)
yosys -V                               # Yosys 0.70
sta -version                           # 3.1.0
klayout -v                             # KLayout 0.30.12
echo $PDK_ROOT $PDK                    # /foss/pdks sky130A
ls $PDK_ROOT/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib
```

Files written inside `/foss/designs/DVD_A1` appear directly in the repository folder on the host.

---

## 6. Running the flow — every command, in order

These are the exact commands that produced the committed results, run from `/foss/designs/DVD_A1`
inside the container. With the pinned `2026.10` image (Section 3), re-running them regenerates the
`synth/` and `sta/` outputs with identical content; this was checked by a complete re-run.

### Part A — RTL design and verification

```sh
# simulate the RTL with the exhaustive self-checking testbench
# (all 256 vectors with the 2-cycle latency, plus a check that the reset clears p)
iverilog -g2012 -o sim tb/tb_mult.v rtl/full_adder.v rtl/mult_array.v
vvp sim
#   -> PASS: 256 vectors checked, 0 errors        (also writes mult.vcd)
gtkwave mult.vcd                       # see Section 7 for the signals and markers

# error-injection test (task 6): simulate a faulty copy with sum = a ^ b
# (the copy lives in /tmp, so rtl/full_adder.v itself is never modified)
sed 's/assign sum  = a ^ b ^ cin;/assign sum  = a ^ b;/' rtl/full_adder.v > /tmp/full_adder_bug.v
grep -n "assign sum" /tmp/full_adder_bug.v   # shows: assign sum  = a ^ b;
iverilog -g2012 -o sim_bug tb/tb_mult.v /tmp/full_adder_bug.v rtl/mult_array.v
vvp sim_bug
#   -> MISMATCH at 1060 ns: a=3 b=3 expected=9 got=5  ...
#   -> FAIL: 256 vectors checked, 95 errors
rm -f sim_bug /tmp/full_adder_bug.v
vvp sim                                # the correct design still gives PASS
```

### Part B — Logic synthesis with Yosys

```sh
yosys -c synth/synth.tcl
#   -> synth/mult_array_netlist.v, synth/mult_array_stat.rpt
cat synth/mult_array_stat.rpt          # 61 cells, chip area 756.976, sequential 400.384 (52.89%)

# gate-level simulation of the synthesized netlist with the same testbench
CELLS=$PDK_ROOT/sky130A/libs.ref/sky130_fd_sc_hd/verilog
iverilog -g2012 -DFUNCTIONAL -DUNIT_DELAY=#1 -o gls \
  tb/tb_mult.v $CELLS/primitives.v $CELLS/sky130_fd_sc_hd.v synth/mult_array_netlist.v
vvp gls
#   -> PASS: 256 vectors checked, 0 errors
```

### Part C — Static timing analysis with OpenSTA

`sta/sta.tcl` reads the clock period from the environment variable `T` (default 10.0 ns).

```sh
sta sta/sta.tcl                 # T = 10 ns (default)  -> worst slack max 7.21
#   Tmin = T - WNS = 10 - 7.21 = 2.79 ns,  Fmax = 1000 / 2.79 = 358.42 MHz
T=2.79 sta sta/sta.tcl          # re-run at T = Tmin     -> worst slack max 0.00 (0.003 ns)
#   sta/mult_array_timing.rpt is the report of this final run (T = 2.79 ns)
cat sta/mult_array_timing.rpt   # critical path: a_r[1] (_91_) -> p[6] (_88_), 8 logic cells
```

### Part D — Physical design with LibreLane (RTL → GDSII)

Initial `CLOCK_PERIOD` = 1.2 × Tmin = 1.2 × 2.79 = 3.348 ns → rounded up to the next 0.5 ns = **3.5 ns**.
Each run takes about 3–5 minutes and creates `pnr/runs/RUN_<date-time>/`.

```sh
cd pnr
# set the period of the attempt (3.5 for the first run; +0.5 ns after every setup failure)
sed -i 's/"CLOCK_PERIOD": [0-9.]*/"CLOCK_PERIOD": 3.5/' config.json
librelane config.json
#   a failing run ends with "Setup violations found in the following corners: ... ss_100C_1v60"
#   repeat with 4.0, 4.5, ... 8.0; the run at 8.0 ns finishes without errors (this is the committed config.json)

# key numbers of the newest run
RUN=$(ls -td runs/*/ | head -1); echo $RUN
python3 -c "
import json; m = json.load(open('$RUN/final/metrics.json'))
for k in ['design__instance__count', 'design__core__area', 'route__wirelength', 'timing__setup__ws',
          'timing__setup__ws__corner:nom_tt_025C_1v80', 'magic__drc_error__count',
          'klayout__drc_error__count', 'design__lvs_error__count']:
    print(f'{k:45s} {m[k]}')"

# copy the results of the final (passing) run
cp runs/RUN_2026-10-19_19-32-37/final/metrics.json .
cp runs/RUN_2026-10-19_19-32-37/final/gds/mult_array.gds .
klayout mult_array.gds         # view the layout (Section 7)
cd ..
```

When repeating the flow, use the name of your own final run instead of `RUN_2026-10-19_19-32-37`
(or `cp $RUN/final/metrics.json .` and `cp $RUN/final/gds/mult_array.gds .`). Do not commit `pnr/runs/`.

Every attempt (LibreLane in IIC-OSIC-TOOLS, `PDK=sky130A`, `sky130_fd_sc_hd`). The worst setup
slack (`timing__setup__ws`) is taken over all 9 signoff corners; it is always set by the slow
`ss_100C_1v60` corner. DRC and LVS were clean in every run.

| Run | CLOCK_PERIOD (ns) | Setup slack, all corners (ns) | Setup slack, tt corner (ns) | DRC (Magic / KLayout) | LVS errors | Result |
|----:|------------------:|------------------------------:|----------------------------:|:---------------------:|-----------:|:-------|
| 1  | 3.5 | −2.188 | +0.509 | 0 / 0 | 0 | setup violation |
| 2  | 4.0 | −1.688 | +1.009 | 0 / 0 | 0 | setup violation |
| 3  | 4.5 | −1.188 | +1.509 | 0 / 0 | 0 | setup violation |
| 4  | 5.0 | −0.686 | +2.009 | 0 / 0 | 0 | setup violation |
| 5  | 5.5 | −0.208 | +2.509 | 0 / 0 | 0 | setup violation |
| 6  | 6.0 | −0.154 | +2.877 | 0 / 0 | 0 | setup violation |
| 7  | 6.5 | −0.220 | +3.119 | 0 / 0 | 0 | setup violation |
| 8  | 7.0 | −0.134 | +3.520 | 0 / 0 | 0 | setup violation |
| 9  | 7.5 | −0.104 | +3.737 | 0 / 0 | 0 | setup violation |
| 10 | **8.0** | **+0.396** | +4.237 | 0 / 0 | 0 | **passed** (final run `RUN_2026-10-19_19-32-37`) |

`pnr/metrics.json` and `pnr/mult_array.gds` are copied from `runs/RUN_2026-10-19_19-32-37/final/`.

Results of the final run: setup slack +0.396 ns (worst corner `max_ss_100C_1v60`; tt corner +4.237 ns),
post-route Fmax = 1000 / (8.0 − 0.396) = 131.51 MHz (Part C: 358.42 MHz), 1883 instances
(331 standard cells + 1552 decap/fill), core area 17759.5 µm², wirelength 2499 µm, 0 DRC, 0 LVS errors.
The only remaining warning is 11 max-slew violations in the ss corner, all on the asynchronous reset net
`rst_n` (0.821 ns transition vs. 0.75 ns limit); reset recovery/removal slack is still +5.15 / +1.30 ns.
It is not one of the pass criteria (0 DRC, 0 LVS, setup slack ≥ 0).

---

## 7. Viewing the waveform and the layout

**Waveform (GTKWave)** — after `vvp sim`:

```sh
gtkwave mult.vcd
```

1. In the left tree open `tb_mult`, select `clk`, `rst_n`, `a[3:0]`, `b[3:0]`, `p[7:0]` and click *Append*;
   open `tb_mult` → `dut` and append `a_r[3:0]` and `b_r[3:0]` as well.
2. Select the bus signals → right click → *Data Format* → *Decimal*.
3. Type `3010 ns` in the *From:* box and `3090 ns` in the *To:* box of the toolbar and press Enter
   (the A = 9, B = 7 vector).
4. Middle-click at 3035 ns (baseline marker, clock edge 0) and left-click at 3055 ns (marker, edge 2):
   the title bar shows `Marker: B+20 ns` = the 2-cycle latency. a = 9, b = 7 are applied at 3040 ns,
   captured into a_r/b_r at 3045 ns (edge 1), and p = 63 appears at 3055 ns (edge 2).

**Layout (KLayout)**:

```sh
klayout pnr/mult_array.gds
```

Press `*` (show all hierarchy levels) and `F2` (zoom to fit) for the whole 150 µm × 150 µm die; drag a
box with the right mouse button to zoom into the standard-cell rows and metal wires. For the SKY130
layer colours: *File* → *Load Layer Properties* →
`$PDK_ROOT/sky130A/libs.tech/klayout/tech/sky130A.lyp`.

---

## 8. Troubleshooting

| Problem | Cause | What to do |
|---------|-------|------------|
| `permission denied ... docker.sock` | user not in the `docker` group | `sudo usermod -aG docker $USER`, then log out/in (or `newgrp docker`) |
| `Cannot connect to the Docker daemon` (WSL) | Docker service not running | `sudo service docker start` |
| `.lib file not found`, wrong cells | PDK not selected | `export PDK=sky130A` (or `sak-pdk sky130A`) in every new container shell |
| `cannot open display` for GTKWave/KLayout | no X server access | Ubuntu: `xhost +SI:localuser:$(whoami)` and start with Way 1; Windows 10: use Way 3 (VNC) |
| `Unknown module full_adder` | file missing from the command | include `rtl/full_adder.v` in every iverilog/Yosys command |
| LibreLane stops with setup violations | clock period too short | increase `CLOCK_PERIOD` by 0.5 ns and run again |
| LibreLane is very slow or crashes | too little memory | give Docker/WSL ≥ 8 GB RAM and 4 CPUs |
| `git` reports *dubious ownership* in the container | different user id inside the container | run `git` commands on the host, or `git config --global --add safe.directory /foss/designs/DVD_A1` |
| WSL: *"WSL2 is unable to start since virtualization is not enabled"* | BIOS virtualization off, or the *Virtual Machine Platform* feature missing | enable VT-x/AMD-V in the BIOS; in admin PowerShell: `wsl --install --no-distribution`, then restart |
| Enabling *Virtual Machine Platform* fails with `0x80073712` / error `14098` *"The component store has been corrupted"* (Windows Update usually fails too) | damaged Windows component store | admin PowerShell: `DISM /Online /Cleanup-Image /RestoreHealth`, restart, try again; if it still fails: *Settings → System → Recovery → "Fix problems using Windows Update" → Reinstall now* (keeps files and apps), then `wsl --install -d Ubuntu-24.04` |

---

## 9. Report

`report/report.pdf` contains the completed results tables of Parts A–D, the PASS/FAIL lines, the
hand-worked example (A = 9, B = 7), the annotated waveform screenshot, the block diagram, the list of
cells on the critical path (mapped to the full adders of the array), the two layout screenshots, an
additional-verification summary and the answers to questions 1–6.
