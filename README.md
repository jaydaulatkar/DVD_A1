# DVD_A1 — 4-bit Array Multiplier from RTL to GDSII (SKY130, open-source tools)

## Team

| Name | Roll number |
|------|-------------|
| Jay Daulatkar | 2023102044 |
| _Teammate name (to be filled)_ | _Teammate roll number (to be filled)_ |

## Environment

All commands are run from the repository root inside the IIC-OSIC-TOOLS container
(`hpretl/iic-osic-tools:latest`), with the repository mounted under `/foss/designs`.

```sh
iverilog -V | head -1      # Icarus Verilog version 14.0 (devel)
yosys -V                   # Yosys 0.70
sta -version               # 3.1.0
echo $PDK_ROOT $PDK        # /foss/pdks ihp-sg13g2  -> not sky130A, so:
sak-pdk sky130A            # select SKY130 (equivalently: export PDK=sky130A)
```

## Part A — RTL design and verification

```sh
# simulate the RTL with the exhaustive self-checking testbench
iverilog -g2012 -o sim tb/tb_mult.v rtl/full_adder.v rtl/mult_array.v
vvp sim
#   -> PASS: 256 vectors checked, 0 errors
gtkwave mult.vcd

# error-injection test: temporarily change sum to a ^ b in rtl/full_adder.v
sed -i 's/assign sum  = a ^ b ^ cin;/assign sum  = a ^ b;/' rtl/full_adder.v
iverilog -g2012 -o sim tb/tb_mult.v rtl/full_adder.v rtl/mult_array.v
vvp sim
#   -> FAIL: 256 vectors checked, 95 errors
git checkout rtl/full_adder.v          # undo the change
```

Example used for the waveform (roll number **2023102044**, Jay Daulatkar): last digit 4,
so A = 4 + 5 = **9**, B = **7**, A × B = **63**.

## Part B — Logic synthesis with Yosys

```sh
yosys -c synth/synth.tcl
#   -> synth/mult_array_netlist.v, synth/mult_array_stat.rpt

# gate-level simulation of the synthesized netlist with the same testbench
CELLS=$PDK_ROOT/sky130A/libs.ref/sky130_fd_sc_hd/verilog
iverilog -g2012 -DFUNCTIONAL -DUNIT_DELAY=#1 -o gls \
  tb/tb_mult.v $CELLS/primitives.v $CELLS/sky130_fd_sc_hd.v synth/mult_array_netlist.v
vvp gls
#   -> PASS: 256 vectors checked, 0 errors
```

Result: 61 cells (16 × `sky130_fd_sc_hd__dfrtp_1`), 756.976 µm², flip-flops 400.384 µm² (52.89 %).

## Part C — Static timing analysis with OpenSTA

```sh
sta sta/sta.tcl                 # T = 10 ns (default)  -> worst slack max 7.21
#   Tmin = T - WNS = 10 - 7.21 = 2.79 ns,  Fmax = 1000 / 2.79 = 358.42 MHz
T=2.79 sta sta/sta.tcl          # re-run at T = Tmin     -> worst slack max 0.00 (0.003 ns)
#   sta/mult_array_timing.rpt is the report of this final run (T = 2.79 ns)
```

`sta/sta.tcl` reads the period from the environment variable `T` (default 10.0 ns).

## Part D — Physical design with LibreLane (RTL → GDSII)

Initial `CLOCK_PERIOD` = 1.2 × Tmin = 1.2 × 2.79 = 3.348 ns → rounded up to the next 0.5 ns = **3.5 ns**.

```sh
cd pnr
librelane config.json          # one run per attempt; each creates runs/RUN_<date-time>/
# if timing fails: increase CLOCK_PERIOD in config.json by 0.5 ns and run again
cp runs/RUN_2026-10-19_19-32-37/final/metrics.json .
cp runs/RUN_2026-10-19_19-32-37/final/gds/mult_array.gds .
klayout mult_array.gds         # view the layout
cd ..
```

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
The `runs/` folder is not committed.
