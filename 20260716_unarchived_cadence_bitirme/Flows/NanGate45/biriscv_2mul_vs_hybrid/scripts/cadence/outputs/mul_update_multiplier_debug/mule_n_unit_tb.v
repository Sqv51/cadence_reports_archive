`timescale 1ns/1ps

module mule_n_unit_tb;
    reg clk;
    reg rst;
    reg valid;
    reg [31:0] opcode;
    reg [31:0] ra;
    reg [31:0] rb;

    wire v2n;
    wire [31:0] y2n;
    wire v3n;
    wire [31:0] y3n;
    wire v5n;
    wire [31:0] y5n;

    biriscv_multiplier_efficient_2_n u2n (
        .clk_i(clk),
        .rst_i(rst),
        .opcode_valid_i(valid),
        .opcode_opcode_i(opcode),
        .opcode_pc_i(32'd0),
        .opcode_invalid_i(1'b0),
        .opcode_rd_idx_i(5'd1),
        .opcode_ra_idx_i(5'd2),
        .opcode_rb_idx_i(5'd3),
        .opcode_ra_operand_i(ra),
        .opcode_rb_operand_i(rb),
        .writeback_valid_o(v2n),
        .writeback_value_o(y2n),
        .writeback_rd_idx_o()
    );

    biriscv_multiplier_efficient_3_n u3n (
        .clk_i(clk),
        .rst_i(rst),
        .opcode_valid_i(valid),
        .opcode_opcode_i(opcode),
        .opcode_pc_i(32'd0),
        .opcode_invalid_i(1'b0),
        .opcode_rd_idx_i(5'd1),
        .opcode_ra_idx_i(5'd2),
        .opcode_rb_idx_i(5'd3),
        .opcode_ra_operand_i(ra),
        .opcode_rb_operand_i(rb),
        .writeback_valid_o(v3n),
        .writeback_value_o(y3n),
        .writeback_rd_idx_o()
    );

    biriscv_multiplier_efficient_5_n u5n (
        .clk_i(clk),
        .rst_i(rst),
        .opcode_valid_i(valid),
        .opcode_opcode_i(opcode),
        .opcode_pc_i(32'd0),
        .opcode_invalid_i(1'b0),
        .opcode_rd_idx_i(5'd1),
        .opcode_ra_idx_i(5'd2),
        .opcode_rb_idx_i(5'd3),
        .opcode_ra_operand_i(ra),
        .opcode_rb_operand_i(rb),
        .writeback_valid_o(v5n),
        .writeback_value_o(y5n),
        .writeback_rd_idx_o()
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    task run_case;
        input [127:0] name;
        input [31:0] op;
        input [31:0] a;
        input [31:0] b;
        input [31:0] expected;
        integer cyc;
        begin
            @(negedge clk);
            opcode = op;
            ra = a;
            rb = b;
            valid = 1'b1;
            @(negedge clk);
            valid = 1'b0;
            opcode = 32'h00000013;
            for (cyc = 0; cyc < 16; cyc = cyc + 1) begin
                @(posedge clk);
                if (v2n)
                    $display("%0t %0s MULE2N got=%08x expected=%08x", $time, name, y2n, expected);
                if (v3n)
                    $display("%0t %0s MULE3N got=%08x expected=%08x", $time, name, y3n, expected);
                if (v5n)
                    $display("%0t %0s MULE5N got=%08x expected=%08x", $time, name, y5n, expected);
            end
        end
    endtask

    initial begin
        rst = 1'b1;
        valid = 1'b0;
        opcode = 32'h00000013;
        ra = 32'd0;
        rb = 32'd0;
        repeat (4) @(negedge clk);
        rst = 1'b0;

        run_case("idx0", 32'h1a00000b, 32'h9e3779b9, 32'h7f4a7c17, 32'h0c6b8b9f);
        run_case("idx0", 32'h1c00000b, 32'h9e3779b9, 32'h7f4a7c17, 32'h0c6b8b9f);
        run_case("idx0", 32'h1e00000b, 32'h9e3779b9, 32'h7f4a7c17, 32'h0c6b8b9f);
        run_case("idx2", 32'h1a00000b, 32'h255992d4, 32'h7f4a7d11, 32'hd4ec4414);
        run_case("idx2", 32'h1c00000b, 32'h255992d4, 32'h7f4a7d11, 32'hd4ec4414);
        run_case("idx2", 32'h1e00000b, 32'h255992d4, 32'h7f4a7d11, 32'hd4ec4414);

        #20;
        $finish;
    end
endmodule
