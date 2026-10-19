# gtkwave -S gtkwave_view.tcl mult.vcd
# Example: A = 9 (last digit of 2023102044 is 4, 4 + 5 = 9), B = 7.
# Vector index 9*16+7 = 151 -> applied at 20 + 151*20 = 3040 ns,
# captured into a_r/b_r at edge 1 (3045 ns), product captured into p at edge 2 (3055 ns).
set nfacs [gtkwave::getNumFacs]
set want [list]
for {set i 0} {$i < $nfacs} {incr i} {
    set f [gtkwave::getFacName $i]
    puts "fac: $f"
}
foreach s {tb_mult.clk tb_mult.rst_n tb_mult.a[3:0] tb_mult.b[3:0] tb_mult.p[7:0]} {
    lappend want $s
}
set n [gtkwave::addSignalsFromList $want]
puts "added $n signals"
gtkwave::/Edit/Highlight_All
gtkwave::/Edit/Data_Format/Decimal
gtkwave::/Edit/UnHighlight_All
gtkwave::setZoomRangeTimes 3010000 3090000
gtkwave::setBaselineMarker 3035000
gtkwave::setMarker 3055000
gtkwave::setNamedMarker A 3040000 "inputs a=9 b=7 applied"
gtkwave::setNamedMarker B 3045000 "edge1: a,b captured"
gtkwave::setNamedMarker C 3055000 "edge2: p=63 captured"
