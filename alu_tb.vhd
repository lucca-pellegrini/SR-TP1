LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.numeric_std.all; -- só no testbench, para o modelo de referência
----------------------------------------------------------------
-- Testbench auto-verificável (NÃO faz parte do projeto sintetizável;
-- pode usar PROCESS, WAIT, REPORT etc.)
-- flags: "c h z v n" (bit 4 ... bit 0); '-' = don't care (não compara)
----------------------------------------------------------------
ENTITY alu_tb IS
END ENTITY;

ARCHITECTURE sim OF alu_tb IS
	SIGNAL a, b : STD_LOGIC_VECTOR(7 DOWNTO 0) := (OTHERS => '0');
	SIGNAL c    : STD_LOGIC := '0';
	SIGNAL op   : STD_LOGIC_VECTOR(3 DOWNTO 0) := "0000";
	SIGNAL r    : STD_LOGIC_VECTOR(7 DOWNTO 0);
	SIGNAL fl   : STD_LOGIC_VECTOR(4 DOWNTO 0);

	FUNCTION b2s(x : BOOLEAN) RETURN STD_LOGIC IS
	BEGIN
		IF x THEN RETURN '1'; ELSE RETURN '0'; END IF;
	END FUNCTION;

	FUNCTION to_slv(n : INTEGER) RETURN STD_LOGIC_VECTOR IS
	BEGIN
		RETURN STD_LOGIC_VECTOR(TO_UNSIGNED(n, 8));
	END FUNCTION;

	FUNCTION bits(v : STD_LOGIC_VECTOR) RETURN STRING IS
		VARIABLE s : STRING(1 TO v'LENGTH);
		VARIABLE t : STRING(1 TO 3);
	BEGIN
		FOR i IN 0 TO v'LENGTH - 1 LOOP
			t := STD_LOGIC'IMAGE(v(v'HIGH - i));
			s(i + 1) := t(2);
		END LOOP;
		RETURN s;
	END FUNCTION;
BEGIN
	dut : ENTITY work.alu
		PORT MAP (a_in => a, b_in => b, c_in => c, op_sel => op,
		          r_out => r, flags_out => fl);

	PROCESS
		VARIABLE total, erros : INTEGER := 0;
		VARIABLE s, sv, sa, sb, ri, ce : INTEGER;
		VARIABLE cc, hc, vv : BOOLEAN;
		VARIABLE ef : STD_LOGIC_VECTOR(4 DOWNTO 0);

		PROCEDURE testa (
			nome   : IN STRING;
			o      : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
			va, vb : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
			vc     : IN STD_LOGIC;
			er     : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
			ex     : IN STD_LOGIC_VECTOR(4 DOWNTO 0)) IS
			VARIABLE ok : BOOLEAN := TRUE;
		BEGIN
			op <= o; a <= va; b <= vb; c <= vc;
			WAIT FOR 1 ns;
			total := total + 1;
			IF r /= er THEN ok := FALSE; END IF;
			FOR i IN 0 TO 4 LOOP
				IF ex(i) /= '-' AND ex(i) /= fl(i) THEN ok := FALSE; END IF;
			END LOOP;
			IF NOT ok THEN
				erros := erros + 1;
				IF erros <= 20 THEN -- evita inundar o terminal
					REPORT "FALHA [" & nome & "] op=" & bits(o) &
					       " a=" & bits(va) & " b=" & bits(vb) &
					       " c_in=" & STD_LOGIC'IMAGE(vc) &
					       " | r=" & bits(r) & " (esperado " & bits(er) &
					       ") flags=" & bits(fl) & " (esperado " & bits(ex) & ")"
					       SEVERITY ERROR;
				END IF;
			END IF;
		END PROCEDURE;
	BEGIN
		------------------------------------------------------------
		-- Casos direcionados.  testa(nome, op, a, b, c_in, r, "chzvn")
		------------------------------------------------------------
		-- Exemplos do enunciado (ADD).  O nº 3 usa E7h (o PDF diz F7h).
		testa("ADD ex1", "0101", x"37", x"10", '0', x"47", "00000");
		testa("ADD ex2", "0101", x"37", x"19", '0', x"50", "01000");
		testa("ADD ex3", "0101", x"77", x"70", '0', x"E7", "00011");
		testa("ADD ex4", "0101", x"77", x"89", '0', x"00", "11100");
		testa("ADD ex5", "0101", x"80", x"80", '0', x"00", "10110");
		testa("ADD ex6", "0101", x"C7", x"D0", '0', x"97", "10001");
		testa("ADD ignora c_in", "0101", x"01", x"01", '1', x"02", "00000");

		-- ADDC
		testa("ADDC 0F+01+0", "0100", x"0F", x"01", '0', x"10", "01000");
		testa("ADDC FF+00+1", "0100", x"FF", x"00", '1', x"00", "11100");
		testa("ADDC 7F+00+1", "0100", x"7F", x"00", '1', x"80", "01011");

		-- SUB / SUBC
		testa("SUB 10-01",  "0111", x"10", x"01", '0', x"0F", "01000");
		testa("SUB 05-05",  "0111", x"05", x"05", '0', x"00", "00100");
		testa("SUB 00-01",  "0111", x"00", x"01", '0', x"FF", "11001");
		testa("SUB 80-01",  "0111", x"80", x"01", '0', x"7F", "01010");
		testa("SUBC 10-0F-1", "0110", x"10", x"0F", '1', x"00", "01100");

		-- Lógicas
		testa("PASS_B A5", "0000", x"FF", x"A5", '1', x"A5", "000-1");
		testa("PASS_B 00", "0000", x"FF", x"00", '1', x"00", "001-0");
		testa("OR",        "0001", x"F0", x"0F", '1', x"FF", "000-1");
		testa("XOR",       "0010", x"FF", x"FF", '1', x"00", "001-0");
		testa("AND",       "0011", x"F0", x"3C", '1', x"30", "000-0");
		testa("NOT 0F",    "1000", x"0F", x"00", '1', x"F0", "0-0-1");
		testa("NOT FF",    "1000", x"FF", x"00", '1', x"00", "0-1-0");

		-- Deslocamentos e rotações
		testa("SRA 81", "1001", x"81", x"00", '0', x"C0", "1-0-1");
		testa("SRA 01", "1001", x"01", x"00", '0', x"00", "1-1-0");
		testa("SRL 81", "1010", x"81", x"00", '1', x"40", "1-0-0");
		testa("SLL 81", "1011", x"81", x"00", '1', x"02", "1-0-0");
		testa("SLL 40", "1011", x"40", x"00", '1', x"80", "0-0-1");
		testa("RRC 01 c=1", "1100", x"01", x"00", '1', x"80", "1-0-1");
		testa("RRC 01 c=0", "1100", x"01", x"00", '0', x"00", "1-1-0");
		testa("RLC 80 c=1", "1101", x"80", x"00", '1', x"01", "1-0-0");
		testa("RLC 80 c=0", "1101", x"80", x"00", '0', x"00", "1-1-0");
		testa("RR 01", "1110", x"01", x"00", '0', x"80", "1-0-1");
		testa("RR 02", "1110", x"02", x"00", '0', x"01", "0-0-0");
		testa("RL 80", "1111", x"80", x"00", '0', x"01", "1-0-0");
		testa("RL 40", "1111", x"40", x"00", '0', x"80", "0-0-1");

		------------------------------------------------------------
		-- Exaustivo: ADDC, ADD, SUBC, SUB para todos a, b, c_in.
		-- O modelo usa inteiros (independente do código da ALU).
		------------------------------------------------------------
		FOR iop IN 4 TO 7 LOOP
			FOR ia IN 0 TO 255 LOOP
				FOR ib IN 0 TO 255 LOOP
					FOR ic IN 0 TO 1 LOOP
						IF iop = 4 OR iop = 6 THEN ce := ic; ELSE ce := 0; END IF;
						IF ia > 127 THEN sa := ia - 256; ELSE sa := ia; END IF;
						IF ib > 127 THEN sb := ib - 256; ELSE sb := ib; END IF;
						IF iop < 6 THEN -- soma
							s  := ia + ib + ce;
							sv := sa + sb + ce;
							hc := ((ia MOD 16) + (ib MOD 16) + ce) >= 16;
							cc := s >= 256;
							ri := s MOD 256;
						ELSE            -- subtração
							s  := ia - ib - ce;
							sv := sa - sb - ce;
							hc := ((ia MOD 16) - (ib MOD 16) - ce) < 0;
							cc := s < 0;
							ri := (s + 256) MOD 256;
						END IF;
						vv := (sv > 127) OR (sv < -128);
						ef := b2s(cc) & b2s(hc) & b2s(ri = 0) & b2s(vv) & b2s(ri > 127);
						testa("exaustivo", STD_LOGIC_VECTOR(TO_UNSIGNED(iop, 4)),
						      to_slv(ia), to_slv(ib), b2s(ic = 1), to_slv(ri), ef);
					END LOOP;
				END LOOP;
			END LOOP;
		END LOOP;

		REPORT "Fim: " & INTEGER'IMAGE(total) & " testes, " &
		       INTEGER'IMAGE(erros) & " erros.";
		WAIT; -- encerra o processo (a simulação termina)
	END PROCESS;
END ARCHITECTURE;
