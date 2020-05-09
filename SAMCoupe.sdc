derive_pll_clocks
derive_clock_uncertainty

set_multicycle_path -from {emu|cpu|*} -setup 2
set_multicycle_path -from {emu|cpu|*} -hold 1

set_multicycle_path -from {emu|psg|*} -setup 2
set_multicycle_path -from {emu|psg|*} -hold 1

set_multicycle_path -from {emu|video|*} -setup 2
set_multicycle_path -from {emu|video|*} -hold 1

set_multicycle_path -to {emu|hmpr*} -setup 2
set_multicycle_path -to {emu|hmpr*} -hold 1
set_multicycle_path -from {emu|hmpr*} -setup 2
set_multicycle_path -from {emu|hmpr*} -hold 1

set_multicycle_path -to {emu|lmpr*} -setup 2
set_multicycle_path -to {emu|lmpr*} -hold 1
set_multicycle_path -from {emu|lmpr*} -setup 2
set_multicycle_path -from {emu|lmpr*} -hold 1

set_multicycle_path -to {emu|brdr*} -setup 2
set_multicycle_path -to {emu|brdr*} -hold 1
set_multicycle_path -from {emu|brdr*} -setup 2
set_multicycle_path -from {emu|brdr*} -hold 1
