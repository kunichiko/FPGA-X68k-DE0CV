library ieee, work;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

package I2C_TLC59116_pkg is
    type led_mode_array is array (Natural range<>) of std_logic_vector(1 downto 0);
end I2C_TLC59116_pkg;
