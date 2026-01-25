`timescale 1ns/1ps
module systolic_tb;

  localparam int N       = 10;
  localparam int SCORE_W = 8;

  localparam logic [1:0] A = 2'd0;
  localparam logic [1:0] C = 2'd1;
  localparam logic [1:0] G = 2'd2;
  localparam logic [1:0] T = 2'd3;

  logic clk, rst_n;
  logic compute_en, clear_en;

  // preload-all
  logic read_load_en;
  logic [1:0] read_base_in [N];

  // ref stream
  logic ref_valid_in;
  logic [1:0] ref_in;

  // DUT outputs
  logic signed [SCORE_W-1:0] pe_score [N];
  logic [1:0]                pe_dir   [N];
  logic                      pe_valid [N];


  // sequences
  logic [1:0] read_seq [N];
  logic [1:0] ref_seq  [N];

  // clock
  initial clk = 1'b0;
  always #5 clk = ~clk;

  // DUT
  systolic #(
    .N(N),
    .SCORE_W(SCORE_W)
  ) dut (
    .clk(clk),
    .rst_n(rst_n),

    .compute_en(compute_en),
    .clear_en(clear_en),

    .read_load_en(read_load_en),
    .read_base_in(read_base_in),

    .ref_valid_in(ref_valid_in),
    .ref_in(ref_in),

    .pe_score(pe_score),
    .pe_dir(pe_dir),
    .pe_valid(pe_valid)
  );

  logic [SCORE_W-1:0] scoring_matrix_0 [$];
  logic [SCORE_W-1:0] scoring_matrix_1 [$];
  logic [SCORE_W-1:0] scoring_matrix_2 [$];
  logic [SCORE_W-1:0] scoring_matrix_3 [$];
  logic [SCORE_W-1:0] scoring_matrix_4 [$];
  logic [SCORE_W-1:0] scoring_matrix_5 [$];
  logic [SCORE_W-1:0] scoring_matrix_6 [$];
  logic [SCORE_W-1:0] scoring_matrix_7 [$];
  logic [SCORE_W-1:0] scoring_matrix_8 [$];
  logic [SCORE_W-1:0] scoring_matrix_9 [$];

  logic [1:0] direction_matrix_0 [$];
  logic [1:0] direction_matrix_1 [$];
  logic [1:0] direction_matrix_2 [$];
  logic [1:0] direction_matrix_3 [$];
  logic [1:0] direction_matrix_4 [$];
  logic [1:0] direction_matrix_5 [$];
  logic [1:0] direction_matrix_6 [$];
  logic [1:0] direction_matrix_7 [$];
  logic [1:0] direction_matrix_8 [$];
  logic [1:0] direction_matrix_9 [$];

  task update_queue;
    forever begin
      @(posedge clk);
      if(pe_valid[0]) begin
        scoring_matrix_0.push_back(pe_score[0]);
        direction_matrix_0.push_back(pe_dir[0]);
      end 
      if(pe_valid[1]) begin
        scoring_matrix_1.push_back(pe_score[1]);
        direction_matrix_1.push_back(pe_dir[1]);
      end
      if(pe_valid[2]) begin
        scoring_matrix_2.push_back(pe_score[2]);
        direction_matrix_2.push_back(pe_dir[2]);
      end
      if(pe_valid[3]) begin
        scoring_matrix_3.push_back(pe_score[3]);
        direction_matrix_3.push_back(pe_dir[3]);
      end
      if(pe_valid[4]) begin
        scoring_matrix_4.push_back(pe_score[4]);
        direction_matrix_4.push_back(pe_dir[4]);
      end
      if(pe_valid[5]) begin
        scoring_matrix_5.push_back(pe_score[5]);
        direction_matrix_5.push_back(pe_dir[5]);
      end
      if(pe_valid[6]) begin
        scoring_matrix_6.push_back(pe_score[6]);
        direction_matrix_6.push_back(pe_dir[6]);
      end
      if(pe_valid[7]) begin
        scoring_matrix_7.push_back(pe_score[7]);
        direction_matrix_7.push_back(pe_dir[7]);
      end
      if(pe_valid[8]) begin
        scoring_matrix_8.push_back(pe_score[8]);
        direction_matrix_8.push_back(pe_dir[8]);
      end
      if(pe_valid[9]) begin
        scoring_matrix_9.push_back(pe_score[9]);
        direction_matrix_9.push_back(pe_dir[9]);
      end
    end
  endtask

  task print_queues;
    $display("=== Scoring Matrix ===");
    $display("%p", scoring_matrix_0);
    $display("%p", scoring_matrix_1);
    $display("%p", scoring_matrix_2);
    $display("%p", scoring_matrix_3);
    $display("%p", scoring_matrix_4);
    $display("%p", scoring_matrix_5);
    $display("%p", scoring_matrix_6);
    $display("%p", scoring_matrix_7);
    $display("%p", scoring_matrix_8);
    $display("%p", scoring_matrix_9);
    $display("=== Direction Matrix ===");
    $display("%p", direction_matrix_0);
    $display("%p", direction_matrix_1);
    $display("%p", direction_matrix_2);
    $display("%p", direction_matrix_3);
    $display("%p", direction_matrix_4);
    $display("%p", direction_matrix_5);
    $display("%p", direction_matrix_6);
    $display("%p", direction_matrix_7);
    $display("%p", direction_matrix_8);
    $display("%p", direction_matrix_9);
  endtask




  initial begin

    fork
      update_queue();
    join_none

    // read="GAGCT", ref="AGCGT"
    // read_seq[0]=G; read_seq[1]=A; read_seq[2]=G; read_seq[3]=C; read_seq[4]=T;
    // ref_seq [0]=A; ref_seq [1]=G; ref_seq [2]=C; ref_seq [3]=G; ref_seq [4]=T;

    read_seq[0]=G; read_seq[1]=A; read_seq[2]=G; read_seq[3]=C; read_seq[4]=T;
    read_seq[5]=T; read_seq[6]=C; read_seq[7]=G; read_seq[8]=C; read_seq[9]=A;

    ref_seq [0]=A; ref_seq [1]=G; ref_seq [2]=C; ref_seq [3]=G; ref_seq [4]=T;
    ref_seq [5]=T; ref_seq [6]=T; ref_seq [7]=C; ref_seq [8]=G; ref_seq [9]=C;


    // init
    rst_n = 1'b0;
    compute_en = 1'b0;
    clear_en   = 1'b0;

    read_load_en = 1'b0;
    for (int i = 0; i < N; i++) 
      read_base_in[i] = '0;

    ref_valid_in = 1'b0;
    ref_in       = '0;

    repeat (2) @(posedge clk);
    rst_n = 1'b1;
    @(posedge clk);

    // preload ALL PEs in 1 cycle
    $display("== Preload ALL read regs ==");
    @(negedge clk);
    for (int i = 0; i < N; i++) begin
      read_base_in[i] = read_seq[i];
    end
    read_load_en = 1'b1;
    @(posedge clk);
    @(negedge clk);
    read_load_en = 1'b0;

    // clear DP state (keeps read_reg)
    $display("== Clear DP state ==");
    @(negedge clk);
    clear_en = 1'b1;
    @(posedge clk);
    @(negedge clk);
    clear_en = 1'b0;

    
    // run compute: 
    $display("== Run compute ==");
    compute_en = 1'b1;

    for (int cyc = 0; cyc < (2*N -1); cyc++) begin
      @(negedge clk);
      if (cyc < N) begin
        ref_valid_in = 1'b1;
        ref_in       = ref_seq[cyc];
      end else begin
        ref_valid_in = 1'b0;
        ref_in       = '0;
      end

      @(posedge clk);

      $write("\n cyc%0d: \n", cyc+1);
      for (int i = 0; i < N; i++) begin
        if (pe_valid[i])
          $write("value %0d from PE %0d / ", pe_score[i], i);
      end
      $write("\n");
      print_queues();
    end

    @(negedge clk);
    compute_en   = 1'b0;
    ref_valid_in = 1'b0;
    ref_in       = '0;

    $finish;
  end

endmodule
