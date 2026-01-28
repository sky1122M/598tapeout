`timescale 1ns/1ps

module scoring_matrix_tb;

  localparam int N = 10;

  logic                        clk;
  logic                        rst_n;
  logic [N-1:0][1:0]            data_in;
  logic [N-1:0]                 data_valid;
  logic                        done;
  logic [N-1:0][N-1:0][1:0]     matrix_out;

  // DUT
  scoring_matrix #(
    .N(N)
  ) dut (
    .clk        (clk),
    .rst_n      (rst_n),
    .data_in    (data_in),
    .data_valid (data_valid),
    .done       (done),
    .matrix_out (matrix_out)
  );

  // Clock: 100 MHz (10 ns period)
  initial clk = 1'b0;
  initial begin
    forever #5 clk = ~clk;
  end

  // Reference model
  logic [N-1:0][N-1:0][1:0]     exp_matrix;
  logic [N-1:0]                 exp_written_mask;
  logic                         exp_done;

  // Column data temps (module scope for Verilator)
  logic [N-1:0][1:0]            col0;
  logic [N-1:0][1:0]            col_new0;
  logic [N-1:0][1:0]            coldata;

  // ----------------------------
  // Utilities / printing helpers
  // ----------------------------
  function automatic logic [N-1:0] onehot_col(input int col);
    logic [N-1:0] v;
    v = '0;
    if (col >= 0 && col < N) v[col] = 1'b1;
    return v;
  endfunction

  function automatic logic [N-1:0][1:0] make_col_data(input int seed);
    logic [N-1:0][1:0] v;
    for (int r = 0; r < N; r++) begin
      v[r] = 2'((seed + r) & 32'h3);   // values 0..3 only
    end
    return v;
  endfunction

  function automatic int onehot_index(input logic [N-1:0] oh);
    int idx;
    idx = -1;
    for (int i = 0; i < N; i++) begin
      if (oh[i]) idx = i;
    end
    return idx;
  endfunction

  task automatic print_cycle(string tag);
    int col;
    col = onehot_index(data_valid);

    $display("t=%0t | %-34s | rst_n=%0b | done=%0b | data_valid=0x%0h%s",
             $time, tag, rst_n, done, data_valid,
             (data_valid == '0) ? " (idle)" :
             (col >= 0) ? $sformatf(" (col=%0d)", col) : " (non-onehot)");

    // Print data_in each cycle as N entries [row0..rowN-1]
    $write("          data_in: ");
    for (int r = 0; r < N; r++) begin
      $write("%0d ", data_in[r]);
    end
    $write("\n");
  endtask

  task automatic print_matrix(string tag);
    $display("          ---- MATRIX (%s) ----", tag);
    for (int r = 0; r < N; r++) begin
      $write("          row %0d: ", r);
      for (int c = 0; c < N; c++) begin
        $write("%0d ", matrix_out[r][c]);
      end
      $write("\n");
    end
    $display("          ----------------------");
  endtask

  // ----------------------------
  // Reference model + checking
  // ----------------------------
  task automatic model_apply_cycle(
    input logic [N-1:0][1:0]  din,
    input logic [N-1:0]       dval
  );
    logic [N-1:0] next_mask;

    if (exp_done && (dval != '0)) begin
      exp_done         = 1'b0;
      exp_written_mask = '0;
    end

    if (dval != '0) begin
      for (int c = 0; c < N; c++) begin
        if (dval[c]) begin
          for (int r = 0; r < N; r++) begin
            exp_matrix[r][c] = din[r];
          end
        end
      end

      if (exp_done && (dval != '0)) begin
        exp_written_mask = dval;
      end else begin
        exp_written_mask = exp_written_mask | dval;
      end
    end

    if (exp_done && (dval != '0)) begin
      next_mask = dval;
    end else begin
      next_mask = exp_written_mask | dval;
    end

    if (next_mask == {N{1'b1}}) begin
      exp_done = 1'b1;
    end
  endtask

  task automatic check_outputs(string tag);
    if (done !== exp_done) begin
      $display("FAIL (%s): done mismatch. DUT=%0b EXP=%0b @ t=%0t", tag, done, exp_done, $time);
      $fatal(1);
    end

    for (int r = 0; r < N; r++) begin
      for (int c = 0; c < N; c++) begin
        if (matrix_out[r][c] !== exp_matrix[r][c]) begin
          $display("FAIL (%s): matrix_out[%0d][%0d] mismatch. DUT=%0h EXP=%0h @ t=%0t",
                   tag, r, c, matrix_out[r][c], exp_matrix[r][c], $time);
          $fatal(1);
        end
      end
    end
  endtask

  // Drives one cycle and prints done/data_valid/data_in EVERY cycle.
  // Prints the full matrix only when it is updated (data_valid != 0).
  task automatic drive_cycle(
    input logic [N-1:0][1:0]  din,
    input logic [N-1:0]       dval,
    input string              tag
  );
    data_in    = din;
    data_valid = dval;

    @(posedge clk);
    #1;

    // After clock edge: print current-cycle signals
    print_cycle(tag);

    // Update model + check
    model_apply_cycle(din, dval);
    check_outputs(tag);

    // Print the matrix every time it is updated (i.e., any write this cycle)
    if (dval != '0) begin
      print_matrix(tag);
    end
  endtask

  // ----------------------------
  // Test sequence
  // ----------------------------
  initial begin
    data_in    = '0;
    data_valid = '0;

    rst_n = 1'b0;
    exp_done         = 1'b0;
    exp_written_mask = '0;
    for (int r = 0; r < N; r++) begin
      for (int c = 0; c < N; c++) begin
        exp_matrix[r][c] = 2'b00;
      end
    end

    // Hold reset for a couple cycles
    repeat (2) @(posedge clk);
    #1;
    print_cycle("reset_cycle");
    rst_n = 1'b1;

    // After reset deassert, check that outputs are cleared (no write)
    @(posedge clk); #1;
    print_cycle("post_reset_idle");
    check_outputs("post_reset_idle");

    // 1) Idle cycles
    drive_cycle('0, '0, "idle_0");
    drive_cycle('0, '0, "idle_1");

    // 2) Write a single column (bit0 -> column 0)
    col0 = make_col_data(0);
    drive_cycle(col0, onehot_col(0), "write_col0_onehot_bit0");

    // 3) Write remaining columns in order 1..N-1
    for (int c = 1; c < N; c++) begin
      coldata = make_col_data(10*c);
      if (c == N-1) begin
        drive_cycle(coldata, onehot_col(c), "write_last_col_expect_done_high");
        if (done !== 1'b1) begin
          $display("FAIL: done was not high after last column write @ t=%0t", $time);
          $fatal(1);
        end
      end else begin
        drive_cycle(coldata, onehot_col(c), $sformatf("write_col_%0d", c));
        if (done !== 1'b0) begin
          $display("FAIL: done asserted early at column %0d @ t=%0t", c, $time);
          $fatal(1);
        end
      end
    end

    // 4) done should stay high across idle cycles (no writes)
    drive_cycle('0, '0, "done_latch_idle_0");
    drive_cycle('0, '0, "done_latch_idle_1");
    if (done !== 1'b1) begin
      $display("FAIL: done did not remain high during idle after completion @ t=%0t", $time);
      $fatal(1);
    end

    // 5) Start next round
    col_new0 = make_col_data(123);
    drive_cycle(col_new0, onehot_col(0), "start_new_round_clears_done_and_writes_col0");
    if (done !== 1'b0) begin
      $display("FAIL: done not cleared on first write of new round @ t=%0t", $time);
      $fatal(1);
    end

    // 6) Complete second round
    for (int c = 1; c < N; c++) begin
      coldata = make_col_data(200 + c);
      drive_cycle(coldata, onehot_col(c), $sformatf("round2_write_col_%0d", c));
    end
    if (done !== 1'b1) begin
      $display("FAIL: done was not high after completing second round @ t=%0t", $time);
      $fatal(1);
    end

    $display("\nPASS: All checks passed.\n");
    $finish;
  end

endmodule
