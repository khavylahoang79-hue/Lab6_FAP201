// ================================================================
// FAP201 - Lab06: Memory Game with 74HC595 Display (Timing Constraints)
// Target: GW5A-LV25UG324C2/I1
// Board : Xiaomeige ACG525
// ================================================================

create_clock -name clk -period 20 -waveform {0 10} [get_ports {clk_50m_i}]