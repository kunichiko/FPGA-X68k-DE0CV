library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity romcopy is
generic(
	BGNADDR	:std_logic_vector(23 downto 0)	:=x"700000";
	ENDADDR	:std_logic_vector(23 downto 0)	:=x"7fffff";
	AWIDTH	:integer	:=20
);
port(
	addr	:out std_logic_vector(AWIDTH-1 downto 0);
	wdat	:out std_logic_vector(7 downto 0);
	aen		:out std_logic;
	wr		:out std_logic;
	ack		:in std_logic;
	done	:out std_logic;
	
	clk		:in std_logic;
	rstn	:in std_logic
);
end romcopy;

architecture rtl of romcopy is
type state_t is (
	st_INIT,
	st_BGN,
	st_BUSY,
	st_WRITE,
	st_DONE
);
signal	state	:state_t;
signal	rden	:std_logic;
signal	rdbgn	:std_logic;
signal	reset	:std_logic;
signal	rxed	:std_logic;
signal	readaddr	:std_logic_vector(23 downto 0);
signal	curaddr	:std_logic_vector(23 downto 0);
signal	addra	:std_logic_vector(23 downto 0);

component asmicont
	PORT
	(
		addr		: IN STD_LOGIC_VECTOR (23 DOWNTO 0);
		clkin		: IN STD_LOGIC ;
		rden		: IN STD_LOGIC ;
		read		: IN STD_LOGIC ;
		reset		: IN STD_LOGIC ;
		busy		: OUT STD_LOGIC ;
		data_valid		: OUT STD_LOGIC ;
		dataout		: OUT STD_LOGIC_VECTOR (7 DOWNTO 0);
		read_address		: OUT STD_LOGIC_VECTOR (23 DOWNTO 0)
	);
END component;
begin
	reset<=not rstn;
	ROM	:asmicont port map(
		addr		=>readaddr,
		clkin		=>clk,
		rden		=>rdbgn,
		read		=>rdbgn,
		reset		=>reset,
		busy		=>open,
		data_valid	=>rxed,
		dataout		=>wdat,
		read_address=>curaddr
	);
	
	process(clk,rstn)begin
		if(rstn='0')then
			state<=st_INIT;
			readaddr<=BGNADDR;
			rdbgn<='0';
			wr<='0';
			aen<='0';
		elsif(clk' event and clk='1')then
			rdbgn<='0';
			case state is
			when st_INIT =>
				readaddr<=BGNADDR;
				aen<='1';
				state<=st_BGN;
			when st_BGN =>
				rdbgn<='1';
				state<=st_BUSY;
			when st_BUSY =>
				if(rxed='1')then
					wr<='1';
					state<=st_WRITE;
				end if;
			when st_WRITE =>
				if(ack='1')then
					wr<='0';
					if(curaddr=ENDADDR and ack='1')then
						aen<='0';
						state<=st_DONE;
					else
						readaddr<=curaddr+1;
						rdbgn<='1';
						state<=st_BUSY;
					end if;
				end if;
			when st_DONE =>
			when others =>
			end case;
		end if;
	end process;
	
	
	addra<=curaddr - BGNADDR;
	addr<=addra(AWIDTH-1 downto 0);
	done<='1' when state=st_DONE else '0';
end rtl;

			