--
-- Author: Kunihiko Ohnaka (@kunichiko on Twitter) @ 2020 November.
--
-- # About this module
-- I2C_TLC59116.vhd を使って、ミニX68000用のフロントパネルLEDを制御するためのモジュールです。
-- 
-- 16個のLED端子の接続構成は以下のようになっています。
-- - LED0 : POWER(B)
-- - LED1 : POWER(G)
-- - LED2 : POWER(R)
-- - LED3 : reserved
-- - LED4 : HD BUSY(B)
-- - LED5 : HD BUSY(G)
-- - LED6 : HD BUSY(R)
-- - LED7 : TIMER
-- - LED8 : FDD0 ACCESS(B)
-- - LED9 : FDD0 ACCESS(G)
-- - LED10: FDD0 ACCESS(R)
-- - LED11: FDD0 EJECT(G)
-- - LED12: FDD1 ACCESS(B)
-- - LED13: FDD1 ACCESS(G)
-- - LED14: FDD1 ACCESS(R)
-- - LED15: FDD1 EJECT(G)
--
-- 本モジュールはこれらをグルーピングして、以下の操作に限定することで簡単に扱えるようにします。
--
-- - Power
--     - "00" - OFF
--     - "01" - STANDBY (R)
--     - "11" - ON (G)
-- - HD BUSY
--     - "0" - Idle (OFF)
--     - "1" - Busy (R)
-- - TIMER
--     - "0" - Idle (OFF)
--     - "1" - Blinking (R)
-- - FDD0/1 Access
--     - "00" - OFF
--     - "01" - Blinking (G) (Controled by program)
--     - "10" - Inserted and Busy (R)
--     - "11" - Inserted and Idle (G)
-- - FDD0/1 Eject
--     - "0" - Not Inserted (OFF)
--     - "1" - Inserted (G)


LIBRARY IEEE;
	USE IEEE.STD_LOGIC_1164.ALL;
	use IEEE.std_logic_arith.all;
	USE IEEE.STD_LOGIC_UNSIGNED.ALL;
	use work.I2C_TLC59116_pkg.all;

entity X68_FRONTPANEL_CONTROLLER is
port(
    -- Control
    LED_POWER       :in     std_logic_vector(1 downto 0);
    LED_HD_BUSY     :in     std_logic;
    LED_TIMER       :in     std_logic;
    LED_FDD0_ACCESS :in     std_logic_vector(1 downto 0);
    LED_FDD1_ACCESS :in     std_logic_vector(1 downto 0);
    LED_FDD0_EJECT  :in     std_logic;
    LED_FDD1_EJECT  :in     std_logic;

    -- to TLC59116 module
	LEDMODES        :out	led_mode_array(0 to 15);
            
    clk			    :in     std_logic;
    rstn		    :in     std_logic
);
end X68_FRONTPANEL_CONTROLLER;

architecture rtl of X68_FRONTPANEL_CONTROLLER is
begin
    process(clk,rstn)
    begin
        if(rstn='0')then
            LEDMODES<=(others=>"00");
        elsif(clk' event and clk='1')then
            case LED_POWER is
            when "00" =>
                LEDMODES(0) <= "00";
                LEDMODES(1) <= "00";
                LEDMODES(2) <= "00";
            when "01" =>
                LEDMODES(0) <= "00";
                LEDMODES(1) <= "00";
                LEDMODES(2) <= "10";
            when "10" =>
                LEDMODES(0) <= "00";
                LEDMODES(1) <= "10";
                LEDMODES(2) <= "00";
            when "11" =>
                LEDMODES(0) <= "00";
                LEDMODES(1) <= "10";
                LEDMODES(2) <= "00";
            end case;

            case LED_HD_BUSY is
            when '0' =>
                LEDMODES(4) <= "00";
                LEDMODES(5) <= "00";
                LEDMODES(6) <= "00";
            when '1' =>
                LEDMODES(4) <= "00";
                LEDMODES(5) <= "00";
                LEDMODES(6) <= "10";
            end case;

            LEDMODES(7) <= LED_TIMER & "0";

            case LED_FDD0_ACCESS is
            when "00" =>
                LEDMODES(8) <= "00";
                LEDMODES(9) <= "00";
                LEDMODES(10) <= "00";
            when "01" =>
                LEDMODES(8) <= "00";
                LEDMODES(9) <= "11";
                LEDMODES(10) <= "00";
            when "10" =>
                LEDMODES(8) <= "00";
                LEDMODES(9) <= "00";
                LEDMODES(10) <= "10";
            when "11" =>
                LEDMODES(8) <= "00";
                LEDMODES(9) <= "10";
                LEDMODES(10) <= "00";
            end case;

            LEDMODES(11) <= LED_FDD0_EJECT & "0";

            case LED_FDD1_ACCESS is
            when "00" =>
                LEDMODES(12) <= "00";
                LEDMODES(13) <= "00";
                LEDMODES(14) <= "00";
            when "01" =>
                LEDMODES(12) <= "00";
                LEDMODES(13) <= "11";
                LEDMODES(14) <= "00";
            when "10" =>
                LEDMODES(12) <= "00";
                LEDMODES(13) <= "00";
                LEDMODES(14) <= "10";
            when "11" =>
                LEDMODES(12) <= "00";
                LEDMODES(13) <= "10";
                LEDMODES(14) <= "00";
            end case;

            LEDMODES(15) <= LED_FDD1_EJECT & "0";

        end if;
    end process;
end rtl;