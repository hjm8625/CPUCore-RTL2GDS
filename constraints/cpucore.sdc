# ns

# target : 50MHz(50% duty)
create_clock -name core_clk \
    -period 20.0 \
    -waveform {0.0 10.0} \
    [get_ports clk]

# make clock more realistic (clock assumptions)
set_clock_uncertainty 0.10 [get_clocks core_clk]
set_clock_transition 0.05 [get_clocks core_clk]

#set i/o delay(except clk)
set_input_delay -clock core_clk -max 1.0 [all_inputs -no_clocks]
set_input_delay -clock core_clk -min 0.0 [all_inputs -no_clocks]
set_output_delay -clock core_clk -max 1.0 [all_outputs]
set_output_delay -clock core_clk -min 0.0 [all_outputs]

# load assumptions for sta
set_load 0.05 [all_outputs]
