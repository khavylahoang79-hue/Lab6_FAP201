-- Git account : <La Hoang Kha Vy>
-- Author      : La Hoang Kha Vy (CE210538)
-- Purpose     : Lab06 - Memory Game (FSM, LFSR Pseudo-Random Generator, Key Debounce & 74HC595).
-- Top entity for Gowin: lab06_top_74hc595
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

--------------------------------------------------------------------------
-- 1) key_conditioner: sync + debounce, gives exactly ONE pulse per press
--------------------------------------------------------------------------
entity key_conditioner is
  generic (G_STABLE_CYCLES : positive := 1000000); 
  port (
    clk_i            : in  std_logic;
    rst_i            : in  std_logic;
    raw_pressed_i    : in  std_logic;   
    press_pulse_o    : out std_logic;   
    stable_pressed_o : out std_logic   
  );
end entity;

architecture rtl of key_conditioner is
  signal meta, sync   : std_logic := '0';   
  signal stable       : std_logic := '0';   
  signal pulse        : std_logic := '0';
  signal counter      : natural range 0 to G_STABLE_CYCLES - 1 := 0;
begin
  stable_pressed_o <= stable;
  press_pulse_o    <= pulse;

  process (clk_i)
  begin
    if rising_edge(clk_i) then
      meta  <= raw_pressed_i;
      sync  <= meta;
      pulse <= '0';

      if sync = stable then                     
        counter <= 0;
      elsif counter = G_STABLE_CYCLES - 1 then   
        counter <= 0;
        stable  <= sync;
        pulse   <= sync;                         
      else
        counter <= counter + 1;
      end if;

      if rst_i = '1' then
        meta <= '0'; sync <= '0'; stable <= '0'; pulse <= '0'; counter <= 0;
      end if;
    end if;
  end process;
end architecture;

--------------------------------------------------------------------------
-- 2) lab06_game: the game FSM
--------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity lab06_game is
  generic (
    G_OFF_TICKS  : positive := 15000000;  
    G_SHOW_TICKS : positive := 20000000   
  );
  port (
    clk_i       : in  std_logic;
    rst_i       : in  std_logic;                      
    start_i     : in  std_logic;                      
    press_i     : in  std_logic_vector(2 downto 0);   
    leds_o      : out std_logic_vector(2 downto 0);
    score_o     : out std_logic_vector(3 downto 0);   
    status_o    : out std_logic_vector(1 downto 0);   
    state_o     : out std_logic_vector(2 downto 0);   
    show_idx_o  : out std_logic_vector(2 downto 0);
    input_idx_o : out std_logic_vector(2 downto 0)
  );
end entity;

architecture rtl of lab06_game is
  type state_t   is (IDLE, PATTERN_OFF, PATTERN_SHOW, WAIT_PLAYER, WIN, LOSE);
  type pattern_t is array (0 to 6) of std_logic_vector(2 downto 0);

  signal state     : state_t := IDLE;
  signal pattern   : pattern_t := (others => "001");  
  signal count     : natural range 0 to G_OFF_TICKS + G_SHOW_TICKS := 0;
  signal round_len : integer range 1 to 7 := 1;       
  signal show_idx  : integer range 0 to 6 := 0;      
  signal input_idx : integer range 0 to 6 := 0;       
  signal seed      : unsigned(7 downto 0) := x"5A";   
  signal first_sym : std_logic_vector(2 downto 0) := "001";  

 
  function lfsr_step(v : unsigned(7 downto 0)) return unsigned is
    variable n : unsigned(7 downto 0);
  begin
    n := v(6 downto 0) & (v(7) xor v(5) xor v(4) xor v(3));
    if n = 0 then n := x"5A"; end if;
    return n;
  end function;

    
  function bits_to_onehot(b : unsigned(1 downto 0)) return std_logic_vector is
  begin
    if    b = "00" then return "001";
    elsif b = "01" then return "010";
    else                return "100";
    end if;
  end function;
begin

  leds_o      <= pattern(show_idx) when state = PATTERN_SHOW else "000";
  score_o     <= std_logic_vector(to_unsigned(round_len, 4));
  status_o    <= "10" when state = WIN else
                 "01" when state = LOSE else "00";
  state_o     <= "000" when state = IDLE         else
                 "001" when state = PATTERN_OFF  else
                 "010" when state = PATTERN_SHOW else
                 "011" when state = WAIT_PLAYER  else
                 "100" when state = WIN          else "101";
  show_idx_o  <= std_logic_vector(to_unsigned(show_idx, 3));
  input_idx_o <= std_logic_vector(to_unsigned(input_idx, 3));

  process (clk_i)
    variable s     : unsigned(7 downto 0);
    variable first : std_logic_vector(2 downto 0);
  begin
    if rising_edge(clk_i) then
      case state is

       
        when IDLE | WIN | LOSE =>
          if start_i = '1' then
            first := first_sym;
            if state /= IDLE then                     
              first := first(1 downto 0) & first(2);
            end if;
            first_sym  <= first;
            pattern(0) <= first;
            s := seed;
            for i in 1 to 6 loop                       
              s := lfsr_step(s);
              pattern(i) <= bits_to_onehot(s(1 downto 0));
            end loop;
            seed      <= s;
            round_len <= 1;
            show_idx  <= 0;
            input_idx <= 0;
            count     <= 0;
            state     <= PATTERN_OFF;
          end if;

     
        when PATTERN_OFF =>
          if count = G_OFF_TICKS - 1 then
            count <= 0;
            state <= PATTERN_SHOW;
          else
            count <= count + 1;
          end if;

        
        when PATTERN_SHOW =>
          if count = G_SHOW_TICKS - 1 then
            count <= 0;
            if show_idx = round_len - 1 then          
              show_idx <= 0;
              state    <= WAIT_PLAYER;
            else
              show_idx <= show_idx + 1;
              state    <= PATTERN_OFF;
            end if;
          else
            count <= count + 1;
          end if;

      
        when WAIT_PLAYER =>
          if press_i /= "000" then
            if press_i /= pattern(input_idx) then      
              state <= LOSE;
            elsif input_idx < round_len - 1 then       
              input_idx <= input_idx + 1;
            elsif round_len = 7 then                   
              state <= WIN;
            else                                      
              round_len <= round_len + 1;
              input_idx <= 0;
              state     <= PATTERN_OFF;
            end if;
          end if;

      end case;

      if rst_i = '1' then
        state     <= IDLE;
        count     <= 0;
        round_len <= 1;
        show_idx  <= 0;
        input_idx <= 0;
        seed      <= x"5A";
        first_sym <= "001";
      end if;
    end if;
  end process;
end architecture;

--------------------------------------------------------------------------
-- 3) sevenseg_74hc595: send score / F / A to the 2x 74HC595 (3 wires)
--    Sends 16 bits MSB first: {8-bit segment, 8-bit digit select}
--    All digits show the same character.
--    If the display is wrong, try G_SEG_REVERSE / G_SEG_ACTIVE_LOW / G_SEL_ACTIVE_HIGH.
--------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity sevenseg_74hc595 is
  generic (
    G_SEG_ACTIVE_LOW  : boolean  := true;
    G_SEL_ACTIVE_HIGH : boolean  := true;
    G_SEG_REVERSE     : boolean  := false;
    G_DIV_TICKS       : positive := 4;       
    G_REFRESH_TICKS   : positive := 50000    
  );
  port (
    clk_i    : in  std_logic;
    score_i  : in  std_logic_vector(3 downto 0); 
    status_i : in  std_logic_vector(1 downto 0);  
    ds_o     : out std_logic;                     
    shcp_o   : out std_logic;                     
    stcp_o   : out std_logic                      
  );
end entity;

architecture rtl of sevenseg_74hc595 is
  type phase_t is (LOAD, SH_HIGH, SH_LOW, LATCH_HIGH, LATCH_LOW, REFRESH);
  signal phase  : phase_t := LOAD;
  signal sh     : std_logic_vector(15 downto 0) := (others => '1');  
  signal bit_n  : integer range 0 to 15 := 0;
  signal div    : natural range 0 to G_DIV_TICKS - 1 := 0;
  signal wait_n : natural range 0 to G_REFRESH_TICKS - 1 := 0;
  signal shcp, stcp : std_logic := '0';

  
  function seg_code(v : std_logic_vector(3 downto 0);
                    s : std_logic_vector(1 downto 0)) return std_logic_vector is
  begin
    if    s = "01" then return x"8E";   
    elsif s = "10" then return x"88";   
    end if;
    case v is
      when "0001" => return x"F9";      
      when "0010" => return x"A4";      
      when "0011" => return x"B0";     
      when "0100" => return x"99";      
      when "0101" => return x"92";      
      when "0110" => return x"82";     
      when "0111" => return x"F8";     
      when others => return x"FF";      
    end case;
  end function;

  function rev8(x : std_logic_vector(7 downto 0)) return std_logic_vector is
    variable r : std_logic_vector(7 downto 0);
  begin
    for i in 0 to 7 loop r(i) := x(7 - i); end loop;
    return r;
  end function;
begin
  ds_o   <= sh(15);   
  shcp_o <= shcp;
  stcp_o <= stcp;

  process (clk_i)
    variable seg : std_logic_vector(7 downto 0);
    variable sel : std_logic_vector(7 downto 0);
  begin
    if rising_edge(clk_i) then
      if div /= G_DIV_TICKS - 1 then
        div <= div + 1;
      else
        div <= 0;
        case phase is
          when LOAD =>                                   
            seg := seg_code(score_i, status_i);
            if not G_SEG_ACTIVE_LOW then seg := not seg; end if;
            if G_SEG_REVERSE        then seg := rev8(seg); end if;
            if G_SEL_ACTIVE_HIGH then sel := x"FF"; else sel := x"00"; end if;
            sh     <= seg & sel;
            bit_n  <= 0;
            phase  <= SH_HIGH;
          when SH_HIGH =>                               
            shcp  <= '1';
            phase <= SH_LOW;
          when SH_LOW =>                                
            shcp <= '0';
            sh   <= sh(14 downto 0) & '0';
            if bit_n = 15 then
              phase <= LATCH_HIGH;
            else
              bit_n <= bit_n + 1;
              phase <= SH_HIGH;
            end if;
          when LATCH_HIGH =>                            
            stcp  <= '1';
            phase <= LATCH_LOW;
          when LATCH_LOW =>
            stcp   <= '0';
            wait_n <= 0;
            phase  <= REFRESH;
          when REFRESH =>                                
            if wait_n = G_REFRESH_TICKS - 1 then
              phase <= LOAD;
            else
              wait_n <= wait_n + 1;
            end if;
        end case;
      end if;
    end if;
  end process;
end architecture;

--------------------------------------------------------------------------
-- 4) lab06_top_74hc595: board top (keys + LEDs + 7-segment)
--------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;

entity lab06_top_74hc595 is
  generic (
    G_KEYS_ACTIVE_LOW : boolean  := true;
    G_LEDS_ACTIVE_LOW : boolean  := false;
    G_STABLE_CYCLES   : positive := 1000000;
    G_OFF_TICKS       : positive := 15000000;
    G_SHOW_TICKS      : positive := 20000000;
    G_SEG_ACTIVE_LOW  : boolean  := true;
    G_SEL_ACTIVE_HIGH : boolean  := true;
    G_SEG_REVERSE     : boolean  := false
  );
  port (
    clk_50m_i  : in  std_logic;
    key_raw_i  : in  std_logic_vector(2 downto 0);
    led_pin_o  : out std_logic_vector(2 downto 0);
    seg_ds_o   : out std_logic;
    seg_shcp_o : out std_logic;
    seg_stcp_o : out std_logic
  );
end entity;

architecture rtl of lab06_top_74hc595 is
  signal pressed, pulse, leds : std_logic_vector(2 downto 0);
  signal score  : std_logic_vector(3 downto 0);
  signal status : std_logic_vector(1 downto 0);
  signal powerup_start : std_logic := '1';   
  signal start_pulse   : std_logic;
begin
  pressed   <= not key_raw_i when G_KEYS_ACTIVE_LOW else key_raw_i;
  led_pin_o <= not leds      when G_LEDS_ACTIVE_LOW else leds;

  gen_keys : for i in 0 to 2 generate
    u_key : entity work.key_conditioner(rtl)
      generic map (G_STABLE_CYCLES => G_STABLE_CYCLES)
      port map (clk_i => clk_50m_i, rst_i => '0',
                raw_pressed_i => pressed(i), press_pulse_o => pulse(i),
                stable_pressed_o => open);
  end generate;


  process (clk_50m_i)
  begin
    if rising_edge(clk_50m_i) then powerup_start <= '0'; end if;
  end process;

 
  start_pulse <= powerup_start or (pulse(0) and (status(0) or status(1)));

  u_game : entity work.lab06_game(rtl)
    generic map (G_OFF_TICKS => G_OFF_TICKS, G_SHOW_TICKS => G_SHOW_TICKS)
    port map (clk_i => clk_50m_i, rst_i => '0', start_i => start_pulse,
              press_i => pulse, leds_o => leds, score_o => score, status_o => status,
              state_o => open, show_idx_o => open, input_idx_o => open);

  u_display : entity work.sevenseg_74hc595(rtl)
    generic map (G_SEG_ACTIVE_LOW => G_SEG_ACTIVE_LOW,
                 G_SEL_ACTIVE_HIGH => G_SEL_ACTIVE_HIGH,
                 G_SEG_REVERSE => G_SEG_REVERSE)
    port map (clk_i => clk_50m_i, score_i => score, status_i => status,
              ds_o => seg_ds_o, shcp_o => seg_shcp_o, stcp_o => seg_stcp_o);
end architecture;