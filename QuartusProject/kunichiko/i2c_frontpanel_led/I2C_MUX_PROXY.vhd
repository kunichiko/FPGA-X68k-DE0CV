--
-- Author: Kunihiko Ohnaka (@kunichiko on Twitter) @ 2020 November.
--
-- # About this module
-- FPGAの1組のI2Cバスポートに、2つのI2Cモジュールを接続するためのマルチプレクサ I2C_MUX.vhdの
-- サポートモジュールです。各I2Cモジュール用のドライバに対するプロキシーとして動作します。
--
-- 動作の詳細は architecture.pptx をご覧ください。
--
LIBRARY IEEE;
	USE IEEE.STD_LOGIC_1164.ALL;
	use IEEE.std_logic_arith.all;
	USE IEEE.STD_LOGIC_UNSIGNED.ALL;
	use work.I2C_pkg.all;
	use work.I2C_TLC59116_pkg.all;

entity I2C_MUX_PROXY is
port(
	-- I2C
	BUSREQ	    :out	std_logic;              	    --bus request
	BUSGNT  	:in		std_logic;                  	--bus granted
    BUSACK		:out	std_logic;						--bus grant acknowledge
    TXEMP       :in     std_logic;

    -- to Driver
	TXEMP_PXY   :out    std_logic;						--tx buffer empty
	WRn_PXY	    :in     std_logic;						--write
	RDn_PXY	    :in     std_logic;						--read
	RESTART_PXY :in     std_logic;						--make re-start condition
	START_PXY   :in     std_logic;						--make start condition
	FINISH_PXY  :in     std_logic;						--next data is final(make stop condition)
	F_FINISH_PXY:in     std_logic;						--next data is final(make stop condition)
	
	clk			:in     std_logic;
	rstn		:in     std_logic
);
end I2C_MUX_PROXY;

architecture rtl of I2C_MUX_PROXY is
type I2CMUXPROXYstate_t is(
    IS_IDLE,
    IS_REQ,
    IS_BUSY,
    IS_FIN
);
signal	state	:I2CMUXPROXYstate_t;

begin

    TXEMP_PXY <='0' when WRn_PXY='0' else 
                '1' when state=IS_IDLE else
                '0' when state=IS_REQ else
                TXEMP;

    process(clk,rstn)
	begin
		if(rstn='0')then
            state<=IS_IDLE;
            BUSREQ<='0';
            BUSACK<='0';
		elsif(clk' event and clk='1')then
			case state is
            when IS_IDLE =>
                if(WRn_PXY='0' and START_PXY='1')then
                    state<=IS_REQ;
                    BUSREQ<='1';
                end if;
            when IS_REQ =>
                if(BUSGNT='1')then
                    state<=IS_BUSY;
                    BUSREQ<='0';
                    BUSACK<='1';
                end if;
            when IS_BUSY =>
                if((WRn_PXY='0' or RDn_PXY='0') and FINISH_PXY='1')then
                    state<=IS_FIN;
                end if;
            when IS_FIN =>
                if(TXEMP='1')then
                    state<=IS_IDLE;
                    BUSACK<='0';
                end if;
            end case;
        end if;
    end process;

end rtl;
                    

