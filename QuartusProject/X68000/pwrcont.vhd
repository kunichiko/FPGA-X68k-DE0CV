library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity pwrcont is
port(
	addrin	:in std_logic_vector(23 downto 0);
	wr		:in std_logic;
	wrdat	:in std_logic_vector(7 downto 0);
	
	psw		:in std_logic;
	
	power	:out std_logic;
	pint	:out std_logic;
	willrst	:out std_logic;
	
	sclk	:in std_logic;
	srstn	:in std_logic;
	pclk	:in std_logic;
	prstn	:in std_logic
);
end pwrcont;

architecture rtl of pwrcont is
signal	portwr	:std_logic;
signal	lportwr	:std_logic;
signal	pwrcount:integer range 2 downto 0;
signal	addrx	:std_logic_vector(23 downto 0);
signal	poweroff	:std_logic;
signal	pson	:std_logic;
signal	lpsw	:std_logic_vector(1 downto 0);
signal	ppint	:std_logic;
signal	willrst_counter:std_logic_vector(23 downto 0);
begin
	addrx<=addrin(23 downto 1) & '1';
	
	portwr<=wr when addrx=x"e8e00f" else '0';
	
	process(sclk,srstn)begin
		if(srstn='0')then
			lportwr<='0';
			pwrcount<=2;
			poweroff<='0';
		elsif(sclk' event and sclk='1')then
			lportwr<=portwr;
			if(lportwr='0' and portwr='1')then
				case pwrcount is
				when 2 =>
					if(wrdat=x"00")then
						pwrcount<=1;
					else
						pwrcount<=2;
					end if;
				when 1 =>
					if(wrdat=x"0f")then
						pwrcount<=0;
					elsif(wrdat=x"00")then
						pwrcount<=1;
					else
						pwrcount<=2;
					end if;
				when 0 =>
					if(wrdat=x"0f")then
						poweroff<='1';
					elsif(wrdat=x"00")then
						pwrcount<=1;
					else
						pwrcount<=2;
					end if;
				when others =>
					pwrcount<=2;
				end case;
			end if;
		end if;
	end process;
	
	process(pclk,prstn)begin
		if(prstn='0')then
			power<='1';
			willrst_counter<=(others=>'1');
			willrst<='0';
		elsif(pclk' event and pclk='1')then
			if(poweroff='1')then
				-- LEDパネルの消灯などのために実際にPLLを止めるまでに0.5秒ほど余裕を持たせる
				willrst<='1';
				if(willrst_counter=0)then
					-- powerを0にするとpllが停止してsrstnがアクティブになり、poweroffも0に戻る
					-- その後再度電源を押すとpsonが1になり、willrstが0になってpowerも1になって再度pllが動き始める
					power<='0';
				else
					willrst_counter<=willrst_counter-1;
				end if;
			elsif(pson='1')then
				power<='1';
				willrst<='0';
				willrst_counter<=(others=>'1');
			end if;
		end if;
	end process;
	
	process(pclk,prstn)begin
		if(prstn='0')then
			lpsw<=(others=>'0');
			pson<='0';
		elsif(pclk' event and pclk='1')then
			pson<='0';
			lpsw<=lpsw(0) & psw;
			if(lpsw="01")then
				pson<='1';
			end if;
		end if;
	end process;
	
	process(pclk,srstn)
	begin
		if(srstn='0')then
			ppint<='0';
		elsif(pclk' event and pclk='1')then
			if(pson='1')then
				ppint<='1';
			end if;
		end if;
	end process;
	
	process(sclk,srstn)begin
		if(srstn='0')then
			pint<='0';
		elsif(sclk' event and sclk='1')then
			pint<=ppint;
		end if;
	end process;

end rtl;

			