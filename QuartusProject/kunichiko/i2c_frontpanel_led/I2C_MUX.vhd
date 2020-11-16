--
-- Author: Kunihiko Ohnaka (@kunichiko on Twitter) @ 2020 November.
--
-- # About this module
-- FPGAの1組のI2Cバスポートに、2つのI2Cモジュールを接続するためのマルチプレクサです。
-- 
-- I2Cの制御はFPGA X68000の作者であるプー氏が作成した I2CIF.vhd を使いますが、
-- このI2CIFに対して2つのモジュールを接続できるようにします。
--

LIBRARY IEEE;
	USE IEEE.STD_LOGIC_1164.ALL;
	use IEEE.std_logic_arith.all;
	USE IEEE.STD_LOGIC_UNSIGNED.ALL;
	use work.I2C_pkg.all;
	use work.I2C_TLC59116_pkg.all;

entity I2C_MUX is
generic(
	NUM_DRIVERS	:integer	:=2
);
port(
	-- I2C
	TXOUT		:out	std_logic_vector(I2CDAT_WIDTH-1 downto 0);	--tx data in
	RXIN		:in		std_logic_vector(I2CDAT_WIDTH-1 downto 0);	--rx data out
	WRn			:out	std_logic;						--write
	RDn			:out	std_logic;						--read

	TXEMP		:in		std_logic;						--tx buffer empty
	RXED		:in		std_logic;						--rx buffered
	NOACK		:in		std_logic;						--no ack
	COLL		:in		std_logic;						--collision detect
	NX_READ		:out	std_logic;						--next data is read
	RESTART		:out	std_logic;						--make re-start condition
	START		:out	std_logic;						--make start condition
	FINISH		:out	std_logic;						--next data is final(make stop condition)
	F_FINISH	:out	std_logic;						--next data is final(make stop condition by force)
	INIT		:out	std_logic;

    -- for Driver
	DATIN_PXY   :in     i2cdat_array(NUM_DRIVERS-1 downto 0);		--tx data in
	DATOUT_PXY	:out    i2cdat_array(NUM_DRIVERS-1 downto 0);		--rx data out
	WRn_PXY		:in     std_logic_vector(NUM_DRIVERS-1 downto 0);	--write
	RDn_PXY		:in     std_logic_vector(NUM_DRIVERS-1 downto 0);	--read

	TXEMP_PXY   :out    std_logic_vector(NUM_DRIVERS-1 downto 0);	--tx buffer empty
	RXED_PXY	:out    std_logic_vector(NUM_DRIVERS-1 downto 0);	--rx buffered
	NOACK_PXY	:out    std_logic_vector(NUM_DRIVERS-1 downto 0);	--no ack
	COLL_PXY	:out    std_logic_vector(NUM_DRIVERS-1 downto 0);	--collision detect
	NX_READ_PXY	:in     std_logic_vector(NUM_DRIVERS-1 downto 0);	--next data is read
	RESTART_PXY	:in     std_logic_vector(NUM_DRIVERS-1 downto 0);	--make re-start condition
	START_PXY	:in     std_logic_vector(NUM_DRIVERS-1 downto 0);	--make start condition
	FINISH_PXY	:in     std_logic_vector(NUM_DRIVERS-1 downto 0);	--next data is final(make stop condition)
	F_FINISH_PXY:in     std_logic_vector(NUM_DRIVERS-1 downto 0);	--next data is final(make stop condition)
	INIT_PXY	:in     std_logic_vector(NUM_DRIVERS-1 downto 0);
	
	clk			:in std_logic;
	rstn		:in std_logic
);
end I2C_MUX;

architecture rtl of I2C_MUX is
type I2CMUXstate_t is(
    IS_IDLE,
    IS_START,
    IS_GRANT,
    IS_BUSY
);
signal	I2CMUXstate	:I2CMUXstate_t;
signal  SEL: integer range 0 to NUM_DRIVERS-1;

signal	BUSREQ:	std_logic_vector(NUM_DRIVERS-1 downto 0);
signal	BUSGNT:	std_logic_vector(NUM_DRIVERS-1 downto 0);
signal	BUSACK:	std_logic_vector(NUM_DRIVERS-1 downto 0);

component I2C_MUX_PROXY is
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
		F_FINISH_PXY:in    std_logic;						--next data is final(make stop condition)
		
		clk			:in 	std_logic;
		rstn		:in 	std_logic
	);
end component;

begin

	GEN1: for I in 0 to NUM_DRIVERS-1 generate
		U: I2C_MUX_PROXY port map(
			BUSREQ 		=> BUSREQ(I),
			BUSGNT 		=> BUSGNT(I),
			BUSACK 		=> BUSACK(I),
			TXEMP		=> TXEMP,
			TXEMP_PXY	=> TXEMP_PXY(I),
			WRn_PXY		=> WRn_PXY(I),
			RDn_PXY		=> RDn_PXY(I),
			RESTART_PXY	=> RESTART_PXY(I),
			START_PXY	=> START_PXY(I),
			FINISH_PXY	=> FINISH_PXY(I),
			F_FINISH_PXY=> F_FINISH_PXY(I),
			clk			=> clk,
			rstn		=> rstn
		);

		DATOUT_PXY(I) <= RXIN;
	end generate;

	WRn     <=  '1' when I2CMUXstate = IS_IDLE else 
				'0' when I2CMUXstate = IS_START else
				WRn_PXY(SEL);
	START   <=  '0' when I2CMUXstate = IS_IDLE else 
				'1' when I2CMUXstate = IS_START else 
				START_PXY(SEL);

	TXOUT   <=  DATIN_PXY(SEL)		when I2CMUXstate /=IS_IDLE else (others=>'0');
    RDn     <=  RDn_PXY(SEL) 		when I2CMUXstate = IS_BUSY else '1';
    NX_READ <=  NX_READ_PXY(SEL)	when I2CMUXstate = IS_BUSY else '0';
    RESTART <=  RESTART_PXY(SEL)	when I2CMUXstate = IS_BUSY else '0';
    FINISH  <=  FINISH_PXY(SEL)		when I2CMUXstate = IS_BUSY else '0';
    F_FINISH<=	F_FINISH_PXY(SEL)	when I2CMUXstate = IS_BUSY else '0';
    INIT    <=  INIT_PXY(SEL)		when I2CMUXstate = IS_BUSY else '0';

	GEN2: for I in 0 to NUM_DRIVERS-1 generate
		RXED_PXY(I) <= RXED			when I2CMUXstate = IS_BUSY and SEL = I else '0';
	    NOACK_PXY(I) <= NOACK		when I2CMUXstate = IS_BUSY and SEL = I else '0';
		COLL_PXY(I) <= COLL			when I2CMUXstate = IS_BUSY and SEL = I else '0';
	end generate;

	process(clk,rstn)
	begin
		if(rstn='0')then
			I2CMUXstate<=IS_IDLE;
			BUSGNT<=(others => '0');
			SEL<=0;
		elsif(clk' event and clk='1')then
			case I2CMUXstate is
			when IS_IDLE =>
				BUSGNT<=(others => '0');
				for I in 0 to NUM_DRIVERS-1 loop
					if(BUSREQ(I)='1' and TXEMP='1')then
						I2CMUXstate<=IS_START;
						SEL<=I;
						exit;
					end if;
				end loop;
			when IS_START =>
				I2CMUXstate<=IS_GRANT;
				BUSGNT(SEL)<='1';			-- STARTの代理発行が終わったら本来のドライバにバス操作権限を委譲
			when IS_GRANT =>
				if(BUSACK(SEL)='1')then		-- ACKが来るまで待つ(このステートはなくてもいいかもしれないが念のため）	
					I2CMUXstate<=IS_BUSY;
					BUSGNT<=(others => '0');
				end if;
			when IS_BUSY =>
				if(BUSACK(SEL)='0')then
					I2CMUXstate<=IS_IDLE;
				end if;
			end case;
		end if;
	end process;
end rtl; 
                    

