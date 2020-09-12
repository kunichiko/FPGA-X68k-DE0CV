LIBRARY	IEEE;
USE	IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_ARITH.ALL;
USE	IEEE.STD_LOGIC_UNSIGNED.ALL;
use work.FDC_timing.all;

entity FDcopy is
generic(
	sysclk		:integer	:=20000;
	maxtrack	:integer	:=85;
	seekstep	:integer	:=3;		--msec
	seekset		:integer	:=30;
	toutlen	:integer	:=2000;	--msec
	contlen	:integer	:=2000
);
port(
	ramaddr	:out std_logic_vector(23 downto 0);
	ramrdat	:in std_logic_vector(15 downto 0);
	ramwdat	:out std_logic_vector(15 downto 0);
	ramwr	:out std_logic;
	ramwait	:in std_logic;
	tracklen	:out std_logic_vector(13 downto 0);

	fdmode		:in std_logic_vector(1 downto 0);
	mfm			:in std_logic;
	unit		:in std_logic;
	emunit		:in std_logic_vector(1 downto 0);
	track		:in std_logic_vector(6 downto 0);
	head		:in std_logic;
	recarib		:in std_logic;
	seek		:in std_logic;
	wrdisk		:in std_logic;
	rddisk		:in std_logic;
	busy		:out std_logic;
	control	:out std_logic;
	error		:out std_logic;
	
	USELn	:out std_logic_vector(1 downto 0);
	MOTORn	:out std_logic_vector(1 downto 0);
	READYn	:in std_logic;
	WRENn	:out std_logic;		--pin24
	WRBITn	:out std_logic;		--pin22
	RDBITn	:in std_logic;		--pin30
	STEPn	:out std_logic;		--pin20
	SDIRn	:out std_logic;		--pin18
	WPRTn	:in std_logic;		--pin28
	track0n	:in std_logic;		--pin26
	indexn	:in std_logic;		--pin8
	siden	:out std_logic;		--pin32

	clk		:in std_logic;
	rstn	:in std_logic
);
end FDcopy;

architecture rtl of FDcopy is
component fmmod
port(
	txdat	:in std_logic_vector(7 downto 0);
	txwr	:in std_logic;
	txmf8	:in std_logic;
	txmfb	:in std_logic;
	txmfc	:in std_logic;
	txmfe	:in std_logic;
	break	:in std_logic;
	
	txemp	:out std_logic;
	txend	:out std_logic;
	
	bitout	:out std_logic;
	writeen	:out std_logic;
	
	sft		:in std_logic;
	clk		:in std_logic;
	rstn	:in std_logic
);
end component;

component mfmmod
port(
	txdat	:in std_logic_vector(7 downto 0);
	txwr	:in std_logic;
	txma1	:in std_logic;
	txmc2	:in std_logic;
	break	:in std_logic;
	
	txemp	:out std_logic;
	txend	:out std_logic;
	
	bitout	:out std_logic;
	writeen	:out std_logic;
	
	sft		:in std_logic;
	clk		:in std_logic;
	rstn	:in std_logic
);
end component;

component fmdem
generic(
	bwidth	:integer	:=22
);
port(
	bitlen	:in integer range 0 to bwidth;
	
	datin	:in std_logic;
	
	init	:in std_logic;
	break	:in std_logic;
	
	RXDAT	:out std_logic_vector(7 downto 0);
	RXED	:out std_logic;
	DetMF8	:out std_logic;
	DetMFB	:out std_logic;
	DetMFC	:out std_logic;
	DetMFE	:out std_logic;
	broken	:out std_logic;
	
	curlen	:out integer range 0 to bwidth*2;
	
	clk		:in std_logic;
	rstn	:in std_logic
);
end component;

component mfmdem
generic(
	bwidth	:integer	:=22
);
port(
	bitlen	:in integer range 0 to bwidth;
	
	datin	:in std_logic;
	
	init	:in std_logic;
	break	:in std_logic;
	
	RXDAT	:out std_logic_vector(7 downto 0);
	RXED	:out std_logic;
	DetMA1	:out std_logic;
	DetMC2	:out std_logic;
	broken	:out std_logic;
	
	curlen	:out integer range 0 to bwidth*2;
	
	clk		:in std_logic;
	rstn	:in std_logic
);
end component;

component headseek
generic(
	maxtrack	:integer	:=79;
	maxset		:integer	:=10;
	initseek	:integer	:=0
);
port(
	desttrack	:in integer range 0 to maxtrack;
	destset		:in std_logic;
	setwait		:in integer range 0 to maxset;		--settling time
	
	curtrack	:out integer range 0 to maxtrack;
	
	reachtrack	:out std_logic;
	busy		:out std_logic;
	
	track0		:in std_logic;
	seek		:out std_logic;
	sdir		:out std_logic;
	
	init		:in std_logic;
	seekerr		:out std_logic;
	
	sft			:in std_logic;
	clk			:in std_logic;
	rstn		:in std_logic
);
end component;

component sftgen
generic(
	maxlen	:integer	:=100
);
port(
	len		:in integer range 0 to maxlen;
	sft		:out std_logic;
	
	clk		:in std_logic;
	rstn	:in std_logic
);
end component;

component  DIGIFILTER
	generic(
		TIME	:integer	:=2;
		DEF		:std_logic	:='0'
	);
	port(
		D	:in std_logic;
		Q	:out std_logic;

		clk	:in std_logic;
		rstn :in std_logic
	);
end component;

component signext
generic(
	extmax	:integer	:=10
);
port(
	len		:in integer range 0 to extmax;
	signin	:in std_logic;
	
	signout	:out std_logic;
	
	clk		:in std_logic;
	rstn	:in std_logic
);
end component;

constant maxbwidth	:integer	:=BR_300_D*sysclk/1000000;
constant extcount	:integer	:=(sysclk*WR_WIDTH)/1000000;

type state_t is(
	st_idle,
	st_recarib,
	st_seek,
	st_readdisk,
	st_writedisk
);
signal	state	:state_t;

type intstate_t is(
	is_idle,
	is_waitready,
	is_waitindex,
	is_read,
	is_write,
	is_writew,
	is_writep,
	is_sync0,
	is_sync0w,
	is_sync0p,
	is_sync1,
	is_sync1w,
	is_sync1p,
	is_gap0,
	is_gap0w,
	is_gap0p,
	is_gap1,
	is_gap1w,
	is_gap1p
);
signal	intstate	:intstate_t;

signal	ramwaits		:std_logic;

signal	seeksft		:std_logic;
signal	itrack		:integer range 0 to maxtrack-1;
signal	icurtrack	:integer range 0 to maxtrack-1;
signal	curtrack	:std_logic_vector(6 downto 0);
signal	seek_recarib	:std_logic;
signal	seek_set		:std_logic;
signal	seek_done		:std_logic;
signal	seek_err		:std_logic;
signal	int_begin		:std_logic;
signal	int_done		:std_logic;
signal	int_error		:std_logic;
signal	curpos		:std_logic_vector(13 downto 0);
signal	indexb,lindex	:std_logic;

signal	deminit		:std_logic;
signal	dembreak	:std_logic;
signal	fmrxdat		:std_logic_vector(7 downto 0);
signal	fmrxed		:std_logic;
signal	fmmf8det	:std_logic;
signal	fmmfbdet	:std_logic;
signal	fmmfcdet	:std_logic;
signal	fmmfedet	:std_logic;
signal	fmbroken	:std_logic;
signal	fmcurwid	:integer range 0 to maxbwidth*2;
signal	mfmrxdat	:std_logic_vector(7 downto 0);
signal	mfmrxed		:std_logic;
signal	mfmma1det	:std_logic;
signal	mfmmc2det	:std_logic;
signal	mfmbroken	:std_logic;
signal	mfmcurwid	:integer range 0 to maxbwidth;

signal	txdat		:std_logic_vector(7 downto 0);
signal	fmtxwr		:std_logic;
signal	mfmtxwr		:std_logic;
signal	fmmf8wr		:std_logic;
signal	fmmfbwr		:std_logic;
signal	fmmfcwr		:std_logic;
signal	fmmfewr		:std_logic;
signal	mfmma1wr	:std_logic;
signal	mfmmc2wr	:std_logic;
signal	fmtxemp		:std_logic;
signal	mfmtxemp	:std_logic;
signal	fmwrbit		:std_logic;
signal	mfmwrbit	:std_logic;
signal	fmwren		:std_logic;
signal	mfmwren		:std_logic;
signal	fmtxend		:std_logic;
signal	mfmtxend	:std_logic;
signal	modsftfm	:std_logic;
signal	modsftmfm	:std_logic;
signal	modbreak	:std_logic;
signal	wrbits		:std_logic;
signal	wrens		:std_logic;
signal	wrbitex		:std_logic;
signal	wrenex		:std_logic;
signal	bitwidth	:integer range 0 to maxbwidth*2;
signal	seekerrd	:std_logic;

constant bit_mc		:integer	:=8;
constant bit_mfm	:integer	:=9;
constant bit_wrote	:integer	:=10;
constant toutval		:integer	:=(toutlen*2)-1;
signal	toutcount	:integer range 0 to toutval;
constant	gap0len	:integer	:=60;
constant	gap1len	:integer	:=8;
constant synclen	:integer	:=12;
signal	gccount	:integer range 0 to gap0len-1;
--signal	turns			:integer range 0 to 1;
signal	contcount	:integer range 0 to (contlen*2)-1;

begin

	process(clk,rstn)begin
		if(rstn='0')then
			state<=st_idle;
			seek_recarib<='0';
			seek_set<='0';
			int_begin<='0';
			error<='0';
		elsif(clk' event and clk='1')then
			seek_recarib<='0';
			seek_set<='0';
			int_begin<='0';
			case state is
			when st_idle =>
				if(recarib='1')then
					seek_recarib<='1';
					state<=st_recarib;
					error<='0';
				elsif(seek='1')then
					seek_set<='1';
					state<=st_seek;
					error<='0';
				elsif(rddisk='1')then
					int_begin<='1';
					state<=st_readdisk;
					error<='0';
				elsif(wrdisk='1')then
					int_begin<='1';
					state<=st_writedisk;
					error<='0';
				end if;
			when st_recarib | st_seek =>
				if(seek_err='1')then
					state<=st_idle;
					error<='1';
				elsif(seek_done='1')then
					state<=st_idle;
					error<='0';
				end if;
			when st_readdisk |st_writedisk =>
				if(int_error='1')then
					state<=st_idle;
					error<='1';
				elsif(int_done='1')then
					state<=st_idle;
					error<='0';
				end if;
			when others =>
			end case;
		end if;
	end process;
	
	itrack<=conv_integer(track);
	busy<='0' when state=st_idle else '1';
	
	seeker	:headseek generic map(
		maxtrack	=>maxtrack,
		maxset		=>30,
		initseek	=>0
	)port map(
		desttrack	=>itrack,
		destset		=>seek_set,
		setwait		=>seekset,
		
		curtrack	=>icurtrack,
		
		reachtrack	=>seek_done,
		busy		=>open,
		
		track0		=>track0n,
		seek		=>STEPn,
		sdir		=>SDIRn,
		
		init		=>seek_recarib,
		seekerr		=>seek_err,
		
		sft			=>seeksft,
		clk			=>clk,
		rstn		=>rstn
	);
				
	ssft	:sftgen generic map(sysclk*seekstep/2)port map(sysclk*seekstep/2,seeksft,clk,rstn);

	ixflt	:DIGIFILTER generic map(1,'1') port map(indexn,indexb,clk,rstn);
	
	process(clk)begin
		if(clk' event and clk='1')then
			ramwaits<=ramwait;
		end if;
	end process;
	
	process(clk,rstn)
	variable rwait	:integer range 0 to 3;
	begin
		if(rstn='0')then
			intstate<=is_idle;
			ramwdat<=(others=>'0');
			ramwr<='0';
			int_done<='0';
			int_error<='0';
			lindex<='1';
			deminit<='0';
			curpos<=(others=>'0');
			txdat<=(others=>'0');
			fmtxwr<='0';
			mfmtxwr<='0';
			fmmf8wr<='0';
			fmmfbwr<='0';
			fmmfcwr<='0';
			fmmfewr<='0';
			mfmma1wr<='0';
			mfmmc2wr<='0';
			modbreak<='0';
			dembreak<='0';
			toutcount<=0;
			rwait:=0;
--			turns<=0;
		elsif(clk' event and clk='1')then
			int_done<='0';
			int_error<='0';
			lindex<=indexb;
			deminit<='0';
			txdat<=(others=>'0');
			fmtxwr<='0';
			mfmtxwr<='0';
			fmmf8wr<='0';
			fmmfbwr<='0';
			fmmfcwr<='0';
			fmmfewr<='0';
			mfmma1wr<='0';
			mfmmc2wr<='0';
			modbreak<='0';
			dembreak<='0';
			case state is
			when st_readdisk =>
				case intstate is
				when is_idle =>
					if(int_begin='1')then
						intstate<=is_gap0;
						toutcount<=toutval;
						curpos<=(others=>'0');
						if(mfm='1')then
							gccount<=gap0len-1;
							ramwdat<=x"064e";
						else
							gccount<=(gap0len/2)-1;
							ramwdat<=x"04ff";
						end if;
					end if;
				when is_gap0 =>
					if(ramwaits='0')then
						ramwr<='1';
						rwait:=3;
						intstate<=is_gap0w;
					end if;
				when is_gap0w =>
					if(rwait>0)then
						rwait:=rwait-1;
					elsif(ramwaits='0')then
						ramwr<='0';
						intstate<=is_gap0p;
					end if;
				when is_gap0p	=>
					curpos<=curpos+1;
					if(gccount>0)then
						gccount<=gccount-1;
						intstate<=is_gap0;
					else
						if(mfm='1')then
							gccount<=synclen-1;
							ramwdat<=x"0600";
						else
							gccount<=(synclen/2)-1;
							ramwdat<=x"0400";
						end if;
						intstate<=is_sync0;
					end if;
				when is_sync0 =>
					if(ramwaits='0')then
						ramwr<='1';
						rwait:=3;
						intstate<=is_sync0w;
					end if;
				when is_sync0w =>
					if(rwait>0)then
						rwait:=rwait-1;
					elsif(ramwaits='0')then
						ramwr<='0';
						intstate<=is_sync0p;
					end if;
				when is_sync0p =>
					curpos<=curpos+1;
					if(gccount>0)then
						gccount<=gccount-1;
						intstate<=is_sync0;
					else
						intstate<=is_waitready;
					end if;
				when is_waitready =>
					if(READYn='0')then
						toutcount<=toutval;
						intstate<=is_waitindex;
					elsif(seeksft='1')then
						if(toutcount>0)then
							toutcount<=toutcount-1;
						else
							int_error<='1';
							intstate<=is_idle;
						end if;
					end if;
				when is_waitindex =>
					if(lindex='1' and indexb='0')then
						deminit<='1';
						intstate<=is_read;
					elsif(seeksft='1')then
						if(toutcount>0)then
							toutcount<=toutcount-1;
						else
							int_error<='1';
							intstate<=is_idle;
						end if;
					end if;
				when is_read =>
					if(lindex='1' and indexb='0')then
						int_done<='1';
						dembreak<='1';
						intstate<=is_idle;
					elsif(mfm='1')then
						if(mfmbroken='1')then
							intstate<=is_sync1;
							gccount<=gap1len-1;
							ramwdat<=x"064e";
						elsif(mfmrxed='1')then
							ramwdat<=x"06" & mfmrxdat;
							intstate<=is_write;
						elsif(mfmma1det='1')then
							ramwdat<=x"07a1";
							intstate<=is_write;
						elsif(mfmmc2det='1')then
							ramwdat<=x"07c2";
							intstate<=is_write;
						end if;
					else
						if(fmbroken='1')then
							intstate<=is_gap1;
							gccount<=(gap1len/2)-1;
							ramwdat<=x"04ff";
						elsif(fmrxed='1')then
							ramwdat<=x"04" & fmrxdat;
							intstate<=is_write;
						elsif(fmmf8det='1')then
							ramwdat<=x"05f8";
							intstate<=is_write;
						elsif(fmmfbdet='1')then
							ramwdat<=x"05fb";
							intstate<=is_write;
						elsif(fmmfcdet='1')then
							ramwdat<=x"05fc";
							intstate<=is_write;
						elsif(fmmfedet='1')then
							ramwdat<=x"05fe";
							intstate<=is_write;
						end if;
					end if;
				when is_write	=>
					if(lindex='1' and indexb='0')then
						int_done<='1';
						dembreak<='1';
						ramwr<='0';
						intstate<=is_idle;
					elsif(ramwaits='0')then
						ramwr<='1';
						rwait:=3;
						intstate<=is_writew;
					end if;
				when is_writew =>
					if(lindex='1' and indexb='0')then
						int_done<='1';
						dembreak<='1';
						ramwr<='0';
						intstate<=is_idle;
					elsif(rwait>0)then
						rwait:=rwait-1;
					elsif(ramwaits='0')then
						ramwr<='0';
						intstate<=is_writep;
					end if;
				when is_writep	=>
					if(lindex='1' and indexb='0')then
						int_done<='1';
						dembreak<='1';
						ramwr<='0';
						intstate<=is_idle;
					else
						curpos<=curpos+1;
						intstate<=is_read;
					end if;
				when is_gap1	=>
					if(lindex='1' and indexb='0')then
						int_done<='1';
						dembreak<='1';
						ramwr<='0';
						intstate<=is_idle;
					elsif(ramwaits='0')then
						ramwr<='1';
						rwait:=3;
						intstate<=is_gap1w;
					end if;
				when is_gap1w	=>
					if(lindex='1' and indexb='0')then
						int_done<='1';
						dembreak<='1';
						ramwr<='0';
						intstate<=is_idle;
					elsif(rwait>0)then
						rwait:=rwait-1;
					elsif(ramwaits='0')then
						ramwr<='0';
						intstate<=is_gap1p;
					end if;
				when is_gap1p =>
					if(lindex='1' and indexb='0')then
						int_done<='1';
						dembreak<='1';
						ramwr<='0';
						intstate<=is_idle;
					else
						curpos<=curpos+1;
						if(gccount>0)then
							gccount<=gccount-1;
							intstate<=is_gap1;
						else
							if(mfm='1')then
								gccount<=synclen-1;
								ramwdat<=x"0600";
							else
								gccount<=(synclen/2)-1;
								ramwdat<=x"0400";
							end if;
							intstate<=is_sync1;
						end if;
					end if;
				when is_sync1	=>
					if(lindex='1' and indexb='0')then
						int_done<='1';
						dembreak<='1';
						ramwr<='0';
						intstate<=is_idle;
					elsif(ramwaits='0')then
						ramwr<='1';
						rwait:=3;
						intstate<=is_sync1w;
					end if;
				when is_sync1w	=>
					if(lindex='1' and indexb='0')then
						int_done<='1';
						dembreak<='1';
						ramwr<='0';
						intstate<=is_idle;
					elsif(rwait>0)then
						rwait:=rwait-1;
					elsif(ramwaits='0')then
						ramwr<='0';
						intstate<=is_sync1p;
					end if;
				when is_sync1p =>
					if(lindex='1' and indexb='0')then
						int_done<='1';
						dembreak<='1';
						ramwr<='0';
						intstate<=is_idle;
					else
						curpos<=curpos+1;
						if(gccount>0)then
							gccount<=gccount-1;
							intstate<=is_sync1;
						else
							intstate<=is_read;
						end if;
					end if;
				when others =>
					intstate<=is_idle;
				end case;
			when st_writedisk =>
				case intstate is
				when is_idle =>
					if(int_begin='1')then
						intstate<=is_waitready;
						toutcount<=toutval;
					end if;
				when is_waitready =>
					if(READYn='0')then
						if(WPRTn='0')then
							int_error<='1';
							intstate<=is_idle;
						else
							toutcount<=toutval;
							curpos<=(others=>'0');
							intstate<=is_waitindex;
						end if;
					elsif(seeksft='1')then
						if(toutcount>0)then
							toutcount<=toutcount-1;
						else
							int_error<='1';
							intstate<=is_idle;
						end if;
					end if;
				when is_waitindex =>
					if(lindex='1' and indexb='0')then
						rwait:=3;
						intstate<=is_read;
					elsif(seeksft='1')then
						if(toutcount>0)then
							toutcount<=toutcount-1;
						else
							int_error<='1';
							intstate<=is_idle;
						end if;
					end if;
				when is_read =>
					if(lindex='1' and indexb='0')then
						modbreak<='1';
						int_done<='1';
						intstate<=is_idle;
					elsif(rwait>0)then
						rwait:=rwait-1;
					elsif(ramwaits='0')then
						if(mfmtxemp='1' and fmtxemp='1')then
							if(ramrdat(bit_mfm)='1')then
								if(ramrdat(8 downto 0)="1" & x"a1")then
									mfmma1wr<='1';
								elsif(ramrdat(8 downto 0)="1" & x"c2")then
									mfmmc2wr<='1';
								else
									txdat<=ramrdat(7 downto 0);
									mfmtxwr<='1';
								end if;
							else
								if(ramrdat(8 downto 0)="1" & x"f8")then
									fmmf8wr<='1';
								elsif(ramrdat(8 downto 0)="1" & x"fb")then
									fmmfbwr<='1';
								elsif(ramrdat(8 downto 0)="1" & x"fc")then
									fmmfcwr<='1';
								elsif(ramrdat(8 downto 0)="1" & x"fe")then
									fmmfewr<='1';
								else
									txdat<=ramrdat(7 downto 0);
									fmtxwr<='1';
								end if;
							end if;
							intstate<=is_write;
						end if;
					end if;
				when is_write =>
					if(lindex='1' and indexb='0')then
						modbreak<='1';
						int_done<='1';
						intstate<=is_idle;
					else
						curpos<=curpos+1;
						rwait:=3;
						intstate<=is_read;
					end if;
				when others =>
					intstate<=is_idle;
				end case;
			when others =>
			end case;
		end if;
	end process;
			
	curtrack<=conv_std_logic_vector(icurtrack,7);
	ramaddr<=emunit & curtrack & head & curpos;
	siden<=not head;
	
	bitwidth<=	BR_300_D*sysclk/1000000 when fdmode="00" else	--2D
					BR_300_D*sysclk/1000000 when fdmode="01" else	--2DD
					BR_360_H*sysclk/1000000 when fdmode="10" else	--2HD
					BR_300_I*sysclk/1000000 when fdmode="11" else	--1.44M
					0;
	
	FMD	:fmdem generic map(
		bwidth	=>maxbwidth
	)
	port map(
		bitlen	=>bitwidth,
		
		datin	=>RDBITn,
		
		init	=>deminit,
		break	=>dembreak,
		
		RXDAT	=>fmrxdat,
		RXED	=>fmrxed,
		DetMF8	=>fmmf8det,
		DetMFB	=>fmmfbdet,
		DetMFC	=>fmmfcdet,
		DetMFE	=>fmmfedet,
		
		curlen	=>fmcurwid,
		
		clk		=>clk,
		rstn	=>rstn
	);

	MFMD:mfmdem generic map(
		bwidth	=>maxbwidth/2
	)
	port map(
		bitlen	=>bitwidth/2,
		
		datin	=>RDBITn,
		
		init	=>deminit,
		break	=>dembreak,
		
		RXDAT	=>mfmrxdat,
		RXED	=>mfmrxed,
		DetMA1	=>mfmma1det,
		DetMC2	=>mfmmc2det,
		
		curlen	=>mfmcurwid,
		
		clk		=>clk,
		rstn	=>rstn
	);

	sgenfm:sftgen generic map(maxbwidth*2) port map(
		len		=>bitwidth,
		sft		=>modsftfm,
		
		clk		=>clk,
		rstn	=>rstn
	);

	sgenmfm:sftgen generic map(maxbwidth) port map(
		len		=>bitwidth/2,
		sft		=>modsftmfm,
		
		clk		=>clk,
		rstn	=>rstn
	);

	FMM	:fmmod
	port map(
		txdat	=>txdat,
		txwr	=>fmtxwr,
		txmf8	=>fmmf8wr,
		txmfb	=>fmmfbwr,
		txmfc	=>fmmfcwr,
		txmfe	=>fmmfewr,
		break	=>modbreak,
		
		txemp	=>fmtxemp,
		txend	=>fmtxend,
		
		bitout	=>fmwrbit,
		writeen	=>fmwren,
		
		sft		=>modsftfm,
		clk		=>clk,
		rstn	=>rstn
	);

	MFMM :mfmmod
	port map(
		txdat	=>txdat,
		txwr	=>mfmtxwr,
		txma1	=>mfmma1wr,
		txmc2	=>mfmmc2wr,
		break	=>modbreak,
		
		txemp	=>mfmtxemp,
		txend	=>mfmtxend,
		
		bitout	=>mfmwrbit,
		writeen	=>mfmwren,
		
		sft		=>modsftmfm,
		clk		=>clk,
		rstn	=>rstn
	);

	wrbits<=fmwrbit or mfmwrbit;
	wrens<=fmwren or mfmwren;
	
	wbext	:signext generic map(extcount) port map(extcount,wrbits,wrbitex,clk,rstn);
	weext	:signext generic map(extcount) port map(extcount,wrens,wrenex,clk,rstn);
	
	WRENn<=not wrenex;
	WRBITn<=not wrbitex;
	
	tracklen<=	conv_std_logic_vector( 6250,14) when fdmode="00" else
					conv_std_logic_vector( 6250,14) when fdmode="01" else
					conv_std_logic_vector(10416,14) when fdmode="10" else
					conv_std_logic_vector(12500,14) when fdmode="11" else
					(others=>'0');
	process(clk,rstn)begin
		if(rstn='0')then
			contcount<=0;
			MOTORn<="11";
			USELn<="11";
			control<='0';
		elsif(clk' event and clk='1')then
			if(state/=st_idle)then
				control<='1';
				if(unit='0')then
					MOTORn<="10";
					USELn<="10";
				else
					MOTORn<="01";
					USELn<="01";
				end if;
				contcount<=(contlen*2)-1;
			elsif(seeksft='1')then
				if(contcount>0)then
					contcount<=contcount-1;
				else
					MOTORn<="11";
					USELn<="11";
					control<='0';
				end if;
			end if;
		end if;
	end process;
				

end rtl;