// uart_rx.v
// UART Receiver module

module uart_rx #(
    parameter CLK_FREQ = 25_000_000,
    parameter BAUD_RATE = 9600
)(
    input wire clk,
    input wire rst_n,
    input wire rx,
    output reg [7:0] rx_data,
    output reg rx_valid
);

    localparam DIVISOR = CLK_FREQ / BAUD_RATE;
    localparam DIVISOR_WIDTH = $clog2(DIVISOR);
    localparam HALF_DIVISOR = DIVISOR / 2;

    localparam IDLE  = 2'b00;
    localparam START = 2'b01;
    localparam DATA  = 2'b10;
    localparam STOP  = 2'b11;

    reg [1:0] state, next_state;
    reg [DIVISOR_WIDTH-1:0] baud_counter;
    reg [2:0] bit_counter;
    reg [7:0] rx_shift_reg;
    reg rx_sync_0, rx_sync_1;
    reg baud_tick;

    // Input synchronizer
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_sync_0 <= 1'b1;
            rx_sync_1 <= 1'b1;
        end else begin
            rx_sync_0 <= rx;
            rx_sync_1 <= rx_sync_0;
        end
    end

    // Baud rate generator
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            baud_counter <= 0;
            baud_tick <= 0;
        end else begin
            if (state == IDLE) begin
                baud_counter <= 0;
                baud_tick <= 0;
            end else if (state == START) begin
                if (baud_counter == HALF_DIVISOR - 1) begin
                    baud_counter <= 0;
                    baud_tick <= 1;
                end else begin
                    baud_counter <= baud_counter + 1;
                    baud_tick <= 0;
                end
            end else begin
                if (baud_counter == DIVISOR - 1) begin
                    baud_counter <= 0;
                    baud_tick <= 1;
                end else begin
                    baud_counter <= baud_counter + 1;
                    baud_tick <= 0;
                end
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
                if (rx_sync_1 == 1'b0)
                    next_state = START;
            end
            
            START: begin
                if (baud_tick) begin
                    if (rx_sync_1 == 1'b0)
                        next_state = DATA;
                    else
                        next_state = IDLE;
                end
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

    // Data reception
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            bit_counter <= 0;
            rx_shift_reg <= 8'h00;
            rx_data <= 8'h00;
            rx_valid <= 1'b0;
        end else begin
            rx_valid <= 1'b0;
            
            case (state)
                IDLE: begin
                    bit_counter <= 0;
                end
                
                START: begin
                end
                
                DATA: begin
                    if (baud_tick) begin
                        rx_shift_reg <= {rx_sync_1, rx_shift_reg[7:1]};
                        bit_counter <= bit_counter + 1;
                    end
                end
                
                STOP: begin
                    if (baud_tick) begin
                        if (rx_sync_1 == 1'b1) begin
                            rx_data <= rx_shift_reg;
                            rx_valid <= 1'b1;
                        end
                    end
                end
            endcase
        end
    end

endmodule
