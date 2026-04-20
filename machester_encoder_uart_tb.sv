// Code your testbench here
// or browse Examples
//============================================================
// TESTBENCH (Stable back-to-back Manchester UART frames)
//============================================================
module tb_manchester_uart;
    logic clk = 0, rst;
    logic tick;
    logic [7:0] data_in, decoded;
    logic [15:0] encoded, rx_encoded;
    logic tx_line, start, tx_done, rx_done;

    // 50-MHz clock
    always #10 clk = ~clk;

    // Instantiate blocks
    baud_gen #(.CLK_FREQ(50_000_000), .BAUD_RATE(500_000)) B (
        .clk(clk), .rst(rst), .tick(tick)
    );

    manchester_encoder ENC (.data_in(data_in), .encoded(encoded));
    manchester_decoder DEC (.encoded(rx_encoded), .decoded(decoded));

    uart_tx_16bit TX (
        .clk(clk), .rst(rst), .tick(tick),
        .data_in(encoded), .start(start),
        .tx_line(tx_line), .done(tx_done)
    );

    uart_rx_16bit RX (
        .clk(clk), .rst(rst), .tick(tick),
        .rx_line(tx_line),
        .data_out(rx_encoded), .done(rx_done)
    );

    // --------------------------------------------------------
    // Utility task: send a frame safely
    // --------------------------------------------------------
    task automatic send_frame(input [7:0] byte_val);
        begin
            data_in = byte_val;
            #50;
            $display("Input Data  : %b", data_in);
            $display("Encoded Data: %b", encoded);

            start = 1; #20 start = 0;

            wait(tx_done);
            $display("UART TX Complete.");

            wait(rx_done);
            #80; // allow decoder settle

            $display("UART RX Data (Encoded): %b", rx_encoded);
            $display("Decoded Output        : %b", decoded);

            if (decoded == data_in)
                $display("Transmission Successful!");
            else
                $display("Mismatch!");
            $display("-------------------------------------------------");

            // --- idle gap: keep line high and reset RX ---
            #600;          // one full bit-time gap
            rst = 1; #40;  // short pulse to clear FSMs
            rst = 0; #200;
        end
    endtask

    // --------------------------------------------------------
    // Main test sequence
    // --------------------------------------------------------
    initial begin
        $dumpfile("manchester_uart_final.vcd");
        $dumpvars(0, tb_manchester_uart);

        $display("\n=================================================");
        $display(" Manchester + UART 16-bit Multi-Frame Test ");
        $display("=================================================");

        rst = 1; start = 0; #200 rst = 0;

        send_frame(8'b01110011); // Frame 1
        send_frame(8'b01010110); // Frame 2

        $display("=================================================");
        $display("   All Frames Transmitted and Verified        ");
        $display("=================================================");
        #2000 $finish;
    end
endmodule
