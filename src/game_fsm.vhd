----------------------------------------------------------------------------
-- game_fsm.vhd
-- Four-state control FSM: IDLE (Red Light wait), LOAD (one clock for the
-- timer to grab its ROM value), GREEN (count down), GAME_OVER (done).
----------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.game_pkg.all;

entity game_fsm is
  port (
    clk            : in  std_logic;
    reset          : in  std_logic;
    btn_pulse      : in  std_logic;
    timer_done     : in  std_logic;
    all_eliminated : in  std_logic;
    winner_exists  : in  std_logic;
    game_state     : out state_type;             -- broadcast to player modules
    timer_load     : out std_logic;              -- one-cycle pulse in LOAD
    timer_en       : out std_logic;              -- high during GREEN
    iter_num       : out unsigned(3 downto 0);   -- indexes the timer ROM
    current_iter   : out unsigned(3 downto 0)    -- for display
  );
end game_fsm;

architecture rtl of game_fsm is
  signal state      : state_type := IDLE;
  signal iter_count : unsigned(3 downto 0) := (others => '0');
begin

  process(clk)
  begin
    if rising_edge(clk) then
      if reset = '1' then
        state      <= IDLE;
        iter_count <= (others => '0');

      else
        case state is

          when IDLE =>
            -- Check end conditions first
            if winner_exists = '1' or all_eliminated = '1' then
              state <= GAME_OVER;
            elsif iter_count = MAX_ITERATIONS then
              -- All 10 iterations completed, no winner
              state <= GAME_OVER;
            elsif btn_pulse = '1' then
              -- Start next iteration
              iter_count <= iter_count + 1;
              state      <= LOAD;
            end if;

          when LOAD =>
            -- One-cycle pause so iter_timer can latch its ROM value
            state <= GREEN;

          when GREEN =>
            -- Check for winner or all eliminated during green
            if winner_exists = '1' or all_eliminated = '1' then
              state <= GAME_OVER;
            elsif timer_done = '1' then
              state <= IDLE;
            end if;

          when GAME_OVER =>
            -- Terminal state, only reset exits
            null;

        end case;
      end if;
    end if;
  end process;

  timer_load <= '1' when state = LOAD  else '0';
  timer_en   <= '1' when state = GREEN else '0';
  game_state <= state;
  iter_num   <= iter_count;
  current_iter <= iter_count;

end rtl;
