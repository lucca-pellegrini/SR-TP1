# -------------------------------------------------------------------------- #
# Synopsys Design Constraints (SDC) para o design "de2_alu" / "alu".
#
# O design é puramente combinacional (nao ha clock nem registradores), entao
# nao existe um clock de porta real para constranger o timing. Para que o
# TimeQuest Timing Analyzer tenha um clock de referencia (evitando os avisos
# "SDC file not found" e "No clocks defined in design"), definimos um clock
# virtual (nao associado a nenhum pino) e usamos set_input_delay /
# set_output_delay para caracterizar os caminhos entrada->saida em relacao a
# ele. Isso nao afeta a logica nem a implementacao: serve apenas para a
# analise de timing ter uma referencia.
# -------------------------------------------------------------------------- #

create_clock -name virtual_clock -period 20.000

set_input_delay  -clock virtual_clock 2.000 [get_ports {SW[*] KEY[*]}]
set_output_delay -clock virtual_clock 2.000 [get_ports {HEX0[*] HEX1[*] HEX2[*] HEX3[*] HEX4[*] HEX5[*] HEX7[*] LEDR[*] LEDG[*]}]
