----------------------------------------------------------------------------
-- ms_prescaler.vhd
-- Counts 0 to 99,999 and fires a one-cycle ms_tick pulse, giving every
-- other module a common 1 ms time base. SIM_FAST swaps the terminal
-- count to 9 so simulation runs 10,000x faster.
----------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.game_pkg.all;

entity ms_prescaler is
  generic (
    SIM_FAST : boolean := false  -- true = fast simulation, false = real hardware
  );
  port (
    clk     : in  std_logic;
    reset   : in  std_logic;
    ms_tick : out std_logic
  );
end ms_prescaler;

architecture rtl of ms_prescaler is
  -- Pick the right terminal count at elaboration time
  function sel_terminal return integer is
  begin
    if SIM_FAST then return SIM_MS_COUNT;
    else             return MS_COUNT_MAX;
    end if;
  end function;

  constant TERMINAL : integer := sel_terminal;

  signal count : unsigned(16 downto 0) := (others => '0');  -- 17 bits for 0..99999
begin

  process(clk)
  begin
    if rising_edge(clk) then
      if reset = '1' then
        count   <= (others => '0');
        ms_tick <= '0';
      elsif count = to_unsigned(TERMINAL, 17) then
        count   <= (others => '0');
        ms_tick <= '1';
      else
        count   <= count + 1;
        ms_tick <= '0';
      end if;
    end if;
  end process;

end rtl;
