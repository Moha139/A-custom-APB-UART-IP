module uart_tx #(
    parameter BAUD_RATE   = 9600,           
    parameter CLK_FREQ    = 100_000_000,    
    parameter DATA_BITS   = 8               
) ( 
    input                           clk,        
    input                          arst_n,     
    input                           tx_en,       
    input[DATA_BITS-1:0]           tx_data,     
    output  reg                     tx_busy,     
    output  reg                     tx_done,     
    output  reg                     tx_serial    
);

    parameter CLKS_PER_BIT =   CLK_FREQ / BAUD_RATE;          
    parameter CLK_CNTER_BW =   $clog2(CLKS_PER_BIT) + 1;     
    parameter BIT_CNTER_BW =   $clog2(DATA_BITS) + 1;        

    // FSM states
    parameter IDLE      = 2'b00;
    parameter START_BIT = 2'b01;
    parameter STOP_BIT  = 2'b10;
    parameter DATA_BITS_STATE = 2'b11;
    reg [1:0]  state, next_state;
    

    reg [CLK_CNTER_BW-1:0]  clk_cnter;  
    reg [BIT_CNTER_BW-1:0]  bit_cnter; 
    reg start_bit_init;
    reg data_bit_init;
    reg stop_bit_init;
    reg stop_bit_end;
    reg busy; 

    // registered input data
    reg [DATA_BITS-1:0] r_tx_data;


    // FSM next state logic
    always @(*) begin
        next_state = IDLE;
        case (state)
            IDLE: if (tx_en == 1'b1) 
                      next_state = START_BIT;
                  else 
                      next_state = IDLE;

            START_BIT: if (data_bit_init) 
                           next_state = DATA_BITS_STATE;
                       else 
                           next_state = START_BIT;

            DATA_BITS_STATE: if (stop_bit_init) 
                                 next_state = STOP_BIT;
                             else 
                                 next_state = DATA_BITS_STATE;

            STOP_BIT: if (stop_bit_end) 
                          next_state = IDLE;
                      else 
                          next_state = STOP_BIT;
        endcase
    end
    

    // FSM output logic
    always @(*) begin
        start_bit_init = 1'b0;
        data_bit_init  = 1'b0;
        stop_bit_init  = 1'b0;
        stop_bit_end   = 1'b0;
        busy           = 1'b1;
        case (state)
            IDLE: begin
                start_bit_init = (tx_en == 1'b1);
                busy = 1'b0;
            end
            START_BIT: data_bit_init = (clk_cnter == CLKS_PER_BIT);

            DATA_BITS_STATE: begin
                if (bit_cnter < DATA_BITS) 
                    data_bit_init = (clk_cnter == CLKS_PER_BIT);
                else 
                    stop_bit_init = (clk_cnter == CLKS_PER_BIT);
            end
            STOP_BIT: stop_bit_end = (clk_cnter == CLKS_PER_BIT);
        endcase
    end

    
    // FSM state register
    always @(posedge clk or negedge arst_n) begin
        if (~arst_n) 
            state <= IDLE;
        else 
            state <= next_state;
    end


    // Register input data
    always @(posedge clk or negedge arst_n) begin
        if (~arst_n) 
            r_tx_data <= {DATA_BITS{1'b0}};
        else if (start_bit_init) 
            r_tx_data <= tx_data;
    end

    // TX line control
    always @(posedge clk or negedge arst_n) begin
        if (~arst_n) 
            tx_serial <= 1'b1;   
        else begin
            if (start_bit_init) 
                tx_serial <= 1'b0;                       
            else if (data_bit_init) 
                tx_serial <= r_tx_data[bit_cnter];       
            else if (stop_bit_init) 
                tx_serial <= 1'b1;                       
        end
    end

    
    // Counters
    always @(posedge clk or negedge arst_n) begin
        if (~arst_n) begin
            clk_cnter <= {CLK_CNTER_BW{1'b0}};
            bit_cnter <= {BIT_CNTER_BW{1'b0}};
        end else begin
            case (state)
                IDLE: begin
                    clk_cnter <= 0;
                    bit_cnter <= 0;
                end
                START_BIT: begin
                    if (clk_cnter < CLKS_PER_BIT) 
                        clk_cnter <= clk_cnter + 1'b1;
                    else 
                        clk_cnter <= 0;
                    if (data_bit_init) 
                        bit_cnter <= bit_cnter + 1'b1;
                end
                DATA_BITS_STATE: begin
                    if (clk_cnter < CLKS_PER_BIT) 
                        clk_cnter <= clk_cnter + 1'b1;
                    else 
                        clk_cnter <= 0;
                    if (data_bit_init) 
                        bit_cnter <= bit_cnter + 1'b1;
                    else if (stop_bit_init) 
                        bit_cnter <= 0;
                end
                STOP_BIT: if (clk_cnter < CLKS_PER_BIT) 
                              clk_cnter <= clk_cnter + 1'b1;
                          else 
                              clk_cnter <= 0;
            endcase
        end
    end

    
    // Status signals
    always @(posedge clk or negedge arst_n) begin
        if (~arst_n) begin
            tx_done <= 1'b0;
            tx_busy <= 1'b0;
        end else begin
            tx_done <= stop_bit_end;  
            tx_busy <= busy;
        end
    end


endmodule




