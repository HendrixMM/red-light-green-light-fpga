# ===========================================================================
# sim.do
# ModelSim simulation script for Red Light, Green Light
# Usage from repository root:  vsim -do sim/sim.do
# ===========================================================================

# --- Create work library ---------------------------------------------------
vlib work

# --- Compile all VHDL files (dependency order) -----------------------------
# Package first (everything depends on it)
vcom src/game_pkg.vhd

# Leaf modules (no dependencies beyond the package)
vcom src/input_sync.vhd
vcom src/ms_prescaler.vhd
vcom src/iter_timer.vhd
vcom src/game_fsm.vhd
vcom src/player_module.vhd
vcom src/display_ctrl.vhd
vcom src/led_ctrl.vhd

# Top level (instantiates all modules)
vcom src/rlgl_top.vhd

# Testbench (instantiates top level)
vcom sim/rlgl_tb.vhd

# --- Load simulation -------------------------------------------------------
vsim work.rlgl_tb

# --- Add waveforms (organized by subsystem) --------------------------------

add wave -divider "========== TOP-LEVEL I/O =========="
add wave -label "clk"         /rlgl_tb/clk
add wave -label "btn_reset"   /rlgl_tb/btn_reset
add wave -label "btn_start"   /rlgl_tb/btn_start
add wave -label "sw"          /rlgl_tb/sw
add wave -label "led"         /rlgl_tb/led

add wave -divider "========== DISPLAY =========="
add wave -label "seg"         -radix binary    /rlgl_tb/seg
add wave -label "dp"          /rlgl_tb/dp
add wave -label "an"          -radix binary    /rlgl_tb/an

add wave -divider "========== SYNC / DEBOUNCE =========="
add wave -label "ms_tick"     /rlgl_tb/uut/ms_tick
add wave -label "btn_pulse"   /rlgl_tb/uut/btn_pulse
add wave -label "reset_sync"  /rlgl_tb/uut/reset_sync
add wave -label "sw_sync"     /rlgl_tb/uut/sw_sync

add wave -divider "========== FSM =========="
add wave -label "state"       /rlgl_tb/uut/u_fsm/state
add wave -label "iter_count"  -radix unsigned  /rlgl_tb/uut/u_fsm/iter_count

add wave -divider "========== TIMER =========="
add wave -label "timer_load"  /rlgl_tb/uut/timer_load
add wave -label "timer_en"    /rlgl_tb/uut/timer_en
add wave -label "nominal"     -radix unsigned  /rlgl_tb/uut/u_timer/nominal
add wave -label "load_value"  -radix unsigned  /rlgl_tb/uut/u_timer/load_value
add wave -label "counter"     -radix unsigned  /rlgl_tb/uut/u_timer/counter
add wave -label "timer_done"  /rlgl_tb/uut/u_timer/timer_done

add wave -divider "========== PLAYER 1 =========="
add wave -label "P1 sw"       /rlgl_tb/uut/sw_sync(0)
add wave -label "P1 status"   /rlgl_tb/uut/gen_players(0)/u_player/status_reg
add wave -label "P1 dist"     -radix unsigned  /rlgl_tb/uut/gen_players(0)/u_player/dist_reg

add wave -divider "========== PLAYER 2 =========="
add wave -label "P2 sw"       /rlgl_tb/uut/sw_sync(1)
add wave -label "P2 status"   /rlgl_tb/uut/gen_players(1)/u_player/status_reg
add wave -label "P2 dist"     -radix unsigned  /rlgl_tb/uut/gen_players(1)/u_player/dist_reg

add wave -divider "========== PLAYER 3 =========="
add wave -label "P3 sw"       /rlgl_tb/uut/sw_sync(2)
add wave -label "P3 status"   /rlgl_tb/uut/gen_players(2)/u_player/status_reg
add wave -label "P3 dist"     -radix unsigned  /rlgl_tb/uut/gen_players(2)/u_player/dist_reg

add wave -divider "========== PLAYER 4 =========="
add wave -label "P4 sw"       /rlgl_tb/uut/sw_sync(3)
add wave -label "P4 status"   /rlgl_tb/uut/gen_players(3)/u_player/status_reg
add wave -label "P4 dist"     -radix unsigned  /rlgl_tb/uut/gen_players(3)/u_player/dist_reg

add wave -divider "========== AGGREGATION =========="
add wave -label "winner_exists"   /rlgl_tb/uut/winner_exists
add wave -label "all_eliminated"  /rlgl_tb/uut/all_eliminated

# --- Run simulation ---------------------------------------------------------
# run -all stops when sim_done halts the clock
run -all

# --- Zoom waveform to fit ---------------------------------------------------
wave zoom full
