// gps_parser.v
// GPS NMEA sentence parser

module gps_parser (
    input wire clk,
    input wire rst_n,
    input wire [7:0] uart_data,
    input wire uart_valid,
    output reg [31:0] latitude,
    output reg [31:0] longitude,
    output reg data_valid
);

    localparam WAIT_DOLLAR  = 4'd0;
    localparam WAIT_G1      = 4'd1;
    localparam WAIT_P       = 4'd2;
    localparam WAIT_G2      = 4'd3;
    localparam WAIT_G3      = 4'd4;
    localparam WAIT_A       = 4'd5;
    localparam SKIP_TIME    = 4'd6;
    localparam READ_LAT     = 4'd7;
    localparam READ_LAT_DIR = 4'd8;
    localparam READ_LON     = 4'd9;
    localparam READ_LON_DIR = 4'd10;
    localparam DONE         = 4'd11;

    reg [3:0] state, next_state;
    reg [3:0] field_count;
    reg [31:0] temp_lat, temp_lon;
    reg [3:0] digit_count;
    reg lat_south, lon_west;
    
    localparam CHAR_DOLLAR = 8'h24;
    localparam CHAR_G      = 8'h47;
    localparam CHAR_P      = 8'h50;
    localparam CHAR_A      = 8'h41;
    localparam CHAR_COMMA  = 8'h2C;
    localparam CHAR_N      = 8'h4E;
    localparam CHAR_S      = 8'h53;
    localparam CHAR_E      = 8'h45;
    localparam CHAR_W      = 8'h57;

    function is_digit;
        input [7:0] ch;
        begin
            is_digit = (ch >= 8'h30 && ch <= 8'h39);
        end
    endfunction

    function [3:0] digit_to_val;
        input [7:0] ch;
        begin
            digit_to_val = ch[3:0];
        end
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state <= WAIT_DOLLAR;
        else
            state <= next_state;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            next_state <= WAIT_DOLLAR;
            field_count <= 0;
            digit_count <= 0;
            temp_lat <= 0;
            temp_lon <= 0;
            latitude <= 0;
            longitude <= 0;
            data_valid <= 0;
            lat_south <= 0;
            lon_west <= 0;
        end else if (uart_valid) begin
            next_state <= state;
            
            case (state)
                WAIT_DOLLAR: begin
                    data_valid <= 0;
                    if (uart_data == CHAR_DOLLAR) begin
                        next_state <= WAIT_G1;
                        field_count <= 0;
                    end
                end
                
                WAIT_G1: begin
                    if (uart_data == CHAR_G)
                        next_state <= WAIT_P;
                    else
                        next_state <= WAIT_DOLLAR;
                end
                
                WAIT_P: begin
                    if (uart_data == CHAR_P)
                        next_state <= WAIT_G2;
                    else
                        next_state <= WAIT_DOLLAR;
                end
                
                WAIT_G2: begin
                    if (uart_data == CHAR_G)
                        next_state <= WAIT_G3;
                    else
                        next_state <= WAIT_DOLLAR;
                end
                
                WAIT_G3: begin
                    if (uart_data == CHAR_G)
                        next_state <= WAIT_A;
                    else
                        next_state <= WAIT_DOLLAR;
                end
                
                WAIT_A: begin
                    if (uart_data == CHAR_A)
                        next_state <= SKIP_TIME;
                    else
                        next_state <= WAIT_DOLLAR;
                end
                
                SKIP_TIME: begin
                    if (uart_data == CHAR_COMMA) begin
                        field_count <= field_count + 1;
                        if (field_count == 1) begin
                            next_state <= READ_LAT;
                            temp_lat <= 0;
                            digit_count <= 0;
                        end
                    end
                end
                
                READ_LAT: begin
                    if (uart_data == CHAR_COMMA) begin
                        next_state <= READ_LAT_DIR;
                    end else if (is_digit(uart_data) && digit_count < 8) begin
                        temp_lat <= temp_lat * 10 + digit_to_val(uart_data);
                        digit_count <= digit_count + 1;
                    end
                end
                
                READ_LAT_DIR: begin
                    if (uart_data == CHAR_N || uart_data == CHAR_S) begin
                        lat_south <= (uart_data == CHAR_S);
                    end else if (uart_data == CHAR_COMMA) begin
                        next_state <= READ_LON;
                        temp_lon <= 0;
                        digit_count <= 0;
                    end
                end
                
                READ_LON: begin
                    if (uart_data == CHAR_COMMA) begin
                        next_state <= READ_LON_DIR;
                    end else if (is_digit(uart_data) && digit_count < 8) begin
                        temp_lon <= temp_lon * 10 + digit_to_val(uart_data);
                        digit_count <= digit_count + 1;
                    end
                end
                
                READ_LON_DIR: begin
                    if (uart_data == CHAR_E || uart_data == CHAR_W) begin
                        lon_west <= (uart_data == CHAR_W);
                        next_state <= DONE;
                    end
                end
                
                DONE: begin
                    latitude <= temp_lat;
                    longitude <= temp_lon;
                    data_valid <= 1;
                    next_state <= WAIT_DOLLAR;
                end
                
                default: next_state <= WAIT_DOLLAR;
            endcase
        end
    end

endmodule
