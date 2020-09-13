--
--  OPM_JT51.vhd
--
--    OPM JT51 is free software: you can redistribute it and/or modify
--    it under the terms of the GNU General Public License as published by
--    the Free Software Foundation, either version 3 of the License, or
--    (at your option) any later version.
--
--    Author Kunihiko Ohnaka
--
library	IEEE;

use	IEEE.STD_LOGIC_1164.ALL;
use	IEEE.STD_LOGIC_ARITH.ALL;
use	IEEE.STD_LOGIC_UNSIGNED.ALL;

-- OPM.vhdと同じインターフェースで、実装として JT51を使用する
-- コンポーネントです

entity OPM_JT51 is
    generic(
        res		:integer	:=9
    );
    port(
        DIN		:in std_logic_vector(7 downto 0);
        DOUT	:out std_logic_vector(7 downto 0);
        DOE		:out std_logic;
        CSn		:in std_logic;
        ADR0	:in std_logic;
        RDn		:in std_logic;
        WRn		:in std_logic;
        INTn	:out std_logic;
        
        sndL	:out std_logic_vector(res-1 downto 0);
        sndR	:out std_logic_vector(res-1 downto 0);
        
        CT1		:out std_logic;
        CT2		:out std_logic;
        
        chenable:in std_logic_vector(7 downto 0)	:=(others=>'1');
        monout	:out std_logic_vector(15 downto 0);
        op0out	:out std_logic_vector(15 downto 0);
        op1out	:out std_logic_vector(15 downto 0);
        op2out	:out std_logic_vector(15 downto 0);
        op3out	:out std_logic_vector(15 downto 0);
    
        fmclk	:in std_logic;  -- 32MHz
        pclk	:in std_logic;  -- 10MHz
        rstn	:in std_logic
    );
end OPM_JT51;
    
architecture rtl of OPM_JT51 is

-- JT51 Verilog module definition is below:
--
-- module jt51(
--    input               rst,    // reset
--    input               clk,    // main clock
--    input               cen,    // clock enable
--    input               cen_p1, // clock enable at half the speed
--    input               cs_n,   // chip select
--    input               wr_n,   // write
--    input               a0,
--    input       [7:0]   din, // data in
--    output      [7:0]   dout, // data out
--    // peripheral control
--    output              ct1,
--    output              ct2,
--    output              irq_n,  // I do not synchronize this signal
--    // Low resolution output (same as real chip)
--    output              sample, // marks new output sample
--    output  signed  [15:0] left,
--    output  signed  [15:0] right,
--    // Full resolution output
--    output  signed  [15:0] xleft,
--    output  signed  [15:0] xright,
--    // unsigned outputs for sigma delta converters, full resolution
--    output  [15:0] dacleft,
--    output  [15:0] dacright
--);

component jt51
port(
	rst		:in std_logic;
	clk		:in std_logic;
    cen		:in std_logic;
    cen_p1  :in std_logic;
    cs_n    :in std_logic;
    wr_n    :in std_logic;
    a0      :in std_logic;
    din     :in std_logic_vector(7 downto 0);
    dout    :out std_logic_vector(7 downto 0);
    -- peripheral control
    ct1     :out std_logic;
    ct2     :out std_logic;
    irq_n   :out std_logic;
    -- Low resolution output (same as real chip)
    sample  :out std_logic;
    left    :out std_logic_vector(15 downto 0); --signed
    right   :out std_logic_vector(15 downto 0); --signed
    -- Full resolution output
    xleft   :out std_logic_vector(15 downto 0); --signed
    xright  :out std_logic_vector(15 downto 0); --signed
    -- unsigned outputes for sigma delta converters, full resolution
    dacleft :out std_logic_vector(15 downto 0); --unsigned
    dacright :out std_logic_vector(15 downto 0) --unsigned
);
end component;

signal jt51_cen     : std_logic;
signal jt51_cen_p1  : std_logic;
signal jt51_cs_n    : std_logic;
signal jt51_wr_n    : std_logic;
signal jt51_a0      : std_logic;
signal jt51_din     : std_logic_vector(7 downto 0);
signal jt51_dout    : std_logic_vector(7 downto 0);
signal jt51_ct1     : std_logic;
signal jt51_ct2     : std_logic;
signal jt51_irq_n   : std_logic;
signal jt51_xleft   : std_logic_vector(15 downto 0);
signal jt51_xright  : std_logic_vector(15 downto 0);

signal din_latch    : std_logic_vector(7 downto 0);
signal ad0_latch    : std_logic;

signal divider      : std_logic_vector(3 downto 0); -- 32MHz → 4MHz → 2MHz

signal CSWRn_d      : std_logic;

signal write_req    : std_logic;
signal write_req_d  : std_logic;
signal write_ack    : std_logic;

begin

    jt51_u0 :jt51 port map(
        rst	    => not rstn,
        clk		=> fmclk,
        cen		=> jt51_cen,
        cen_p1  => jt51_cen_p1,
        cs_n    => jt51_cs_n,
        wr_n    => jt51_wr_n,
        a0      => jt51_a0,
        din     => jt51_din,
        dout    => jt51_dout,
        -- peripheral control
        ct1     => jt51_ct1,
        ct2     => jt51_ct2,
        irq_n   => jt51_irq_n,
        -- Low resolution output (same as real chip)
        sample  => open,
        left    => open,
        right   => open,
        -- Full resolution output
        xleft   => jt51_xleft,
        xright  => jt51_xright,
        -- unsigned outputes for sigma delta converters, full resolution
        dacleft => open,
        dacright => open
    );

    -- data bus
    DOUT <= jt51_dout;
    DOE <='1' when CSn='0' and RDn='0' else '0';

    jt51_din <= din_latch;
    jt51_a0  <= ad0_latch;

    monout <= (others => '0');
    op0out <= (others => '0');
    op1out <= (others => '0');
    op2out <= (others => '0');
    op3out <= (others => '0');

    -- fmclk(sndclk) synchronized signals (can be connected directly)
    sndL <= jt51_xleft(15 downto (16 - res));
    sndR <= jt51_xright(15 downto (16 - res));

    -- sysclk synchronized inputs
    process(pclk,rstn)
        variable CSWRn: std_logic := '1';
    begin
        if(rstn='0')then
            CSWRn_d <= '1';
            din_latch <= (others => '0');
            ad0_latch <= '0';
            write_req <= '0';
        elsif(pclk' event and pclk='1')then
            CSWRn := CSn or WRn;
            CSWRn_d <= CSWRn;
            if(   CSWRn_d = '1' and CSWRn = '0') then -- falling edge
                din_latch <= DIN;
                ad0_latch <= ADR0;
                write_req <= not write_req;
            end if;
        end if;
    end process;

    -- sysclk synchronized outputs
    process(pclk,rstn)begin
        if(rstn='0')then
            CT1 <= '0';
            CT2 <= '0';
            INTn <= '1';
        elsif(pclk' event and pclk='1')then
            CT1 <= jt51_ct1;
            CT2 <= jt51_ct2;
            INTn <= jt51_irq_n;
        end if;
    end process;

    -- fmclk synchronized
    process(fmclk,rstn)begin
        if(rstn='0')then
            write_req_d <= '0';
            write_ack   <= '0';
            jt51_cs_n <= '1';
            jt51_wr_n <= '1'; 
        elsif(fmclk' event and fmclk='1')then
            write_req_d <= write_req; -- メタステーブル回避
            jt51_cs_n <= '1';
            jt51_wr_n <= '1';
            if(write_req_d /= write_ack) then
                jt51_cs_n <= '0';  -- cs_n only used for writing
                jt51_wr_n <= '0';
                write_ack <= not write_ack;
            end if;

        end if;
    end process;

    -- fmclk enable
    -- On X68000, YM2151 is driven by 4MHz.
    -- So cen should be active every 8 clocks (32MHz/8 = 4MHz)
    -- And cen_p1 should be active every 16 clock (32MHz/16 = 2MHz)
    process(fmclk,rstn)begin
        if(rstn='0')then
            jt51_cen    <= '0';
            jt51_cen_p1 <= '0';
            divider <= (others => '0');
        elsif(fmclk' event and fmclk='1')then
            divider <= divider + 1;

            jt51_cen    <= '0';
            jt51_cen_p1 <= '0';
            if(divider = 0)then
                jt51_cen    <= '1';
                jt51_cen_p1 <= '1';
            elsif(divider = 8)then
                jt51_cen    <= '1';
            end if;
        end if;
    end process;

end rtl;
    
    