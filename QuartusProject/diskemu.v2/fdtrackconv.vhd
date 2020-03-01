LIBRARY	IEEE,work;
USE	IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_ARITH.ALL;
USE	IEEE.STD_LOGIC_UNSIGNED.ALL;
use work.FDC_sectinfo.all;

entity fdtrackconv is
port(
	TRAMADDR	:out std_logic_vector(13 downto 0);
	TRAMRDAT	:in std_logic_vector(8 downto 0);
	TRAMWDAT	:out std_logic_vector(8 downto 0);
	TRAMWR		:out std_logic;
	
	IRAMADDR	:out std_logic_vector(13 downto 0);
	IRAMRDAT	:in std_logic_vector(7 downto 0);
	IRAMWDAT	:out std_logic_vector(7 downto 0);
	IRAMWR		:out std_logic;
	
	I2TTRACKLEN	:in std_logic_vector(13 downto 0);
	T2ITRACKLEN	:in std_logic_vector(13 downto 0);
	
	I2TREQ		:in std_logic;
	I2TBUSY		:out std_logic;
	MFMOUT		:out std_logic;
	
	T2IREQ		:in std_logic;
	T2IBUSY		:out std_logic;
	MFMIN		:in std_logic;
	
	CRCMON		:out std_logic_vector(15 downto 0);
	
	clk			:in std_logic;
	rstn		:in std_logic
);
end fdtrackconv;

architecture rtl of fdtrackconv is

component CRCGENN
	generic(
		DATWIDTH :integer	:=10;
		WIDTH	:integer	:=3
	);
	port(
		POLY	:in std_logic_vector(WIDTH downto 0);
		DATA	:in std_logic_vector(DATWIDTH-1 downto 0);
		DIR		:in std_logic;
		WRITE	:in std_logic;
		BITIN	:in std_logic;
		BITWR	:in std_logic;
		CLR		:in std_logic;
		CLRDAT	:in std_logic_vector(WIDTH-1 downto 0);
		CRC		:out std_logic_vector(WIDTH-1 downto 0);
		BUSY	:out std_logic;
		DONE	:out std_logic;
		CRCZERO	:out std_logic;

		clk		:in std_logic;
		rstn	:in std_logic
	);
end component;

--type state_t is(
--	st_IDLE,
--	st_I2T_READMFM,
--	st_I2T_GAP0,
--	st_I2T_SYNCP,
--	st_I2T_IM0,
--	st_I2T_IM1,
--	st_I2T_IM2,
--	st_I2T_IM3,
--	st_I2T_GAP1,
--	st_I2T_Synci,
--	st_I2T_IAM0,
--	st_I2T_IAM1,
--	st_I2T_IAM2,
--	st_I2T_IAM3,
--	st_I2T_C,
--	st_I2T_H,
--	st_I2T_R,
--	st_I2T_N,
--	st_I2T_CRCi0,
--	st_I2T_CRCi1,
--	st_I2T_GAP2,
--	st_I2T_Syncd,
--	st_I2T_DAM0,
--	st_I2T_DAM1,
--	st_I2T_DAM2,
--	st_I2T_DAM3,
--	st_I2T_DATA,
--	st_I2T_CRCd0,
--	st_I2T_CRCd1,
--	st_I2T_GAP3,
--	st_I2T_GAP4,
--	st_T2I_COUNTSECTS,
--	st_T2I_IAM0,
--	st_T2I_IAM1,
--	st_T2I_IAM2,
--	st_T2I_IAM3,
--	st_T2I_C,
--	st_T2I_H,
--	st_T2I_R,
--	st_T2I_N,
--	st_T2I_SECTORS,
--	st_T2I_SECTSIZEL,
--	st_T2I_SECTSIZEH,
--	st_T2I_res0,
--	st_T2I_res1,
--	st_T2I_res2,
--	st_T2I_res3,
--	st_T2I_res4,
--	st_T2I_MODE,
--	st_T2I_CRCi0,
--	st_T2I_CRCi1,
--	st_T2I_STATE1,
--	st_T2I_DAM0,
--	st_T2I_DAM1,
--	st_T2I_DAM2,
--	st_T2I_DAM3,
--	st_T2I_DELETED,
--	st_T2I_DATA,
--	st_T2I_CRCd0,
--	st_T2I_CRCd1,
--	st_T2I_STATE2
--);
--
--signal	state	:state_t;

constant	st_IDLE				:integer	:=0;
constant	st_I2T_READMFM		:integer	:=1;
constant	st_I2T_GAP0			:integer	:=2;
constant	st_I2T_SYNCP		:integer	:=3;
constant	st_I2T_IM0			:integer	:=4;
constant	st_I2T_IM1			:integer	:=5;
constant	st_I2T_IM2			:integer	:=6;
constant	st_I2T_IM3			:integer	:=7;
constant	st_I2T_GAP1			:integer	:=8;
constant	st_I2T_Synci		:integer	:=9;
constant	st_I2T_IAM0			:integer	:=10;
constant	st_I2T_IAM1			:integer	:=11;
constant	st_I2T_IAM2			:integer	:=12;
constant	st_I2T_IAM3			:integer	:=13;
constant	st_I2T_C				:integer	:=14;
constant	st_I2T_H				:integer	:=15;
constant	st_I2T_R				:integer	:=16;
constant	st_I2T_N				:integer	:=17;
constant	st_I2T_CRCi0		:integer	:=18;
constant	st_I2T_CRCi1		:integer	:=19;
constant	st_I2T_GAP2			:integer	:=20;
constant	st_I2T_Syncd		:integer	:=21;
constant	st_I2T_DAM0			:integer	:=22;
constant	st_I2T_DAM1			:integer	:=23;
constant	st_I2T_DAM2			:integer	:=24;
constant	st_I2T_DAM3			:integer	:=25;
constant	st_I2T_DATA			:integer	:=26;
constant	st_I2T_CRCd0		:integer	:=27;
constant	st_I2T_CRCd1		:integer	:=28;
constant	st_I2T_GAP3			:integer	:=29;
constant	st_I2T_GAP4			:integer	:=30;
constant	st_T2I_COUNTSECTS	:integer	:=31;
constant	st_T2I_IAM0			:integer	:=32;
constant	st_T2I_IAM1			:integer	:=33;
constant	st_T2I_IAM2			:integer	:=34;
constant	st_T2I_IAM3			:integer	:=35;
constant	st_T2I_C				:integer	:=36;
constant	st_T2I_H				:integer	:=37;
constant	st_T2I_R				:integer	:=38;
constant	st_T2I_N				:integer	:=39;
constant	st_T2I_SECTORSL	:integer	:=40;
constant	st_T2I_SECTORSH	:integer	:=61;
constant	st_T2I_SECTSIZEL	:integer	:=41;
constant	st_T2I_SECTSIZEH	:integer	:=42;
constant	st_T2I_res0			:integer	:=43;
constant	st_T2I_res1			:integer	:=44;
constant	st_T2I_res2			:integer	:=45;
constant	st_T2I_res3			:integer	:=46;
constant	st_T2I_res4			:integer	:=47;
constant	st_T2I_MODE			:integer	:=48;
constant	st_T2I_CRCi0		:integer	:=49;
constant	st_T2I_CRCi1		:integer	:=50;
constant	st_T2I_STATE1		:integer	:=51;
constant	st_T2I_DAM0			:integer	:=52;
constant	st_T2I_DAM1			:integer	:=53;
constant	st_T2I_DAM2			:integer	:=54;
constant	st_T2I_DAM3			:integer	:=55;
constant	st_T2I_DELETED		:integer	:=56;
constant	st_T2I_DATA			:integer	:=57;
constant	st_T2I_CRCd0		:integer	:=58;
constant	st_T2I_CRCd1		:integer	:=59;
constant	st_T2I_STATE2		:integer	:=60;

signal	state	:integer range 0 to 61;

signal	CRCwdat	:std_logic_vector(7 downto 0);
signal	CRCwr	:std_logic;
signal	CRCclr	:std_logic;
signal	CRCclrdat	:std_logic_vector(15 downto 0);
signal	CRCerr	:std_logic;
signal	CRCdat	:std_logic_vector(15 downto 0);
signal	CRCZero	:std_logic;
signal	CRCbusy	:std_logic;

signal	CURTADDR	:std_logic_vector(13 downto 0);
signal	CURIADDR	:std_logic_vector(13 downto 0);
signal	T2I_STADDR	:std_logic_vector(13 downto 0);
signal	SECTSIZE	:std_logic_vector(15 downto 0);
signal	bytecount	:integer range 0 to 16384;
signal	MFM		:std_logic;
signal	SECTSTATE	:std_logic_vector(7 downto 0);
signal	SECTORS		:integer range 0 to 255;
signal	SECTCOUNT	:integer range 0 to 255;
signal	STATEADDR	:std_logic_vector(13 downto 0);
signal	DELETED		:std_logic;
begin

	process(clk,rstn)
	variable ramwait	:integer range 0 to 2;
	variable lT2I,lI2T	:std_logic;
	variable SDAT0,SDAT1,SDAT2,SDAT3	:std_logic_vector(8 downto 0);
	begin
		if(rstn='0')then
			state<=st_IDLE;
			CURTADDR<=(others=>'0');
			CURIADDR<=(others=>'0');
			TRAMWDAT<=(others=>'0');
			IRAMWDAT<=(others=>'0');
			TRAMADDR<=(others=>'0');
			IRAMADDR<=(others=>'0');
			TRAMWR<='0';
			IRAMWR<='0';
			CRCwdat<=(others=>'0');
			CRCwr<='0';
			CRCclr<='0';
			T2I_STADDR<=(others=>'0');
			ramwait:=0;
			bytecount<=0;
			MFM<='0';
			CRCerr<='0';
			SECTSTATE<=(others=>'0');
			SECTORS<=0;
			SECTCOUNT<=0;
			SECTSIZE<=(others=>'0');
			I2TBUSY<='0';
			T2IBUSY<='0';
			DELETED<='0';
			SDAT0:=(others=>'0');SDAT1:=(others=>'0');SDAT2:=(others=>'0');SDAT3:=(others=>'0');
			lI2T:='0';
			lT2I:='0';
		elsif(clk' event and clk='1')then
			TRAMwr<='0';
			IRAMWR<='0';
			CRCCLR<='0';
			CRCWR<='0';
			if(lI2T='0' and I2TREQ='1')then
				CURTADDR<=(others=>'0');
				CURIADDR<=(others=>'0');
				IRAMADDR<="00" & x"006";
				state<=st_I2T_READMFM;
				I2TBUSY<='1';
				ramwait:=1;
			elsif(lT2I='0' and T2IREQ='1')then
				state<=st_T2I_COUNTSECTS;
				CURTADDR<=(others=>'0');
				CURIADDR<=(others=>'0');
				SECTORS<=0;
				SECTCOUNT<=0;
				MFM<=MFMIN;
				T2IBUSY<='1';
			elsif(ramwait>0)then
				ramwait:=ramwait-1;
			else
				case state is
				when st_I2T_READMFM =>
					if(IRAMRDAT=x"00")then
						MFM<='1';
						MFMOUT<='1';
						TRAMWDAT<='0' & x"4e";
						bytecount<=nmfmGap0 -1;
					else
						MFM<='0';
						MFMOUT<='0';
						TRAMWDAT<='0' & x"ff";
						bytecount<=nfmGap0 -1;
					end if;
					TRAMADDR<=CURTADDR;
					CURTADDR<=CURTADDR+1;
					TRAMWR<='1';
					state<=st_I2T_GAP0;
				when st_I2T_GAP0 =>
					if(bytecount>0)then
						TRAMADDR<=CURTADDR;
						bytecount<=bytecount-1;
					else
						TRAMADDR<=CURTADDR;
						TRAMWDAT<='0' & x"00";
						if(MFM='1')then
							bytecount<=nmfmSyncp -1;
						else
							bytecount<=nfmSyncp -1;
						end if;
						state<=st_I2T_syncp;
					end if;
					TRAMwr<='1';
					CURTADDR<=CURTADDR+1;
				when st_I2T_syncp =>
					TRAMADDR<=CURTADDR;
					if(bytecount>0)then
						bytecount<=bytecount-1;
					else
						if(MFM='1')then
							TRAMWDAT<='1' & x"c2";
						else
							TRAMWDAT<='1' & x"fc";
						end if;
						state<=st_I2T_IM0;
					end if;
					TRAMWR<='1';
					CURTADDR<=CURTADDR+1;
				when st_I2T_IM0 =>
					SECTCOUNT<=0;
					TRAMADDR<=CURTADDR;
					if(MFM='1')then
						TRAMWDAT<='1' & x"c2";
						state<=st_I2T_IM1;
					else
						TRAMWDAT<='0' & x"ff";
						bytecount<=nfmGap1 -1;
						state<=st_I2T_GAP1;
					end if;
					CURTADDR<=CURTADDR+1;
					TRAMWR<='1';
					IRAMADDR<=CURIADDR+("00" & x"008");
				when st_I2T_IM1 =>
					TRAMADDR<=CURTADDR;
					TRAMWR<='1';
					CURTADDR<=CURTADDR+1;
					state<=st_I2T_IM2;
				when st_I2T_IM2 =>
					TRAMADDR<=CURTADDR;
					TRAMWDAT<='0' & x"fc";
					TRAMWR<='1';
					CURTADDR<=CURTADDR+1;
					state<=st_I2T_IM3;
				when st_I2T_IM3 =>
					TRAMADDR<=CURTADDR;
					TRAMWDAT<='0' & x"4e";
					TRAMWR<='1';
					bytecount<=nmfmGap1 -1;
					CURTADDR<=CURTADDR+1;
					state<=st_I2T_GAP1;
				when st_I2T_GAP1 =>
					TRAMADDR<=CURTADDR;
					if(bytecount>0)then
						bytecount<=bytecount-1;
					else
						SECTSTATE<=IRAMRDAT;
						TRAMWDAT<='0' & x"00";
						if(MFM='1')then
							bytecount<=nmfmSynci -1;
						else
							bytecount<=nfmSynci -1;
						end if;
						state<=st_I2T_Synci;
						IRAMADDR<=CURIADDR+("00" & x"004");
					end if;
					TRAMWR<='1';
					CURTADDR<=CURTADDR+1;
					
				when st_I2T_Synci =>
					TRAMADDR<=CURTADDR;
					if(bytecount>0)then
						bytecount<=bytecount-1;
					else
						CRCCLR<='1';
						SECTORS<=conv_integer(IRAMRDAT);
						if(IRAMRDAT/=x"00")then
							IRAMADDR<=CURIADDR+("00" & x"000");
							if(SECTSTATE=x"a0")then
								CRCerr<='1';
							else
								CRCerr<='0';
							end if;
							if(MFM='1')then
								TRAMWDAT<='1' & x"a1";
								CRCWDAT<=x"a1";
							else
								TRAMWDAT<='1' & x"fe";
								CRCWDAT<=x"fe";
							end if;
							CRCWR<='1';
							state<=st_I2T_IAM0;
						else	--unformatted
							TRAMWDAT<='0' & x"4e";
							state<=st_I2T_GAP4;
						end if;
					end if;
					TRAMWR<='1';
					CURTADDR<=CURTADDR+1;
				when st_I2T_IAM0 =>
					if(CRCBUSY='0')then
						TRAMADDR<=CURTADDR;
						if(MFM='1')then
							state<=st_I2T_IAM1;
						else
							TRAMWDAT<='0' & IRAMRDAT;
							CRCWDAT<=IRAMRDAT;
							IRAMADDR<=CURIADDR+("00" & x"001");
							state<=st_I2T_C;
						end if;
						CRCWR<='1';
						TRAMWR<='1';
						CURTADDR<=CURTADDR+1;
					end if;
				when st_I2T_IAM1 =>
					if(CRCBUSY='0')then
						TRAMADDR<=CURTADDR;
						TRAMWR<='1';
						CRCWR<='1';
						CURTADDR<=CURTADDR+1;
						state<=st_I2T_IAM2;
					end if;
				when st_I2T_IAM2 =>
					if(CRCBUSY='0')then
						TRAMADDR<=CURTADDR;
						TRAMWDAT<='0' & x"fe";
						CRCWDAT<=x"fe";
						TRAMWR<='1';
						CRCWR<='1';
						CURTADDR<=CURTADDR+1;
						state<=st_I2T_IAM3;
					end if;
				when st_I2T_IAM3 =>
					if(CRCBUSY='0')then
						TRAMADDR<=CURTADDR;
						TRAMWDAT<='0' & IRAMRDAT;
						CRCWDAT<=IRAMRDAT;
						TRAMWR<='1';
						CRCWR<='1';
						IRAMADDR<=CURIADDR+("00" & x"001");
						CURTADDR<=CURTADDR+1;
						state<=st_I2T_C;
					end if;
				when st_I2T_C =>
					if(CRCBUSY='0')then
						TRAMADDR<=CURTADDR;
						TRAMWDAT<='0' & IRAMRDAT;
						CRCWDAT<=IRAMRDAT;
						TRAMWR<='1';
						CRCWR<='1';
						IRAMADDR<=CURIADDR+("00" & x"002");
						CURTADDR<=CURTADDR+1;
						state<=st_I2T_H;
					end if;
				when st_I2T_H =>
					if(CRCBUSY='0')then
						TRAMADDR<=CURTADDR;
						TRAMWDAT<='0' & IRAMRDAT;
						CRCWDAT<=IRAMRDAT;
						TRAMWR<='1';
						CRCWR<='1';
						IRAMADDR<=CURIADDR+("00" & x"003");
						CURTADDR<=CURTADDR+1;
						state<=st_I2T_R;
					end if;
				when st_I2T_R =>
					if(CRCBUSY='0')then
						TRAMADDR<=CURTADDR;
						TRAMWDAT<='0' & IRAMRDAT;
						CRCWDAT<=IRAMRDAT;
						TRAMWR<='1';
						CRCWR<='1';
						IRAMADDR<=CURIADDR+("00" & x"00e");
						CURTADDR<=CURTADDR+1;
						state<=st_I2T_N;
					end if;
				when st_I2T_N =>
					if(CRCBUSY='0')then
						SECTSIZE(7 downto 0)<=IRAMRDAT;
						IRAMADDR<=CURIADDR+("00" & x"00f");
						ramwait:=1;
						TRAMADDR<=CURTADDR;
						TRAMWDAT<='0' & CRCDAT(15 downto 8);
						TRAMWR<='1';
						CURTADDR<=CURTADDR+1;
						state<=st_I2T_CRCi0;
					end if;
				when st_I2T_CRCi0 =>
					SECTSIZE(15 downto 8)<=IRAMRDAT;
					TRAMADDR<=CURTADDR;
					TRAMWDAT<='0' & CRCDAT(7 downto 0);
					if(SECTSTATE=x"b0")then
						CRCerr<='1';
					else
						CRCerr<='0';
					end if;
					TRAMWR<='1';
					CRCCLR<='1';
					CURTADDR<=CURTADDR+1;
					state<=st_I2T_CRCi1;
				when st_I2T_CRCi1 =>
					TRAMADDR<=CURTADDR;
					if(MFM='1')then
						TRAMWDAT<='0' & x"4e";
						bytecount<=nmfmGap2 -1;
					else
						TRAMWDAT<='0' & x"ff";
						bytecount<=nfmGap2 -1;
					end if;
					TRAMWR<='1';
					CURTADDR<=CURTADDR+1;
					state<=st_I2T_GAP2;
				when st_I2T_GAP2 =>
					TRAMADDR<=CURTADDR;
					if(bytecount>0)then
						bytecount<=bytecount-1;
					else
						TRAMWDAT<='0' & x"00";
						if(MFM='1')then
							bytecount<=nmfmSyncd -1;
						else
							bytecount<=nfmSyncd -1;
						end if;
						state<=st_I2T_Syncd;
						CURIADDR<=CURIADDR+("00" & x"010");
					end if;
					TRAMWR<='1';
					CURTADDR<=CURTADDR+1;
				when st_I2T_Syncd =>
					TRAMADDR<=CURTADDR;
					if(bytecount>0)then
						bytecount<=bytecount-1;
					else
						if(MFM='1')then
							TRAMWDAT<='1' & x"a1";
							CRCWDAT<=x"a1";
						else
							if(SECTSTATE=x"10")then
								TRAMWDAT<='1' & x"f8";
								CRCWDAT<=x"f8";
							else
								TRAMWDAT<='1' & x"fb";
								CRCWDAT<=x"fb";
							end if;
						end if;
						IRAMADDR<=CURIADDR;
						CRCWR<='1';
						CURIADDR<=CURIADDR+1;
						state<=st_I2T_DAM0;
					end if;
					TRAMWR<='1';
					CURTADDR<=CURTADDR+1;
				when st_I2T_DAM0 =>
					if(CRCBUSY='0')then
						TRAMADDR<=CURTADDR;
						if(MFM='1')then
							state<=st_I2T_DAM1;
						else
							TRAMWDAT<='0' & IRAMRDAT;
							CRCWDAT<=IRAMRDAT;
							IRAMADDR<=CURIADDR;
							CURIADDR<=CURIADDR+1;
							ramwait:=1;
							state<=st_I2T_DATA;
							SECTSIZE<=SECTSIZE-1;
						end if;
						TRAMWR<='1';
						CRCWR<='1';
						CURTADDR<=CURTADDR+1;
					end if;
				when st_I2T_DAM1 =>
					if(CRCBUSY='0')then
						TRAMADDR<=CURTADDR;
						TRAMWR<='1';
						CRCWR<='1';
						CURTADDR<=CURTADDR+1;
						state<=st_I2T_DAM2;
					end if;
				when st_I2T_DAM2 =>
					if(CRCBUSY='0')then
						TRAMADDR<=CURTADDR;
						if(SECTSTATE=x"10")then
							TRAMWDAT<='0' & x"f8";
							CRCWDAT<=x"f8";
						else
							TRAMWDAT<='0' & x"fb";
							CRCWDAT<=x"fb";
						end if;
						TRAMWR<='1';
						CRCWR<='1';
						CURTADDR<=CURTADDR+1;
						state<=st_I2T_DAM3;
					end if;
				when st_I2T_DAM3 =>
					if(CRCBUSY='0')then
						TRAMADDR<=CURTADDR;
						TRAMWDAT<='0' & IRAMRDAT;
						CRCWDAT<=IRAMRDAT;
						IRAMADDR<=CURIADDR;
						CURIADDR<=CURIADDR+1;
						TRAMWR<='1';
						CRCWR<='1';
						state<=st_I2T_DATA;
						SECTSIZE<=SECTSIZE-1;
						CURTADDR<=CURTADDR+1;
					end if;
				when st_I2T_DATA =>
					if(CRCBUSY='0')then
						TRAMADDR<=CURTADDR;
						if(SECTSIZE/=x"0000")then
							IRAMADDR<=CURIADDR;
							SECTSIZE<=SECTSIZE-1;
							TRAMWDAT<='0' & IRAMRDAT;
							CRCWDAT<=IRAMRDAT;
							CURIADDR<=CURIADDR+1;
							CRCWR<='1';
						else
							CURIADDR<=CURIADDR-1;
							TRAMWDAT<='0' & CRCDAT(15 downto 8);
							state<=st_I2T_CRCd0;
						end if;
						TRAMWR<='1';
						CURTADDR<=CURTADDR+1;
					end if;
				when st_I2T_CRCd0 =>
					TRAMADDR<=CURTADDR;
					TRAMWDAT<='0' & CRCDAT(7 downto 0);
					TRAMWR<='1';
					CURTADDR<=CURTADDR+1;
					state<=st_I2T_CRCd1;
				when st_I2T_CRCd1 =>
					TRAMADDR<=CURTADDR;
					SECTCOUNT<=SECTCOUNT+1;
					if((SECTCOUNT+1)<SECTORS)then
						if(MFM='1')then
							TRAMWDAT<='0' & x"4e";
							bytecount<=nmfmGap1 -1;
						else
							TRAMWDAT<='0' & x"ff";
							bytecount<=nfmGap1 -1;
						end if;
						TRAMWR<='1';
						CURTADDR<=CURTADDR+1;
						state<=st_I2T_GAP1;
					else
						if(MFM='1')then
							TRAMWDAT<='0' & x"4e";
						else
							TRAMWDAT<='0' & x"ff";
						end if;
						TRAMWR<='1';
						CURTADDR<=CURTADDR+1;
						state<=st_I2T_GAP4;
					end if;
				when st_I2T_GAP4 =>
					if(CURTADDR<I2TTRACKLEN)then
						TRAMADDR<=CURTADDR;
						TRAMWR<='1';
						CURTADDR<=CURTADDR+1;
					else
						I2TBUSY<='0';
						state<=st_IDLE;
					end if;
				when st_T2I_COUNTSECTS =>
					SDAT3:=SDAT2;
					SDAT2:=SDAT1;
					SDAT1:=SDAT0;
					SDAT0:=TRAMRDAT;
					if(MFM='1')then
						if(SDAT3="1" & x"a1" and SDAT2="1" & x"a1" and SDAT1="1" & x"a1" and SDAT0="0" & x"fe")then
							SECTORS<=SECTORS+1;
						end if;
					else
						if(SDAT0="1" & x"fe")then
							SECTORS<=SECTORS+1;
						end if;
					end if;
					if(CURTADDR<T2ITRACKLEN)then
						TRAMADDR<=CURTADDR+1;
						CURTADDR<=CURTADDR+1;
					else
						if(SECTORS=0)then	--not formatted
							T2IBUSY<='0';
							state<=st_IDLE;
						else
							CURTADDR<=(others=>'0');
							state<=st_T2I_IAM0;
							CRCerr<='0';
							CRCCLR<='1';
						end if;
					end if;
				when st_T2I_IAM0 =>
					if(MFM='1')then
						if(TRAMRDAT='1' & x"a1")then
							CRCWDAT<=x"a1";
							CRCWR<='1';
							state<=st_T2I_IAM1;
						end if;
					else
						if(TRAMRDAT='1' & x"fe")then
							CRCWDAT<=x"a1";
							CRCWR<='1';
							state<=st_T2I_C;
						end if;
					end if;
					TRAMADDR<=CURTADDR+1;
					CURTADDR<=CURTADDR+1;
					ramwait:=1;
				when st_T2I_IAM1 =>
					if(CRCBUSY='0')then
						if(TRAMRDAT='1' & x"a1")then
							CRCWDAT<=x"a1";
							CRCWR<='1';
							state<=st_T2I_IAM2;
						else
							CRCCLR<='1';
							state<=st_T2I_IAM0;
						end if;
						TRAMADDR<=CURTADDR+1;
						CURTADDR<=CURTADDR+1;
					end if;
				when st_T2I_IAM2 =>
					if(CRCBUSY='0')then
						if(TRAMRDAT='1' & x"a1")then
							CRCWDAT<=x"a1";
							CRCWR<='1';
							state<=st_T2I_IAM3;
						else
							CRCCLR<='1';
							state<=st_T2I_IAM0;
						end if;
						TRAMADDR<=CURTADDR+1;
						CURTADDR<=CURTADDR+1;
					end if;
				when st_T2I_IAM3 =>
					if(CRCBUSY='0')then
						if(TRAMRDAT='0' & x"fe")then
							CRCWDAT<=x"fe";
							CRCWR<='1';
							state<=st_T2I_C;
						else
							CRCCLR<='1';
							state<=st_T2I_IAM0;
						end if;
						TRAMADDR<=CURTADDR+1;
						CURTADDR<=CURTADDR+1;
					end if;
				when st_T2I_C =>
					if(CRCBUSY='0')then
						IRAMADDR<=CURIADDR+("00" & x"000");
						IRAMWDAT<=TRAMRDAT(7 downto 0);
						CRCWDAT<=TRAMRDAT(7 downto 0);
						IRAMWR<='1';
						CRCWR<='1';
						state<=st_T2I_H;
						TRAMADDR<=CURTADDR+1;
						CURTADDR<=CURTADDR+1;
					end if;
				when st_T2I_H =>
					if(CRCBUSY='0')then
						IRAMADDR<=CURIADDR+("00" & x"001");
						IRAMWDAT<=TRAMRDAT(7 downto 0);
						CRCWDAT<=TRAMRDAT(7 downto 0);
						IRAMWR<='1';
						CRCWR<='1';
						state<=st_T2I_R;
						TRAMADDR<=CURTADDR+1;
						CURTADDR<=CURTADDR+1;
					end if;
				when st_T2I_R =>
					if(CRCBUSY='0')then
						IRAMADDR<=CURIADDR+("00" & x"002");
						IRAMWDAT<=TRAMRDAT(7 downto 0);
						CRCWDAT<=TRAMRDAT(7 downto 0);
						IRAMWR<='1';
						CRCWR<='1';
						state<=st_T2I_N;
						TRAMADDR<=CURTADDR+1;
						CURTADDR<=CURTADDR+1;
					end if;
				when st_T2I_N =>
					if(CRCBUSY='0')then
						IRAMADDR<=CURIADDR+("00" & x"003");
						IRAMWDAT<=TRAMRDAT(7 downto 0);
						CRCWDAT<=TRAMRDAT(7 downto 0);
						IRAMWR<='1';
						CRCWR<='1';
						state<=st_T2I_SECTORSL;
					end if;
				when st_T2I_SECTORSL =>
					IRAMADDR<=CURIADDR+("00" & x"004");
					IRAMWDAT<=conv_std_logic_vector(SECTORS,8);
					IRAMWR<='1';
					state<=st_T2I_SECTORSH;
				when st_T2I_SECTORSH =>
					IRAMADDR<=CURIADDR+("00" & x"005");
					IRAMWDAT<=x"00";
					IRAMWR<='1';				
					state<=st_T2I_SECTSIZEL;
				when st_T2I_SECTSIZEL =>
					IRAMADDR<=CURIADDR+("00" & x"00e");
					case TRAMRDAT(7 downto 0) is
					when  x"00" =>
						IRAMWDAT<=x"80";
					when others =>
						IRAMWDAT<=x"00";
					end case;
					IRAMWR<='1';
					state<=st_T2I_SECTSIZEH;
				when st_T2I_SECTSIZEH =>
					IRAMADDR<=CURIADDR+("00" & x"00f");
					case TRAMRDAT(7 downto 0) is
					when x"00" =>
						IRAMWDAT<=x"00";
						SECTSIZE<=x"0080";
					when x"01" =>
						IRAMWDAT<=x"01";
						SECTSIZE<=x"0100";
					when x"02" =>
						IRAMWDAT<=x"02";
						SECTSIZE<=x"0200";
					when x"03" =>
						IRAMWDAT<=x"04";
						SECTSIZE<=x"0400";
					when x"04" =>
						IRAMWDAT<=x"08";
						SECTSIZE<=x"0800";
					when x"05" =>
						IRAMWDAT<=x"10";
						SECTSIZE<=x"1000";
					when x"06" =>
						IRAMWDAT<=x"20";
						SECTSIZE<=x"2000";
					when others =>
						IRAMWDAT<=x"40";
						SECTSIZE<=x"4000";
					end case;
					state<=st_T2I_res0;
					IRAMWR<='1';
					TRAMADDR<=CURTADDR+1;
					CURTADDR<=CURTADDR+1;
				when st_T2I_res0 =>
					IRAMADDR<=CURIADDR+("00" & x"009");
					IRAMWDAT<=x"00";
					IRAMWR<='1';
					state<=st_T2I_res1;
				when st_T2I_res1 =>
					IRAMADDR<=CURIADDR+("00" & x"00a");
					IRAMWDAT<=x"00";
					IRAMWR<='1';
					state<=st_T2I_res2;
				when st_T2I_res2 =>
					IRAMADDR<=CURIADDR+("00" & x"00b");
					IRAMWDAT<=x"00";
					IRAMWR<='1';
					state<=st_T2I_res3;
				when st_T2I_res3 =>
					IRAMADDR<=CURIADDR+("00" & x"00c");
					IRAMWDAT<=x"00";
					IRAMWR<='1';
					state<=st_T2I_res4;
				when st_T2I_res4 =>
					IRAMADDR<=CURIADDR+("00" & x"00d");
					IRAMWDAT<=x"00";
					IRAMWR<='1';
					state<=st_T2I_MODE;
				when st_T2I_MODE =>
					IRAMADDR<=CURIADDR+("00" & x"006");
					if(MFM='1')then
						IRAMWDAT<=x"00";
					else
						IRAMWDAT<=x"40";
					end if;
					IRAMWR<='1';
					state<=st_T2I_CRCi0;
				when st_T2I_CRCi0 =>
					if(CRCBUSY='0')then
						CRCWDAT<=TRAMRDAT(7 downto 0);
						TRAMADDR<=CURTADDR+1;
						CURTADDR<=CURTADDR+1;
						CRCWR<='1';
						state<=st_T2I_CRCi1;
					end if;
				when st_T2I_CRCi1 =>
					if(CRCBUSY='0')then
						CRCWDAT<=TRAMRDAT(7 downto 0);
						TRAMADDR<=CURTADDR+1;
						CURTADDR<=CURTADDR+1;
						CRCWR<='1';
						state<=st_T2I_STATE1;
					end if;
				when st_T2I_STATE1 =>
					if(CRCBUSY='0')then
						IRAMADDR<=CURIADDR+("00" & x"008");
						STATEADDR<=CURIADDR+("00" & x"008");
						if(CRCZERO='1')then
							IRAMWDAT<=x"00";
						else
							IRAMWDAT<=x"a0";
						end if;
						IRAMWR<='1';
						state<=st_T2I_DAM0;
						CRCCLR<='1';
					end if;
				when st_T2I_DAM0 =>
					IRAMADDR<=STATEADDR;
					if(MFM='1')then
						if(TRAMRDAT='1' & x"a1")then
							CRCWDAT<=x"a1";
							CRCWR<='1';
							state<=st_T2I_DAM1;
						end if;
					else
						if(TRAMRDAT='1' & x"fb")then
							CRCWDAT<=x"fb";
							CRCWR<='1';
							DELETED<='0';
							state<=st_T2I_DELETED;
						elsif(TRAMRDAT='1' & x"f8")then
							CRCWDAT<=x"f8";
							CRCWR<='1';
							state<=st_T2I_DELETED;
							DELETED<='1';
							IRAMWDAT<=IRAMRDAT or x"10";
							IRAMWR<='1';
						end if;
					end if;
					TRAMADDR<=CURTADDR+1;
					CURTADDR<=CURTADDR+1;
					ramwait:=1;
				when st_T2I_DAM1 =>
					if(CRCBUSY='0')then
						if(TRAMRDAT='1' & x"a1")then
							CRCWDAT<=x"a1";
							CRCWR<='1';
							state<=st_T2I_DAM2;
						else
							CRCCLR<='1';
							state<=st_T2I_DAM0;
						end if;
						TRAMADDR<=CURTADDR+1;
						CURTADDR<=CURTADDR+1;
					end if;
				when st_T2I_DAM2 =>
					if(CRCBUSY='0')then
						if(TRAMRDAT='1' & x"a1")then
							CRCWDAT<=x"a1";
							CRCWR<='1';
							state<=st_T2I_DAM3;
						else
							CRCCLR<='1';
							state<=st_T2I_DAM0;
						end if;
						TRAMADDR<=CURTADDR+1;
						CURTADDR<=CURTADDR+1;
					end if;
				when st_T2I_DAM3 =>
					if(CRCBUSY='0')then
						if(TRAMRDAT='0' & x"f8")then
							CRCWDAT<=x"f8";
							CRCWR<='1';
							DELETED<='1';
							state<=st_T2I_DELETED;
							IRAMWDAT<=IRAMRDAT or x"10";
							IRAMWR<='1';
						elsif(TRAMRDAT='0' & x"fb")then
							CRCWDAT<=x"fb";
							CRCWR<='1';
							DELETED<='0';
							state<=st_T2I_DELETED;
						else
							CRCCLR<='1';
							state<=st_T2I_DAM0;
						end if;
						TRAMADDR<=CURTADDR+1;
						CURTADDR<=CURTADDR+1;
					end if;
				when st_T2I_DELETED =>
					IRAMADDR<=CURIADDR+("00" & x"007");
					if(DELETED='1')then
						IRAMWDAT<=x"10";
					else
						IRAMWDAT<=x"00";
					end if;
					IRAMWR<='1';
					CURIADDR<=CURIADDR+("00" & x"010");
					state<=st_T2I_DATA;
				when st_T2I_DATA =>
					if(CRCBUSY='0')then
						IRAMADDR<=CURIADDR;
						IRAMWDAT<=TRAMRDAT(7 downto 0);
						CRCWDAT<=TRAMRDAT(7 downto 0);
						IRAMWR<='1';
						CRCWR<='1';
						CURIADDR<=CURIADDR+1;
						TRAMADDR<=CURTADDR+1;
						CURTADDR<=CURTADDR+1;
						if(SECTSIZE=x"0001")then
							state<=st_T2I_CRCd0;
						else
							SECTSIZE<=SECTSIZE-1;
						end if;
					end if;
				when st_T2I_CRCd0 =>
					if(CRCBUSY='0')then
						CRCWDAT<=TRAMRDAT(7 downto 0);
						CRCWR<='1';
						TRAMADDR<=CURTADDR+1;
						CURTADDR<=CURTADDR+1;
						IRAMADDR<=STATEADDR;
						state<=st_T2I_CRCd1;
					end if;
				when st_T2I_CRCd1 =>
					if(CRCBUSY='0')then
						CRCWDAT<=TRAMRDAT(7 downto 0);
						CRCWR<='1';
						TRAMADDR<=CURTADDR+1;
						CURTADDR<=CURTADDR+1;
						state<=st_T2I_STATE2;
					end if;
				when st_T2I_STATE2 =>
					if(CRCBUSY='0')then
						if(CRCZERO='0')then
							IRAMWDAT<=IRAMRDAT or x"b0";
							IRAMWR<='1';
						end if;
						if((SECTCOUNT+1)=SECTORS)then
							T2IBUSY<='0';
							state<=st_IDLE;
						else
							SECTCOUNT<=SECTCOUNT+1;
							CRCCLR<='1';
							state<=st_T2I_IAM0;
						end if;
					end if;
				when others =>
					CURTADDR<=(others=>'0');
					CURIADDR<=(others=>'0');
					TRAMADDR<=(others=>'0');
					IRAMADDR<=(others=>'0');
					state<=st_IDLE;
				end case;
			end if;
			lT2I:=T2IREQ;
			lI2T:=I2TREQ;
		end if;
	end process;
	
	CRCclrdat<=(others=>'1') when CRCerr='0' else (others=>'0');
	CRC	:CRCGENN generic map(8,16) port map(
		POLY	=>"10000100000010001",
		DATA	=>CRCWDAT,
		DIR		=>'0',
		WRITE	=>CRCWR,
		BITIN	=>'0',
		BITWR	=>'0',
		CLR		=>CRCclr,
		CLRDAT	=>CRCclrdat,
		CRC		=>CRCDAT,
		BUSY	=>CRCbusy,
		DONE	=>open,
		CRCZERO	=>CRCZero,

		clk		=>clk,
		rstn	=>rstn
	);
	CRCMON<=CRCDAT;
	
end rtl;
