module apb_uart_wrapper #(
    parameter PADDR_WIDTH = 32,
    parameter PWDATA_WIDTH = 32,
    parameter PRDATA_WIDTH = 32,
    parameter DATA_BITS = 8
)(
    input                       PCLK,
    input                       PRESETn,
    input  [PADDR_WIDTH-1:0]    PADDR,
    input                       PSEL,
    input                       PENABLE,
    input                       PWRITE,
    input  [PWDATA_WIDTH-1:0]   PWDATA,
    output reg [PRDATA_WIDTH-1:0] PRDATA,
    output reg                  PREADY,
    output reg                  PSLVERR,

    // UART I/O
    output                      tx_serial,
    input                       rx_serial
);

    // Register Definitions (32-bit registers)
    parameter CTRL_REG_ADDR = 32'h0000;
    parameter STATS_REG_ADDR = 32'h0001;
    parameter TX_DATA_ADDR = 32'h0002;
    parameter RX_DATA_ADDR = 32'h0003;

    // Internal Registers
    reg [PWDATA_WIDTH-1:0] ctrl_reg;
    reg [PWDATA_WIDTH-1:0] stats_reg;
    reg [PWDATA_WIDTH-1:0] tx_data_reg;
    reg [PWDATA_WIDTH-1:0] rx_data_reg;

    // Control and Status Signals for UART
    wire tx_en, rx_en, tx_rst, rx_rst;
    wire tx_busy, tx_done, rx_busy, rx_done, rx_error;
    wire [DATA_BITS-1:0] tx_data_uart, rx_data_uart;

    assign tx_en  = ctrl_reg[0];
    assign rx_en  = ctrl_reg[1];
    assign tx_rst = ctrl_reg[2];
    assign rx_rst = ctrl_reg[3];
    assign tx_data_uart = tx_data_reg[DATA_BITS-1:0];
   
    // Status bits for STATS_REG
    parameter TX_BUSY_BIT = 0;
    parameter TX_DONE_BIT = 1;
    parameter RX_BUSY_BIT = 2;
    parameter RX_DONE_BIT = 3;
    parameter RX_ERROR_BIT = 4;

    // APB State Machine 
    parameter APB_IDLE = 2'b00;
    parameter APB_SETUP = 2'b01;
    parameter APB_ACCESS = 2'b10;
    reg [1:0] apb_state;
    

    // FSM for APB Protocol
    always @(posedge PCLK or negedge PRESETn) begin
        if (~PRESETn) begin
            apb_state <= APB_IDLE;
            PREADY <= 1'b0;
        end else begin
            case (apb_state)
                APB_IDLE: begin
                    PREADY <= 1'b0;
                    if (PSEL) begin
                        apb_state <= APB_SETUP;
                    end else begin
                        apb_state <= APB_IDLE;
                    end
                end
                APB_SETUP: begin
                    PREADY <= 1'b0;
                    if (PENABLE) begin
                        apb_state <= APB_ACCESS;
                    end else begin
                        apb_state <= APB_SETUP;
                    end
                end
                APB_ACCESS: begin
                    PREADY <= 1'b1;
                    apb_state <= APB_IDLE;
                end
                default: begin
                    apb_state <= APB_IDLE;
                    PREADY <= 1'b0;
                end
            endcase
        end
    end
    
    // APB Read/Write Logic
    always @(posedge PCLK or negedge PRESETn) begin
        if (~PRESETn) begin
            ctrl_reg <= 0;
            stats_reg <= 0;
            tx_data_reg <= 0;
            rx_data_reg <= 0;
            PRDATA <= 0;
            PSLVERR <= 0;

        end else if (PSEL && PENABLE) begin // APB Access Phase

            if (PWRITE) begin // Write Cycle
                PSLVERR <= 1'b0; // No error on writes 
                case (PADDR)
                    CTRL_REG_ADDR:  ctrl_reg <= PWDATA;
                    TX_DATA_ADDR:   tx_data_reg <= PWDATA;
                    default:        PSLVERR <= 1'b1; // Slave error for invalid address
                endcase

            end else begin // Read Cycle
                PSLVERR <= 1'b0; // No error on reads 
                case (PADDR)
                    CTRL_REG_ADDR:  PRDATA <= ctrl_reg;
                    STATS_REG_ADDR: PRDATA <= stats_reg;
                    TX_DATA_ADDR:   PRDATA <= tx_data_reg;
                    RX_DATA_ADDR:   PRDATA <= rx_data_reg;
                    default: begin
                        PRDATA <= 0;
                        PSLVERR <= 1'b1; // Slave error for invalid address
                    end
                endcase
            end
        end
        // Update stats_reg from UART outputs
        stats_reg <= {27'h0, rx_error, rx_done, rx_busy, tx_done, tx_busy};
        
        // Update RX_DATA_REG from UART receiver
        if (rx_done) begin
            rx_data_reg <= {24'h0, rx_data_uart};
        end
    end

    // Instance of UART Transmitter
    uart_tx #(
        .BAUD_RATE(9600),
        .CLK_FREQ(100_000_000)
    ) tx_inst (
        .clk(PCLK),
        .arst_n(PRESETn),
        .tx_en(tx_en),
        .tx_data(tx_data_uart),
        .tx_busy(tx_busy),
        .tx_done(tx_done),
        .tx_serial(tx_serial)
    );
    
    // Instance of UART Receiver
    uart_rx #(
        .BAUD_RATE(9600),
        .CLK_FREQ(100_000_000)
    ) rx_inst (
        .clk(PCLK),
        .arst_n( PRESETn),
        .rx_en(rx_en),
        .rx_rst(rx_rst),
        .rx_serial(rx_serial),
        .rx_done(rx_done),
        .rx_busy(rx_busy),
        .rx_error(rx_error),
        .rx_data(rx_data_uart)
    );

endmodule
