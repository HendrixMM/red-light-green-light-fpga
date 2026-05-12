----------------------------------------------------------------------------
-- rlgl_tb.vhd
-- Self-checking testbench. SIM_FAST = true (ms_tick every 10 clocks =
-- 100 ns), ENABLE_RANDOM = false (deterministic durations from the ROM).
-- Eight deterministic scenarios covering the main FSM end conditions
-- and player-state transitions.
----------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity rlgl_tb is
end rlgl_tb;

architecture sim of rlgl_tb is

  ---------------------------------------------------------------------------
  -- With SIM_FAST, the prescaler counts 0..9, so one game-ms = 100 ns.
  -- A 6-second iteration finishes in 600 us of sim time. The debouncer
  -- needs 21 stable ticks (2100 ns); we hold for 25 (2500 ns) to be safe.
  ---------------------------------------------------------------------------
  constant CLK_PERIOD : time := 10 ns;    -- 100 MHz
  constant TICK       : time := 100 ns;   -- 1 game-ms with SIM_FAST

  -- ROM nominal durations (ms) for reference - ENABLE_RANDOM = false
  -- Iter:  1     2     3     4     5     6     7     8     9    10
  --       6000  4500  3375  2531  1898  1423  1067   800   600  450

  signal clk       : std_logic := '0';
  signal btn_start : std_logic := '0';
  signal btn_reset : std_logic := '0';
  signal sw        : std_logic_vector(3 downto 0) := "0000";
  signal led       : std_logic_vector(3 downto 0);
  signal seg       : std_logic_vector(6 downto 0);
  signal dp        : std_logic;
  signal an        : std_logic_vector(7 downto 0);

  signal sim_done : boolean := false;  -- stops the clock after the final test

begin

  -- Clock
  clk <= not clk after CLK_PERIOD / 2 when not sim_done else '0';

  -- DUT: random off so durations are deterministic (assertions need exact
  -- tick counts), SIM_FAST on for 10,000x speedup. LFSR still runs but
  -- its output is ignored since the non-random generate block drives
  -- load_value.
  uut : entity work.rlgl_top
    generic map (
      ENABLE_RANDOM => false,
      SIM_FAST      => true
    )
    port map (
      clk_100mhz => clk,
      btn_start  => btn_start,
      btn_reset  => btn_reset,
      sw         => sw,
      led        => led,
      seg        => seg,
      dp         => dp,
      an         => an
    );

  stim : process

    -- Hold reset for 15 ticks, wait 5 for things to settle.
    -- Clears btn_start and sw so nothing is left over.
    procedure do_reset is
    begin
      btn_reset <= '1';
      btn_start <= '0';
      sw        <= "0000";
      wait for 15 * TICK;
      btn_reset <= '0';
      wait for 5 * TICK;
    end procedure;

    -- Simulate a button press: 25 ticks high (clears the 21-tick
    -- debounce), then release + 5 ticks for LOAD->GREEN to finish.
    -- By the time this returns the timer has been counting for ~8 ticks.
    procedure press_btn is
    begin
      btn_start <= '1';
      wait for 25 * TICK;
      btn_start <= '0';
      wait for 5 * TICK;
    end procedure;

    -- Variables for blink detection
    variable saw_hi : boolean;
    variable saw_lo : boolean;

  begin

    -----------------------------------------------------------------
    -- TEST 1: Reset and initial state
    -- All four LEDs on, nothing weird left over.
    -----------------------------------------------------------------
    report "===== TEST 1: Reset and initial state =====" severity note;
    do_reset;

    assert led = "1111"
      report "TEST 1 FAIL: All 4 LEDs should be ON after reset (all ACTIVE)"
      severity error;

    report "TEST 1 PASSED" severity note;

    -----------------------------------------------------------------
    -- TEST 2: One full iteration, nobody moves
    -- Start iteration 1 (6000 ticks), all switches down. Timer
    -- expires, FSM goes back to IDLE, everyone still active.
    -----------------------------------------------------------------
    report "===== TEST 2: Single iteration, no player action =====" severity note;

    press_btn;  -- iteration 1, 6000 ticks

    -- ~8 ticks already elapsed in press_btn, wait 6100 for margin
    wait for 6100 * TICK;

    assert led = "1111"
      report "TEST 2 FAIL: All LEDs should still be ON (no movement, no elimination)"
      severity error;

    report "TEST 2 PASSED" severity note;

    -----------------------------------------------------------------
    -- TEST 3: Red Light elimination
    -- FSM is in IDLE after test 2. Player 2 switch goes up during
    -- Red Light -> eliminated. Others unaffected.
    -----------------------------------------------------------------
    report "===== TEST 3: Red Light elimination =====" severity note;

    sw(1) <= '1';  -- Player 2 moves during Red Light
    wait for 5 * TICK;  -- a few ticks for the elimination to register

    assert led(1) = '0'
      report "TEST 3 FAIL: Player 2 LED should be OFF (eliminated)"
      severity error;
    assert led(0) = '1' and led(2) = '1' and led(3) = '1'
      report "TEST 3 FAIL: Players 1, 3, 4 should remain active"
      severity error;

    sw(1) <= '0';
    wait for 2 * TICK;

    report "TEST 3 PASSED" severity note;

    -----------------------------------------------------------------
    -- TEST 4: Player 1 wins across two iterations
    -- Iter 1: switch up for 5800 ticks (~5800 mm), down before expiry.
    -- Iter 2: switch up again, crosses 10,000 mm around tick 4200.
    -- Check the winner LED blinks by sampling over 2 blink cycles.
    -----------------------------------------------------------------
    report "===== TEST 4: Win scenario (Player 1) =====" severity note;
    do_reset;

    -- Iter 1: rack up ~5800 mm, pull switch before timer ends
    press_btn;
    sw(0) <= '1';
    wait for 5800 * TICK;
    sw(0) <= '0';
    wait for 400 * TICK;      -- timer expires, back to IDLE

    -- Iter 2: finish the race
    press_btn;
    sw(0) <= '1';
    wait for 4500 * TICK;     -- wins around tick 4200
    sw(0) <= '0';

    -- Sample the LED 8 times over 800 ticks. If it's blinking we
    -- should see both high and low.
    saw_hi := false;
    saw_lo := false;
    for i in 0 to 7 loop
      if led(0) = '1' then saw_hi := true; end if;
      if led(0) = '0' then saw_lo := true; end if;
      wait for 100 * TICK;
    end loop;

    assert saw_hi and saw_lo
      report "TEST 4 FAIL: Player 1 LED should be blinking (WINNER)"
      severity error;

    report "TEST 4 PASSED" severity note;

    -----------------------------------------------------------------
    -- TEST 5: Button does nothing in GAME_OVER
    -- Still in GAME_OVER from test 4. Press start, confirm nothing
    -- changes.
    -----------------------------------------------------------------
    report "===== TEST 5: Button ignored in GAME_OVER =====" severity note;

    press_btn;
    wait for 100 * TICK;

    -- Other three players were active when GAME_OVER hit
    assert led(1) = '1' and led(2) = '1' and led(3) = '1'
      report "TEST 5 FAIL: Non-winner player LEDs should remain ON in GAME_OVER"
      severity error;

    report "TEST 5 PASSED" severity note;

    -----------------------------------------------------------------
    -- TEST 6: All four eliminated at once
    -- Run one iteration, then all switches up during Red Light.
    -- Everyone out, GAME_OVER. Button should still do nothing.
    -----------------------------------------------------------------
    report "===== TEST 6: All players eliminated =====" severity note;
    do_reset;

    press_btn;                -- iteration 1
    wait for 6100 * TICK;     -- timer expires, enter IDLE

    sw <= "1111";  -- all four move during Red Light
    wait for 5 * TICK;

    assert led = "0000"
      report "TEST 6 FAIL: All LEDs should be OFF (all eliminated)"
      severity error;

    sw <= "0000";

    press_btn;  -- should be ignored
    wait for 100 * TICK;

    assert led = "0000"
      report "TEST 6 FAIL: LEDs should remain OFF after button press in GAME_OVER"
      severity error;

    report "TEST 6 PASSED" severity note;

    -----------------------------------------------------------------
    -- TEST 7: Run all 10 iterations, nobody moves, nobody wins
    -- 6200-tick wait per iteration covers the longest timer (6000)
    -- with margin. After the 10th, FSM should hit GAME_OVER.
    -----------------------------------------------------------------
    report "===== TEST 7: 10 iterations, no winner =====" severity note;
    do_reset;

    for i in 1 to 10 loop
      press_btn;
      wait for 6200 * TICK;
    end loop;

    -- Everyone still active, just no winner
    assert led = "1111"
      report "TEST 7 FAIL: All LEDs should be ON (active, no winner after 10 iterations)"
      severity error;

    press_btn;  -- should be ignored in GAME_OVER
    wait for 100 * TICK;

    assert led = "1111"
      report "TEST 7 FAIL: LEDs should remain ON in GAME_OVER"
      severity error;

    report "TEST 7 PASSED" severity note;

    -----------------------------------------------------------------
    -- TEST 8: Partial elimination, game keeps going
    -- Eliminate players 3 and 4 during Red Light. Game should NOT
    -- end (need all four out). Start another iteration, confirm
    -- the eliminated ones stay dead.
    -----------------------------------------------------------------
    report "===== TEST 8: Partial elimination, game continues =====" severity note;
    do_reset;

    press_btn;                -- iteration 1
    wait for 6100 * TICK;     -- timer expires, enter IDLE

    sw(2) <= '1';  -- P3 and P4 move during Red Light
    sw(3) <= '1';
    wait for 5 * TICK;

    assert led(2) = '0' and led(3) = '0'
      report "TEST 8 FAIL: Players 3, 4 should be eliminated"
      severity error;
    assert led(0) = '1' and led(1) = '1'
      report "TEST 8 FAIL: Players 1, 2 should remain active"
      severity error;

    sw(2) <= '0';
    sw(3) <= '0';

    -- Game continues; start another iteration
    press_btn;
    wait for 100 * TICK;

    -- P3 and P4 should still be out
    assert led(2) = '0' and led(3) = '0'
      report "TEST 8 FAIL: Eliminated players must stay eliminated across iterations"
      severity error;

    report "TEST 8 PASSED" severity note;

    -- Done
    report "=========================================" severity note;
    report "  ALL TESTS COMPLETED SUCCESSFULLY"       severity note;
    report "=========================================" severity note;

    sim_done <= true;
    wait;
  end process;

end sim;
