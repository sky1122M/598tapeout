`timescale 1ns/1ps

module tb_pe_array;


  localparam int N       = 5;  // #PEs == read length
  localparam int SCORE_W = 8;

  // Encoding: A=0, C=1, G=2, T=3
  localparam logic [1:0] A = 2'd0;
  localparam logic [1:0] C = 2'd1;
  localparam logic [1:0] G = 2'd2;
  localparam logic [1:0] T = 2'd3;

  // Read / Ref sequences (paper red box window)
  logic [1:0] read_seq [N];
  logic [1:0] ref_seq  [N];

  // Clock/reset/control
  logic clk;
  logic rst_n;
  logic compute_en;
  logic clear_en;

  // Ref injection
  logic [1:0] ref_in;
  logic       ref_valid_in;

  // Ref shift inside TB (mimic real systolic array)
  logic [1:0] ref_pipe  [N];
  logic       ref_valid [N];

  // PE IO
  logic       read_load_en ;
  logic [1:0] read_base_in [N];

  logic signed [SCORE_W-1:0] in1_up   [N];
  logic signed [SCORE_W-1:0] in2_diag [N];
  logic signed [SCORE_W-1:0] out1     [N];
  logic signed [SCORE_W-1:0] out2     [N];
  logic                      out_valid[N];
  logic [1:0]                dir      [N];
  logic signed [SCORE_W-1:0] pe_score [N];




  int tcount;
  int cyc;

  // ----------------------------
  // DUT: instantiate N PEs as an array
  // ----------------------------
  genvar gi;
  generate
    for (gi = 0; gi < N; gi++) begin : GEN_PES

      // DP chain connections:
      // in1_up(i)   = out1(i-1)
      // in2_diag(i) = out2(i-1)
      if (gi == 0) begin
        always_comb begin
          in1_up[gi]   = '0;
          in2_diag[gi] = '0;
        end
      end else begin
        always_comb begin
          in1_up[gi]   = out1[gi-1];
          in2_diag[gi] = out2[gi-1];
        end
      end

      // Your PE module
      pe #(.SCORE_W(SCORE_W)) u_pe (
        .clk          (clk),
        .rst_n        (rst_n),

        .compute_en   (compute_en),
        .clear_en     (clear_en),
        .in_valid     (ref_valid[gi]),

        .read_load_en (read_load_en),
        .read_base_in (read_base_in[gi]),

        .ref_base_in  (ref_pipe[gi]),

        .in1_up       (in1_up[gi]),
        .in2_diag     (in2_diag[gi]),

        .out1         (out1[gi]),
        .out2         (out2[gi]),
        .out_valid    (out_valid[gi]),

        .dir          (dir[gi]),
        .pe_score     (pe_score[gi])
      );
    end
  endgenerate

  // Clock
  initial clk = 1'b0;
  always #5 clk = ~clk; 

  // ----------------------------
  // Ref shift pipeline (mimic array behavior)
  // Shifts on compute_en. Clears on clear_en.
  // ----------------------------
  always_ff @(posedge clk) begin
    if (!rst_n) begin
      for (int k = 0; k < N; k++) begin
        ref_pipe[k]  <= '0;
        ref_valid[k] <= 1'b0;
      end
    end else if (clear_en) begin
      for (int k = 0; k < N; k++) begin
        ref_pipe[k]  <= '0;
        ref_valid[k] <= 1'b0;
      end
    end else if (compute_en) begin
      // shift right
      for (int k = N-1; k >= 1; k--) begin
        ref_pipe[k]  <= ref_pipe[k-1];
        ref_valid[k] <= ref_valid[k-1];
      end
      // inject at PE0
      ref_pipe[0]  <= ref_in;
      ref_valid[0] <= ref_valid_in;
    end
  end

  logic [SCORE_W-1:0] scoring_matrix_0 [$];
  logic [SCORE_W-1:0] scoring_matrix_1 [$];
  logic [SCORE_W-1:0] scoring_matrix_2 [$];
  logic [SCORE_W-1:0] scoring_matrix_3 [$];
  logic [SCORE_W-1:0] scoring_matrix_4 [$];

  logic [1:0] direction_matrix_0 [$];
  logic [1:0] direction_matrix_1 [$];
  logic [1:0] direction_matrix_2 [$];
  logic [1:0] direction_matrix_3 [$];
  logic [1:0] direction_matrix_4 [$];

  task update_matrix;
    forever begin
      @(posedge clk);
      if(out_valid[0]) begin
        scoring_matrix_0.push_back(pe_score[0]);
        direction_matrix_0.push_back(dir[0]);
      end 
      if(out_valid[1]) begin
        scoring_matrix_1.push_back(pe_score[1]);
        direction_matrix_1.push_back(dir[1]);
      end
      if(out_valid[2]) begin
        scoring_matrix_2.push_back(pe_score[2]);
        direction_matrix_2.push_back(dir[2]);
      end
      if(out_valid[3]) begin
        scoring_matrix_3.push_back(pe_score[3]);
        direction_matrix_3.push_back(dir[3]);
      end
      if(out_valid[4]) begin
        scoring_matrix_4.push_back(pe_score[4]);
        direction_matrix_4.push_back(dir[4]);
      end
    end
  endtask

  task print_matrix;
    $display("=== Scoring Matrix ===");
    $display("%p", scoring_matrix_0);
    $display("%p", scoring_matrix_1);
    $display("%p", scoring_matrix_2);
    $display("%p", scoring_matrix_3);
    $display("%p", scoring_matrix_4);
    $display("=== Direction Matrix ===");
    $display("%p", direction_matrix_0);
    $display("%p", direction_matrix_1);
    $display("%p", direction_matrix_2);
    $display("%p", direction_matrix_3);
    $display("%p", direction_matrix_4);
  endtask

  task print_cycle;
      $display("\nCycle %0d:", cyc + 1);
      $write("  read:     ");
      for (int p = 0; p < N; p++) 
        $write("%2d ", read_base_in[p]);
      $write("\n  ref_pipe: ");
      for (int p = 0; p < N; p++) 
        $write("%2d ", ref_pipe[p]);
      $write("  \n ref_valid: ");
      for (int p = 0; p < N; p++) 
        $write("%2d ", ref_valid[p]);
      // $write("\n  out1:     ");
      // for (int p = 0; p < N; p++) 
      //   $write("%2d ", out1[p]);
      // $write("\n  out2:     ");
      // for (int p = 0; p < N; p++) 
      //   $write("%2d ", out2[p]);
      $write("\n  pe_out:   ");
      for (int p = 0; p < N; p++) 
        $write("%2d ", pe_score[p]);
      $write("\n  dir:      ");
      for (int p = 0; p < N; p++) 
        $write("%2d ", dir[p]);
      $write("\n");
      $write("  valid:    ");
      for (int p = 0; p < N; p++) 
        $write("%2d ", out_valid[p]);
      $write("\n");
      print_matrix();  
  endtask

  // Main stimulus

  initial begin
    fork
      update_matrix();
    join_none
    // sequences: read="GAGCT", ref="AGCGT"
    read_seq[0] = G;
    read_seq[1] = A;
    read_seq[2] = G;
    read_seq[3] = C;
    read_seq[4] = T;

    ref_seq[0]  = A;
    ref_seq[1]  = G;
    ref_seq[2]  = C;
    ref_seq[3]  = G;
    ref_seq[4]  = T;

    // init signals
    rst_n        = 1'b0;
    compute_en   = 1'b0;
    clear_en     = 1'b0;
    ref_in       = '0;
    ref_valid_in = 1'b0;

    for (int i = 0; i < N; i++) begin
      read_load_en    = 1'b0;
      read_base_in[i] = '0;
    end

    repeat (2) @(posedge clk);
    rst_n = 1'b1;
    @(posedge clk);

    // Preload read into each PE
    $display("== Preload read into PEs ==");
      read_load_en    = 1'b1;
      for (int i = 0; i < N; i++) begin
        read_base_in[i] = read_seq[i];
      end
      $write("  read:     ");
      for (int p = 0; p < N; p++) $write("%0d ", read_base_in[p]);
      $write("\n");

    @(posedge clk);
    read_load_en = 1'b0;

    // Clear state for new window (keep read_reg)
    $display("== Clear state ==");
    clear_en = 1'b1;
    @(posedge clk);
    clear_en = 1'b0;
    @(posedge clk);

    $display("== Run systolic compute ==");
    compute_en = 1'b1;

    for (cyc = 0; cyc < (2*N - 1); cyc++) begin
      if (cyc < N) begin
        ref_valid_in = 1'b1;
        ref_in       = ref_seq[cyc];
      end else begin
        ref_valid_in = 1'b0;
        ref_in       = '0;
      end

      @(posedge clk);
      print_cycle();
    end

    compute_en      = 1'b0;
    ref_valid_in = 1'b0;
    ref_in       = '0;
    $display("== Finish simulation ==");
    $finish;
  end



endmodule

