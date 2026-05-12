----------------------------------------------------------------------------
-- rlgl_top.vhd
-- Structural top level. Instantiates input sync, prescaler, FSM, timer,
-- four player modules, display, and LED control. The only logic here is
-- the winner_exists / all_eliminated aggregation.
-- Target: Nexys A7-100T (xc7a100tcsg324-1).
----------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.game_pkg.all;

entity rlgl_top is
  generic (
    ENABLE_RANDOM : boolean := true;  -- set false to disable bonus randomness
    SIM_FAST      : boolean := false  -- set true in testbench for 10,000x speedup
  );
  port (
    clk_100mhz : in  std_logic;                     -- 100 MHz oscillator input
    btn_start  : in  std_logic;                     -- BTNC, active high
    btn_reset  : in  std_logic;                     -- BTNU, active high
    sw         : in  std_logic_vector(3 downto 0);  -- SW[3:0], active high
    led        : out std_logic_vector(3 downto 0);  -- LED[3:0], active high
    seg        : out std_logic_vector(6 downto 0);  -- CA..CG, active low
    dp         : out std_logic;                      -- DP, active low
    an         : out std_logic_vector(7 downto 0)    -- AN[7:0], active low
  );
end rlgl_top;

architecture structural of rlgl_top is

  -----------------------------------------------------------
  -- Internal signals
  -----------------------------------------------------------

  -- Synced / debounced inputs
  signal btn_pulse   : std_logic;
  signal reset_sync  : std_logic;
  signal sw_sync     : std_logic_vector(3 downto 0);

  -- Prescaler
  signal ms_tick : std_logic;

  -- FSM outputs
  signal game_state  : state_type;
  signal timer_load  : std_logic;
  signal timer_en    : std_logic;
  signal iter_num    : unsigned(3 downto 0);
  signal current_iter: unsigned(3 downto 0);

  -- Timer outputs
  signal time_left   : unsigned(12 downto 0);
  signal timer_done  : std_logic;

  -- Player statuses and distances
  type status_array is array (0 to 3) of std_logic_vector(1 downto 0);
  type dist_array   is array (0 to 3) of unsigned(13 downto 0);
  signal p_status : status_array;
  signal p_dist   : dist_array;

  -- Aggregation signals
  signal winner_exists   : std_logic;
  signal all_eliminated  : std_logic;

begin

  -----------------------------------------------------------
  -- Input sync + debounce
  -----------------------------------------------------------
  u_input_sync : entity work.input_sync
    port map (
      clk       => clk_100mhz,
      ms_tick   => ms_tick,
      btn_raw   => btn_start,
      rst_raw   => btn_reset,
      sw_raw    => sw,
      btn_pulse => btn_pulse,
      reset_out => reset_sync,
      sw_sync   => sw_sync
    );

  -----------------------------------------------------------
  -- ms_tick prescaler
  -----------------------------------------------------------
  u_prescaler : entity work.ms_prescaler
    generic map (
      SIM_FAST => SIM_FAST
    )
    port map (
      clk     => clk_100mhz,
      reset   => reset_sync,
      ms_tick => ms_tick
    );

  -----------------------------------------------------------
  -- Control FSM
  -----------------------------------------------------------
  u_fsm : entity work.game_fsm
    port map (
      clk            => clk_100mhz,
      reset          => reset_sync,
      btn_pulse      => btn_pulse,
      timer_done     => timer_done,
      all_eliminated => all_eliminated,
      winner_exists  => winner_exists,
      game_state     => game_state,
      timer_load     => timer_load,
      timer_en       => timer_en,
      iter_num       => iter_num,
      current_iter   => current_iter
    );

  -----------------------------------------------------------
  -- Iteration timer (ROM + optional LFSR + down-counter)
  -----------------------------------------------------------
  u_timer : entity work.iter_timer
    generic map (
      ENABLE_RANDOM => ENABLE_RANDOM
    )
    port map (
      clk        => clk_100mhz,
      reset      => reset_sync,
      ms_tick    => ms_tick,
      load       => timer_load,
      timer_en   => timer_en,
      iter_num   => iter_num,
      time_left  => time_left,
      timer_done => timer_done
    );

  -----------------------------------------------------------
  -- Four player modules (identical, via generate)
  -----------------------------------------------------------
  gen_players : for i in 0 to 3 generate
    u_player : entity work.player_module
      port map (
        clk        => clk_100mhz,
        reset      => reset_sync,
        ms_tick    => ms_tick,
        sw         => sw_sync(i),
        game_state => game_state,
        status     => p_status(i),
        distance   => p_dist(i)
      );
  end generate gen_players;

  -----------------------------------------------------------
  -- Did anyone win? Is everyone out?
  -----------------------------------------------------------
  winner_exists <= '1' when (p_status(0) = ST_WINNER or
                             p_status(1) = ST_WINNER or
                             p_status(2) = ST_WINNER or
                             p_status(3) = ST_WINNER)
                       else '0';

  all_eliminated <= '1' when (p_status(0) = ST_ELIMINATED and
                              p_status(1) = ST_ELIMINATED and
                              p_status(2) = ST_ELIMINATED and
                              p_status(3) = ST_ELIMINATED)
                        else '0';

  -----------------------------------------------------------
  -- 7-segment display
  -----------------------------------------------------------
  u_display : entity work.display_ctrl
    port map (
      clk        => clk_100mhz,
      reset      => reset_sync,
      ms_tick    => ms_tick,
      time_left  => time_left,
      p1_dist    => p_dist(0),
      p2_dist    => p_dist(1),
      p3_dist    => p_dist(2),
      p4_dist    => p_dist(3),
      p1_status  => p_status(0),
      p2_status  => p_status(1),
      p3_status  => p_status(2),
      p4_status  => p_status(3),
      iter_count => current_iter,
      seg        => seg,
      dp         => dp,
      an         => an
    );

  -----------------------------------------------------------
  -- Player LEDs
  -----------------------------------------------------------
  u_led : entity work.led_ctrl
    port map (
      clk       => clk_100mhz,
      reset     => reset_sync,
      ms_tick   => ms_tick,
      p1_status => p_status(0),
      p2_status => p_status(1),
      p3_status => p_status(2),
      p4_status => p_status(3),
      led       => led
    );

end structural;
