module uart_tx_tb;
   parameter BAUD_RATE   = 9600;          
    parameter CLK_FREQ    = 100_000_000;   
    parameter DATA_BITS   = 8;             

    real BAUD_RATE_REAL = BAUD_RATE;
    real BAUD_PERIOD_NS = 104166.6667 ; 
    real WAIT_TIME      = 1041666.667 ; 

    reg clk, arst_n;
    reg  tx_en;
    reg  [DATA_BITS-1:0] tx_data;
    wire tx_busy, tx_done;
    wire tx_serial;

    // DUT instantiation
    uart_tx #(
        .BAUD_RATE(BAUD_RATE),
        .CLK_FREQ(CLK_FREQ),
        .DATA_BITS(DATA_BITS)
    ) DUT (
        .clk(clk),
        .arst_n(arst_n),
        .tx_en(tx_en),
        .tx_data(tx_data),
        .tx_busy(tx_busy),
        .tx_done(tx_done),
        .tx_serial(tx_serial)
    );

    // Task to send one byte
    task send_data;
        input [7:0] data;
        begin
            tx_data = data;
            #20 tx_en = 1'b1;      
            #20 tx_en = 1'b0;
            #WAIT_TIME;           
            #200;                  
        end
    endtask

    always #5 clk = ~clk; 

    // Test sequence
    initial begin
        clk    = 0;
        arst_n  = 0;
        tx_en    = 1'b0;
        #100 arst_n = 1;

        send_data(8'h55);   
        send_data(8'hAF);   

        #200;
        $stop;
    end
endmodule