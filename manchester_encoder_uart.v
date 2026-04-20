// Code your design here
//============================================================
// Manchester Encoded UART TX/RX System (Fully Working)
//============================================================
`timescale 1ns/1ps

//============================================================
// Manchester Encoder (8-bit → 16-bit)
//============================================================
module manchester_encoder (
    input  logic [7:0] data_in,
    output logic [15:0] encoded
);
    always_comb begin
        for (int i = 0; i < 8; i++) begin
            encoded[2*i +: 2] = data_in[i] ? 2'b10 : 2'b01;
        end
    end
endmodule

//============================================================
// Manchester Decoder (16-bit → 8-bit)
//============================================================
module manchester_decoder (
    input  logic [15:0] encoded,
    output logic [7:0] decoded
);
    always_comb begin
        for (int i = 0; i < 8; i++) begin
            case (encoded[2*i +: 2])
                2'b10: decoded[i] = 1;
                2'b01: decoded[i] = 0;
                default: decoded[i] = 1'bx;
            endcase
        end
    end
endmodule

//============================================================
// Baud Rate Generator (shared by TX and RX)
//============================================================
module baud_gen #(
    parameter CLK_FREQ = 50_000_000,
    parameter BAUD_RATE = 500_000
)(
    input  logic clk,
    input  logic rst,
    output logic tick
);
    localparam integer CLK_PER_BIT = CLK_FREQ / BAUD_RATE;
    integer counter;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            counter <= 0;
            tick <= 0;
        end else begin
            if (counter == CLK_PER_BIT - 1) begin
                counter <= 0;
                tick <= 1;
            end else begin
                counter <= counter + 1;
                tick <= 0;
            end
        end
    end
endmodule

//============================================================
// UART Transmitter for 16-bit data
//============================================================
module uart_tx_16bit (
    input  logic clk,
    input  logic rst,
    input  logic tick,
    input  logic [15:0] data_in,
    input  logic start,
    output logic tx_line,
    output logic done
);
    typedef enum logic [1:0] {IDLE, START, DATA, STOP} state_t;
    state_t state;
    logic [4:0] bit_idx;
    logic [15:0] shift_reg;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE;
            bit_idx <= 0;
            shift_reg <= 0;
            tx_line <= 1;
            done <= 0;
        end else begin
            done <= 0;
            case (state)
                IDLE: begin
                    tx_line <= 1;
                    if (start) begin
                        shift_reg <= data_in;
                        bit_idx <= 0;
                        state <= START;
                    end
                end
                START: if (tick) begin
                    tx_line <= 0;
                    state <= DATA;
                end
                DATA: if (tick) begin
                    tx_line <= shift_reg[bit_idx];
                    if (bit_idx == 15) state <= STOP;
                    else bit_idx <= bit_idx + 1;
                end
                STOP: if (tick) begin
                    tx_line <= 1;
                    done <= 1;
                    state <= IDLE;
                end
            endcase
        end
    end
endmodule

//============================================================
// UART Receiver for 16-bit data (shared baud tick)
//============================================================
module uart_rx_16bit (
    input  logic clk,
    input  logic rst,
    input  logic tick,
    input  logic rx_line,
    output logic [15:0] data_out,
    output logic done
);
    typedef enum logic [1:0] {IDLE, START, DATA, STOP} state_t;
    state_t state;
    logic [4:0] bit_idx;
    logic [15:0] shift_reg;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE;
            bit_idx <= 0;
            shift_reg <= 0;
            data_out <= 0;
            done <= 0;
        end else begin
            done <= 0;
            case (state)
                IDLE: if (!rx_line) state <= START;
                START: if (tick) state <= DATA;
                DATA: if (tick) begin
                    shift_reg[bit_idx] <= rx_line;
                    if (bit_idx == 15) state <= STOP;
                    else bit_idx <= bit_idx + 1;
                end
                STOP: if (tick) begin
                    data_out <= shift_reg;
                    done <= 1;
                    state <= IDLE;
                end
            endcase
        end
    end
endmodule
