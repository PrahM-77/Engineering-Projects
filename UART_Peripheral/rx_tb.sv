  module rx_testbench;
      // Input vals
      logic clk;
      logic rst;
      logic async_in;

      // Output vals
      logic rx_sync;
      logic rx_valid_start;
      logic [7:0] rx_data;
      logic rx_done;
      logic tick;
      logic idle_check;

      // TestBench exclusive values
      logic [3:0] bit_counter;
      logic bit_checker;
      logic [3:0] sample_counter;
      logic read_checker;
      logic data_checker;

      localparam CLK_FREQ_HZ = 100_000_000;
      localparam BAUD_RATE = 115200;
      localparam OVERSAMPLING_RATE = 16;

      localparam CLKS_PER_BIT = (CLK_FREQ_HZ/BAUD_RATE);
      localparam CLKS_PER_SAMPLE = CLKS_PER_BIT/OVERSAMPLING_RATE;

      logic rx_checker;

      logic rx_done_seen;

      UART_RX #(
          .CLK_FREQ_HZ(CLK_FREQ_HZ),
          .BAUD_RATE(BAUD_RATE),
          .OVERSAMPLING_RATE(OVERSAMPLING_RATE),
          .N_BITS(8)
          ) rx_dut (
          .clk(clk),
          .rst(rst),
          .async_in(async_in),

          .rx_sync(rx_sync),
          .rx_valid_start(rx_valid_start),
          .rx_data(rx_data),
          .rx_done(rx_done),
          .tick(tick),
          .idle_check(idle_check),
          
          .bit_counter(bit_counter),
          .bit_checker(bit_checker),
          .sample_counter(sample_counter),
          .read_checker(read_checker),
          .data_checker(data_checker)
      );

      always #5 clk = ~clk;

    always_ff @ (posedge clk) begin
      if (rst) begin
        rx_done_seen <= 0;
      end
      else if(rx_done) begin
        rx_done_seen <= 1;
      end
    end

      task automatic check_val(
              input logic expected_val,
              input logic [2:0] bit_no
          );

          #1;

          if(rx_data[bit_no] !== expected_val) begin
              $error("Bit Mismatch (%0d)", bit_no);
              // Allows for easier debugging, as we can see which bits is causing the issue
          end else begin
              $display("Bit %0d is a go", bit_no);
          end
      endtask


      
      initial begin
          // default values
          clk = 0;
          rst = 1;
          async_in = 1;

          rx_checker = 0;

          @(posedge clk);
          rst = 0;

          // Start bit
        @(posedge clk);
          async_in = 0;

          repeat (CLKS_PER_BIT) @(negedge clk);

          // Byte is 10100101
          async_in = 1;

          repeat (CLKS_PER_BIT) @(negedge clk);
          async_in = 0;

          repeat (CLKS_PER_BIT) @(negedge clk);
          async_in = 1;

          repeat (CLKS_PER_BIT) @(negedge clk);
          async_in = 0;

          repeat (CLKS_PER_BIT) @(negedge clk);
          async_in = 0;

          repeat (CLKS_PER_BIT) @(negedge clk);
          async_in = 1;

          repeat (CLKS_PER_BIT) @(negedge clk);
          async_in = 0;

          repeat (CLKS_PER_BIT) @(negedge clk);
          async_in = 1;

        // Stop bit
          repeat (CLKS_PER_BIT) @(negedge clk);
          async_in = 1;
        
          repeat (CLKS_PER_BIT) @(posedge clk);

          fork
              begin
                wait(rx_done_seen === 1);
              end
              begin
                repeat(CLKS_PER_BIT * 20) @(posedge clk);
                rx_checker = 1;
                $error("rx_done never asserts");
                $finish;
              end
          join_any

          $display("rx_done asserts");

          if(rx_data !== 8'b10100101) begin
              rx_checker = 1;
              check_val(1,0);
              check_val(0,1);
              check_val(1,2);
              check_val(0,3);
              check_val(0,4);
              check_val(1,5);
              check_val(0,6);
              check_val(1,7);
          end else if (rx_data == 8'b10100101) begin
            $display("Bit value correct");
          end

          if(idle_check !== 1) begin
              rx_checker = 1;
              $error("FSM Not in IDLE");
          end else begin
            $display("FSM is in IDLE");
          end

          // Final check
          if(rx_checker == 0) begin
            $display("Test passed successfully at %0t.", $time);
            $finish;
          end else begin
            $error("Error");
            $finish;
          end

      end

  endmodule
