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
