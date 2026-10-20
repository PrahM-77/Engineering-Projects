 module UART_RX #(
    parameter CLK_FREQ_HZ = 100000000,
    parameter BAUD_RATE = 115200,
    parameter CLKS_PER_BIT = 16,
    parameter N_BITS = 8
    )(
    input logic         clk,
    input logic         rst,
    input logic         async_in,

    output logic        rx_sync,
    output logic        rx_valid_start,
    output logic  [7:0] rx_data,
    output logic        rx_done,
    output logic        tick
    );

    // Flip-Flop Synchronizer
        logic rx_sync_mid;

        always_ff @ (posedge clk) begin
            rx_sync_mid <= async_in;            
            rx_sync <= rx_sync_mid;
        end
    
    // Detecting falling edge
        logic rx_prev;
        logic falling_edge;

        always_ff @ (posedge clk) begin
            rx_prev <= rx_sync;
        end

        assign falling_edge = rx_prev & ~rx_sync;

    // Timers (Clock / Sampling)
        localparam int OVERSAMPLING_RATE = 16;
        localparam int DIV = (CLK_FREQ_HZ + (BAUD_RATE * OVERSAMPLING_RATE)/2) / (BAUD_RATE * OVERSAMPLING_RATE);
        localparam int W = $clog2(DIV) + 1;

        logic [W-1:0] clk_counter;

        always_ff @ (posedge clk or posedge rst) begin
            if (rst) begin
                clk_counter <= '0;
                tick <= 1'b0;
            end else begin
                if (clk_counter == DIV-1) begin
                    clk_counter <= '0;
                    tick <= 1'b1;
                end else begin
                    clk_counter <= clk_counter + 1'b1;
                    tick <= 1'b0;
                end
            end
        end 

        logic [3:0] sample_counter;

        logic [3:0] bit_counter;
        
        typedef enum logic [1:0] {IDLE, READ, DATA, STOP} state_machine;

        state_machine curr_state, next_state;

        always_ff @ (posedge clk or posedge rst) begin
            if (rst) begin
                curr_state <= IDLE;
            end else begin
                curr_state <= next_state;
            end
        end

        always_ff @ (posedge clk or posedge rst) begin
            if (rst) begin
                bit_counter <= 4'd0;
                rx_data <= '0;
                sample_counter <= '0;
            end else if (curr_state == READ) begin
                if(sample_counter == 8 && rx_valid_start == 0) begin
                    sample_counter <= '0;
                end
            end
            else if (curr_state == DATA) begin
                if (rx_done) begin
                    bit_counter <= '0;
                end
                else if (tick) begin
                    if(sample_counter == 15) begin
                        rx_data[bit_counter] <= rx_sync;
                        bit_counter <= bit_counter + 1'b1;
                        sample_counter <= '0;
                    end else begin
                        sample_counter <= sample_counter + 1;
                    end
                end
            end 
            else if (falling_edge || rx_valid_start) begin
                sample_counter <= 3'd0;
            end else if (curr_state != IDLE && tick) begin
                sample_counter <= sample_counter + 1;
            end 
        end

    always_ff @ (posedge clk or posedge rst) begin
        fifo_write_enable <= 0;
        if (rst) begin
            fifo_write_enable <= 0;
        end else if (curr_state == IDLE) begin
            fifo_write_enable <= 0;
        end else if (curr_state == STOP) begin
            if (valid_stop_bit && !full) begin
                    fifo_write_enable <= 1;
                end
        end 
    end


    always_comb begin
        next_state = curr_state;

        case(curr_state)
            IDLE: if(falling_edge) next_state = READ;

            READ: if (sample_counter == 8)
                    if (rx_valid_start == 1) 
                        next_state = DATA;
                    else if (rx_valid_start == 0)
                        next_state = IDLE;

            DATA: if(rx_done) next_state = STOP;
            
            STOP: if(valid_stop_bit == 1) next_state = IDLE;
                  else if (framing_error == 1) next_state = IDLE;

            default: next_state = IDLE;
        endcase
    end


    // Framing:
        logic framing_error;
        logic fifo_write_enable;
        logic fifo_read_enable;

    logic valid_stop_bit;
    logic move;

    always_comb begin
        rx_valid_start = 0;
        rx_done = 0;
        valid_stop_bit = 0;

        framing_error = 0;

        case(curr_state)
            IDLE: begin
                rx_done = 0;
            end

            READ: begin
                if (sample_counter == 8) begin
                    if (rx_sync == 0) begin
                        rx_valid_start = 1;
                    end else begin
                        rx_valid_start = 0;
                    end
                end
            end

            DATA: begin
                rx_valid_start = 0;
                if (bit_counter == N_BITS)
                    rx_done = 1;
            end

            STOP: begin
                if(tick && sample_counter == 15) begin
                    if (rx_sync == 1) begin
                        valid_stop_bit = 1;
                    end else if (rx_sync == 0) begin
                        valid_stop_bit = 0;
                        framing_error = 1;
                    end
                end 
            end

        endcase
    end


    // FIFO interface
        logic [7:0] convenient_array;
        logic full, empty;

        UART_FIFO #(
            .WIDTH(8),
            .DEPTH(16)

            ) uart_fifo (

            .clk (clk),
            .rst (rst),
            .writer_enable(fifo_write_enable),
            .read_enable(fifo_read_enable),
            .cpu_data(rx_data),
            
            .data_sent(convenient_array),
            .full(full),
            .empty(empty)
        );
endmodule

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
        end else if (writer_enable && !full) begin
            mem[write_ptr] <= cpu_data;
            write_ptr <= next_write_ptr;
        end
    end

    always_ff @ (posedge clk or posedge rst) begin
        if (rst) begin
            read_ptr <= 0;
            data_sent <= 8'b0;
        end else if (read_enable && !empty) begin
            data_sent <= mem[read_ptr];
            read_ptr <= next_read_ptr;
        end
    end
endmodule