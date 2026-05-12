----------------------------------------------------------------------------
-- display_ctrl.vhd
-- Drives the 8-digit multiplexed 7-segment display on the Nexys A7.
-- Refreshes one digit per ms_tick (~8 ms full cycle).
--
-- Digit map (left to right):
--   7: seconds (dp on)   6: tenths   5: hundredths
--   4: P1 meters   3: P2   2: P3   1: P4   (E=elim, -=win)
--   0: iteration number (1-9, A=10, 0=not started)
--
----------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.game_pkg.all;

entity display_ctrl is
  port (
    clk        : in  std_logic;
    reset      : in  std_logic;
    ms_tick    : in  std_logic;
    time_left  : in  unsigned(12 downto 0);         -- timer value in ms
    p1_dist    : in  unsigned(13 downto 0);
    p2_dist    : in  unsigned(13 downto 0);
    p3_dist    : in  unsigned(13 downto 0);
    p4_dist    : in  unsigned(13 downto 0);
    p1_status  : in  std_logic_vector(1 downto 0);
    p2_status  : in  std_logic_vector(1 downto 0);
    p3_status  : in  std_logic_vector(1 downto 0);
    p4_status  : in  std_logic_vector(1 downto 0);
    iter_count : in  unsigned(3 downto 0);
    seg        : out std_logic_vector(6 downto 0);  -- cathodes (active low)
    dp         : out std_logic;                      -- decimal point (active low)
    an         : out std_logic_vector(7 downto 0)    -- anodes (active low)
  );
end display_ctrl;

architecture rtl of display_ctrl is

  -- Digit refresh counter (cycles 0..7, advances each ms_tick)
  signal digit_sel : unsigned(2 downto 0) := (others => '0');

  -- Timer BCD digits (combinational extraction)
  signal t_seconds    : unsigned(3 downto 0);
  signal t_tenths     : unsigned(3 downto 0);
  signal t_hundredths : unsigned(3 downto 0);

  -- Intermediate for timer digit extraction
  signal time_div10   : unsigned(12 downto 0);
  signal time_div100  : unsigned(12 downto 0);
  signal time_div1000 : unsigned(12 downto 0);

  -- Player meter digits (combinational)
  signal p1_digit : std_logic_vector(6 downto 0);
  signal p2_digit : std_logic_vector(6 downto 0);
  signal p3_digit : std_logic_vector(6 downto 0);
  signal p4_digit : std_logic_vector(6 downto 0);

  -- Iteration digit
  signal iter_digit : std_logic_vector(6 downto 0);

  -- Currently active segment pattern
  signal seg_out : std_logic_vector(6 downto 0);
  signal dp_out  : std_logic;

  -- BCD digit -> active-low segment pattern
  function digit_to_seg(d : unsigned(3 downto 0)) return std_logic_vector is
  begin
    case to_integer(d) is
      when 0      => return SEG_0;
      when 1      => return SEG_1;
      when 2      => return SEG_2;
      when 3      => return SEG_3;
      when 4      => return SEG_4;
      when 5      => return SEG_5;
      when 6      => return SEG_6;
      when 7      => return SEG_7;
      when 8      => return SEG_8;
      when 9      => return SEG_9;
      when 10     => return SEG_A;
      when others => return SEG_DASH;
    end case;
  end function;

  -- Show E if eliminated, dash if winner, otherwise whole meters 0-9
  function player_seg(stat : std_logic_vector(1 downto 0);
                      dist : unsigned(13 downto 0))
    return std_logic_vector is
    variable meters : integer;
  begin
    if stat = ST_ELIMINATED then
      return SEG_E;
    elsif stat = ST_WINNER then
      return SEG_DASH;
    else
      -- Extract whole meters: dist / 1000
      meters := to_integer(dist) / 1000;
      if meters > 9 then
        return SEG_A;  -- fallback for distances >= 10 m when status is not WINNER
      else
        return digit_to_seg(to_unsigned(meters, 4));
      end if;
    end if;
  end function;

begin

  -------------------------------------------------------
  -- Pull seconds/tenths/hundredths out of the ms value.
  -- Integer division by constant powers of 10; the
  -- synth tool handles this fine.
  -------------------------------------------------------
  process(time_left)
    variable t_int : integer;
  begin
    t_int := to_integer(time_left);
    t_seconds    <= to_unsigned((t_int / 1000) mod 10, 4);
    t_tenths     <= to_unsigned((t_int / 100) mod 10, 4);
    t_hundredths <= to_unsigned((t_int / 10) mod 10, 4);
  end process;

  -------------------------------------------------------
  -- Player digit computation (combinational)
  -------------------------------------------------------
  p1_digit <= player_seg(p1_status, p1_dist);
  p2_digit <= player_seg(p2_status, p2_dist);
  p3_digit <= player_seg(p3_status, p3_dist);
  p4_digit <= player_seg(p4_status, p4_dist);

  -------------------------------------------------------
  -- Iteration digit (combinational)
  -------------------------------------------------------
  iter_digit <= digit_to_seg(iter_count);

  -------------------------------------------------------
  -- Digit refresh counter
  -------------------------------------------------------
  process(clk)
  begin
    if rising_edge(clk) then
      if reset = '1' then
        digit_sel <= (others => '0');
      elsif ms_tick = '1' then
        digit_sel <= digit_sel + 1;  -- wraps 0..7
      end if;
    end if;
  end process;

  -------------------------------------------------------
  -- Mux: pick the right digit and light its anode
  -------------------------------------------------------
  process(digit_sel, t_seconds, t_tenths, t_hundredths,
          p1_digit, p2_digit, p3_digit, p4_digit, iter_digit)
  begin
    -- Defaults
    an     <= (others => '1');  -- all anodes OFF
    seg_out <= SEG_OFF;
    dp_out  <= '1';            -- decimal point OFF (active low)

    case to_integer(digit_sel) is
      when 7 =>
        -- Timer: seconds digit (with decimal point)
        an(7)   <= '0';
        seg_out <= digit_to_seg(t_seconds);
        dp_out  <= '0';  -- decimal point ON

      when 6 =>
        -- Timer: tenths digit
        an(6)   <= '0';
        seg_out <= digit_to_seg(t_tenths);

      when 5 =>
        -- Timer: hundredths digit
        an(5)   <= '0';
        seg_out <= digit_to_seg(t_hundredths);

      when 4 =>
        -- Player 1 distance (whole meters)
        an(4)   <= '0';
        seg_out <= p1_digit;

      when 3 =>
        -- Player 2 distance
        an(3)   <= '0';
        seg_out <= p2_digit;

      when 2 =>
        -- Player 3 distance
        an(2)   <= '0';
        seg_out <= p3_digit;

      when 1 =>
        -- Player 4 distance
        an(1)   <= '0';
        seg_out <= p4_digit;

      when 0 =>
        -- Iteration number
        an(0)   <= '0';
        seg_out <= iter_digit;

      when others =>
        null;
    end case;
  end process;

  seg <= seg_out;
  dp  <= dp_out;

end rtl;
