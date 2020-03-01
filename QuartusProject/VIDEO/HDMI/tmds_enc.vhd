library IEEE,work;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_arith.all;
use IEEE.std_logic_signed.all;

entity tmds_enc is
port(
	D		:in std_logic_vector(7 downto 0);
	C		:in std_logic_vector(1 downto 0);
	A		:in std_logic_vector(3 downto 0);
	CH		:in integer range 0 to 2;
	DMODE	:in std_logic_vector(1 downto 0);	--"00":video "01":2b/10b "10":4b/10b "11":guard band
	CK		:in std_logic;
	Q		:out std_logic_vector(9 downto 0)
);
end tmds_enc;

architecture rtl of tmds_enc is
signal	Db		: std_logic_vector(7 downto 0);
signal	Cb,DMODEb	:std_logic_vector(1 downto 0);
signal	Ab		:std_logic_vector(3 downto 0);
signal	CHb		:integer range 0 to 2;
signal	N1_D	:integer range 0 to 8;
signal	cnt	:integer range -16 to 15;
signal	q_m	:std_logic_vector(8 downto 0);
signal	a_m	:std_logic_vector(3 downto 0);
signal	c_m	:std_logic_vector(1 downto 0);
signal	ch_m:integer range 0 to 2;
signal	dmode_m:std_logic_vector(1 downto 0);
signal	N1_QM	:integer range 0 to 8;
signal	Qb		:std_logic_vector(9 downto 0);
begin

	process(CK)begin
		if(CK' event and CK='1')then
			Db<=D;
			Cb<=C;
			Ab<=A;
			DMODEb<=DMODE;
			CHb<=CH;
		end if;
	end process;
	
	process(Db)
	variable tmp	:integer range 0 to 8;
	begin
		tmp:=0;
		for i in 0 to 7 loop
			if(Db(i)='1')then
				tmp:=tmp+1;
			end if;
		end loop;
		N1_D<=tmp;
	end process;
	
	process(q_m)
	variable tmp	:integer range 0 to 8;
	begin
		tmp:=0;
		for i in 0 to 7 loop
			if(q_m(i)='1')then
				tmp:=tmp+1;
			end if;
		end loop;
		N1_QM<=tmp;
	end process;
	
	process(CK)
	variable tmp	:std_logic;
	begin
		if(CK' event and CK='1')then
			if((N1_D>4) or (N1_D=4 and Db(0)='0'))then
				tmp:=Db(0);
				q_m(0)<=Db(0);
				for i in 1 to 7 loop
					tmp:=tmp xnor Db(i);
					q_m(i)<=tmp;
				end loop;
				q_m(8)<='0';
			else
				tmp:=Db(0);
				Q_m(0)<=Db(0);
				for i in 1 to 7 loop
					tmp:=tmp xor Db(i);
					q_m(i)<=tmp;
				end loop;
				q_m(8)<='1';
			end if;
			dmode_m<=DMODEb;
			c_m<=Cb;
			a_m<=Ab;
			ch_m<=CHb;
		end if;
	end process;
	
	process(CK)
	variable	tmp	:integer range 0 to 8;
	begin
		if(CK' event and CK='1')then
			case dmode_m is
			when "00" =>
				cnt<=0;
				case c_m is
				when "00" =>
					Qb<="1101010100";
				when "01" =>
					Qb<="0010101011";
				when "10" =>
					Qb<="0101010100";
				when "11" =>
					Qb<="1010101011";
				when others =>
					Qb<=(others=>'0');
				end case;
			when "01" =>
				if((cnt=0) or (N1_QM=4))then
					Qb(9 downto 8)<=not q_m(8) & q_m(8);
					if(q_m(8)='1')then
						Qb(7 downto 0)<=q_m(7 downto 0);
					else
						Qb(7 downto 0)<=not q_m(7 downto 0);
					end if;
					if(q_m(8)='1')then
						cnt<=cnt+N1_QM+N1_QM-8;
					else
						cnt<=cnt+8-N1_QM-N1_QM;
					end if;
				elsif(((cnt>0) and (N1_QM>4)) or ((cnt<0) and (N1_QM<4)))then
					Qb<='1' & q_m(8) & not q_m(7 downto 0);
					if(q_m(8)='1')then
						tmp:=2;
					else
						tmp:=0;
					end if;
					cnt<=cnt+tmp+8-N1_QM-N1_QM;
				else
					Qb<='0' & q_m(8) & q_m(7 downto 0);
					if(q_m(8)='1')then
						tmp:=0;
					else
						tmp:=2;
					end if;
					cnt<=cnt-tmp+N1_QM+N1_QM-8;
				end if;
			when "10" =>
				cnt<=0;
				case a_m is
				when x"0" =>
					Qb<="1010011100";
				when x"1" =>
					Qb<="1001100011";
				when x"2" =>
					Qb<="1011100100";
				when x"3" =>
					Qb<="1011100010";
				when x"4" =>
					Qb<="0101110001";
				when x"5" =>
					Qb<="0100011110";
				when x"6" =>
					Qb<="0110001110";
				when x"7" =>
					Qb<="0100111100";
				when x"8" =>
					Qb<="1011001100";
				when x"9" =>
					Qb<="0100111001";
				when x"a" =>
					Qb<="0110011100";
				when x"b" =>
					Qb<="1011000110";
				when x"c" =>
					Qb<="1010001110";
				when x"d" =>
					Qb<="1010001110";
				when x"e" =>
					Qb<="0101100011";
				when x"f" =>
					Qb<="1011000011";
				when others =>
					Qb<=(others=>'0');
				end case;
			when "11" =>
				cnt<=0;
				case ch_m is
				when 0 =>
					Qb<="1011001100";
				when 1 =>
					Qb<="0100110011";
				when 2 =>
					Qb<="1011001100";
				when others =>
					Qb<="0100110011";
				end case;
			end case;
		end if;
	end process;
	
	process(Qb)begin
		for i in 0 to 9 loop
			Q(i)<=Qb(9-i);
		end loop;
	end process;
	
end rtl;
