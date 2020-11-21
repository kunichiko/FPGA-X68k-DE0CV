--
-- Author: Kunihiko Ohnaka (@kunichiko on Twitter) @ 2020 Aug.
--
-- # About this module
-- 最大16個のLEDを制御できるTIの TLCS59116 をFPGAからコントロールするための
-- 回路です。
-- 
-- I2Cの制御はFPGA X68000の作者であるプー氏が作成した I2CIF.vhd を使います。
--
-- # How does it work?
-- TLC59116は I2Cバスを使って最大16個のLEDを制御できます。
--
-- * 個々のLEDに対して、以下の4つモードを設定可能です
--   * 消灯("00") - LEDに電流が流れません
--   * 点灯("01") - LEDに常時電流が流れます
--   * PWM("10") - 別のレジスタで設定したパルス幅でLEDに電流を流します(輝度調整)
--   * 点滅("11") - 別のレジスタで設定した周期で「消灯」と「PWM」を繰り返します
-- 
-- 本モジュールは、16個の入力ポートに対して"00"〜”11"の値入力するだけで、その状態変化を
-- 検知してTLC559116をI2Cバスで制御して当該の状態になるようにします。

LIBRARY IEEE;
	USE IEEE.STD_LOGIC_1164.ALL;
	use IEEE.std_logic_arith.all;
	USE IEEE.STD_LOGIC_UNSIGNED.ALL;
	use work.I2C_pkg.all;
	use work.I2C_TLC59116_pkg.all;

entity I2C_TLC59116 is
generic(
	LED0_BRIGHTNESS		:std_logic_vector(7 downto 0) := x"80";
	LED1_BRIGHTNESS		:std_logic_vector(7 downto 0) := x"80";
	LED2_BRIGHTNESS		:std_logic_vector(7 downto 0) := x"80";
	LED3_BRIGHTNESS		:std_logic_vector(7 downto 0) := x"80";
	LED4_BRIGHTNESS		:std_logic_vector(7 downto 0) := x"80";
	LED5_BRIGHTNESS		:std_logic_vector(7 downto 0) := x"80";
	LED6_BRIGHTNESS		:std_logic_vector(7 downto 0) := x"80";
	LED7_BRIGHTNESS		:std_logic_vector(7 downto 0) := x"80";
	LED8_BRIGHTNESS		:std_logic_vector(7 downto 0) := x"80";
	LED9_BRIGHTNESS		:std_logic_vector(7 downto 0) := x"80";
	LED10_BRIGHTNESS	:std_logic_vector(7 downto 0) := x"80";
	LED11_BRIGHTNESS	:std_logic_vector(7 downto 0) := x"80";
	LED12_BRIGHTNESS	:std_logic_vector(7 downto 0) := x"80";
	LED13_BRIGHTNESS	:std_logic_vector(7 downto 0) := x"80";
	LED14_BRIGHTNESS	:std_logic_vector(7 downto 0) := x"80";
	LED15_BRIGHTNESS	:std_logic_vector(7 downto 0) := x"80"
);
port(
	-- I2C
	TXOUT		:out	std_logic_vector(7 downto 0);	--tx data in
	RXIN		:in		std_logic_vector(7 downto 0);	--rx data out
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

    -- LED Control Ports
	LEDMODES    :in		led_mode_array(0 to 15);
	
	clk			:in		std_logic;
	rstn		:in		std_logic
);
end I2C_TLC59116;

architecture rtl of I2C_TLC59116 is
type I2Cstate_t is(
	IS_INI_BGN,
	IS_INI_REGADDR,
	IS_INI_MODE1,
	IS_INI_MODE2,
	IS_INI_PWM0,
	IS_INI_PWM1,
	IS_INI_PWM2,
	IS_INI_PWM3,
	IS_INI_PWM4,
	IS_INI_PWM5,
	IS_INI_PWM6,
	IS_INI_PWM7,
	IS_INI_PWM8,
	IS_INI_PWM9,
	IS_INI_PWM10,
	IS_INI_PWM11,
	IS_INI_PWM12,
	IS_INI_PWM13,
	IS_INI_PWM14,
	IS_INI_PWM15,
	IS_INI_GRPPWM,
	IS_INI_GRPFREQ,
	IS_INI_FIN,
	IS_IDLE,
	IS_UPDATE_BGN,
	IS_UPDATE_REGADDR,
	IS_UPDATE_LEDOUT0,
	IS_UPDATE_LEDOUT1,
	IS_UPDATE_LEDOUT2,
	IS_UPDATE_LEDOUT3,
	IS_UPDATE_FIN
);
signal	I2Cstate	:I2Cstate_t;
signal	D_LEDMODES	:led_mode_array(0 to 15);

constant	SADR_TLC59116	:std_logic_vector(6 downto 0)	:="1100000";

begin
	process(clk,rstn)
	begin
		if(rstn='0')then
			I2Cstate<=IS_INI_BGN;
			WRn<='1';
			RDn<='1';
			NX_READ<='0';
			RESTART<='0';
			START<='0';
			FINISH<='0';
			F_FINISH<='0';
			INIT<='0';
		elsif(clk' event and clk='1')then
			WRn<='1';
			RDn<='1';
			F_FINISH<='0';
			INIT<='0';
			case I2Cstate is
			when IS_INI_BGN =>
				if(TXEMP='1')then
					NX_READ<='0';
					RESTART<='0';
					START<='1';
					FINISH<='0';
					TXOUT<=SADR_TLC59116 & '0'; -- WR
					WRn<='0';
					I2CSTATE<=IS_INI_REGADDR; -- NEXT:レジスタアドレス指定
				end if;
			when IS_INI_REGADDR =>
				if(TXEMP='1')then
					NX_READ<='0';
					RESTART<='0';
					START<='0';
					FINISH<='0';
					TXOUT<=x"80"; -- Auto-increment On All Registers, start with 0x00
					WRn<='0';
					I2CSTATE<=IS_INI_MODE1; -- NEXT:MODE1初期化
				end if;
			when IS_INI_MODE1 =>
				if(TXEMP='1')then
					NX_READ<='0';
					RESTART<='0';
					START<='0';
					FINISH<='0';
					TXOUT<=x"01";
					WRn<='0';
					I2CSTATE<=IS_INI_MODE2; -- NEXT:MODE2初期化
				end if;
			when IS_INI_MODE2 =>
				if(TXEMP='1')then
					NX_READ<='0';
					RESTART<='0';
					START<='0';
					FINISH<='0';
					TXOUT<=x"20";
					WRn<='0';
					I2CSTATE<=IS_INI_PWM0; -- NEXT:PWM0初期化
				end if;

			when IS_INI_PWM0 =>
				if(TXEMP='1')then
					NX_READ<='0';
					RESTART<='0';
					START<='0';
					FINISH<='0';
					TXOUT<=LED0_BRIGHTNESS;
					WRn<='0';
					I2CSTATE<=IS_INI_PWM1; -- NEXT:PWM1初期化
				end if;
			when IS_INI_PWM1 =>
				if(TXEMP='1')then
					NX_READ<='0';
					RESTART<='0';
					START<='0';
					FINISH<='0';
					TXOUT<=LED1_BRIGHTNESS;
					WRn<='0';
					I2CSTATE<=IS_INI_PWM2; -- NEXT:PWM2初期化
				end if;
			when IS_INI_PWM2 =>
				if(TXEMP='1')then
					NX_READ<='0';
					RESTART<='0';
					START<='0';
					FINISH<='0';
					TXOUT<=LED2_BRIGHTNESS;
					WRn<='0';
					I2CSTATE<=IS_INI_PWM3; -- NEXT:PWM3初期化
				end if;
			when IS_INI_PWM3 =>
				if(TXEMP='1')then
					NX_READ<='0';
					RESTART<='0';
					START<='0';
					FINISH<='0';
					TXOUT<=LED3_BRIGHTNESS;
					WRn<='0';
					I2CSTATE<=IS_INI_PWM4; -- NEXT:PWM4初期化
				end if;

			when IS_INI_PWM4 =>
				if(TXEMP='1')then
					NX_READ<='0';
					RESTART<='0';
					START<='0';
					FINISH<='0';
					TXOUT<=LED4_BRIGHTNESS;
					WRn<='0';
					I2CSTATE<=IS_INI_PWM5; -- NEXT:PWM5初期化
				end if;
			when IS_INI_PWM5 =>
				if(TXEMP='1')then
					NX_READ<='0';
					RESTART<='0';
					START<='0';
					FINISH<='0';
					TXOUT<=LED5_BRIGHTNESS; 
					WRn<='0';
					I2CSTATE<=IS_INI_PWM6; -- NEXT:PWM6初期化
				end if;
			when IS_INI_PWM6 =>
				if(TXEMP='1')then
					NX_READ<='0';
					RESTART<='0';
					START<='0';
					FINISH<='0';
					TXOUT<=LED6_BRIGHTNESS;
					WRn<='0';
					I2CSTATE<=IS_INI_PWM7; -- NEXT:PWM7初期化
				end if;
			when IS_INI_PWM7 =>
				if(TXEMP='1')then
					NX_READ<='0';
					RESTART<='0';
					START<='0';
					FINISH<='0';
					TXOUT<=LED7_BRIGHTNESS;
					WRn<='0';
					I2CSTATE<=IS_INI_PWM8; -- NEXT:PWM8初期化
				end if;

			when IS_INI_PWM8 =>
				if(TXEMP='1')then
					NX_READ<='0';
					RESTART<='0';
					START<='0';
					FINISH<='0';
					TXOUT<=LED8_BRIGHTNESS;
					WRn<='0';
					I2CSTATE<=IS_INI_PWM9; -- NEXT:PWM9初期化
				end if;
			when IS_INI_PWM9 =>
				if(TXEMP='1')then
					NX_READ<='0';
					RESTART<='0';
					START<='0';
					FINISH<='0';
					TXOUT<=LED9_BRIGHTNESS; 
					WRn<='0';
					I2CSTATE<=IS_INI_PWM10; -- NEXT:PWM10初期化
				end if;
			when IS_INI_PWM10 =>
				if(TXEMP='1')then
					NX_READ<='0';
					RESTART<='0';
					START<='0';
					FINISH<='0';
					TXOUT<=LED10_BRIGHTNESS;
					WRn<='0';
					I2CSTATE<=IS_INI_PWM11; -- NEXT:PWM11初期化
				end if;
			when IS_INI_PWM11 =>
				if(TXEMP='1')then
					NX_READ<='0';
					RESTART<='0';
					START<='0';
					FINISH<='0';
					TXOUT<=LED11_BRIGHTNESS;
					WRn<='0';
					I2CSTATE<=IS_INI_PWM12; -- NEXT:PWM12初期化
				end if;

			when IS_INI_PWM12 =>
				if(TXEMP='1')then
					NX_READ<='0';
					RESTART<='0';
					START<='0';
					FINISH<='0';
					TXOUT<=LED12_BRIGHTNESS;
					WRn<='0';
					I2CSTATE<=IS_INI_PWM13; -- NEXT:PWM13初期化
				end if;
			when IS_INI_PWM13 =>
				if(TXEMP='1')then
					NX_READ<='0';
					RESTART<='0';
					START<='0';
					FINISH<='0';
					TXOUT<=LED13_BRIGHTNESS; 
					WRn<='0';
					I2CSTATE<=IS_INI_PWM14; -- NEXT:PWM14初期化
				end if;
			when IS_INI_PWM14 =>
				if(TXEMP='1')then
					NX_READ<='0';
					RESTART<='0';
					START<='0';
					FINISH<='0';
					TXOUT<=LED14_BRIGHTNESS;
					WRn<='0';
					I2CSTATE<=IS_INI_PWM15; -- NEXT:PWM15初期化
				end if;
			when IS_INI_PWM15 =>
				if(TXEMP='1')then
					NX_READ<='0';
					RESTART<='0';
					START<='0';
					FINISH<='0';
					TXOUT<=LED15_BRIGHTNESS;
					WRn<='0';
					I2CSTATE<=IS_INI_GRPPWM; -- NEXT:GRPPWM初期化
				end if;


			when IS_INI_GRPPWM =>
				if(TXEMP='1')then
					NX_READ<='0';
					RESTART<='0';
					START<='0';
					FINISH<='0';
					TXOUT<=x"80";	-- duty 50%
					WRn<='0';
					I2CSTATE<=IS_INI_GRPFREQ; -- NEXT:GRPFREQ初期化
				end if;

			when IS_INI_GRPFREQ =>
				if(TXEMP='1')then
					NX_READ<='0';
					RESTART<='0';
					START<='0';
					FINISH<='1';	-- FINISH
					TXOUT<=x"18";	-- 1Hz
					WRn<='0';
					I2CSTATE<=IS_INI_FIN; -- NEXT:初期化終了処理
				end if;

			when IS_INI_FIN =>
				if(TXEMP='1')then
					NX_READ<='0';
					RESTART<='0';
					START<='0';
					FINISH<='0';
					I2CSTATE<=IS_UPDATE_BGN; -- 初期化後必ず1回はUPDATE実行
				end if;

			when IS_IDLE =>
				if(D_LEDMODES /= LEDMODES)then
					I2CSTATE<=IS_UPDATE_BGN;
					D_LEDMODES <= LEDMODES;
				end if;

			when IS_UPDATE_BGN =>
				if(TXEMP='1')then
					NX_READ<='0';
					RESTART<='0';
					START<='1';
					FINISH<='0';
					TXOUT<=SADR_TLC59116 & '0'; -- WR
					WRn<='0';
					I2CSTATE<=IS_UPDATE_REGADDR; -- NEXT:レジスタアドレス指定
				end if;

			when IS_UPDATE_REGADDR =>
				if(TXEMP='1')then
					NX_READ<='0';
					RESTART<='0';
					START<='0';
					FINISH<='0';
					TXOUT<=x"94"; -- Auto-increment On All Registers, start with 0x14
					WRn<='0';
					I2CSTATE<=IS_UPDATE_LEDOUT0; -- NEXT:LED output state 0の更新
				end if;

			when IS_UPDATE_LEDOUT0 =>
				if(TXEMP='1')then
					NX_READ<='0';
					RESTART<='0';
					START<='0';
					FINISH<='0';
					TXOUT<=D_LEDMODES(3) & D_LEDMODES(2) & D_LEDMODES(1) & D_LEDMODES(0);
					WRn<='0';
					I2CSTATE<=IS_UPDATE_LEDOUT1; -- NEXT:LED output state 1の更新
				end if;

			when IS_UPDATE_LEDOUT1 =>
				if(TXEMP='1')then
					NX_READ<='0';
					RESTART<='0';
					START<='0';
					FINISH<='0';
					TXOUT<=D_LEDMODES(7) & D_LEDMODES(6) & D_LEDMODES(5) & D_LEDMODES(4);
					WRn<='0';
					I2CSTATE<=IS_UPDATE_LEDOUT2; -- NEXT:LED output state 2の更新
				end if;

			when IS_UPDATE_LEDOUT2 =>
				if(TXEMP='1')then
					NX_READ<='0';
					RESTART<='0';
					START<='0';
					FINISH<='0';
					TXOUT<=D_LEDMODES(11) & D_LEDMODES(10) & D_LEDMODES(9) & D_LEDMODES(8);
					WRn<='0';
					I2CSTATE<=IS_UPDATE_LEDOUT3; -- NEXT:LED output state 3の更新
				end if;

			when IS_UPDATE_LEDOUT3 =>
				if(TXEMP='1')then
					NX_READ<='0';
					RESTART<='0';
					START<='0';
					FINISH<='1';
					TXOUT<=D_LEDMODES(15) & D_LEDMODES(14) & D_LEDMODES(13) & D_LEDMODES(12);
					WRn<='0';
					I2CSTATE<=IS_UPDATE_FIN; -- NEXT:アップデート終了処理
				end if;

			when IS_UPDATE_FIN =>
				if(TXEMP='1')then
					NX_READ<='0';
					RESTART<='0';
					START<='0';
					FINISH<='0';
					I2CSTATE<=IS_IDLE;
				end if;

			when others =>
			end case;
		end if;
	end process;
			
end rtl;