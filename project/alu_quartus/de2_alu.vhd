LIBRARY ieee;
USE ieee.std_logic_1164.all;

-- Top-level para a placa DE2 (Cyclone II EP2C35F672C6).
--
--   SW(7 DOWNTO 0)   -> a_in
--   SW(15 DOWNTO 8)  -> b_in
--   SW(16)           -> não usado
--   SW(17)           -> c_in
--   KEY(3 DOWNTO 0)  -> op_sel (KEY3 = MSB, KEY0 = LSB; ativos em 0, então
--                       o botão pressionado vale '1' no opcode)
--   HEX1 & HEX0      -> r_out em hexadecimal (HEX1 = nibble alto)
--   HEX7             -> opcode selecionado, em hexadecimal
--   LEDR(4 DOWNTO 0) -> flags: LEDR0 = C, LEDR1 = H, LEDR2 = Z, LEDR3 = V,
--                       LEDR4 = N (mesma ordem de flags_out, da esquerda
--                       para a direita)
ENTITY de2_alu IS
	PORT (
		SW   : IN  STD_LOGIC_VECTOR(17 DOWNTO 0);
		KEY  : IN  STD_LOGIC_VECTOR(3 DOWNTO 0);
		HEX0 : OUT STD_LOGIC_VECTOR(6 DOWNTO 0);
		HEX1 : OUT STD_LOGIC_VECTOR(6 DOWNTO 0);
		HEX7 : OUT STD_LOGIC_VECTOR(6 DOWNTO 0);
		LEDR : OUT STD_LOGIC_VECTOR(4 DOWNTO 0)
	);
END ENTITY;

ARCHITECTURE arch OF de2_alu IS
	COMPONENT alu IS
		PORT (
			a_in      : IN  STD_LOGIC_VECTOR(7 DOWNTO 0);
			b_in      : IN  STD_LOGIC_VECTOR(7 DOWNTO 0);
			c_in      : IN  STD_LOGIC;
			op_sel    : IN  STD_LOGIC_VECTOR(3 DOWNTO 0);
			r_out     : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
			flags_out : OUT STD_LOGIC_VECTOR(4 DOWNTO 0)
		);
	END COMPONENT;

	SIGNAL op_sel : STD_LOGIC_VECTOR(3 DOWNTO 0);
	SIGNAL r_out  : STD_LOGIC_VECTOR(7 DOWNTO 0);
	SIGNAL flags  : STD_LOGIC_VECTOR(4 DOWNTO 0); -- C, H, Z, V, N

	-- Decodificador hexadecimal -> 7 segmentos (ativo em 0, bit 0 = seg. a)
	FUNCTION hex_to_7seg(nibble : STD_LOGIC_VECTOR(3 DOWNTO 0))
		RETURN STD_LOGIC_VECTOR IS
	BEGIN
		CASE nibble IS
			WHEN "0000" => RETURN "1000000"; -- 0
			WHEN "0001" => RETURN "1111001"; -- 1
			WHEN "0010" => RETURN "0100100"; -- 2
			WHEN "0011" => RETURN "0110000"; -- 3
			WHEN "0100" => RETURN "0011001"; -- 4
			WHEN "0101" => RETURN "0010010"; -- 5
			WHEN "0110" => RETURN "0000010"; -- 6
			WHEN "0111" => RETURN "1111000"; -- 7
			WHEN "1000" => RETURN "0000000"; -- 8
			WHEN "1001" => RETURN "0010000"; -- 9
			WHEN "1010" => RETURN "0001000"; -- A
			WHEN "1011" => RETURN "0000011"; -- b
			WHEN "1100" => RETURN "1000110"; -- C
			WHEN "1101" => RETURN "0100001"; -- d
			WHEN "1110" => RETURN "0000110"; -- E
			WHEN OTHERS => RETURN "0001110"; -- F
		END CASE;
	END FUNCTION;
BEGIN
	-- Botões da DE2 são '0' quando pressionados
	op_sel <= NOT KEY;

	u_alu : alu
		PORT MAP (
			a_in      => SW(7 DOWNTO 0),
			b_in      => SW(15 DOWNTO 8),
			c_in      => SW(17),
			op_sel    => op_sel,
			r_out     => r_out,
			flags_out => flags
		);

	HEX0 <= hex_to_7seg(r_out(3 DOWNTO 0));
	HEX1 <= hex_to_7seg(r_out(7 DOWNTO 4));
	HEX7 <= hex_to_7seg(op_sel);

	-- LEDR0 = C ... LEDR4 = N (flags(4) = C, flags(0) = N)
	LEDR(0) <= flags(4);
	LEDR(1) <= flags(3);
	LEDR(2) <= flags(2);
	LEDR(3) <= flags(1);
	LEDR(4) <= flags(0);
END ARCHITECTURE;
