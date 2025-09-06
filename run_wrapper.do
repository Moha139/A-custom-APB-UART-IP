vlib work
vlog apb_uart_wrapper.v apb_uart_wrapper_tb.v
vsim -voptargs=+acc apb_uart_wrapper_tb
add wave *
run -all
