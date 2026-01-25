module systolic #(
  parameter int N       = 5,
  parameter int SCORE_W = 8
)(
  input  logic                         clk,
  input  logic                         rst_n,

  // Control
  input  logic                         compute_en,
  input  logic                         clear_en,

  // Preload ALL PEs in 1 cycle
  input  logic                         read_load_en,
  input  logic       [1:0]             read_base_in [N],

  // Stream reference
  input  logic                         ref_valid_in,
  input  logic       [1:0]             ref_in,

  // outputs
  output logic signed [SCORE_W-1:0]     pe_score [N],
  output logic       [1:0]              pe_dir   [N],
  output logic                          pe_valid [N]
);


  logic [1:0] ref_pipe [N];
  logic       v_pipe   [N];

  logic [1:0]        ref_to_pe [N];
  logic              v_to_pe   [N];

  always_comb begin
    ref_to_pe[0] = ref_in;
    v_to_pe[0]   = ref_valid_in;
  end

  genvar gi;
  generate
    for (gi = 1; gi < N; gi++) begin 
      assign ref_to_pe[gi] = ref_pipe[gi];
      assign v_to_pe[gi]   = v_pipe[gi];
    end
  endgenerate

  always_ff @(posedge clk) begin
    ref_pipe[1] <= ref_in;
    v_pipe[1]   <= ref_valid_in;
    if (!rst_n) begin
      for (int k = 1; k < N; k++) begin
        ref_pipe[k] <= '0;
        v_pipe[k]   <= 1'b0;
      end
    end else if (clear_en) begin
      for (int k = 1; k < N; k++) begin
        ref_pipe[k] <= '0;
        v_pipe[k]   <= 1'b0;
      end
    end else if (compute_en) begin
      for (int k = N-1; k >= 2; k--) begin
        ref_pipe[k] <= ref_pipe[k-1];
        v_pipe[k]   <= v_pipe[k-1];
      end
    end
  end

  // some alignment for using generate function
  // in1_up(i)   = out1(i-1)
  // in2_diag(i) = out2(i-1)

  logic signed [SCORE_W-1:0] in1_up   [N];
  logic signed [SCORE_W-1:0] in2_diag [N];
  logic signed [SCORE_W-1:0] out1     [N];
  logic signed [SCORE_W-1:0] out2     [N];

  generate
    for (gi = 0; gi < N; gi++) begin 
      if (gi == 0) begin
        assign in1_up[gi]   = '0;
        assign in2_diag[gi] = '0;
      end else begin
        assign in1_up[gi]   = out1[gi-1];
        assign in2_diag[gi] = out2[gi-1];
      end
    end
  endgenerate

  // Instantiate PEs
  generate
    for (gi = 0; gi < N; gi++) begin 
      pe #(.SCORE_W(SCORE_W)) u_pe (
        .clk         (clk),
        .rst_n       (rst_n),

        .compute_en  (compute_en),
        .clear_en    (clear_en),
        .in_valid    (v_to_pe[gi]),

        .read_load_en(read_load_en),
        .read_base_in(read_base_in[gi]),

        .ref_base_in (ref_to_pe[gi]),

        .in1_up      (in1_up[gi]),
        .in2_diag    (in2_diag[gi]),

        .out1        (out1[gi]),
        .out2        (out2[gi]),

        .out_valid   (pe_valid[gi]),
        .dir         (pe_dir[gi]),
        .pe_score    (pe_score[gi])
      );
    end
  endgenerate

endmodule
