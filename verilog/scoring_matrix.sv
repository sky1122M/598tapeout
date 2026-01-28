`timescale 1ns/1ps

module scoring_matrix #(
  parameter int N = 10
) (
  input  logic                   clk,
  input  logic                   rst_n,

  // One column per cycle: N rows, each 2-bit
  input  logic [N-1:0][1:0]       data_in,

  // One-hot column select; all-zero means "no input this cycle"
  // Bit 0 corresponds to column 0 (e.g., 5'b00001 -> column 0)
  input  logic [N-1:0]            data_valid,

  // Stays high after all N columns have been stored, until the next new round starts
  output logic                    done,

  // Whole matrix: matrix_out[row][col] is 2-bit
  output logic [N-1:0][N-1:0][1:0] matrix_out
);

  logic [N-1:0] written_mask;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      done         <= 1'b0;
      written_mask <= '0;

      // Clear matrix to zero
      for (int r = 0; r < N; r++) begin
        for (int c = 0; c < N; c++) begin
          matrix_out[r][c] <= 2'b00;
        end
      end

    end else begin
      // If done is high, it remains high until a new write occurs (start of next round).
      // Starting a new round clears done and resets the written_mask *in the same cycle*
      // that processes the first write of the new round.
      if (done && (data_valid != '0)) begin
        done         <= 1'b0;
        written_mask <= '0;
      end

      // Apply writes for any asserted column bits
      if (data_valid != '0) begin
        for (int c = 0; c < N; c++) begin
          if (data_valid[c]) begin
            for (int r = 0; r < N; r++) begin
              matrix_out[r][c] <= data_in[r];
            end
          end
        end

        // Update written_mask (if done was just cleared above, treat it as new round)
        if (done && (data_valid != '0)) begin
          written_mask <= data_valid;
        end else begin
          written_mask <= written_mask | data_valid;
        end
      end

      // Assert done when all columns have been written in the current round
      // (i.e., written_mask becomes all-ones after considering this cycle's write)
      begin
        logic [N-1:0] next_mask;
        if (done && (data_valid != '0)) begin
          next_mask = data_valid;
        end else begin
          next_mask = written_mask | data_valid;
        end

        if (next_mask == {N{1'b1}}) begin
          done <= 1'b1;
        end
      end
    end
  end

endmodule
