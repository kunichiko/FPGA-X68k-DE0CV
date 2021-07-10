--
-- Author: Kunihiko Ohnaka (@kunichiko on Twitter) @ 2021 July.
--
-- # About this module
-- FPGA X68000 に仮想SCSIインターフェースを持たせるためのモジュールです。
-- 本モジュールの内部に Fujitsu MB89352 (SPC) を模した em89352モジュールを
-- 内包します。
--
-- 詳細は Inside-FPGA-X68k.pptx を参照してください
-- https://drive.google.com/file/d/1E3Cgl-jsmxX4M7jbEJWzoqiro-h-QUoM/view
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use IEEE.std_logic_unsigned.all;

entity scsiif is
generic(
	inirstwait	:integer	:=10;
	rstlen		:integer	:=100
);
port(
	cs		:in std_logic;
	addr	:in std_logic_vector(3 downto 0);
	rd		:in std_logic;
	wr		:in std_logic;
	wdat	:in std_logic_vector(7 downto 0);
	rdat	:out std_logic_vector(7 downto 0);
	doe		:out std_logic;
	int		:out std_logic;
	iack	:in std_logic;
	drq		:out std_logic;
	dack	:in std_logic;
	iowait	:out std_logic;
	
	IDAT	:in std_logic_vector(7 downto 0);
	IDATp	:in std_logic;
	ODAT	:out std_logic_vector(7 downto 0);
	ODATp	:out std_logic;
	ODEN	:out std_logic;
	SEL		:out std_logic;
	BSY		:in std_logic;
	REQ		:in std_logic;
	ACK		:out std_logic;
	IO		:in std_logic;
	CD		:in std_logic;
	MSG		:in std_logic;
	RST		:out std_logic;
	
	clk		:in std_logic;
	rstn	:in std_logic
);
end scsiif;

architecture rtl of scsiif is
signal	iowdat	:std_logic_vector(7 downto 0);
signal	CMDWR	:std_logic;
signal	CMDRD	:std_logic;
signal	DMACLR:std_logic;
signal	IDWR	:std_logic;
signal	IDCLR	:std_logic;
signal	BUSRST	:std_logic;
signal	adrwr,ladrwr	:std_logic_vector(3 downto 0);
signal	adrrd,ladrrd	:std_logic_vector(3 downto 0);
signal	RDDAT_DAT	:std_logic_vector(7 downto 0);
signal	RDDAT_STA	:std_logic_vector(7 downto 0);
signal	ACKb,lACK	:std_logic;
signal	sREQ,lREQ	:std_logic;
signal	SELb		:std_logic;
signal	HSwait		:std_logic;
signal	inirst		:std_logic;



component em89352 is
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
end component;

begin
	spc: em89352 port map(
		-- for CPU bus
		CS		=> cs,
		A	 	=> addr,
		RD		=> rd,
		WR		=> wr,
		WDAT  	=> wdat,
		RDAT 	=> rdat,
		INTR	=> int,
		DREQ	=> drq,
		DACK	=> dack,
		iowait	=> iowait,

		-- for SCSI bus
		SDI 	=> IDAT,
		SDIp    => IDATp,
		SDO 	=> ODAT,
		SDOP    => ODATp,
		SEL		=> SEL,
		BSY		=> BSY,
		REQ		=> REQ,
		ACK		=> ACK,
		IO		=> IO,
		CD		=> CD,
		MSG		=> MSG,
		RST		=> RST,
		ATN     => ATN,
		
		clk		=> clk,
		rstn	=> rstn
	);

end rtl;
