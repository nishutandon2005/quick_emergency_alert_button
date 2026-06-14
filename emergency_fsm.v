
module emergency_fsm (
    input wire clk,
    input wire rst_n,
    input wire btn_pressed,
    input wire btn_released,
    input wire gps_valid,
    input wire message_done,
    output reg emergency_active,
    output reg send_alert,
    output reg [2:0] state_out
);

    localparam [2:0] IDLE        = 3'b000;
    localparam [2:0] EMERGENCY   = 3'b001;
    localparam [2:0] WAIT_GPS    = 3'b010;
    localparam [2:0] SEND_ALERT  = 3'b011;
    localparam [2:0] SENDING     = 3'b100;
    localparam [2:0] COOLDOWN    = 3'b101;

    reg [2:0] current_state, next_state;
    reg [25:0] timeout_counter;
    localparam TIMEOUT_MAX = 26'd25_000_000;
    wire timeout_expired = (timeout_counter >= TIMEOUT_MAX);

    // State register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            timeout_counter <= 0;
        end else begin
            current_state <= next_state;
            
            if (current_state == WAIT_GPS) begin
                if (timeout_counter < TIMEOUT_MAX)
                    timeout_counter <= timeout_counter + 1;
            end else begin
                timeout_counter <= 0;
            end
        end
    end

    // Next state logic
    always @(*) begin
        next_state = current_state;
        emergency_active = 1'b0;
        send_alert = 1'b0;
        
        case (current_state)
            IDLE: begin
                if (btn_pressed) begin
                    next_state = EMERGENCY;
                end
            end
            
            EMERGENCY: begin
                emergency_active = 1'b1;
                if (btn_released) begin
                    next_state = IDLE;
                end else begin
                    next_state = WAIT_GPS;
                end
            end
            
            WAIT_GPS: begin
                emergency_active = 1'b1;
                if (gps_valid) begin
                    next_state = SEND_ALERT;
                end else if (timeout_expired) begin
                    next_state = SEND_ALERT;
                end else if (btn_released) begin
                    next_state = IDLE;
                end
            end
            
            SEND_ALERT: begin
                emergency_active = 1'b1;
                send_alert = 1'b1;
                next_state = SENDING;
            end
            
            SENDING: begin
                emergency_active = 1'b1;
                if (message_done) begin
                    next_state = COOLDOWN;
                end
            end
            
            COOLDOWN: begin
                next_state = IDLE;
            end
            
            default: begin
                next_state = IDLE;
            end
        endcase
    end

    // Debug output
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state_out <= 3'b000;
        else
            state_out <= current_state;
    end

endmodule
