// uart_tx.v
// UART Transmitter module

module uart_tx #(
    parameter CLK_FREQ = 25_000_000,
    parameter BAUD_RATE = 9600
)(
    input wire clk,
    input wire rst_n,
    input wire [7:0] tx_data,
    input wire tx_valid,
    output reg tx,
    output wire tx_ready
);

    localparam DIVISOR = CLK_FREQ / BAUD_RATE;
    localparam DIVISOR_WIDTH = $clog2(DIVISOR);

    localparam IDLE  = 2'b00;
    localparam START = 2'b01;
    localparam DATA  = 2'b10;
    localparam STOP  = 2'b11;

    reg [1:0] state, next_state;
    reg [DIVISOR_WIDTH-1:0] baud_counter;
    reg [2:0] bit_counter;
    reg [7:0] tx_shift_reg;
    reg baud_tick;

    assign tx_ready = (state == IDLE);

    // Baud rate generator
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            baud_counter <= 0;
            baud_tick <= 0;
        end else begin
            if (state == IDLE) begin
                baud_counter <= 0;
                baud_tick <= 0;
            end else if (baud_counter == DIVISOR - 1) begin
                baud_counter <= 0;
                baud_tick <= 1;
            end else begin
                baud_counter <= baud_counter + 1;
                baud_tick <= 0;
            end
        end
    end

    // State register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state <= IDLE;
        else
            state <= next_state;
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        
        case (state)
            IDLE: begin
                if (tx_valid)
                    next_state = START;
            end
            
            START: begin
                if (baud_tick)
                    next_state = DATA;
            end
            
            DATA: begin
                if (baud_tick && bit_counter == 7)
                    next_state = STOP;
            end
            
            STOP: begin
                if (baud_tick)
                    next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

    // Output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tx <= 1'b1;
            bit_counter <= 0;
            tx_shift_reg <= 8'h00;
        end else begin
            case (state)
                IDLE: begin
                    tx <= 1'b1;
                    bit_counter <= 0;
                    if (tx_valid)
                        tx_shift_reg <= tx_data;
                end
                
                START: begin
                    tx <= 1'b0;
                end
                
                DATA: begin
                    tx <= tx_shift_reg[0];
                    if (baud_tick) begin
                        tx_shift_reg <= {1'b0, tx_shift_reg[7:1]};
                        bit_counter <= bit_counter + 1;
                    end
                end
                
                STOP: begin
                    tx <= 1'b1;
                end
            endcase
        end
    end

endmodule
