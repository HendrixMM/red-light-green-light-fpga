----------------------------------------------------------------------------
-- input_sync.vhd
-- Synchronizes raw I/O (2-stage chain on everything), debounces the start
-- button with a 20 ms counter, and outputs a single-cycle rising-edge pulse.
----------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.game_pkg.all;

entity input_sync is
  port (
    clk       : in  std_logic;
    ms_tick   : in  std_logic;
    btn_raw   : in  std_logic;                     -- raw from board
    rst_raw   : in  std_logic;
    sw_raw    : in  std_logic_vector(3 downto 0);
    btn_pulse : out std_logic;                     -- single-cycle rising edge, debounced
    reset_out : out std_logic;                     -- synchronized reset
    sw_sync   : out std_logic_vector(3 downto 0)   -- synchronized switches
  );
end input_sync;

architecture rtl of input_sync is

  -- 2-stage synchronizer registers
  signal btn_s1, btn_s2       : std_logic := '0';
  signal rst_s1, rst_s2       : std_logic := '0';
  signal sw_s1, sw_s2         : std_logic_vector(3 downto 0) := (others => '0');

  -- Debouncer for start button
  signal btn_candidate        : std_logic := '0';
  signal stable_count         : unsigned(4 downto 0) := (others => '0');
  signal btn_db               : std_logic := '0';
  signal btn_prev             : std_logic := '0';

begin

  -------------------------------------------------------
  -- 2-stage synchronizer chain (all inputs)
  -------------------------------------------------------
  process(clk)
  begin
    if rising_edge(clk) then
      btn_s1 <= btn_raw;
      btn_s2 <= btn_s1;
      rst_s1 <= rst_raw;
      rst_s2 <= rst_s1;
      sw_s1  <= sw_raw;
      sw_s2  <= sw_s1;
    end if;
  end process;

  -- Switches and reset just need the synchronized level, no debounce
  sw_sync   <= sw_s2;
  reset_out <= rst_s2;

  -------------------------------------------------------
  -- Counter-based debouncer for start button
  -------------------------------------------------------
  process(clk)
  begin
    if rising_edge(clk) then
      if rst_s2 = '1' then
        btn_candidate <= '0';
        stable_count  <= (others => '0');
        btn_db        <= '0';
      elsif btn_s2 /= btn_candidate then
        -- Input changed: restart stability counter
        btn_candidate <= btn_s2;
        stable_count  <= (others => '0');
      elsif ms_tick = '1' then
        if stable_count = to_unsigned(DEBOUNCE_MS, 5) then
          -- Stable for 20 ms: latch debounced value
          btn_db <= btn_candidate;
        else
          stable_count <= stable_count + 1;
        end if;
      end if;
    end if;
  end process;

  -------------------------------------------------------
  -- Rising edge detector on debounced button
  -------------------------------------------------------
  process(clk)
  begin
    if rising_edge(clk) then
      if rst_s2 = '1' then
        btn_prev <= '0';
      else
        btn_prev <= btn_db;
      end if;
    end if;
  end process;

  btn_pulse <= '1' when (btn_db = '1' and btn_prev = '0') else '0';

end rtl;
