module apb_uart_wrapper_tb();
    parameter PADDR_WIDTH = 32;
    parameter PWDATA_WIDTH = 32;
    parameter PRDATA_WIDTH = 32;

    // Register Addresses
    parameter CTRL_REG_ADDR  = 32'h0000;
    parameter STATS_REG_ADDR = 32'h0001;
    parameter TX_DATA_ADDR   = 32'h0002;
    parameter RX_DATA_ADDR   = 32'h0003;

    // Testbench signals
    reg                 PCLK;
    reg                 PRESETn;
    reg [PADDR_WIDTH-1:0] PADDR;
    reg                 PSEL;
    reg                 PENABLE;
    reg                 PWRITE;
    reg [PWDATA_WIDTH-1:0]  PWDATA;
    wire [PRDATA_WIDTH-1:0] PRDATA;
    wire                PREADY;
    wire                PSLVERR;
    
    // UART signals
    wire tx_serial;
    reg  rx_serial;

    // A register to hold the data read from the APB wrapper
    reg [PRDATA_WIDTH-1:0] read_data;

    // Instantiate the APB UART Wrapper
    apb_uart_wrapper #(
        .PADDR_WIDTH(PADDR_WIDTH),
        .PWDATA_WIDTH(PWDATA_WIDTH),
        .PRDATA_WIDTH(PRDATA_WIDTH)
    ) dut (
        .PCLK(PCLK),
        .PRESETn(PRESETn),
        .PADDR(PADDR),
        .PSEL(PSEL),
        .PENABLE(PENABLE),
        .PWRITE(PWRITE),
        .PWDATA(PWDATA),
        .PRDATA(PRDATA),
        .PREADY(PREADY),
        .PSLVERR(PSLVERR),
        .tx_serial(tx_serial),
        .rx_serial(rx_serial)
    );

    // Clock Generation
    always #5 PCLK = ~PCLK;

    // Test Tasks
    task apb_write;
        input [PADDR_WIDTH-1:0] addr;
        input [PWDATA_WIDTH-1:0] data;
    begin
        // Setup phase
        @(posedge PCLK);
        PSEL = 1'b1;
        PENABLE = 1'b0;
        PWRITE = 1'b1;
        PADDR = addr;
        PWDATA = data;
        
        // Access phase
        @(posedge PCLK);
        PENABLE = 1'b1;
        
        // Wait for transaction to complete
        @(posedge PCLK);
        while (PREADY == 1'b0) @(posedge PCLK);
        
        // Return to IDLE
        @(posedge PCLK);
        PSEL = 1'b0;
        PENABLE = 1'b0;
    end
    endtask

    task apb_read;
        input [PADDR_WIDTH-1:0] addr;
        output reg [PRDATA_WIDTH-1:0] data;
    begin
        // Setup phase
        @(posedge PCLK);
        PSEL = 1'b1;
        PENABLE = 1'b0;
        PWRITE = 1'b0;
        PADDR = addr;
        
        // Access phase
        @(posedge PCLK);
        PENABLE = 1'b1;
        
        // Wait for transaction to complete
        @(posedge PCLK);
        while (PREADY == 1'b0) @(posedge PCLK);
        data = PRDATA;
        
        // Return to IDLE
        @(posedge PCLK);
        PSEL = 1'b0;
        PENABLE = 1'b0;
    end
    endtask

    //  Test Sequence
    initial begin
        PCLK = 0;
        PRESETn = 0;
        PSEL = 0;
        PENABLE = 0;
        PWRITE = 0;
        PADDR = 0;
        PWDATA = 0;
        rx_serial = 1;
        read_data = 0;

        #100 PRESETn = 1;
        
        $display("Test 1: Writing data 8'h01 to TX_DATA register...");
        apb_write(TX_DATA_ADDR, 32'h0000_0001);

        $display("Test 2: Writing 8'h1 to CTRL_REG to enable TX...");
        apb_write(CTRL_REG_ADDR, 32'h0000_0001); 
        
        #1_000_000;
        
        $display("Test 3: Reading STATS_REG to check status...");
        apb_read(STATS_REG_ADDR, read_data);
        $display("STATS_REG after TX: 0x%h. Expected tx_done.", read_data);

        $display("Test 4: Writing 8'hC to CTRL_REG to reset TX and RX...");
        apb_write(CTRL_REG_ADDR, 32'h0000_000C); // tx_rst = 1, rx_rst = 1
        #100;
        apb_write(CTRL_REG_ADDR, 32'h0000_0000); // Clear reset bits

        
        $display("Test 5: Simulating incoming byte 8'hA5...");
        apb_write(CTRL_REG_ADDR, 32'h0000_0002); // rx_en = 1
        @(posedge PCLK);
        
        // Simulate start bit
        rx_serial = 1'b0;
        #104167;

        rx_serial = 1'b1; #104167;
        rx_serial = 1'b0; #104167;
        rx_serial = 1'b1; #104167;
        rx_serial = 1'b0; #104167;
        rx_serial = 1'b0; #104167;
        rx_serial = 1'b1; #104167;
        rx_serial = 1'b0; #104167;
        rx_serial = 1'b1; #104167;

        // Simulate stop bit
        rx_serial = 1'b1;
        #104167;

        $display("Test 6: Reading RX_DATA register...");
        apb_read(RX_DATA_ADDR, read_data);
        $display("RX_DATA: 0x%h. Expected 0x0000_00A5", read_data);

        $stop;
    end

endmodule