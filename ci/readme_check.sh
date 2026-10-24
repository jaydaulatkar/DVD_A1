#!/bin/bash
# Runs the README Part A-C commands verbatim in the pinned image and checks that the
# regenerated synth/ and sta/ files are byte-identical to the committed ones.
set -u
cd /foss/designs/DVD_A1
export PDK=sky130A
export STD_CELL_LIBRARY=sky130_fd_sc_hd
OUT=ci_out
mkdir -p $OUT /tmp/committed
cp synth/mult_array_netlist.v synth/mult_array_stat.rpt sta/mult_array_timing.rpt /tmp/committed/
cp rtl/full_adder.v /tmp/committed/full_adder.v
{
echo "== Part A =="
iverilog -g2012 -o sim tb/tb_mult.v rtl/full_adder.v rtl/mult_array.v
vvp sim

echo "== Part A task 6 (README commands) =="
sed 's/assign sum  = a ^ b ^ cin;/assign sum  = a ^ b;/' rtl/full_adder.v > /tmp/full_adder_bug.v
grep -n "assign sum" /tmp/full_adder_bug.v
iverilog -g2012 -o sim_bug tb/tb_mult.v /tmp/full_adder_bug.v rtl/mult_array.v
vvp sim_bug | sed -n '1p;$p'
rm -f sim_bug /tmp/full_adder_bug.v
vvp sim | grep -E "^(PASS|FAIL):"
cmp rtl/full_adder.v /tmp/committed/full_adder.v && echo "rtl/full_adder.v untouched"

echo "== Part B =="
yosys -q -c synth/synth.tcl
CELLS=$PDK_ROOT/sky130A/libs.ref/sky130_fd_sc_hd/verilog
iverilog -g2012 -DFUNCTIONAL -DUNIT_DELAY=#1 -o gls \
  tb/tb_mult.v $CELLS/primitives.v $CELLS/sky130_fd_sc_hd.v synth/mult_array_netlist.v
vvp gls | grep -E "^(PASS|FAIL):"

echo "== Part C =="
sta sta/sta.tcl > /tmp/sta10.log 2>&1; grep -i "slack" /tmp/sta10.log | head -3
T=2.79 sta sta/sta.tcl > /tmp/sta279.log 2>&1; grep -i "slack" /tmp/sta279.log | head -3

echo "== byte comparison with committed files =="
cmp synth/mult_array_netlist.v /tmp/committed/mult_array_netlist.v && echo "IDENTICAL synth/mult_array_netlist.v"
cmp synth/mult_array_stat.rpt  /tmp/committed/mult_array_stat.rpt  && echo "IDENTICAL synth/mult_array_stat.rpt"
cmp sta/mult_array_timing.rpt  /tmp/committed/mult_array_timing.rpt && echo "IDENTICAL sta/mult_array_timing.rpt"
} 2>&1 | tee $OUT/readme_check.log
