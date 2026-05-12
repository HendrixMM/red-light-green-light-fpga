----------------------------------------------------------------------------
-- player_module.vhd
-- One player's status and distance register. Instantiated four times
-- via generate in rlgl_top. Freezes once the player leaves ST_ACTIVE.
----------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.game_pkg.all;

entity player_module is
  port (
    clk        : in  std_logic;
    reset      : in  std_logic;
    ms_tick    : in  std_logic;
    sw         : in  std_logic;                     -- this player's switch
    game_state : in  state_type;                    -- from FSM
    status     : out std_logic_vector(1 downto 0);  -- ACTIVE/ELIMINATED/WINNER
    distance   : out unsigned(13 downto 0)          -- 0..12000 mm
  );
end player_module;

architecture rtl of player_module is
  signal status_reg : std_logic_vector(1 downto 0) := ST_ACTIVE;
  signal dist_reg   : unsigned(13 downto 0) := (others => '0');
begin

  process(clk)
  begin
    if rising_edge(clk) then
      if reset = '1' then
        status_reg <= ST_ACTIVE;
        dist_reg   <= (others => '0');

      elsif status_reg = ST_ACTIVE then

        case game_state is

          when IDLE =>
            -- Red Light: switch up = eliminated
            if sw = '1' then
              status_reg <= ST_ELIMINATED;
            end if;

          when GREEN =>
            -- Green Light: +1 mm per ms_tick while switch is up
            if sw = '1' and ms_tick = '1' then
              if dist_reg + 1 >= FINISH_LINE_MM then
                dist_reg   <= FINISH_LINE_MM;
                status_reg <= ST_WINNER;
              else
                dist_reg <= dist_reg + 1;
              end if;
            end if;

          when LOAD =>
            null;

          when GAME_OVER =>
            null;

        end case;

      end if;
    end if;
  end process;

  status   <= status_reg;
  distance <= dist_reg;

end rtl;
