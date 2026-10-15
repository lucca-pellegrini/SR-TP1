# -------------------------------------------------------------------------- #
# Synopsys Design Constraints (SDC) para o design "reg_bank".
#
# Clock de 50 MHz (o oscilador da DE2) em clk_in. As demais entradas e saídas
# são constrangidas em relação a ele, só para o TimeQuest ter uma referência
# (isso não afeta a lógica nem a implementação).
# -------------------------------------------------------------------------- #

create_clock -name clk_in -period 20.000 [get_ports clk_in]

set_input_delay  -clock clk_in 2.000 [remove_from_collection [all_inputs] [get_ports clk_in]]
set_output_delay -clock clk_in 2.000 [all_outputs]
