LIBRARY	IEEE;
	USE	IEEE.STD_LOGIC_1164.ALL;
	USE	IEEE.STD_LOGIC_ARITH.ALL;
	USE	IEEE.STD_LOGIC_UNSIGNED.ALL;

entity hdmiconv is
port(
	datinR	:in std_logic_vector(7 downto 0);
	datinG	:in std_logic_vector(7 downto 0);
	datinB	:in std_logic_vector(7 downto 0);
	Hsync		:in std_logic;
	Vsync		:in std_logic;
	VIDen		:in std_logic;
	
	LVDS0		:out std_logic;
	LVDS1		:out std_logic;
	LVDS2		:out std_logic;
	LVDSclk	:out std_logic;
	
	vclk		:in std_logic;
	clk2		:in std_logic;
	rstn		:in std_logic
);
end hdmiconv;

architecture rtl of hdmiconv is
signal	tmds0sig	:std_logic_vector(9 downto 0);
signal	tmds1sig	:std_logic_vector(9 downto 0);
signal	tmds2sig	:std_logic_vector(9 downto 0);
signal	LVDSsig	:std_logic_vector(2 downto 0);
signal	hdmiclk	:std_logic;

component tmds_enc
port(
	D		:in std_logic_vector(7 downto 0);
	C		:in std_logic_vector(1 downto 0);
	A		:in std_logic_vector(3 downto 0);
	CH		:in integer range 0 to 2;
	DMODE	:in std_logic_vector(1 downto 0);	--"00":video "01":2b/10b "10":4b/10b "11":guard band
	CK		:in std_logic;
	Q		:out std_logic_vector(9 downto 0)
);
end component;

component LVDStrans
	PORT
	(
		tx_in		: IN STD_LOGIC_VECTOR (29 DOWNTO 0);
		tx_inclock		: IN STD_LOGIC ;
		tx_coreclock		: OUT STD_LOGIC ;
		tx_locked		: OUT STD_LOGIC ;
		tx_out		: OUT STD_LOGIC_VECTOR (2 DOWNTO 0);
		tx_outclock		: OUT STD_LOGIC 
	);
END component;

begin
	tmds0	:tmds_enc port map(
		D	=>datinB,
		C	=>Vsync & Hsync,
		A	=>(others=>'0'),
		CH	=>0,
		DMODE=>'0' & VIDen,
		CK	=>clk2,
		Q	=>tmds0sig
	);

	tmds1	:tmds_enc port map(
		D	=>datinG,
		C	=>"00",
		A	=>(others=>'0'),
		CH	=>1,
		DMODE=>'0' & VIDen,
		CK	=>clk2,
		Q	=>tmds1sig
	);

	tmds2	:tmds_enc port map(
		D	=>datinR,
		C	=>"00",
		A	=>(others=>'0'),
		CH	=>2,
		DMODE=>'0' & VIDen,
		CK	=>clk2,
		Q	=>tmds2sig
	);

	VLDS	:LVDStrans port map(
		tx_in			=>tmds2sig & tmds1sig & tmds0sig,
		tx_inclock	=>clk2,
		tx_coreclock=>LVDSclk,
		tx_locked	=>open,
		tx_out		=>LVDSsig,
		tx_outclock	=>open
	);
	
	LVDS0<=LVDSsig(0);
	LVDS1<=LVDSsig(1);
	LVDS2<=LVDSsig(2);

end rtl;
