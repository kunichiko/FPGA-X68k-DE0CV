--
--  i2s_encoder.vhd
--
--    Copyright (C)2020 Kunihiko Ohnaka All rights reserved.
--
library	IEEE;

use	IEEE.STD_LOGIC_1164.ALL;
use	IEEE.STD_LOGIC_ARITH.ALL;
use	IEEE.STD_LOGIC_UNSIGNED.ALL;

-- ● 想定入力フォーマット
-- snd_clk に同期した32bit PCMデータが、snd_L, snd_R に入力されてくる
-- ことを想定しています。
-- snd_clkと clkの周波数は完全に異なっていて構いません。
--
-- ● I2S出力仕様について
-- 48kHz 32bit フォーマットを、MCK(SCK)を使わない 3線式のI2Sで出力することを
-- 想定しています。その際のbclkは 48kHz * 32 * 2(ステレオ) で 3.072MHzとなるため、
-- そのクロックを外部で生成し、本モジュールの i2s_bclkに入力してください。
-- data, lrck は本モジュールが生成します。
--
-- ● 周波数変換について
-- snd_clkが 48kHzの bclkに同期していない場合は、本来であればデジタルフィルタを
-- 使って周波数変換する必要があります。
-- 本実装では簡略化のために入力PCMデータを直接サンプリングしてしまっています。

entity i2s_encoder is
port(
	snd_clk     :in std_logic;
	snd_L       :in std_logic_vector(31 downto 0);
    snd_R       :in std_logic_vector(31 downto 0);

	i2s_data    :out std_logic;
	i2s_lrck    :out std_logic;
	
	i2s_bclk    :in std_logic;  -- I2S BCK (Bit Clock) 3.072MHz (=48kHz * 64)
	rstn		:in std_logic
);
end i2s_encoder;

architecture rtl of i2s_encoder is
signal pcm_req	   :std_logic;
signal pcm_req_d   :std_logic;
signal pcm_ack     :std_logic;
signal pcm_latch_l :std_logic_vector(31 downto 0);
signal pcm_latch_r :std_logic_vector(31 downto 0);

signal i2s_counter :std_logic_vector(5 downto 0);
signal i2s_data_v  :std_logic_vector(63 downto 0);
begin

	process(snd_clk,rstn)

	begin
		if(rstn='0')then
			pcm_ack <= '0';
			pcm_latch_l <= (others => '0');
			pcm_latch_r <= (others => '0');
		elsif(snd_clk' event and snd_clk='1') then
			pcm_req_d <= pcm_req; -- メタステーブル回避
			if(pcm_req_d /= pcm_ack) then
				-- pcmデータ要求に応答
				pcm_ack <= not pcm_ack;
				pcm_latch_l <= snd_L;
				pcm_latch_r <= snd_R;
			end if;
		end if;
	end process;

	process(i2s_bclk,rstn)
	begin
		if(rstn='0')then
			pcm_req <= '0';
			i2s_counter <= (others => '0');
		elsif(i2s_bclk' event and i2s_bclk='1')then
			i2s_data <= i2s_data_v(63);
			i2s_data_v <= i2s_data_v(62 downto 0) & '0';

			i2s_counter <= i2s_counter + 1;
			if(i2s_counter = 0) then
				i2s_data_v <= pcm_latch_l & pcm_latch_r;
				i2s_lrck <= '0';
				pcm_req <= not pcm_req;
			elsif(i2s_counter = 32) then
			    i2s_lrck <= '1';
			end if;
		end if;
	end process;


end rtl;