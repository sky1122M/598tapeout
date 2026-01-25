clc; clear;

%% ============================================================
%  Input / scoring parameters
%% ============================================================
% Subwindow reference (the red box window)
ref_str  = "AGCGTTTCGC";      % reference window length M
read_str = "GAGCTTCGCA";      % read length N == #PEs

match    = 9;
mismatch = -9;
gap      = -5;

%% ============================================================
%  Convert DNA chars -> numbers (A=0,C=1,G=2,T=3) inline
%% ============================================================
ref_c  = char(ref_str);
read_c = char(read_str);

M = length(ref_c);
N = length(read_c);

ref  = zeros(1,M);
read = zeros(1,N);

for k = 1:M
    if     ref_c(k)=='A', ref(k)=0;
    elseif ref_c(k)=='C', ref(k)=1;
    elseif ref_c(k)=='G', ref(k)=2;
    elseif ref_c(k)=='T', ref(k)=3;
    else, error("Invalid base in ref: %c", ref_c(k));
    end
end

for k = 1:N
    if     read_c(k)=='A', read(k)=0;
    elseif read_c(k)=='C', read(k)=1;
    elseif read_c(k)=='G', read(k)=2;
    elseif read_c(k)=='T', read(k)=3;
    else, error("Invalid base in read: %c", read_c(k));
    end
end

fprintf("Finish convert DNA into number\n");
fprintf("ref  = %s -> %s\n", ref_str,  mat2str(ref));
fprintf("read = %s -> %s\n\n", read_str, mat2str(read));

%% ============================================================
%  Systolic array setting (assume read is preloaded into every PE)
%% ============================================================
read_reg  = read(:);            % each PE holds preloaded value (Nx1)
h_left    = zeros(N,1);         % stores H(i, j-1) inside each PE

out1_reg  = zeros(N,1);         % registered output to next PE: H(i, j)
out2_reg  = zeros(N,1);         % registered output to next PE: H(i, j-1) (old left)

ref_pipe  = zeros(N,1);         % shifting reference bases through PEs
v_pipe    = false(N,1);         % valid bits

H   = zeros(N,M);
DIR = zeros(N,M);

maxScore = 0;
maxPos   = [0 0];

total_cycles = M + N - 1;

%% ============================================================
%  Print formatting (fixed width)
%% ============================================================
fprintf("Legend:\n");
fprintf("  base: A=0 C=1 G=2 T=3\n");
fprintf("  dir : 0=ZERO 1=DIAG 2=UP 3=LEFT\n\n");

row_fmt = "%2d | %1d | %2d | %2d | %5d | %5d | %4d | %6d | %6d | %6d | %4d | %1d\n";

%% ============================================================
%  Cycle-by-cycle simulation
%% ============================================================
for t = 1:total_cycles

    % Shift reference into PE chain (1 symbol per cycle)
    if t <= M
        inj = ref(t);
        ref_pipe = [inj; ref_pipe(1:end-1)];
        v_pipe   = [true; v_pipe(1:end-1)];
    else
        inj = -1; % no more input
        ref_pipe = [0; ref_pipe(1:end-1)];
        v_pipe   = [false; v_pipe(1:end-1)];
    end

    fprintf("\n==================== Cycle %2d ====================\n", t);

    % Print injected ref + ref_pipe in fixed-width style
    if inj >= 0
        fprintf("Injected ref = %d | ref_pipe =", inj);
    else
        fprintf("Injected ref = - | ref_pipe =");
    end
    fprintf(" %2d", ref_pipe);
    fprintf("\n");

    % Table header
    fprintf("PE | v | rd | rf |   in1 |   in2 | left |   diag |    up |  left |    H | d\n");
    fprintf("---+---+----+----+------+------+------+--------+-------+-------+------+--\n");

    new_out1  = zeros(N,1);
    new_out2  = zeros(N,1);
    new_hleft = h_left;          % bubbles keep old left by default
    new_dir   = zeros(N,1);

    for i = 1:N

        if ~v_pipe(i)
            % bubble row
            in1 = 0; in2 = 0; left = h_left(i);
            cand_diag = 0; cand_up = 0; cand_left = 0;
            best = 0; dir = 0;

            new_out1(i) = best;
            new_out2(i) = left;
            new_dir(i)  = dir;

            fprintf(row_fmt, i, v_pipe(i), read_reg(i), ref_pipe(i), ...
                    in1, in2, left, cand_diag, cand_up, cand_left, best, dir);
            continue;
        end

        % Inputs from previous PE (1-cycle delayed)
        if i == 1
            in1 = 0; in2 = 0;
        else
            in1 = out1_reg(i-1);   % "up"    = H(i-1, j)
            in2 = out2_reg(i-1);   % "diag"  = H(i-1, j-1)
        end

        left = h_left(i);         % "left"  = H(i, j-1) stored locally

        % substitution score
        if ref_pipe(i) == read_reg(i)
            sub = match;
        else
            sub = mismatch;
        end

        cand_diag = in2 + sub;
        cand_up   = in1 + gap;
        cand_left = left + gap;

        % Smith-Waterman: H = max(0, diag, up, left)
        best_raw = max([cand_diag, cand_up, cand_left]);

        if best_raw <= 0
            best = 0;
            dir  = 0;   % keep ZERO direction when output is 0
        else
            best = best_raw;
            % tie-break: DIAG > UP > LEFT
            if cand_diag == best_raw
                dir = 1;
            elseif cand_up == best_raw
                dir = 2;
            else
                dir = 3;
            end
        end

        % Outputs and state updates
        new_out1(i)  = best;      % H(i, j)
        new_out2(i)  = left;      % old H(i, j-1) for next PE's diag pipeline
        new_hleft(i) = best;      % update left for next column
        new_dir(i)   = dir;

        % Map to matrix coordinate (i, j)
        j = t - i + 1;
        if (j >= 1) && (j <= M)
            H(i,j)   = best;
            DIR(i,j) = dir;
        end

        % Track global max
        if best > maxScore
            maxScore = best;
            maxPos   = [i j];
        end

        fprintf(row_fmt, i, v_pipe(i), read_reg(i), ref_pipe(i), ...
                in1, in2, left, cand_diag, cand_up, cand_left, best, dir);
    end

    % Register for next cycle
    out1_reg = new_out1;
    out2_reg = new_out2;
    h_left   = new_hleft;

    fprintf("Current maxScore = %d at (i=%d, j=%d)\n", maxScore, maxPos(1), maxPos(2));

    % Optional: show H each cycle (comment out if too verbose)
    fprintf("=== H (N x M) after cycle %d ===\n", t);
    disp(H);
end

%% ============================================================
%  Final matrices
%% ============================================================
fprintf("\n=== Final H (N x M) ===\n");
disp(H);

fprintf("=== Final DIR (0=Z,1=D,2=U,3=L) ===\n");
disp(DIR);
