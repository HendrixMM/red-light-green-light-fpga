----------------------------------------------------------------------------
-- iter_timer.vhd
-- 10-entry ROM with nominal durations and 10% max offsets, an 8-bit LFSR
-- for optional randomness, and a 13-bit down-counter. ENABLE_RANDOM gates
-- the LFSR path; when false the counter just loads the nominal value.
----------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.game_pkg.all;

entity iter_timer is
  generic (
    ENABLE_RANDOM : boolean := true
  );
  port (
    clk        : in  std_logic;
    reset      : in  std_logic;
    ms_tick    : in  std_logic;
    load       : in  std_logic;          -- asserted during LOAD state
    timer_en   : in  std_logic;          -- asserted during GREEN state
    iter_num   : in  unsigned(3 downto 0);  -- 1..10
    time_left  : out unsigned(12 downto 0); -- current counter value
    timer_done : out std_logic              -- asserted when counter = 0
  );
end iter_timer;

architecture rtl of iter_timer is

  -- ROM outputs
  signal nominal    : unsigned(12 downto 0);
  signal max_offset : unsigned(9 downto 0);

  -- LFSR
  signal lfsr_reg   : unsigned(7 downto 0) := "10110100";  -- non-zero seed
  signal feedback   : std_logic;

  -- Offset calculation
  signal product      : unsigned(17 downto 0);   -- 8-bit * 10-bit = 18-bit
  signal scaled       : unsigned(10 downto 0);   -- product >> 7
  signal load_value   : unsigned(12 downto 0);   -- final value to load

  -- Down-counter
  signal counter : unsigned(12 downto 0) := (others => '0');

begin

  -------------------------------------------------------
  -- Duration ROM (combinational)
  -- Column 1: nominal duration in ms (truncated)
  -- Column 2: max offset = 10% of nominal (truncated)
  -------------------------------------------------------
  process(iter_num)
  begin
    case to_integer(iter_num) is
      when 1      => nominal <= to_unsigned(6000, 13); max_offset <= to_unsigned(600, 10);
      when 2      => nominal <= to_unsigned(4500, 13); max_offset <= to_unsigned(450, 10);
      when 3      => nominal <= to_unsigned(3375, 13); max_offset <= to_unsigned(337, 10);
      when 4      => nominal <= to_unsigned(2531, 13); max_offset <= to_unsigned(253, 10);
      when 5      => nominal <= to_unsigned(1898, 13); max_offset <= to_unsigned(189, 10);
      when 6      => nominal <= to_unsigned(1423, 13); max_offset <= to_unsigned(142, 10);
      when 7      => nominal <= to_unsigned(1067, 13); max_offset <= to_unsigned(106, 10);
      when 8      => nominal <= to_unsigned(800,  13); max_offset <= to_unsigned(80,  10);
      when 9      => nominal <= to_unsigned(600,  13); max_offset <= to_unsigned(60,  10);
      when 10     => nominal <= to_unsigned(450,  13); max_offset <= to_unsigned(45,  10);
      when others => nominal <= to_unsigned(6000, 13); max_offset <= to_unsigned(600, 10);
    end case;
  end process;

  -------------------------------------------------------
  -- 8-bit maximal-length LFSR (free-running)
  -- Polynomial: x^8 + x^6 + x^5 + x^4 + 1
  -- Taps: bit 7, bit 5, bit 4, bit 3
  -------------------------------------------------------
  feedback <= lfsr_reg(7) xor lfsr_reg(5) xor lfsr_reg(4) xor lfsr_reg(3);

  process(clk)
  begin
    if rising_edge(clk) then
      if reset = '1' then
        lfsr_reg <= "10110100";  -- non-zero seed
      else
        lfsr_reg <= lfsr_reg(6 downto 0) & feedback;
      end if;
    end if;
  end process;

  -------------------------------------------------------
  -- Offset calculator (combinational)
  -- Maps LFSR 0..255 to offset in [-max_offset, +max_offset]
  --   product = lfsr_val * max_offset      (18 bits)
  --   scaled  = product / 128              (shift right 7)
  --   load_value = nominal - max_offset + scaled
  -- When LFSR=0:   load = nominal - max_offset  (minimum)
  -- When LFSR=128: load = nominal               (nominal)
  -- When LFSR=255: load ~ nominal + max_offset  (maximum)
  -------------------------------------------------------
  product <= lfsr_reg * max_offset;
  scaled  <= product(17 downto 7);  -- divide by 128

  gen_random: if ENABLE_RANDOM generate
    load_value <= nominal - resize(max_offset, 13) + resize(scaled, 13);
  end generate;

  gen_no_random: if not ENABLE_RANDOM generate
    load_value <= nominal;
  end generate;

  -------------------------------------------------------
  -- 13-bit down-counter
  -------------------------------------------------------
  process(clk)
  begin
    if rising_edge(clk) then
      if reset = '1' then
        counter <= (others => '0');
      elsif load = '1' then
        counter <= load_value;
      elsif ms_tick = '1' and timer_en = '1' then
        if counter /= 0 then
          counter <= counter - 1;
        end if;
      end if;
    end if;
  end process;

  -- Outputs
  time_left  <= counter;
  timer_done <= '1' when counter = 0 else '0';

end rtl;
