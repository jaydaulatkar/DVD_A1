#!/bin/bash
# Runs inside hpretl/iic-osic-tools. Executes every step of the assignment, in order,
# exactly with the commands given in the assignment PDF, logging all output to ci_out/.
set -u
cd /foss/designs/DVD_A1
OUT=ci_out
mkdir -p $OUT
STAGE=${STAGE:-all}
# select the SKY130 PDK (the image defaults to another PDK)
type sak-pdk 2>&1 | head -2
export PDK=sky130A
export STD_CELL_LIBRARY=sky130_fd_sc_hd

{
echo "== tool versions =="
iverilog -V 2>&1 | head -1
yosys -V
sta -version
echo "PDK_ROOT=$PDK_ROOT PDK=$PDK"
librelane --version 2>&1 | tail -1
klayout -v
} 2>&1 | tee $OUT/versions.log

if [ "$STAGE" = "all" ] || [ "$STAGE" = "abc" ]; then
# ---------------------------------------------------------------- Part A
echo "== Part A: RTL simulation =="
iverilog -g2012 -o sim tb/tb_mult.v rtl/full_adder.v rtl/mult_array.v 2>&1 | tee $OUT/rtl_compile.log
vvp sim 2>&1 | tee $OUT/rtl_sim.log
cp mult.vcd $OUT/mult.vcd

echo "== Part A task 6: error-injection test (sum = a ^ b) =="
cp rtl/full_adder.v /tmp/full_adder.v.orig
sed -i 's/assign sum  = a ^ b ^ cin;/assign sum  = a ^ b;/' rtl/full_adder.v
grep -n "assign sum" rtl/full_adder.v | tee $OUT/fail_test_change.log
iverilog -g2012 -o sim tb/tb_mult.v rtl/full_adder.v rtl/mult_array.v
vvp sim > $OUT/fail_test_sim.log 2>&1
cp /tmp/full_adder.v.orig rtl/full_adder.v          # undo the change
rm -f mult.vcd
grep -c MISMATCH $OUT/fail_test_sim.log | sed 's/^/mismatch lines: /'
grep -E "^(PASS|FAIL):" $OUT/fail_test_sim.log
git diff --stat -- rtl/ || true
echo "== extra check: reset mutation (p reset value 0 -> 5) =="
cp rtl/mult_array.v /tmp/mult_array.v.orig
sed -i "s/p   <= 8'd0;/p   <= 8'd5;/" rtl/mult_array.v
grep -n "p   <= 8'd5" rtl/mult_array.v
iverilog -g2012 -o sim tb/tb_mult.v rtl/full_adder.v rtl/mult_array.v
vvp sim > $OUT/reset_mutation_sim.log 2>&1
cp /tmp/mult_array.v.orig rtl/mult_array.v
grep -E "reset|^(PASS|FAIL):" $OUT/reset_mutation_sim.log
# regenerate the correct waveform
iverilog -g2012 -o sim tb/tb_mult.v rtl/full_adder.v rtl/mult_array.v
vvp sim > /dev/null 2>&1

# ---------------------------------------------------------------- Part B
echo "== Part B: synthesis =="
yosys -c synth/synth.tcl 2>&1 | tee $OUT/synth.log
cat synth/mult_array_stat.rpt

echo "== Part B: gate-level simulation =="
CELLS=$PDK_ROOT/sky130A/libs.ref/sky130_fd_sc_hd/verilog
iverilog -g2012 -DFUNCTIONAL -DUNIT_DELAY=#1 -o gls \
  tb/tb_mult.v $CELLS/primitives.v $CELLS/sky130_fd_sc_hd.v synth/mult_array_netlist.v 2>&1 | tee $OUT/gls_compile.log
vvp gls 2>&1 | tee $OUT/gls_sim.log
rm -f mult.vcd
vvp sim > /dev/null 2>&1      # leave the RTL waveform as mult.vcd

# ---------------------------------------------------------------- Part C
echo "== Part C: STA at T = 10 ns =="
T=10.0 sta sta/sta.tcl 2>&1 | tee $OUT/sta_T10.log
cp sta/mult_array_timing.rpt $OUT/mult_array_timing_T10.rpt
WNS=$(grep -i "worst slack" $OUT/sta_T10.log | awk '{print $NF}' | tail -1)
TMIN=$(python3 -c "print(f'{10.0-float(\"$WNS\"):.2f}')")
echo "WNS=$WNS  Tmin=$TMIN" | tee $OUT/tmin.txt
echo "== Part C: STA at T = Tmin = $TMIN ns =="
T=$TMIN sta sta/sta.tcl 2>&1 | tee $OUT/sta_Tmin.log
cp sta/mult_array_timing.rpt $OUT/mult_array_timing_Tmin.rpt
fi

# ---------------------------------------------------------------- Part D
if [ "$STAGE" = "all" ] || [ "$STAGE" = "d" ]; then
if [ -f pnr/config.json ]; then
  echo "== Part D: LibreLane =="
  cd pnr
  mkdir -p ../$OUT/attempts
  echo "attempt,CLOCK_PERIOD,exit_code,setup_ws,setup_ws_tt,drc_magic,drc_klayout,lvs_errors,run_dir" > ../$OUT/attempts.csv
  N=0
  P=$(python3 -c "import json;print(json.load(open('config.json'))['CLOCK_PERIOD'])")
  while :; do
    N=$((N+1))
    python3 - "$P" <<'PY'
import json,sys
c=json.load(open('config.json')); c['CLOCK_PERIOD']=float(sys.argv[1])
open('config.json','w').write(json.dumps(c,indent=4)+chr(10))
PY
    echo "=== attempt $N: CLOCK_PERIOD=$P ===" | tee -a ../$OUT/librelane.log
    librelane config.json 2>&1 | tee ../$OUT/attempts/librelane_attempt${N}_P${P}.log
    RC=${PIPESTATUS[0]}
    RUN=$(ls -td runs/*/ | head -1)
    cp "$RUN/final/metrics.json" ../$OUT/attempts/metrics_attempt${N}_P${P}.json 2>/dev/null
    LINE=$(python3 - "$RUN/final/metrics.json" <<'PY'
import json,sys
try: m=json.load(open(sys.argv[1]))
except Exception: print("NA,NA,NA,NA,NA"); sys.exit()
g=lambda k: m.get(k,"NA")
print(f"{g('timing__setup__ws')},{g('timing__setup__ws__corner:nom_tt_025C_1v80')},{g('magic__drc_error__count')},{g('klayout__drc_error__count')},{g('design__lvs_error__count')}")
PY
)
    echo "$N,$P,$RC,$LINE,$RUN" | tee -a ../$OUT/attempts.csv
    if [ "$RC" = "0" ]; then break; fi
    if [ $N -ge 10 ]; then break; fi
    P=$(python3 -c "print($P+0.5)")
  done
  cp config.json ../$OUT/config_final.json
  ls runs/ | tee ../$OUT/runs_list.txt
  for nl in "$RUN"/final/nl/*.nl.v "$RUN"/final/pnl/*.pnl.v; do
    [ -f "$nl" ] && { echo "== $nl"; grep -o "sky130_fd_sc_hd__[a-z0-9_]*" "$nl" | sort | uniq -c | sort -rn; }
  done > ../$OUT/pnr_cell_types.txt
  echo "run dir: $RUN"
  if [ -f "$RUN/final/metrics.json" ]; then
    cp "$RUN/final/metrics.json" ../$OUT/metrics.json
    cp "$RUN"/final/gds/*.gds ../$OUT/ 2>/dev/null
  fi
  # bundle the useful parts of the run (no huge intermediates)
  tar czf ../$OUT/run_final.tgz "$RUN/final" "$RUN"/*.log "$RUN/resolved.json" \
      $(find "$RUN" -maxdepth 3 \( -name "*.rpt" -o -name "*.log" -o -name "*.json" \) ) 2>/dev/null
  cd ..
  if [ -f $OUT/mult_array.gds ]; then
    echo "== KLayout screenshots =="
    klayout -zz -r ci/klayout_shot.py -rd gds=$OUT/mult_array.gds -rd outdir=$OUT \
      -rd lyp=$PDK_ROOT/sky130A/libs.tech/klayout/tech/sky130A.lyp 2>&1 | tee $OUT/klayout.log
  fi
fi
fi
exit 0
