LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.std_logic_unsigned.all;

ENTITY alu IS
	PORT (
		a_in      : IN  STD_LOGIC_VECTOR(7 DOWNTO 0);
		b_in      : IN  STD_LOGIC_VECTOR(7 DOWNTO 0);
		c_in      : IN  STD_LOGIC;
		op_sel    : IN  STD_LOGIC_VECTOR(3 DOWNTO 0);
		r_out     : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
		flags_out : OUT STD_LOGIC_VECTOR(4 DOWNTO 0)
	);
END ENTITY;

ARCHITECTURE arch OF alu IS
	-- Códigos das operações ---------------------------------------------
	CONSTANT OP_PASS_B : STD_LOGIC_VECTOR(3 DOWNTO 0) := "0000";
	CONSTANT OP_OR     : STD_LOGIC_VECTOR(3 DOWNTO 0) := "0001";
	CONSTANT OP_XOR    : STD_LOGIC_VECTOR(3 DOWNTO 0) := "0010";
	CONSTANT OP_AND    : STD_LOGIC_VECTOR(3 DOWNTO 0) := "0011";
	CONSTANT OP_ADDC   : STD_LOGIC_VECTOR(3 DOWNTO 0) := "0100";
	CONSTANT OP_ADD    : STD_LOGIC_VECTOR(3 DOWNTO 0) := "0101";
	CONSTANT OP_SUBC   : STD_LOGIC_VECTOR(3 DOWNTO 0) := "0110";
	CONSTANT OP_SUB    : STD_LOGIC_VECTOR(3 DOWNTO 0) := "0111";
	CONSTANT OP_NOT    : STD_LOGIC_VECTOR(3 DOWNTO 0) := "1000";
	CONSTANT OP_SRA    : STD_LOGIC_VECTOR(3 DOWNTO 0) := "1001";
	CONSTANT OP_SRL    : STD_LOGIC_VECTOR(3 DOWNTO 0) := "1010";
	CONSTANT OP_SLL    : STD_LOGIC_VECTOR(3 DOWNTO 0) := "1011";
	CONSTANT OP_RRC    : STD_LOGIC_VECTOR(3 DOWNTO 0) := "1100";
	CONSTANT OP_RLC    : STD_LOGIC_VECTOR(3 DOWNTO 0) := "1101";
	CONSTANT OP_RR     : STD_LOGIC_VECTOR(3 DOWNTO 0) := "1110";
	CONSTANT OP_RL     : STD_LOGIC_VECTOR(3 DOWNTO 0) := "1111";

	-- Carry-in efetivo (só vale c_in em ADDC e SUBC)
	SIGNAL cin_ef : STD_LOGIC;

	-- Somador e subtrator (bit 8 é o carry)
	SIGNAL soma : STD_LOGIC_VECTOR(8 DOWNTO 0);
	SIGNAL dif  : STD_LOGIC_VECTOR(8 DOWNTO 0);

	-- Somador e subtrator dos nibbles baixos (bit 4 é o half-carry)
	SIGNAL h_soma : STD_LOGIC_VECTOR(4 DOWNTO 0);
	SIGNAL h_dif  : STD_LOGIC_VECTOR(4 DOWNTO 0);

	-- Overflow de soma/subtração
	SIGNAL v_soma : STD_LOGIC;
	SIGNAL v_dif  : STD_LOGIC;

	-- Resultado
	SIGNAL res   : STD_LOGIC_VECTOR(8 DOWNTO 0);
	SIGNAL r_int : STD_LOGIC_VECTOR(7 DOWNTO 0); -- resultado sem o carry

	SIGNAL n_flag, v_flag, z_flag, h_flag, c_flag : STD_LOGIC;
BEGIN
	-- Seleção da operação ------------------------------------------------
	WITH op_sel SELECT
		res <= '0'     & b_in                         WHEN OP_PASS_B,
		       '0'     & (a_in OR  b_in)              WHEN OP_OR,
		       '0'     & (a_in XOR b_in)              WHEN OP_XOR,
		       '0'     & (a_in AND b_in)              WHEN OP_AND,
		       soma                                   WHEN OP_ADDC | OP_ADD,
		       dif                                    WHEN OP_SUBC | OP_SUB,
		       '0'     & (NOT a_in)                   WHEN OP_NOT,
		       a_in(0) & a_in(7) & a_in(7 DOWNTO 1)   WHEN OP_SRA,
		       a_in(0) & '0' & a_in(7 DOWNTO 1)       WHEN OP_SRL,
		       a_in(7) & a_in(6 DOWNTO 0) & '0'       WHEN OP_SLL,
		       a_in(0) & c_in & a_in(7 DOWNTO 1)      WHEN OP_RRC,
		       a_in(7) & a_in(6 DOWNTO 0) & c_in      WHEN OP_RLC,
		       a_in(0) & a_in(0) & a_in(7 DOWNTO 1)   WHEN OP_RR,
		       a_in(7) & a_in(6 DOWNTO 0) & a_in(7)   WHEN OP_RL,
		       (OTHERS => '0')                        WHEN OTHERS;

	r_int <= res(7 DOWNTO 0);
	r_out <= r_int;

	-- Unidade aritmética -------------------------------------------------
	WITH op_sel SELECT
		cin_ef <= c_in WHEN OP_ADDC | OP_SUBC,
		          '0'  WHEN OTHERS;

	soma <= ('0' & a_in) + ('0' & b_in) + cin_ef;
	dif  <= ('0' & a_in) - ('0' & b_in) - cin_ef;

	h_soma <= ('0' & a_in(3 DOWNTO 0)) + ('0' & b_in(3 DOWNTO 0)) + cin_ef;
	h_dif  <= ('0' & a_in(3 DOWNTO 0)) - ('0' & b_in(3 DOWNTO 0)) - cin_ef;

	-- Soma: overflow se os operandos têm o mesmo sinal e o resultado tem
	-- sinal diferente.
	v_soma <= (a_in(7) AND b_in(7) AND (NOT soma(7))) OR
	          ((NOT a_in(7)) AND (NOT b_in(7)) AND soma(7));

	-- Subtração: overflow se os operandos têm sinais diferentes e o
	-- resultado tem o sinal de b.
	v_dif  <= (a_in(7) AND (NOT b_in(7)) AND (NOT dif(7))) OR
	          ((NOT a_in(7)) AND b_in(7) AND dif(7));

	-- Flags --------------------------------------------------------------
	n_flag <= res(7);
	c_flag <= res(8);

	WITH r_int SELECT
		z_flag <= '1' WHEN "00000000",
		          '0' WHEN OTHERS;

	WITH op_sel SELECT
		h_flag <= '0'        WHEN OP_PASS_B | OP_OR | OP_XOR | OP_AND,
		          h_soma(4)  WHEN OP_ADDC | OP_ADD,
		          h_dif(4)   WHEN OP_SUBC | OP_SUB,
		          '-'        WHEN OTHERS;

	WITH op_sel SELECT
		v_flag <= v_soma     WHEN OP_ADDC | OP_ADD,
		          v_dif      WHEN OP_SUBC | OP_SUB,
		          '-'        WHEN OTHERS;

	flags_out <= c_flag & h_flag & z_flag & v_flag & n_flag;
END ARCHITECTURE;
