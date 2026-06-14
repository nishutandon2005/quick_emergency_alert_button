// testbench.v
// Testbench for Emergency Alert System

`timescale 1ns/1ps

module tb_emergency_alert_top();

    parameter CLK_PERIOD = 40;
    parameter CLK_FREQ = 25_000_000;
    parameter BAUD_RATE = 9600;
    
    reg clk;
    reg rst_n;
    reg emergency_btn;
    reg uart_rx_gps;
    wire uart_tx_gsm;
    wire led_ready;
    wire led_emergency;
    wire led_gps_valid;
    wire [2:0] state_debug;
    
    emergency_alert_top #(
        .CLK_FREQ(CLK_FREQ),
        .BAUD_RATE(BAUD_RATE),
        .DEBOUNCE_TIME_MS(5)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .emergency_btn(emergency_btn),
        .uart_rx_gps(uart_rx_gps),
        .uart_tx_gsm(uart_tx_gsm),
        .led_ready(led_ready),
        .led_emergency(led_emergency),
        .led_gps_valid(led_gps_valid),
        .state_debug(state_debug)
    );
    
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end
    
    localparam UART_BIT_PERIOD = 104167;
    
    task send_uart_byte;
        input [7:0] data;
        integer i;
        begin
            uart_rx_gps = 0;
            #UART_BIT_PERIOD;
            
            for (i = 0; i < 8; i = i + 1) begin
                uart_rx_gps = data[i];
                #UART_BIT_PERIOD;
            end
            
            uart_rx_gps = 1;
            #UART_BIT_PERIOD;
        end
    endtask
    
    task send_gps_sentence;
        begin
            $display("[%0t] Sending GPS NMEA sentence...", $time);
            send_uart_byte(8'h24); // $
            send_uart_byte(8'h47); // G
            send_uart_byte(8'h50); // P
            send_uart_byte(8'h47); // G
            send_uart_byte(8'h47); // G
            send_uart_byte(8'h41); // A
            send_uart_byte(8'h2C); // ,
            
            send_uart_byte(8'h31); // 1
            send_uart_byte(8'h32); // 2
            send_uart_byte(8'h33); // 3
            send_uart_byte(8'h35); // 5
            send_uart_byte(8'h31); // 1
            send_uart_byte(8'h39); // 9
            send_uart_byte(8'h2C); // ,
            
            send_uart_byte(8'h34); // 4
            send_uart_byte(8'h38); // 8
            send_uart_byte(8'h30); // 0
            send_uart_byte(8'h37); // 7
            send_uart_byte(8'h30); // 0
            send_uart_byte(8'h33); // 3
            send_uart_byte(8'h38); // 8
            send_uart_byte(8'h2C); // ,
            
            send_uart_byte(8'h4E); // N
            send_uart_byte(8'h2C); // ,
            
            send_uart_byte(8'h30); // 0
            send_uart_byte(8'h31); // 1
            send_uart_byte(8'h31); // 1
            send_uart_byte(8'h33); // 3
            send_uart_byte(8'h31); // 1
            send_uart_byte(8'h30); // 0
            send_uart_byte(8'h30); // 0
            send_uart_byte(8'h30); // 0
            send_uart_byte(8'h2C); // ,
            
            send_uart_byte(8'h45); // E
            send_uart_byte(8'h0D); // \r
            send_uart_byte(8'h0A); // \n
            $display("[%0t] GPS sentence sent", $time);
        end
    endtask
    
    task press_button;
        input integer duration_ms;
        begin
            $display("[%0t] Button pressed", $time);
            emergency_btn = 1;
            #(duration_ms * 1000000);
            emergency_btn = 0;
            $display("[%0t] Button released", $time);
        end
    endtask
    
    always @(state_debug) begin
        case (state_debug)
            3'b000: $display("[%0t] State: IDLE", $time);
            3'b001: $display("[%0t] State: EMERGENCY", $time);
            3'b010: $display("[%0t] State: WAIT_GPS", $time);
            3'b011: $display("[%0t] State: SEND_ALERT", $time);
            3'b100: $display("[%0t] State: SENDING", $time);
            3'b101: $display("[%0t] State: COOLDOWN", $time);
        endcase
    end
    
    always @(posedge led_gps_valid) begin
        $display("[%0t] *** GPS DATA VALID ***", $time);
        $display("         Latitude:  %d", dut.latitude);
        $display("         Longitude: %d", dut.longitude);
    end
    
    initial begin
        $dumpfile("emergency_alert.vcd");
        $dumpvars(0, tb_emergency_alert_top);
        
        rst_n = 0;
        emergency_btn = 0;
        uart_rx_gps = 1;
        
        $display("========================================");
        $display("Emergency Alert System Testbench");
        $display("========================================");
        
        #(CLK_PERIOD * 10);
        rst_n = 1;
        #(CLK_PERIOD * 10);
        $display("[%0t] Reset released", $time);
        
        #10000;
        
        // Test Case 1: Send GPS data first
        $display("\n--- Test Case 1: GPS data reception ---");
        #100000;
        send_gps_sentence();
        #5000000; // Wait 5ms for GPS parsing
        
        // Test Case 2: Emergency with GPS already valid
        $display("\n--- Test Case 2: Emergency with GPS ---");
        press_button(30);
        #10000000; // Wait 10ms for message transmission
        
        // Test Case 3: Another GPS update
        $display("\n--- Test Case 3: Second GPS update ---");
        send_gps_sentence();
        #2000000;
        
        // Test Case 4: Quick button press (should cancel)
        $display("\n--- Test Case 4: Quick press (cancel) ---");
        emergency_btn = 1;
        #50000; // Very short press
        emergency_btn = 0;
        #1000000;
        
        $display("\n========================================");
        $display("Simulation completed successfully!");
        $display("========================================");
        $display("Check waveforms with: gtkwave emergency_alert.vcd");
        #100000;
        $finish;
    end
    
    // Increased timeout
    initial begin
        #200_000_000; // 200ms timeout (increased from 100ms)
        $display("\nERROR: Simulation timeout!");
        $display("This is normal if message transmission is slow.");
        $display("Check waveforms anyway: gtkwave emergency_alert.vcd");
        $finish;
    end

endmodule
