module UART_FIFO #(
    parameter WIDTH = 8,
    parameter DEPTH = 16
    )(
    input logic         clk,
    input logic         rst,
    input logic         writer_enable,
    input logic         read_enable,
    input logic [7:0]   cpu_data,
    
    output logic [7:0]  data_sent,
    output logic        full,
    output logic        empty
    );

    logic [WIDTH - 1:0] mem [0:DEPTH-1];

    logic [$clog2(DEPTH) - 1:0] write_ptr;
    logic [$clog2(DEPTH) - 1:0] read_ptr;

    logic [$clog2(DEPTH) - 1:0] next_write_ptr;
    logic [$clog2(DEPTH) - 1:0] next_read_ptr;

    assign next_write_ptr = (write_ptr == DEPTH - 1) ? 0 : write_ptr + 1;
    assign next_read_ptr = (read_ptr == DEPTH - 1) ? 0 : read_ptr + 1;

    assign full = (next_write_ptr == read_ptr);
    assign empty = (write_ptr == read_ptr);

    always_ff @ (posedge clk or posedge rst) begin
        if (rst) begin
            write_ptr <= 0;
            data_sent <= 8'b0;
        end else if (writer_enable && !full) begin
            mem[write_ptr] <= cpu_data;
            write_ptr <= next_write_ptr;
        end
    end

    always_ff @ (posedge clk or posedge rst) begin
        if (rst) begin
            read_ptr <= 0;
        end else if (read_enable && !empty) begin
            data_sent <= mem[read_ptr];
            read_ptr <= next_read_ptr;
        end
    end

endmodule

module BAUD_GENERATOR #(
    parameter DIVISOR = 5280
    )(
    input logic         clk,
    input logic         rst,

    output logic        tick
    );

    logic [$clog2(DIVISOR)-1: 0] counter;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            tick <= 0;
            counter <= 0;
        end else if(counter == (DIVISOR-1)) begin
            tick <= 1;
            counter <= 0;
        end else begin
            counter <= counter + 1;
            tick <= 0;
        end
    end 

endmodule

module SHIFT_REGISTER (
    input logic         clk,
    input logic         rst,
    input logic         load,
    input logic         shift,
    input logic [7:0]   data_in,

    output logic [7:0]  shift_reg,
    output logic        serial_out
    );

    assign serial_out = shift_reg[0];

    always_ff @ (posedge clk or posedge rst) begin
        if (rst) begin
            shift_reg <= 8'b0;
        end else if (load) begin
                shift_reg <= data_in;
        end else if (shift) begin
            shift_reg <= {1'b0, shift_reg[7:1]};
        end
    end 

endmodule

module BIT_COUNTER (
    input logic     clk,
    input logic     rst,
    input logic     tick,
    input logic     shift_enable,
    input logic     load,

    output logic    bit_done
    );

    logic [2:0] counter;

    assign bit_done = (counter == 3'd7);

    always_ff @ (posedge clk or posedge rst) begin
        if (rst) begin
           counter <= 3'd0; 
        end else if (load) begin
            counter <= 3'd0;
        end else if (tick && shift_enable && counter != 3'd7) begin
            counter <= counter + 1;
        end
    end

endmodule

module FSM_UART_TX (
    input logic     clk,
    input logic     rst,
    input logic     tick,
    input logic     bit_done,
    input logic     serial_out,
    input logic     empty,

    output logic    fsm_reader_en,
    output logic    tx_line,
    output logic    load_shift_reg,
    output logic    shift_enable,
    output logic    busy,
    output logic    idle_check
    );

    typedef enum logic [1:0] {IDLE, READ, START, DATA, STOP}state_machine;

    state_machine curr_state, next_state;

    always_ff @ (posedge clk or posedge rst) begin
        if (rst) begin
            curr_state <= IDLE;
        end else begin
            curr_state <= next_state;
        end
    end

    always_comb begin
        next_state = curr_state;

        case (curr_state)
            IDLE: if (!empty) next_state = READ;

            READ: next_state = START;

            START: if (tick) next_state = DATA;

            DATA: if(tick && bit_done) next_state = STOP;

            STOP: if (tick) next_state = IDLE;

            default: next_state = IDLE;
        endcase
    end

    always_comb begin
        tx_line = 1'b1;
        load_shift_reg = 1'b0;
        shift_enable = 1'b0;
        busy = 1'b0;
        fifo_reader_en = 1'b0;
        idle_check = 1;

        case (curr_state)
            IDLE: begin
                tx_line = 1;
                busy = 0;
                idle_check = 1;
            end

            READ: begin
                fifo_reader_en = 1;
                busy = 1;
                idle_check = 0;
            end

            START: begin
                tx_line = 0;
                load_shift_reg = 1;
                busy = 1;
                idle_check = 0;
            end

            DATA: begin
                tx_line = serial_out;
                shift_enable = 1;
                busy = 1;
                idle_check = 0;
            end

            STOP: begin
                tx_line  = 1;
                busy = 1;
                idle_check = 0;
            end
        endcase
    end 
endmodule

module TOP_UART_TX (
    input logic clk,
    input logic rst,
    input logic [7:0] cpu_data,
    input logic       cpu_write_en,
    input logic       shift_enable,

    output logic tx_line,
    output logic busy,
    output logic fifo_full,
    output logic fifo_empty,
    output logic serial_out,
    output logic idle_check
    );

    logic [7:0] data_in;
    logic tick;
    logic load_shift_reg;
    logic serial_out;
    logic bit_done;

    wire fifo_writer_en;
    wire fifo_reader_en;

    UART_FIFO #( // Finish
        .WIDTH(8),
        .DEPTH(16)
        ) uart_fifo (
        .clk (clk),
        .rst (rst),
        .writer_enable(fifo_writer_en),
        .read_enable(fifo_reader_en),
        .cpu_data(cpu_data),
        
        .data_sent(data_in),
        .full(fifo_full),
        .empty(fifo_empty),
        .idle_check(idle_check)
    );

    BAUD_GENERATOR #(
        .DIVISOR(5280)
        ) baud_gen (
        .clk (clk),
        .rst (rst),

        .tick (tick)
    );

    SHIFT_REGISTER shift_reg (
        .clk (clk),
        .rst (rst),
        .load (load_shift_reg),
        .shift (shift_enable & tick),
        .data_in (data_in),

        .serial_out (serial_out)
    );

    BIT_COUNTER bit_count (
        .clk (clk),
        .rst (rst),
        .tick (tick),
        .shift_enable (shift_enable),
        .load (load_shift_reg),

        .bit_done (bit_done)
    );

    FSM_UART_TX fsm (
        .clk (clk),
        .rst (rst),
        .tick (tick),
        .bit_done (bit_done),
        .serial_out (serial_out),
        .empty (fifo_empty),

        .tx_line (tx_line),
        .load_shift_reg (load_shift_reg),
        .shift_enable (shift_enable),
        .busy (busy),
        .fsm_reader_en (fifo_reader_en)
    );

endmodule
