// button_debounce.v
// Debounces mechanical button presses

module button_debounce #(
    parameter CLK_FREQ = 25_000_000,
    parameter DEBOUNCE_TIME_MS = 20
)(
    input wire clk,
    input wire rst_n,
    input wire btn_in,
    output reg btn_pressed,
    output reg btn_released
);

    localparam COUNTER_MAX = (CLK_FREQ / 1000) * DEBOUNCE_TIME_MS;
    localparam COUNTER_WIDTH = $clog2(COUNTER_MAX + 1);

    reg [COUNTER_WIDTH-1:0] counter;
    reg btn_sync_0, btn_sync_1;
    reg btn_state;
    reg btn_state_prev;

    // Two-stage synchronizer
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            btn_sync_0 <= 1'b0;
            btn_sync_1 <= 1'b0;
        end else begin
            btn_sync_0 <= btn_in;
            btn_sync_1 <= btn_sync_0;
        end
    end

    // Debounce counter
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            counter <= 0;
            btn_state <= 1'b0;
        end else begin
            if (btn_sync_1 != btn_state) begin
                if (counter == COUNTER_MAX) begin
                    btn_state <= btn_sync_1;
                    counter <= 0;
                end else begin
                    counter <= counter + 1;
                end
            end else begin
                counter <= 0;
            end
        end
    end

    // Edge detection
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            btn_state_prev <= 1'b0;
            btn_pressed <= 1'b0;
            btn_released <= 1'b0;
        end else begin
            btn_state_prev <= btn_state;
            btn_pressed <= btn_state && !btn_state_prev;
            btn_released <= !btn_state && btn_state_prev;
        end
    end

endmodule
