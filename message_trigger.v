// message_trigger.v
// Message generation and GSM communication

module message_trigger (
    input wire clk,
    input wire rst_n,
    input wire send_alert,
    input wire [31:0] latitude,
    input wire [31:0] longitude,
    input wire tx_ready,
    output reg [7:0] tx_data,
    output reg tx_valid,
    output reg done
);

    localparam IDLE           = 4'd0;
    localparam SEND_AT_CMGF   = 4'd1;
    localparam WAIT_OK1       = 4'd2;
    localparam SEND_AT_CMGS   = 4'd3;
    localparam WAIT_PROMPT    = 4'd4;
    localparam SEND_MESSAGE   = 4'd5;
    localparam SEND_CTRL_Z    = 4'd6;
    localparam WAIT_OK2       = 4'd7;
    localparam COMPLETE       = 4'd8;

    reg [3:0] state, next_state;
    reg [8:0] char_index;
    reg [7:0] message_len;
    reg [3:0] wait_counter;

    localparam AT_CMGF_LEN = 11;
    reg [7:0] at_cmgf [0:10];
    
    localparam AT_CMGS_LEN = 23;
    reg [7:0] at_cmgs [0:22];
    
    localparam MSG_LEN = 43;
    reg [7:0] message [0:42];

    integer i;
    initial begin
        // AT+CMGF=1\r\n
        at_cmgf[0]  = 8'h41; // A
        at_cmgf[1]  = 8'h54; // T
        at_cmgf[2]  = 8'h2B; // +
        at_cmgf[3]  = 8'h43; // C
        at_cmgf[4]  = 8'h4D; // M
        at_cmgf[5]  = 8'h47; // G
        at_cmgf[6]  = 8'h46; // F
        at_cmgf[7]  = 8'h3D; // =
        at_cmgf[8]  = 8'h31; // 1
        at_cmgf[9]  = 8'h0D; // \r
        at_cmgf[10] = 8'h0A; // \n
        
        // AT+CMGS="+1234567890"\r\n
        at_cmgs[0]  = 8'h41; // A
        at_cmgs[1]  = 8'h54; // T
        at_cmgs[2]  = 8'h2B; // +
        at_cmgs[3]  = 8'h43; // C
        at_cmgs[4]  = 8'h4D; // M
        at_cmgs[5]  = 8'h47; // G
        at_cmgs[6]  = 8'h53; // S
        at_cmgs[7]  = 8'h3D; // =
        at_cmgs[8]  = 8'h22; // "
        at_cmgs[9]  = 8'h2B; // +
        at_cmgs[10] = 8'h31; // 1
        at_cmgs[11] = 8'h32; // 2
        at_cmgs[12] = 8'h33; // 3
        at_cmgs[13] = 8'h34; // 4
        at_cmgs[14] = 8'h35; // 5
        at_cmgs[15] = 8'h36; // 6
        at_cmgs[16] = 8'h37; // 7
        at_cmgs[17] = 8'h38; // 8
        at_cmgs[18] = 8'h39; // 9
        at_cmgs[19] = 8'h30; // 0
        at_cmgs[20] = 8'h22; // "
        at_cmgs[21] = 8'h0D; // \r
        at_cmgs[22] = 8'h0A; // \n
        
        // Message: "EMERGENCY! Help needed. Location available."
        message[0]  = 8'h45; // E
        message[1]  = 8'h4D; // M
        message[2]  = 8'h45; // E
        message[3]  = 8'h52; // R
        message[4]  = 8'h47; // G
        message[5]  = 8'h45; // E
        message[6]  = 8'h4E; // N
        message[7]  = 8'h43; // C
        message[8]  = 8'h59; // Y
        message[9]  = 8'h21; // !
        message[10] = 8'h20; // (space)
        message[11] = 8'h48; // H
        message[12] = 8'h65; // e
        message[13] = 8'h6C; // l
        message[14] = 8'h70; // p
        message[15] = 8'h20; // (space)
        message[16] = 8'h6E; // n
        message[17] = 8'h65; // e
        message[18] = 8'h65; // e
        message[19] = 8'h64; // d
        message[20] = 8'h65; // e
        message[21] = 8'h64; // d
        message[22] = 8'h2E; // .
        message[23] = 8'h20; // (space)
        message[24] = 8'h4C; // L
        message[25] = 8'h6F; // o
        message[26] = 8'h63; // c
        message[27] = 8'h61; // a
        message[28] = 8'h74; // t
        message[29] = 8'h69; // i
        message[30] = 8'h6F; // o
        message[31] = 8'h6E; // n
        message[32] = 8'h20; // (space)
        message[33] = 8'h61; // a
        message[34] = 8'h76; // v
        message[35] = 8'h61; // a
        message[36] = 8'h69; // i
        message[37] = 8'h6C; // l
        message[38] = 8'h61; // a
        message[39] = 8'h62; // b
        message[40] = 8'h6C; // l
        message[41] = 8'h65; // e
        message[42] = 8'h2E; // .
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state <= IDLE;
        else
            state <= next_state;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            next_state <= IDLE;
            char_index <= 0;
            tx_data <= 8'h00;
            tx_valid <= 1'b0;
            done <= 1'b0;
            wait_counter <= 0;
            message_len <= MSG_LEN;
        end else begin
            tx_valid <= 1'b0;
            done <= 1'b0;
            
            case (state)
                IDLE: begin
                    char_index <= 0;
                    wait_counter <= 0;
                    if (send_alert) begin
                        next_state <= SEND_AT_CMGF;
                    end
                end
                
                SEND_AT_CMGF: begin
                    if (tx_ready) begin
                        tx_data <= at_cmgf[char_index];
                        tx_valid <= 1'b1;
                        if (char_index < AT_CMGF_LEN - 1) begin
                            char_index <= char_index + 1;
                        end else begin
                            char_index <= 0;
                            next_state <= WAIT_OK1;
                        end
                    end
                end
                
                WAIT_OK1: begin
                    wait_counter <= wait_counter + 1;
                    if (wait_counter == 15) begin
                        wait_counter <= 0;
                        next_state <= SEND_AT_CMGS;
                    end
                end
                
                SEND_AT_CMGS: begin
                    if (tx_ready) begin
                        tx_data <= at_cmgs[char_index];
                        tx_valid <= 1'b1;
                        if (char_index < AT_CMGS_LEN - 1) begin
                            char_index <= char_index + 1;
                        end else begin
                            char_index <= 0;
                            next_state <= WAIT_PROMPT;
                        end
                    end
                end
                
                WAIT_PROMPT: begin
                    wait_counter <= wait_counter + 1;
                    if (wait_counter == 15) begin
                        wait_counter <= 0;
                        next_state <= SEND_MESSAGE;
                    end
                end
                
                SEND_MESSAGE: begin
                    if (tx_ready) begin
                        tx_data <= message[char_index];
                        tx_valid <= 1'b1;
                        if (char_index < message_len - 1) begin
                            char_index <= char_index + 1;
                        end else begin
                            char_index <= 0;
                            next_state <= SEND_CTRL_Z;
                        end
                    end
                end
                
                SEND_CTRL_Z: begin
                    if (tx_ready) begin
                        tx_data <= 8'h1A; // Ctrl+Z
                        tx_valid <= 1'b1;
                        next_state <= WAIT_OK2;
                    end
                end
                
                WAIT_OK2: begin
                    wait_counter <= wait_counter + 1;
                    if (wait_counter == 15) begin
                        next_state <= COMPLETE;
                    end
                end
                
                COMPLETE: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end
                
                default: next_state <= IDLE;
            endcase
        end
    end

endmodule
