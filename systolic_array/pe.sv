module pe #(
  parameter int SCORE_W = 8    // signed score width
)(
  input  logic                         clk,
  input  logic                         rst_n,

  // Control
  input  logic                         compute_en,    // advance 1 cycle of computing
  input  logic                         clear_en,      // reset state for new window
  input  logic                         in_valid,      // whether ref is valid this cycle

  // Preloaded read 
  input  logic                          read_load_en,
  input  logic       [1:0]              read_base_in,

  // Streaming reference 
  input  logic       [1:0]              ref_base_in,

  // inputs from previous PE (i-1 row)
  input  logic signed [SCORE_W-1:0]     in1_up,       // H(i-1, j)
  input  logic signed [SCORE_W-1:0]     in2_diag,     // H(i-1, j-1)

  // Outputs to next PE (i+1 row)
  output logic signed [SCORE_W-1:0]     out1,         // H(i, j)
  output logic signed [SCORE_W-1:0]     out2,         // H(i, j-1) (old left)

  // Optional outputs for traceback / debug
  output logic                          out_valid,
  output logic        [1:0]             dir,          // 0=ZERO 1=DIAG 2=UP 3=LEFT
  output logic signed [SCORE_W-1:0]     pe_score      
);
  // register declarations
  logic        [1:0]         read_r;
  logic        [SCORE_W-1:0] out1_r, out2_r;

  // candidates
  logic signed [SCORE_W-1:0] cand_diag, cand_up, cand_left;
  logic signed [SCORE_W-1:0] best_raw;
  logic signed [SCORE_W-1:0] best;
  logic        [1:0]         best_dir;


   // hardcode penalty and reward into a LUT
  logic signed [SCORE_W-1:0]     match_score;
  logic signed [SCORE_W-1:0]     gap_penalty;   

  always_comb begin
    match_score    = 8'sd9;    // 9 for match
    gap_penalty    = 8'sd5;    // -5 for gap
  end

  // evaluate the best candidate, max(0, diag, up, left)
  always_comb begin
    if (compute_en) begin
      cand_diag = (ref_base_in == read_r) ? in2_diag + match_score : in2_diag - match_score;
      cand_up   = in1_up   - gap_penalty;
      cand_left = out1_r  - gap_penalty;

      best_raw = cand_diag;
      if (cand_up   > best_raw) best_raw = cand_up;
      if (cand_left > best_raw) best_raw = cand_left;

      if (!in_valid || (best_raw <= 0)) begin
        best     = '0;
        best_dir = 2'd0; // ZERO
      end else begin
        best = best_raw;
        if (cand_diag == best_raw)      
          best_dir = 2'd1; // DIAG
        else if (cand_up == best_raw)   
          best_dir = 2'd2; // UP
        else                            
          best_dir = 2'd3; // LEFT
      end
    end else begin
      best     = '0;
      best_dir = 2'd0;
    end
  end

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      read_r       <= '0;
      out1_r       <= '0;
      out2_r       <= '0;
    end else begin
      read_r       <= read_base_in;
      out1_r       <= '0;
      out2_r       <= '0;
      if (read_load_en) begin
        read_r     <= read_base_in;
      end
      if (clear_en) begin
        out1_r      <= '0;
        out2_r      <= '0;
      end else if (compute_en) begin
        out2_r      <= out1_r;
        out1_r      <= best;
      end
    end
  end

  assign out1      = out1_r;
  assign out2      = out2_r;
  assign out_valid = in_valid;
  assign dir       = best_dir;
  assign pe_score  = best;

endmodule
 




       
