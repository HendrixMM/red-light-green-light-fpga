----------------------------------------------------------------------------
-- game_pkg.vhd
-- All the constants and types shared across the project live here.
----------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package game_pkg is

  -- FSM state type
  type state_type is (IDLE, LOAD, GREEN, GAME_OVER);

  -- Player status encoding
  constant ST_ACTIVE     : std_logic_vector(1 downto 0) := "00";
  constant ST_ELIMINATED : std_logic_vector(1 downto 0) := "01";
  constant ST_WINNER     : std_logic_vector(1 downto 0) := "10";

  -- System constants
  constant CLK_FREQ       : integer := 100_000_000;  -- 100 MHz
  constant MS_COUNT_MAX   : integer := 99_999;        -- counts 0..99999 for 1 ms
  constant SIM_MS_COUNT   : integer := 9;             -- counts 0..9 for fast simulation
  constant FINISH_LINE_MM : unsigned(13 downto 0) := to_unsigned(10000, 14);
  constant MAX_ITERATIONS : unsigned(3 downto 0)  := to_unsigned(10, 4);

  -- Debounce threshold in ms ticks
  constant DEBOUNCE_MS : integer := 20;

  -- Blink half-period in ms ticks (200 ms -> 2.5 Hz blink)
  constant BLINK_MS : integer := 200;

  -- 7-segment display character codes (active-low cathodes)
  --                                        gfedcba
  constant SEG_0 : std_logic_vector(6 downto 0) := "1000000";
  constant SEG_1 : std_logic_vector(6 downto 0) := "1111001";
  constant SEG_2 : std_logic_vector(6 downto 0) := "0100100";
  constant SEG_3 : std_logic_vector(6 downto 0) := "0110000";
  constant SEG_4 : std_logic_vector(6 downto 0) := "0011001";
  constant SEG_5 : std_logic_vector(6 downto 0) := "0010010";
  constant SEG_6 : std_logic_vector(6 downto 0) := "0000010";
  constant SEG_7 : std_logic_vector(6 downto 0) := "1111000";
  constant SEG_8 : std_logic_vector(6 downto 0) := "0000000";
  constant SEG_9 : std_logic_vector(6 downto 0) := "0010000";
  constant SEG_A : std_logic_vector(6 downto 0) := "0001000";  -- for 10
  constant SEG_E : std_logic_vector(6 downto 0) := "0000110";  -- Eliminated
  constant SEG_DASH : std_logic_vector(6 downto 0) := "0111111"; -- winner dash
  constant SEG_OFF  : std_logic_vector(6 downto 0) := "1111111"; -- blank

end package game_pkg;
