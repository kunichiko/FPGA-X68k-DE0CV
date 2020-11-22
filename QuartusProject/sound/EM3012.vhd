--
--  EM3012.vhd
--
--    Author Kunihiko Ohnaka
--
library	IEEE;

use	IEEE.STD_LOGIC_1164.ALL;
use	IEEE.STD_LOGIC_ARITH.ALL;
use	IEEE.STD_LOGIC_UNSIGNED.ALL;

entity EM3012 is
    port(
        CLK_PHY1  : in std_logic; -- Phy0 clock 2MHz divided by YM2151
        SDATA     : in std_logic;
        SAM_HOLD1 : in std_logic;
        SAM_HOLD2 : in std_logic;

        -- system side
        sndL      : out std_logic_vector(15 downto 0);
        sndR      : out std_logic_vector(15 downto 0);

        fmclk     : in std_logic;  -- 32MHz
        rstn	  : in std_logic
    );
end EM3012;
    
architecture rtl of EM3012 is
--
signal shift_reg    : std_logic_vector(12 downto 0); -- 3bit exponent / 10bit significand

--
signal sam1_d       : std_logic;
signal sam2_d       : std_logic;
signal sndL_pre     : std_logic_vector(15 downto 0);
signal sndR_pre     : std_logic_vector(15 downto 0);

--
signal latch_req    : std_logic;
signal latch_req_d  : std_logic;
signal latch_ack    : std_logic;
signal sndL_latch   : std_logic_vector(15 downto 0);
signal sndR_latch   : std_logic_vector(15 downto 0);

begin

    process(CLK_PHY1,rstn)
        variable s : std_logic := '0';
    begin
        if(rstn='0')then
            shift_reg <= (others => '0');
            sam1_d <= '0';
            sam2_d <= '0';
            sndL_pre <= (others => '1');
            sndR_pre <= (others => '1');
            latch_req <= '0';
        elsif (CLK_PHY1' event and CLK_PHY1='1') then
				
				shift_reg <= SDATA & shift_reg(12 downto 1);

				sam1_d <= SAM_HOLD1;
				sam2_d <= SAM_HOLD2;

				if (sam1_d = '1' and SAM_HOLD1 = '0') then -- falling edge
					 s := not shift_reg(9);
					 case shift_reg(12 downto 10) is
						  when "000" => sndR_pre <= s & s & s & s & s & s & s & s & shift_reg(8 downto 1);
						  when "001" => sndR_pre <= s & s & s & s & s & s & s & shift_reg(8 downto 0);
						  when "010" => sndR_pre <= s & s & s & s & s & s & shift_reg(8 downto 0) & "0";
						  when "011" => sndR_pre <= s & s & s & s & s & shift_reg(8 downto 0) & "00";
						  when "100" => sndR_pre <= s & s & s & s & shift_reg(8 downto 0) & "000";
						  when "101" => sndR_pre <= s & s & s & shift_reg(8 downto 0) & "0000";
						  when "110" => sndR_pre <= s & s & shift_reg(8 downto 0) & "00000";
						  when "111" => sndR_pre <= s & shift_reg(8 downto 0) & "000000";
					 end case;
					 latch_req <= not latch_req;
				end if;

				if (sam2_d = '1' and SAM_HOLD2 = '0') then -- falling edge
					 s := not shift_reg(9);
					 case shift_reg(12 downto 10) is
						  when "000" => sndL_pre <= s & s & s & s & s & s & s & s & shift_reg(8 downto 1);
						  when "001" => sndL_pre <= s & s & s & s & s & s & s & shift_reg(8 downto 0);
						  when "010" => sndL_pre <= s & s & s & s & s & s & shift_reg(8 downto 0) & "0";
						  when "011" => sndL_pre <= s & s & s & s & s & shift_reg(8 downto 0) & "00";
						  when "100" => sndL_pre <= s & s & s & s & shift_reg(8 downto 0) & "000";
						  when "101" => sndL_pre <= s & s & s & shift_reg(8 downto 0) & "0000";
						  when "110" => sndL_pre <= s & s & shift_reg(8 downto 0) & "00000";
						  when "111" => sndL_pre <= s & shift_reg(8 downto 0) & "000000";
					 end case;
				end if;
        end if;

    end process;

    process(fmclk,rstn)
    begin
        if(rstn='0')then
            latch_req_d  <= '0';
            latch_ack    <= '0';
            sndL_latch   <= (others => '0');
            sndR_latch   <= (others => '0');
        elsif (fmclk' event and fmclk='1') then
            latch_req_d <= latch_req;

            if (latch_req_d /= latch_ack) then
                latch_ack <= not latch_ack;
                sndL_latch <= sndL_pre;
                sndR_latch <= sndR_pre;
            end if;
        end if;
    end process;

    sndL <= sndL_latch;
    sndR <= sndR_latch;

    end rtl;
    
    