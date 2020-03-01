library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity rastercopy is
generic(
	arange	:integer	:=14;
	brsize	:integer	:=8
);
port(
	src		:in std_logic_vector(7 downto 0);
	dst		:in std_logic_vector(7 downto 0);
	prane	:in std_logic_vector(3 downto 0);
	start	:in std_logic;
	stop	:in std_logic;
	busy	:out std_logic;

	t_base	:in std_logic_vector(arange-1 downto 0);	
	srcaddr	:out std_logic_vector(arange-1 downto 0);
	dstaddr	:out std_logic_vector(arange-1 downto 0);
	cpy		:out std_logic_vector(3 downto 0);
	ack		:in std_logic;
	
	clk		:in std_logic;
	rstn	:in std_logic
);
end rastercopy;
architecture rtl of rastercopy is
type state_t is (
	st_IDLE,
	st_COPY
);
signal	STATE	:state_t;
constant selwidth	:integer	:=10-brsize;
signal	eack	:std_logic;
signal	lack	:std_logic;
signal	sel	:std_logic_vector(selwidth-1 downto 0);
constant	selmax	:std_logic_vector(selwidth-1 downto 0)	:=(others=>'1');
begin
	srcaddr(arange-1 downto selwidth+8)<=t_base(arange-1 downto selwidth+8);
	srcaddr(selwidth-1 downto 0)<=sel;
		
	dstaddr(arange-1 downto selwidth+8)<=t_base(arange-1 downto selwidth+8);
	dstaddr(selwidth-1 downto 0)<=sel;

	process(clk,rstn)begin
		if(rstn='0')then
			lack<='0';
			eack<='0';
		elsif(clk' event and clk='1')then
			if(lack='0' and ack='1')then
				eack<='1';
			else
				eack<='0';
			end if;
			lack<=ack;
		end if;
	end process;
	
	process(clk,rstn)begin
		if(rstn='0')then
			cpy<=(others=>'0');
			srcaddr(selwidth+7 downto selwidth)<=(others=>'0');
			dstaddr(selwidth+7 downto selwidth)<=(others=>'0');
		elsif(clk' event and clk='1')then
			case STATE is
			when st_IDLE=>
				if(start='1')then
					srcaddr(selwidth+7 downto selwidth)<=src;
					dstaddr(selwidth+7 downto selwidth)<=dst;
					cpy<=prane;
					STATE<=st_COPY;
				end if;
			when st_COPY =>
				if(eack='1')then
					if(sel=selmax)then
						cpy<=(others=>'0');
						STATE<=st_IDLE;
						sel<=(others=>'0');
					else
						sel<=sel+1;
					end if;
				end if;
			when others =>
			end case;
			if(stop='1')then
				cpy<=(others=>'0');
				STATE<=st_IDLE;
			end if;
		end if;
	end process;
	
	busy<='0' when STATE=st_IDLE else '1';
end rtl;

			
