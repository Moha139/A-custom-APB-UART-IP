vlib work
vlog uart_rx.v uart_rx_tb.v
vsim -voptargs=+acc work.uart_rx_tb
add wave *
run -all
