LIBRARY ieee;
USE ieee.std_logic_1164.all;

-- Top-level para a placa DE2 (Cyclone II EP2C35F672C6).
--
--   SW(7 DOWNTO 0)    -> di
--   SW(17 DOWNTO 16)  -> a_sel (SW17 = MSB)
--   SW(15 DOWNTO 14)  -> b_sel (SW15 = MSB)
--   SW(13)            -> wr_ena
--   SW(12)            -> modo de exibição: '0' = conteúdo dos registradores,
--                        '1' = saídas a_do e b_do
--   KEY(0)            -> clock; a escrita acontece na subida do sinal, ou
--                        seja, ao PRESSIONAR o botão (KEY é ativo em '0')
--   KEY(3)            -> nrst; reset assíncrono enquanto o botão estiver
--                        pressionado (KEY é ativo em '0', então nrst = KEY)
--
-- Modo SW(12) = '0' (registradores):
--   HEX7..HEX6 -> R3, HEX5..HEX4 -> R2, HEX3..HEX2 -> R1, HEX1..HEX0 -> R0
--                 (cada registrador em hexadecimal, nibble alto à esquerda)
--
-- Modo SW(12) = '1' (saídas):
--   HEX7..HEX6 -> a_do, HEX5..HEX4 -> b_do (em hexadecimal)
--   HEX3..HEX2 -> apagados
--   HEX1..HEX0 -> "rd" (read) se wr_ena = '0'; "En" (enable) se wr_ena = '1'
--
-- LEDs:
--   LEDG(3 DOWNTO 0)  -> acesos enquanto KEY(3..0) estiver pressionado
--   LEDG(7)           -> wr_ena (SW13); LEDG(6..4) apagados
--   LEDR(17 DOWNTO 10)-> a_do em binário (LEDR17 = MSB)
--   LEDR(7 DOWNTO 0)  -> b_do em binário (LEDR7 = MSB)
--   LEDR(9 DOWNTO 8)  -> não usados (sempre '0')
ENTITY de2_reg_bank IS
	PORT (
		SW   : IN  STD_LOGIC_VECTOR(17 DOWNTO 0);
		KEY  : IN  STD_LOGIC_VECTOR(3 DOWNTO 0);
		HEX0 : OUT STD_LOGIC_VECTOR(6 DOWNTO 0);
		HEX1 : OUT STD_LOGIC_VECTOR(6 DOWNTO 0);
		HEX2 : OUT STD_LOGIC_VECTOR(6 DOWNTO 0);
		HEX3 : OUT STD_LOGIC_VECTOR(6 DOWNTO 0);
		HEX4 : OUT STD_LOGIC_VECTOR(6 DOWNTO 0);
		HEX5 : OUT STD_LOGIC_VECTOR(6 DOWNTO 0);
		HEX6 : OUT STD_LOGIC_VECTOR(6 DOWNTO 0);
		HEX7 : OUT STD_LOGIC_VECTOR(6 DOWNTO 0);
		LEDR : OUT STD_LOGIC_VECTOR(17 DOWNTO 0);
		LEDG : OUT STD_LOGIC_VECTOR(7 DOWNTO 0)
	);
END ENTITY;

ARCHITECTURE arch OF de2_reg_bank IS
	COMPONENT reg_bank_de2 IS
		PORT (
			nrst   : IN  STD_LOGIC;
			clk_in : IN  STD_LOGIC;
			di     : IN  STD_LOGIC_VECTOR(7 DOWNTO 0);
			a_sel  : IN  STD_LOGIC_VECTOR(1 DOWNTO 0);
			b_sel  : IN  STD_LOGIC_VECTOR(1 DOWNTO 0);
			wr_ena : IN  STD_LOGIC;
			a_do   : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
			b_do   : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
			r_all  : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)
		);
	END COMPONENT;

	SIGNAL nrst   : STD_LOGIC;
	SIGNAL clk_in : STD_LOGIC;
	SIGNAL a_do   : STD_LOGIC_VECTOR(7 DOWNTO 0);
	SIGNAL b_do   : STD_LOGIC_VECTOR(7 DOWNTO 0);
	SIGNAL r_all  : STD_LOGIC_VECTOR(31 DOWNTO 0); -- R3 & R2 & R1 & R0

	-- Letras que o HEX consegue formar (ativo em 0, bit 0 = seg. a,
	-- bit 6 = seg. g)
	CONSTANT SEG_APAGADO : STD_LOGIC_VECTOR(6 DOWNTO 0) := "1111111";
	CONSTANT SEG_R       : STD_LOGIC_VECTOR(6 DOWNTO 0) := "0101111"; -- r
	CONSTANT SEG_N       : STD_LOGIC_VECTOR(6 DOWNTO 0) := "0101011"; -- n

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
	nrst   <= KEY(3);     -- reset enquanto KEY3 estiver pressionado
	clk_in <= NOT KEY(0); -- subida (escrita) ao pressionar KEY0

	u_bank : reg_bank_de2
		PORT MAP (
			nrst   => nrst,
			clk_in => clk_in,
			di     => SW(7 DOWNTO 0),
			a_sel  => SW(17 DOWNTO 16),
			b_sel  => SW(15 DOWNTO 14),
			wr_ena => SW(13),
			a_do   => a_do,
			b_do   => b_do,
			r_all  => r_all
		);

	-- Displays
	PROCESS (SW, r_all, a_do, b_do)
	BEGIN
		IF SW(12) = '0' THEN
			-- Modo registradores: R3 em HEX7..6, R2 em HEX5..4, R1 em
			-- HEX3..2, R0 em HEX1..0
			HEX7 <= hex_to_7seg(r_all(31 DOWNTO 28));
			HEX6 <= hex_to_7seg(r_all(27 DOWNTO 24));
			HEX5 <= hex_to_7seg(r_all(23 DOWNTO 20));
			HEX4 <= hex_to_7seg(r_all(19 DOWNTO 16));
			HEX3 <= hex_to_7seg(r_all(15 DOWNTO 12));
			HEX2 <= hex_to_7seg(r_all(11 DOWNTO 8));
			HEX1 <= hex_to_7seg(r_all(7 DOWNTO 4));
			HEX0 <= hex_to_7seg(r_all(3 DOWNTO 0));
		ELSE
			-- Modo saídas: a_do em HEX7..6, b_do em HEX5..4
			HEX7 <= hex_to_7seg(a_do(7 DOWNTO 4));
			HEX6 <= hex_to_7seg(a_do(3 DOWNTO 0));
			HEX5 <= hex_to_7seg(b_do(7 DOWNTO 4));
			HEX4 <= hex_to_7seg(b_do(3 DOWNTO 0));
			HEX3 <= SEG_APAGADO;
			HEX2 <= SEG_APAGADO;
			IF SW(13) = '0' THEN
				HEX1 <= SEG_R;                  -- "rd": leitura
				HEX0 <= hex_to_7seg("1101");    -- d
			ELSE
				HEX1 <= hex_to_7seg("1110");    -- "En": escrita habilitada
				HEX0 <= SEG_N;                  -- n
			END IF;
		END IF;
	END PROCESS;

	-- LEDs verdes: KEY3..0 pressionadas acendem LEDG3..0 (ativo em '0' -> invertido)
	LEDG(3 DOWNTO 0) <= NOT KEY;
	LEDG(6 DOWNTO 4) <= (OTHERS => '0');
	LEDG(7)          <= SW(13);

	-- LEDs vermelhos: a_do em LEDR17..10, b_do em LEDR7..0
	LEDR(17 DOWNTO 10) <= a_do;
	LEDR(9 DOWNTO 8)   <= (OTHERS => '0');
	LEDR(7 DOWNTO 0)   <= b_do;
END ARCHITECTURE;
