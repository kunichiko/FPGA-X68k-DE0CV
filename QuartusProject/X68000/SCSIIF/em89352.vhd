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
signal	adrwr,ladrwr	:std_logic_vector(7 downto 0);
signal	adrrd,ladrrd	:std_logic_vector(7 downto 0);

signal	BDID_WR	:std_logic;
signal	BDID_RD	:std_logic;

-- registers
signal	BDID	:std_logic_vector(7 downto 0);

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
				when "000" =>
					adrwr<="00000001";
				when "001" =>
					adrwr<="00000010";
				when "010" =>
					adrwr<="00000100";
				when "011" =>
					adrwr<="00001000";
				when "100" =>
					adrwr<="00010000";
				when "101" =>
					adrwr<="00100000";
				when "110" =>
					adrwr<="01000000";
				when "111" =>
					adrwr<="10000000";
				when others =>
					adrwr<="00000000";
				end case;
			else
				adrwr<="0000";
			end if;
			if(CS='1' and RD='1')then
				case A is
				when "000" =>
					adrrd<="00000001";
				when "001" =>
					adrrd<="00000010";
				when "010" =>
					adrrd<="00000100";
				when "011" =>
					adrrd<="00001000";
				when "100" =>
					adrrd<="00010000";
				when "101" =>
					adrrd<="00100000";
				when "110" =>
					adrrd<="01000000";
				when "111" =>
					adrrd<="10000000";
				when others =>
					adrrd<="00000000";
				end case;
			else
				adrrd<="0000";
			end if;
		end if;
	end process;

	RDAT<=	BDID when adrrd="00000001" else
			(others=>'0');

	-- R0: Bus Device ID
	BDID_WR<=	'1' when ladrwr(0)='1' and adrwr(0)='0' else '0';	-- falling edge

	process(clk,rstn)begin
		if(rstn='0')then
			BDID	<=(others=>'0');
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
					BDID<="00000000";
				end case;
			end if;
		end if;
	end process;

	--	iowait<=HSwait when cs='1' else '0';
	iowait <= '0';

end rtl;