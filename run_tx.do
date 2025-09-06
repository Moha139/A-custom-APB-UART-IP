vlib work
vlog uart_tx.v uart_tx_tb.v
vsim -voptargs=+acc work.uart_tx_tb
add wave *
run -all
