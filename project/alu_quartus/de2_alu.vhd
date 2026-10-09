LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.std_logic_unsigned.all;

-- Top-level para a placa DE2 (Cyclone II EP2C35F672C6).
--
--   SW(7 DOWNTO 0)   -> a_in
--   SW(15 DOWNTO 8)  -> b_in
--   SW(16)           -> modo de exibição decimal: '0' = sem sinal (0..255),
--                       '1' = com sinal (-128..127)
--   SW(17)           -> c_in
--   KEY(3 DOWNTO 0)  -> op_sel (KEY3 = MSB, KEY0 = LSB; ativos em 0, então
--                       o botão pressionado vale '1' no opcode)
--   HEX5 & HEX4      -> r_out em hexadecimal (HEX5 = nibble alto)
--   HEX2, HEX1, HEX0 -> |r_out| em decimal (HEX2 = centena, HEX0 = unidade)
--   HEX3             -> sinal do valor decimal (apenas o segmento do meio
--                       aceso quando negativo; apagado quando SW(16)='0'
--                       ou o resultado é positivo)
--   HEX7             -> opcode selecionado, em hexadecimal
--   LEDR(4 DOWNTO 0)  -> flags: LEDR0 = C, LEDR1 = H, LEDR2 = Z, LEDR3 = V,
--                        LEDR4 = N (mesma ordem de flags_out, da esquerda
--                        para a direita)
--   LEDR(9 DOWNTO 5)  -> não usado (sempre '0')
--   LEDR(17 DOWNTO 10)-> r_out em binário (LEDR17 = MSB, LEDR10 = LSB)
--   LEDG(3 DOWNTO 0)  -> opcode selecionado em binário (LEDG3 = MSB,
--                        LEDG0 = LSB)
ENTITY de2_alu IS
	PORT (
		SW   : IN  STD_LOGIC_VECTOR(17 DOWNTO 0);
		KEY  : IN  STD_LOGIC_VECTOR(3 DOWNTO 0);
		HEX0 : OUT STD_LOGIC_VECTOR(6 DOWNTO 0);
		HEX1 : OUT STD_LOGIC_VECTOR(6 DOWNTO 0);
		HEX2 : OUT STD_LOGIC_VECTOR(6 DOWNTO 0);
		HEX3 : OUT STD_LOGIC_VECTOR(6 DOWNTO 0);
		HEX4 : OUT STD_LOGIC_VECTOR(6 DOWNTO 0);
		HEX5 : OUT STD_LOGIC_VECTOR(6 DOWNTO 0);
		HEX7 : OUT STD_LOGIC_VECTOR(6 DOWNTO 0);
		LEDR : OUT STD_LOGIC_VECTOR(17 DOWNTO 0);
		LEDG : OUT STD_LOGIC_VECTOR(3 DOWNTO 0)
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

	SIGNAL op_sel    : STD_LOGIC_VECTOR(3 DOWNTO 0);
	SIGNAL r_out     : STD_LOGIC_VECTOR(7 DOWNTO 0);
	SIGNAL flags     : STD_LOGIC_VECTOR(4 DOWNTO 0); -- C, H, Z, V, N

	-- Conversão para decimal (módulo de r_out e sinal, quando SW(16)='1')
	SIGNAL sign_neg  : STD_LOGIC;
	SIGNAL magnitude : STD_LOGIC_VECTOR(7 DOWNTO 0);
	SIGNAL mag_int   : INTEGER RANGE 0 TO 255;
	SIGNAL d_unid    : INTEGER RANGE 0 TO 9;
	SIGNAL d_dez     : INTEGER RANGE 0 TO 9;
	SIGNAL d_cem     : INTEGER RANGE 0 TO 2;

	-- Decodificador decimal (0..9) -> 7 segmentos
	FUNCTION dec_to_7seg(digit : INTEGER RANGE 0 TO 9)
		RETURN STD_LOGIC_VECTOR IS
	BEGIN
		CASE digit IS
			WHEN 0 => RETURN "1000000";
			WHEN 1 => RETURN "1111001";
			WHEN 2 => RETURN "0100100";
			WHEN 3 => RETURN "0110000";
			WHEN 4 => RETURN "0011001";
			WHEN 5 => RETURN "0010010";
			WHEN 6 => RETURN "0000010";
			WHEN 7 => RETURN "1111000";
			WHEN 8 => RETURN "0000000";
			WHEN 9 => RETURN "0010000";
		END CASE;
	END FUNCTION;

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

	-- Resultado em hexadecimal (HEX5 = nibble alto, HEX4 = nibble baixo)
	HEX4 <= hex_to_7seg(r_out(3 DOWNTO 0));
	HEX5 <= hex_to_7seg(r_out(7 DOWNTO 4));

	-- Opcode selecionado
	HEX7 <= hex_to_7seg(op_sel);

	-- Módulo exibido em decimal: com SW(16)='1' e r_out negativo (bit 7 em
	-- 1), usa o complemento de dois para obter o valor absoluto (0..128);
	-- caso contrário, mostra r_out sem sinal (0..255).
	sign_neg  <= SW(16) AND r_out(7);
	magnitude <= r_out WHEN sign_neg = '0' ELSE (NOT r_out) + 1;
	mag_int   <= CONV_INTEGER(magnitude);

	d_unid <= mag_int MOD 10;
	d_dez  <= (mag_int / 10) MOD 10;
	d_cem  <= mag_int / 100;

	HEX0 <= dec_to_7seg(d_unid);
	HEX1 <= dec_to_7seg(d_dez);
	HEX2 <= dec_to_7seg(d_cem);

	-- HEX3: apenas o segmento do meio (g) aceso quando o valor é negativo
	HEX3 <= "0111111" WHEN sign_neg = '1' ELSE "1111111";

	-- LEDR0 = C ... LEDR4 = N (flags(4) = C, flags(0) = N)
	LEDR(0) <= flags(4);
	LEDR(1) <= flags(3);
	LEDR(2) <= flags(2);
	LEDR(3) <= flags(1);
	LEDR(4) <= flags(0);
	LEDR(9 DOWNTO 5) <= (OTHERS => '0');

	-- r_out em binário
	LEDR(17 DOWNTO 10) <= r_out;

	-- Opcode selecionado em binário
	LEDG <= op_sel;
END ARCHITECTURE;
