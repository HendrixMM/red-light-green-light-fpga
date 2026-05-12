----------------------------------------------------------------------------
-- led_ctrl.vhd
-- Drives the four player LEDs: steady on if active, off if eliminated,
-- blinking (~2.5 Hz) if winner.
----------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.game_pkg.all;

entity led_ctrl is
  port (
    clk       : in  std_logic;
    reset     : in  std_logic;
    ms_tick   : in  std_logic;
    p1_status : in  std_logic_vector(1 downto 0);
    p2_status : in  std_logic_vector(1 downto 0);
    p3_status : in  std_logic_vector(1 downto 0);
    p4_status : in  std_logic_vector(1 downto 0);
    led       : out std_logic_vector(3 downto 0)
  );
end led_ctrl;

architecture rtl of led_ctrl is
  signal blink_count  : unsigned(7 downto 0) := (others => '0');
  signal blink_toggle : std_logic := '0';

  function status_to_led(stat : std_logic_vector(1 downto 0);
                         blink : std_logic) return std_logic is
  begin
    if stat = ST_ACTIVE then
      return '1';          -- steady ON
    elsif stat = ST_WINNER then
      return blink;        -- blinking
    else
      return '0';          -- OFF (eliminated or unknown)
    end if;
  end function;

begin

  -------------------------------------------------------
  -- Blink generator: toggle every 200 ms (2.5 Hz)
  -------------------------------------------------------
  process(clk)
  begin
    if rising_edge(clk) then
      if reset = '1' then
        blink_count  <= (others => '0');
        blink_toggle <= '0';
      elsif ms_tick = '1' then
        if blink_count = to_unsigned(BLINK_MS - 1, 8) then
          blink_count  <= (others => '0');
          blink_toggle <= not blink_toggle;
        else
          blink_count <= blink_count + 1;
        end if;
      end if;
    end if;
  end process;

  -------------------------------------------------------
  -- LED output logic (active-high LEDs on Nexys A7)
  -------------------------------------------------------
  led(0) <= status_to_led(p1_status, blink_toggle);
  led(1) <= status_to_led(p2_status, blink_toggle);
  led(2) <= status_to_led(p3_status, blink_toggle);
  led(3) <= status_to_led(p4_status, blink_toggle);

end rtl;
