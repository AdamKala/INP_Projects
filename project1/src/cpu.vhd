-- cpu.vhd: Simple 8-bit CPU (BrainFuck interpreter)
-- Copyright (C) 2022 Brno University of Technology,
--                    Faculty of Information Technology
-- Author(s): jmeno <login AT stud.fit.vutbr.cz>
--
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

-- ----------------------------------------------------------------------------
--                        Entity declaration
-- ----------------------------------------------------------------------------
entity cpu is
 port (
   CLK   : in std_logic;  -- hodinovy signal
   RESET : in std_logic;  -- asynchronni reset procesoru
   EN    : in std_logic;  -- povoleni cinnosti procesoru
 
   -- synchronni pamet RAM
   DATA_ADDR  : out std_logic_vector(12 downto 0); -- adresa do pameti
   DATA_WDATA : out std_logic_vector(7 downto 0); -- mem[DATA_ADDR] <- DATA_WDATA pokud DATA_EN='1'
   DATA_RDATA : in std_logic_vector(7 downto 0);  -- DATA_RDATA <- ram[DATA_ADDR] pokud DATA_EN='1'
   DATA_RDWR  : out std_logic;                    -- cteni (0) / zapis (1)
   DATA_EN    : out std_logic;                    -- povoleni cinnosti
   
   -- vstupni port
   IN_DATA   : in std_logic_vector(7 downto 0);   -- IN_DATA <- stav klavesnice pokud IN_VLD='1' a IN_REQ='1'
   IN_VLD    : in std_logic;                      -- data platna
   IN_REQ    : out std_logic;                     -- pozadavek na vstup data
   
   -- vystupni port
   OUT_DATA : out  std_logic_vector(7 downto 0);  -- zapisovana data
   OUT_BUSY : in std_logic;                       -- LCD je zaneprazdnen (1), nelze zapisovat
   OUT_WE   : out std_logic                       -- LCD <- OUT_DATA pokud OUT_WE='1' a OUT_BUSY='0'
 );
end cpu;


-- ----------------------------------------------------------------------------
--                      Architecture declaration
-- ----------------------------------------------------------------------------
architecture behavioral of cpu is
  signal cnt: std_logic_vector (7 downto 0);
  signal cnt_inc: std_logic;
  signal cnt_dec: std_logic;

  signal pc: std_logic_vector (12 downto 0);
  signal pc_inc: std_logic;
  signal pc_dec: std_logic;

  signal pc_jump: std_logic; --pomocna hodnota pro do while
  
  signal ptr: std_logic_vector (12 downto 0);
  signal ptr_inc: std_logic;
  signal ptr_dec: std_logic;

  signal ptr_do: std_logic_vector(12 downto 0); --pomocna hodnota pro do while

  signal mx1: std_logic;

  signal mx2: std_logic_vector (1 downto 0);

type fsm_state is( --vsechny state automatu
  signal_start,
  signal_fetch,
  signal_decode,
  signal_ptr_inc,
  signal_ptr_dec,
  signal_value_inc,
  signal_value_inc2,
  signal_value_inc3,
  signal_value_dec,
  signal_value_dec2,
  signal_value_dec3,
  signal_print_char,
  signal_print_char2,
  signal_comma, 
  signal_comma2,
  signal_comma3,
  signal_while1,
  signal_while2,
  signal_while1_2,
  signal_while1_3,
  signal_while1_4,
  signal_while2_2,
  signal_while2_3,
  signal_while2_4,
  signal_while2_5,
  signal_do_while1,
  signal_do_while2,
  signal_do_while2_2,
  signal_null
);

signal actual_state: fsm_state;
signal next_state: fsm_state;

begin
-----pc process-----
pc_process: process(CLK, RESET, pc_inc, pc, pc_dec)
begin
  if(RESET = '1') then 
      pc <= (others => '0');
    elsif(CLK'event) and CLK = '1' then 
      if(pc_inc = '1') then
        pc <= pc + 1;
      elsif(pc_dec = '1') then 
        pc <= pc - 1;
      elsif(pc_jump = '1') then
        pc <= ptr_do;
      end if;
  end if;
end process;
-----cnt process-----
cnt_process: process(CLK, RESET, cnt, cnt_inc, cnt_dec)
begin
  if(RESET = '1') then
    cnt <= (others => '0');
  elsif (CLK'event) and CLK = '1' then
    if(cnt_inc = '1') then
      cnt <= cnt + 1;
    elsif(cnt_dec = '1') then
      cnt <= cnt - 1;
    end if;
  end if;
end process;
-----ptr process-----
ptr_process: process(CLK, RESET, ptr, ptr_inc, ptr_dec)
begin
  if(RESET = '1') then
    ptr <= "1000000000000";
  elsif(CLK'event) and CLK = '1' then
    if(ptr_inc = '1') then
      if ptr = "1111111111111" then
        ptr <= "1000000000000";
      else 
        ptr <= ptr + 1;
      end if;
    elsif(ptr_dec = '1') then
      if ptr = "1000000000000" then
        ptr <= "1111111111111";
      else 
        ptr <= ptr - 1;
      end if;
    end if;
  end if;
end process;
-----mx1 process-----
mx1_process: process(CLK, mx1)
begin
  if rising_edge(CLK) then
    case mx1 is
      when '0' => DATA_ADDR <= pc;
      when '1' => DATA_ADDR <= ptr;
      when others =>
    end case;
  end if;
end process;

-----mx2 process-----
mx2_process: process(CLK, IN_DATA, DATA_RDATA, mx2)
begin
  if rising_edge(CLK) then
    case mx2 is
      when "00" => DATA_WDATA <= IN_DATA;
      when "01" => DATA_WDATA <= DATA_RDATA - 1;
      when "10" => DATA_WDATA <= DATA_RDATA + 1;
      when "11" => DATA_WDATA <= DATA_RDATA;
      when others =>
    end case;
  end if;
end process;
-----aktualni state-----
actual: process (CLK, EN, RESET)
begin
    if RESET = '1' then 
      actual_state <= signal_start;
    elsif(CLK'event) and CLK = '1' then
      if EN = '1' then
        actual_state <= next_state;
      end if;
    end if;
end process;
-----fsm-----
fsm_astate: process(CLK, EN, RESET, DATA_RDATA)
begin

    pc_inc <= '0';
    pc_dec <= '0';
    cnt_inc <= '0';
    cnt_dec <= '0';
    ptr_inc <= '0';
    ptr_dec <= '0';
    OUT_WE <= '0';
    DATA_RDWR <= '0';
    DATA_EN <= '0';
    IN_REQ <= '0';
    pc_jump <= '0';
    ptr_do <= "0000000000000";
    mx2 <= "00";

    case actual_state is 
      when signal_start =>
        mx1 <= '0';
        next_state <= signal_fetch;

      when signal_fetch =>
        OUT_WE <= '0';
        DATA_EN <= '1';
        DATA_RDWR <= '0';
        next_state <= signal_decode;

      when signal_decode =>    
        case DATA_RDATA is
          when X"3E" => next_state <= signal_ptr_inc; -- >

          when X"3C" => next_state <= signal_ptr_dec; -- <

          when X"2B" => 
            mx1 <= '1';
            next_state <= signal_value_inc; -- +

          when X"2D" => 
            mx1 <= '1';
            next_state <= signal_value_dec; -- -

          when X"2E" => 
            mx1 <= '1';
            next_state <= signal_print_char; -- .

          when X"2C" => 
            mx1 <= '1';
            next_state <= signal_comma; -- ,

          when X"5B" => 
            mx1 <= '1';
            next_state <= signal_while1; -- [

          when X"5D" => 
            mx1 <= '1';
            next_state <= signal_while2; -- ]

          when X"28" => 
            mx1 <= '1';
            next_state <= signal_do_while1; -- (

          when X"29" => 
            mx1 <= '1';
            next_state <= signal_do_while2; -- )

          when X"00" => next_state <= signal_null; -- null

          when others => 
            pc_inc <= '1';
            next_state <= signal_start; -- znovu na start
        end case;
      ----- >
      when signal_ptr_inc =>
        ptr_inc <= '1';
        pc_inc <= '1';
        next_state <= signal_start;
      ----- <
      when signal_ptr_dec =>
        ptr_dec <= '1';
        pc_inc <= '1';
        next_state <= signal_start;
      ----- +
      when signal_value_inc =>
        DATA_EN <= '1';
        DATA_RDWR <= '0';
        next_state <= signal_value_inc2;

      when signal_value_inc2 =>
        mx2 <= "10"; --DATA_RDATA + 1
        next_state <= signal_value_inc3;

      when signal_value_inc3 =>
        DATA_EN <= '1';
        DATA_RDWR <= '1';
        pc_inc <= '1';
        next_state <= signal_start;
      ----- -
      when signal_value_dec =>
        DATA_EN <= '1';
        DATA_RDWR <= '0';
        next_state <= signal_value_dec2;

      when signal_value_dec2 =>
        mx2 <= "01"; --DATA_RDATA - 1
        next_state <= signal_value_dec3;

      when signal_value_dec3 =>
        DATA_EN <= '1';
        DATA_RDWR <= '1';
        pc_inc <= '1';
        next_state <= signal_start;
      ----- .
      when signal_print_char =>
        DATA_EN <= '1';
        DATA_RDWR <= '0';
        next_state <= signal_print_char2;

      when signal_print_char2 =>
        DATA_RDWR <= '1';
        if OUT_BUSY = '0' then --while(OUT_BUSY)
          OUT_WE <= '1';
          OUT_DATA <= DATA_RDATA;
          pc_inc <= '1';
          next_state <= signal_start;
        else 
          next_state <= signal_print_char;
        end if;
      ----- ,
      when signal_comma =>
        IN_REQ <= '1'; --IN_REQ <- 1
        mx2 <= "00";
        next_state <= signal_comma2;

      when signal_comma2 =>
        if IN_VLD = '1' then 
          IN_REQ <= '1'; --IN_REQ <- 1
          mx1 <= '1';
          mx2 <= "00";
          pc_inc <= '1';
          next_state <= signal_comma3;
        else 
          IN_REQ <= '1'; --IN_REQ <- 1
          next_state <= signal_comma;
        end if;

      when signal_comma3 =>
        DATA_EN <= '1'; 
        DATA_RDWR <= '1';
        next_state <= signal_start;
        
      ----- [
      when signal_while1 =>
        DATA_EN <= '1'; 
        DATA_RDWR <= '0';
        pc_inc <= '1'; -- PC <- PC + 1
        mx1 <= '1';
        next_state <= signal_while1_2;

      when signal_while1_2 =>
        if (DATA_RDATA = "00000000") then
          cnt_inc <= '1';
          mx1 <= '0';
          next_state <= signal_while1_3;
          DATA_EN <= '1';
        else 
          next_state <= signal_start;
        end if;
      
      when signal_while1_3 =>
        if cnt = "00000000" then
          pc_dec <= '1';
          next_state <= signal_start;
        else
          if DATA_RDATA = X"5B" then 
            cnt_inc <= '1';
          elsif DATA_RDATA = X"5D" then
            cnt_dec <= '1';
          elsif DATA_RDATA = X"28" then 
            cnt_inc <= '1';
          elsif DATA_RDATA = X"29" then
            cnt_dec <= '1';
          end if;
          next_state <= signal_while1_4;
          pc_inc <= '1';
        end if;
      
      when signal_while1_4 =>
        DATA_EN <= '1';
        next_state <= signal_while1_3;
          
      ---- ]
      when signal_while2 =>
        DATA_EN <= '1';
        DATA_RDWR <= '0';
        next_state <= signal_while2_2;

      when signal_while2_2 =>
        if (DATA_RDATA = "00000000") then
          pc_inc <= '1';
          next_state <= signal_start;
        else 
          pc_dec <= '1';
          cnt_inc <= '1';
          next_state <= signal_while2_3;
        end if;

      when signal_while2_3 =>
        if cnt = "00000000" then
          next_state <= signal_start;
        else 
          DATA_EN <= '1';
          mx1 <= '0';
          next_state <= signal_while2_4;
        end if;

      when signal_while2_4 =>
        if DATA_RDATA = X"5B" then 
          cnt_dec <= '1';
        elsif DATA_RDATA = X"5D" then
          cnt_inc <= '1';
        elsif DATA_RDATA = X"28" then
          cnt_inc <= '1';
        elsif DATA_RDATA = X"29" then
          cnt_dec <= '1';
        end if;
        next_state <= signal_while2_5;

      when signal_while2_5 =>
        if cnt = "00000000" then
          pc_inc <= '1';
        else
          pc_dec <= '1';
        end if;
        next_state <= signal_while2_3;

      ----- (
      when signal_do_while1 =>
        pc_inc <= '1'; -- PC <- PC + 1
        ptr_do <= pc + 1;
        next_state <= signal_start;
          
      ---- )
      when signal_do_while2 =>
        DATA_EN <= '1';
        DATA_RDWR <= '0';
        next_state <= signal_do_while2_2;

      when signal_do_while2_2 =>
        if (DATA_RDATA = "00000000") then
          pc_inc <= '1';
          next_state <= signal_start;
        else 
          pc_jump <= '1';
          next_state <= signal_start;
        end if;
      ----- null
      when signal_null =>
    end case;
  end process;
end behavioral;

