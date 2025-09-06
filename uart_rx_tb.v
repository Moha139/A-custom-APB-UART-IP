module uart_rx_tb;

    parameter BAUD_RATE  = 9600;          
    parameter CLK_FREQ   = 100_000_000;   
    parameter DATA_BITS  = 8;             

    integer i;
    real BAUD_RATE_REAL = BAUD_RATE;
    real BIT_PERIOD_NS  = 104166.6667; 

    reg  clk, arst_n;
    reg  rx_en, rx_rst;
    reg  rx_serial;
    wire rx_done, rx_busy, rx_error;
    wire [DATA_BITS-1:0] rx_data;

    // DUT instantiation
    uart_rx #(
        .BAUD_RATE(BAUD_RATE),
        .CLK_FREQ(CLK_FREQ),
        .DATA_BITS(DATA_BITS)
    ) dut (
        .clk(clk),
        .arst_n(arst_n),
        .rx_en(rx_en),
        .rx_rst(rx_rst),
        .rx_serial(rx_serial),
        .rx_done(rx_done),
        .rx_busy(rx_busy),
        .rx_error(rx_error),
        .rx_data(rx_data)
    );

      // Task to send one UART frame
    task send_byte;
        input [7:0] data;
        begin
            rx_serial = 1'b0;
            #(BIT_PERIOD_NS);

            for (i = 0; i < DATA_BITS; i = i + 1) begin
                rx_serial = data[i];
                #(BIT_PERIOD_NS);
            end
            
            rx_serial = 1'b1;
            #(BIT_PERIOD_NS);

            #(BIT_PERIOD_NS);
        end
    endtask

    always #5 clk = ~clk;

    initial begin
        clk     = 0;
        arst_n  = 0;
        rx_en     = 0;
        rx_rst    = 0;
        rx_serial = 1'b1;  
        #200 arst_n = 1;

        rx_en = 1;

        rx_rst = 1;
        #100 rx_rst = 0;

        #500;
        send_byte(8'h55);     
        #200;
        $stop;
    end
    endmodule
    

