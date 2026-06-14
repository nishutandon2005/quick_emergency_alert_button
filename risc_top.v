// emergency_alert_top.v
// Top-level module for Emergency Alert System

module emergency_alert_top #(
    parameter CLK_FREQ = 25_000_000,
    parameter BAUD_RATE = 9600,
    parameter DEBOUNCE_TIME_MS = 20
)(
    input wire clk,
    input wire rst_n,
    input wire emergency_btn,
    input wire uart_rx_gps,
    output wire uart_tx_gsm,
    output wire led_ready,
    output wire led_emergency,
    output wire led_gps_valid,
    output wire [2:0] state_debug
);

    wire btn_pressed;
    wire btn_released;
    wire emergency_active;
    wire send_alert;
    wire uart_tx_ready;
    
    wire [7:0] gps_rx_data;
    wire gps_rx_valid;
    
    wire [31:0] latitude;
    wire [31:0] longitude;
    wire gps_data_valid;
    
    wire [7:0] message_data;
    wire message_valid;
    wire message_done;

    button_debounce #(
        .CLK_FREQ(CLK_FREQ),
        .DEBOUNCE_TIME_MS(DEBOUNCE_TIME_MS)
    ) u_debounce (
        .clk(clk),
        .rst_n(rst_n),
        .btn_in(emergency_btn),
        .btn_pressed(btn_pressed),
        .btn_released(btn_released)
    );

    emergency_fsm u_fsm (
        .clk(clk),
        .rst_n(rst_n),
        .btn_pressed(btn_pressed),
        .btn_released(btn_released),
        .gps_valid(gps_data_valid),
        .message_done(message_done),
        .emergency_active(emergency_active),
        .send_alert(send_alert),
        .state_out(state_debug)
    );

    uart_rx #(
        .CLK_FREQ(CLK_FREQ),
        .BAUD_RATE(BAUD_RATE)
    ) u_uart_rx_gps (
        .clk(clk),
        .rst_n(rst_n),
        .rx(uart_rx_gps),
        .rx_data(gps_rx_data),
        .rx_valid(gps_rx_valid)
    );

    gps_parser u_gps_parser (
        .clk(clk),
        .rst_n(rst_n),
        .uart_data(gps_rx_data),
        .uart_valid(gps_rx_valid),
        .latitude(latitude),
        .longitude(longitude),
        .data_valid(gps_data_valid)
    );

    message_trigger u_message_trigger (
        .clk(clk),
        .rst_n(rst_n),
        .send_alert(send_alert),
        .latitude(latitude),
        .longitude(longitude),
        .tx_ready(uart_tx_ready),
        .tx_data(message_data),
        .tx_valid(message_valid),
        .done(message_done)
    );

    uart_tx #(
        .CLK_FREQ(CLK_FREQ),
        .BAUD_RATE(BAUD_RATE)
    ) u_uart_tx_gsm (
        .clk(clk),
        .rst_n(rst_n),
        .tx_data(message_data),
        .tx_valid(message_valid),
        .tx(uart_tx_gsm),
        .tx_ready(uart_tx_ready)
    );

    assign led_ready = rst_n && !emergency_active;
    assign led_emergency = emergency_active;
    assign led_gps_valid = gps_data_valid;

endmodule
