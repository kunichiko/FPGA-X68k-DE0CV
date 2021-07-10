--
-- Author: Kunihiko Ohnaka (@kunichiko on Twitter) @ 2021 July.
--
-- # About this module
-- Fujitsu MB89352 (SPC) を模した em89352モジュールです。
--
-- 詳細は Inside-FPGA-X68k.pptx を参照してください
-- https://drive.google.com/file/d/1E3Cgl-jsmxX4M7jbEJWzoqiro-h-QUoM/view
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use IEEE.std_logic_unsigned.all;

entity em89352 is
port(
    -- for CPU bus
	CS		:in std_logic;
	A	    :in std_logic_vector(3 downto 0);
	RD		:in std_logic;
	WR		:in std_logic;
	WDAT  	:in std_logic_vector(7 downto 0);
	RDAT 	:out std_logic_vector(7 downto 0);
	INTR	:out std_logic;
	DREQ	:out std_logic;
	DACK	:in std_logic;
	iowait	:out std_logic;

    -- for SCSI bus
	SDI 	:in std_logic_vector(7 downto 0);
    SDIp    :in std_logic;      -- parity for SDI
	SDO 	:out std_logic_vector(7 downto 0);
    SDOP    :out std_logic;     -- parity for SDO
	SEL		:out std_logic;
	BSY		:in std_logic;
	REQ		:in std_logic;
	ACK		:out std_logic;
	IO		:in std_logic;
	CD		:in std_logic;
	MSG		:in std_logic;
	RST		:out std_logic;
    ATN     :out std_logic;
	
	clk		:in std_logic;
	rstn	:in std_logic
);
end sasiif;

architecture rtl of sasiif is
signal	iowdat	:std_logic_vector(7 downto 0);			-- CPUからの書き込みデータ
signal	adrwr,ladrwr	:std_logic_vector(15 downto 0);
signal	adrrd,ladrrd	:std_logic_vector(15 downto 0);

signal	BDID_WR	:std_logic;
signal	SCTL_WR	:std_logic;
signal	SCMD_WR	:std_logic;
signal	INTS_WR	:std_logic;
signal	PSNS_WR	:std_logic;

-- registers
signal	BDID	:std_logic_vector(7 downto 0);
signal	SCTL	:std_logic_Vector(7 downto 0);
signal	SCMD	:std_logic_Vector(7 downto 0);
signal	INTS	:std_logic_Vector(7 downto 0);
signal	PSNS	:std_logic_Vector(7 downto 0);
signal	SDGC	:std_logic_Vector(7 downto 0);
signal	SSTS	:std_logic_Vector(7 downto 0);
signal	SERR	:std_logic_Vector(7 downto 0);

type initstate_t is (
	is_init,
	is_reset,
	is_idle
);
signal	initstate	:initstate_t;

type state_t	is(
	st_IDLE,
	st_SEL,
	st_SELA,
	st_CMD,
	st_EXEC,
	st_STA,
	st_MSG
);
signal	STATE	:state_t;

begin
	process(clk,rstn)begin
		if(rstn='0')then
			ladrwr<=(others=>'0');
			iowdat<=(others=>'0');
			ladrrd<=(others=>'0');
		elsif(clk' event and clk='1')then
			ladrwr<=adrwr;
			ladrrd<=adrrd;
			if(CS='1' and WR='1')then
				iowdat<=WDAT;
			end if;
		end if;
	end process;

	process(clk)begin
		if(clk' event and clk='1')then
			if(CS='1' and WR='1')then
				case A is
				when "0000" =>
					adrwr<="0000000000000001";
				when "0001" =>
					adrwr<="0000000000000010";
				when "0010" =>
					adrwr<="0000000000000100";
				when "0011" =>
					adrwr<="0000000000001000";
				when "0100" =>
					adrwr<="0000000000010000";
				when "0101" =>
					adrwr<="0000000000100000";
				when "0110" =>
					adrwr<="0000000001000000";
				when "0111" =>
					adrwr<="0000000010000000";
				when "1000" =>
					adrwr<="0000000100000000";
				when "1001" =>
					adrwr<="0000001000000000";
				when "1010" =>
					adrwr<="0000010000000000";
				when "1011" =>
					adrwr<="0000100000000000";
				when "1100" =>
					adrwr<="0001000000000000";
				when "1101" =>
					adrwr<="0010000000000000";
				when "1110" =>
					adrwr<="0100000000000000";
				when "1111" =>
					adrwr<="1000000000000000";
				when others =>
					adrwr<="0000000000000000";
				end case;
			else
				adrwr<=(others=>'0');
			end if;
			if(CS='1' and RD='1')then
				case A is
				when "0000" =>
					adrrd<="0000000000000001";
				when "0001" =>
					adrrd<="0000000000000010";
				when "0010" =>
					adrrd<="0000000000000100";
				when "0011" =>
					adrrd<="0000000000001000";
				when "0100" =>
					adrrd<="0000000000010000";
				when "0101" =>
					adrrd<="0000000000100000";
				when "0110" =>
					adrrd<="0000000001000000";
				when "0111" =>
					adrrd<="0000000010000000";
				when "1000" =>
					adrrd<="0000000100000000";
				when "1001" =>
					adrrd<="0000001000000000";
				when "1010" =>
					adrrd<="0000010000000000";
				when "1011" =>
					adrrd<="0000100000000000";
				when "1100" =>
					adrrd<="0001000000000000";
				when "1101" =>
					adrrd<="0010000000000000";
				when "1110" =>
					adrrd<="0100000000000000";
				when "1111" =>
					adrrd<="1000000000000000";
				when others =>
					adrrd<="0000000000000000";
				end case;
			else
				adrrd<=(others=>'0');
			end if;
		end if;
	end process;

	RDAT<=	BDID when adrrd="00000000"&"00000001" else
			SCTL when adrrd="00000000"&"00000010" else
			SCMD when adrrd="00000000"&"00000010" else
			--
			INTS when adrrd="00000000"&"00001000" else
			PSNS when adrrd="00000000"&"00010000" else
			SDGC when adrrd="00000000"&"00100000" else
			SSTS when adrrd="00000000"&"01000000" else
			SERR when adrrd="00000000"&"10000000" else
			(others=>'0');

	-- R0: Bus Device ID
	BDID_WR<=	'1' when ladrwr(0)='1' and adrwr(0)='0' else '0';	-- falling edge

	process(clk,rstn)begin
		if(rstn='0')then
			BDID	<="10000000";
		elsif(clk' event and clk='1')then
			if(BDID_WR='1')then
				case iowdat(2 downto 0) is
				when "000" =>
					BDID<="00000001";
				when "001" =>
					BDID<="00000010";
				when "010" =>
					BDID<="00000100";
				when "011" =>
					BDID<="00001000";
				when "100" =>
					BDID<="00010000";
				when "101" =>
					BDID<="00100000";
				when "110" =>
					BDID<="01000000";
				when "111" =>
					BDID<="10000000";
				when others =>
					BDID<="10000000";
				end case;
			end if;
		end if;
	end process;

	-- R1: SPC Control
	SCTL_WR<=	'1' when ladrwr(1)='1' and adrwr(1)='0' else '0';	-- falling edge

	process(clk,rstn)begin
		if(rstn='0')then
			SCTL	<=(others=>'0')
		elsif(clk' event and clk='1')then
			if(SCTL_WR='1')then
				SCTL<=iowdat;
			end if;
		end if;
	end process;

	SCMD <=X"00";
			--
	INTS <=X"00";
	PSNS <=X"00";
	SDGC <=X"00";
	SSTS <=X"00";
	SERR <=X"00";

	--	iowait<=HSwait when cs='1' else '0';
	iowait <= '0';

end rtl;