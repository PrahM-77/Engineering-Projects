module tx_testbench;
    // Input vals
    logic clk;
    logic rst;
    logic [7:0] cpu_data;
    logic cpu_write_en;

    // Output vals
    logic tx_line;
    logic busy;
    logic fifo_full;
    logic fifo_empty;
    logic shift_enable;
    logic serial_out;
    logic idle_check;

    TOP_UART_TX dut (
        .clk(clk),
        .rst(rst),
        .cpu_data(cpu_data),
        .cpu_write_en(cpu_write_en),
        .shift_enable(shift_enable)

        .tx_line(tx_line),
        .busy(busy),
        .fifo_full(fifo_full),
        .fifo_empty(fifo_empty),
        .serial_out(serial_out),
        .idle_check(idle_check)
    )

    always #5 clk = ~clk;

    initial begin
        clk = 0;
        rst = 1;
        cpu_data = 8'h00;
        shift_enable = 0;

        repeat(5)@(posedge clk);
        rst = 0;
    end

    @(negedge clk);
    cpu_data = 8'hA5;
    shift_enable = 1;

    @(negedge clk);
    tx_start = 0; 
    // Currently, shift has immediately started

    task automatic check_if_same(
            input logic expected_val,
            input logic [2:0] bit_no
        );
        repeat(8) @(posedge clk);

        #1;

        if(serial_out !== expected_val) begin
            $error("Bit Mismatch (%0d)", bit_no);
        end

        repeat(8) @(posedge clk);
        #1;

    endtask

    // Test byte is 8'hA5, which is 10100101
    check_if_same(1'b1, 0);
    check_if_same(1'b0, 1);
    check_if_same(1'b1, 2);
    check_if_same(1'b0, 3);
    check_if_same(1'b0, 4);
    check_if_same(1'b1, 5);
    check_if_same(1'b0, 6);
    check_if_same(1'b1, 7);


    // So far, checked if all the bytes are the same, now to 
    task automatic check_var( // Could get away with not using another task, but more for learning purposes
        input logic rx_done,
        input logic tx_busy,
        input logic idle_check
    );
        if(serial_out !== 1) begin // Need to find way to get stop_bit, currently, serial_out will likely stop before
            $error("Stop bit is incorrect");
        end

        if(rx_done !== 1) begin
            $error("rx_done is not asserted");
        end

        if(tx_busy !== 0) begin
            $error("tx_busy is not de-asserted");
        end

        if(idle_check !== 1) begin
            $error("Curr_state is not in IDLE");
        end

    endtask
 
    // Things to do:
        // Fix serial_out == 1, so as to check if stop bit is 1
        // Fix tx doc to ensure that rx_done is on there
        // Finish rest of the TB


endmodule