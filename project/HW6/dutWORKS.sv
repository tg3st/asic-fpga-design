`include "common.vh"

module MyDesign(
  input wire reset_n,
  input wire clk,
  input wire dut_valid,
  output reg dut_ready,  // Changed from wire to reg since it's assigned in sequential logic

  // Input SRAM interface
  output reg dut__tb__sram_input_write_enable,
  output wire [`SRAM_ADDR_RANGE] dut__tb__sram_input_write_address,
  output wire [`SRAM_DATA_RANGE] dut__tb__sram_input_write_data,
  output reg [`SRAM_ADDR_RANGE] dut__tb__sram_input_read_address,  // Changed from wire to reg
  input wire [`SRAM_DATA_RANGE] tb__dut__sram_input_read_data,

  // Weight SRAM interface
  output reg dut__tb__sram_weight_write_enable,
  output wire [`SRAM_ADDR_RANGE] dut__tb__sram_weight_write_address,
  output wire [`SRAM_DATA_RANGE] dut__tb__sram_weight_write_data,
  output reg [`SRAM_ADDR_RANGE] dut__tb__sram_weight_read_address,  // Changed from wire to reg
  input wire [`SRAM_DATA_RANGE] tb__dut__sram_weight_read_data,

  // Result SRAM interface
  output reg dut__tb__sram_result_write_enable,  // Changed from wire to reg
  output reg [`SRAM_ADDR_RANGE] dut__tb__sram_result_write_address,  // Changed from wire to reg
  output reg [`SRAM_DATA_RANGE] dut__tb__sram_result_write_data,    // Changed from wire to reg
  output wire [`SRAM_ADDR_RANGE] dut__tb__sram_result_read_address,
  input wire [`SRAM_DATA_RANGE] tb__dut__sram_result_read_data
);

  // State definition
  typedef enum logic [2:0] {
    IDLE = 3'd0,
    PARSE_MATRIX_DIMENSIONS = 3'd1,
    S0 = 3'd2,
    S1 = 3'd3,
    POST_WRITE = 3'd4
  } state_t;

  state_t current_state, next_state;  // Fixed naming convention

  // Registers
  reg [`SRAM_ADDR_RANGE] a_count;  // Fixed naming convention
  reg [`SRAM_ADDR_RANGE] b_count;
  reg [`SRAM_ADDR_RANGE] c_count;
  reg [15:0] a_columns;
  reg [15:0] a_rows;
  reg [15:0] b_columns;
  reg [15:0] a_row_count;
  reg [`SRAM_ADDR_RANGE] a_end;  // Fixed naming convention
  reg [`SRAM_ADDR_RANGE] b_end;
  reg [`SRAM_ADDR_RANGE] c_end;
  reg [`SRAM_ADDR_RANGE] cPrime_end;


  // MAC interface signals
  wire [2:0] inst_rnd;
  reg [63:0] mac_result_z;
  reg [63:0] z_out;

  // Sequential logic for state transitions
  always_ff @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
      current_state <= IDLE;
      dut_ready <= 1'b1;
      a_columns <= '0;
      a_rows <= '0;
      b_columns <= '0;
      a_count <= '0;
      b_count <= '0;
      c_count <= '0;
      a_row_count <= '0;
      dut__tb__sram_result_write_enable <= 1'b0;
      mac_result_z <= '0;
      dut__tb__sram_input_write_enable <= '0;
      dut__tb__sram_weight_write_enable <= '0;
    end else begin
      current_state <= next_state;

      case (current_state)
        IDLE: begin
          if (dut_valid) begin
            dut_ready <= 1'b0;
            a_row_count <= 16'd1;
            dut__tb__sram_result_write_enable <= 1'b0;
            mac_result_z <= '0;
            dut__tb__sram_input_write_enable <= '0;
            dut__tb__sram_weight_write_enable <= '0;
            a_columns <= tb__dut__sram_input_read_data[15:0];
            a_rows <= tb__dut__sram_input_read_data[31:16];
            b_columns <= tb__dut__sram_weight_read_data[15:0];
          end
        end

        PARSE_MATRIX_DIMENSIONS: begin
          a_count <= 16'd1;
          b_count <= 16'd1;
          c_count <= 16'd0;
          a_end <= a_columns * a_row_count;
          c_end <= a_rows * b_columns - 1;
          b_end <= a_columns*b_columns;
          cPrime_end <= a_row_count * b_columns - 1;
        end

        POST_WRITE: begin
            a_end <= a_columns * a_row_count;
            cPrime_end <= a_row_count * b_columns - 1;
            a_count <= a_count + 1'b1;
            b_count <= b_count + 1'b1;
        end

        S0: begin
          if (a_count == a_end) begin
            dut__tb__sram_result_write_enable <= 1'b1;
          end else begin
            a_count <= a_count + 1'b1;
            b_count <= b_count + 1'b1;
          end
          mac_result_z <= dut__tb__sram_result_write_data;
        end

        S1: begin
          if (b_count == b_end) begin
            b_count <= 16'd1;
          end
          else begin
            b_count <= b_count + 1'b1;
          end
          mac_result_z <= '0;
          dut__tb__sram_result_write_enable <= 1'b0;
          c_count <= c_count + 1'b1;
          if (c_count == cPrime_end) begin
            if (a_rows == a_row_count) begin
              dut_ready <= 1'b1;
              a_count <= 0;
              b_count <= 0;
            end else begin
              a_row_count <= a_row_count + 1'b1;
              a_count <= a_count + 1;
            end
          end else begin
            a_count <= 1 + a_columns * (a_row_count - 1);
          end
        end
      endcase
    end
  end

  // Combinational logic for next state
  always_comb begin
    next_state = current_state;  // Default assignment

    case (current_state)
      IDLE: begin
        if (dut_valid) begin
          next_state = PARSE_MATRIX_DIMENSIONS;
        end
      end

      PARSE_MATRIX_DIMENSIONS: begin
        next_state = S0;
      end

      POST_WRITE: begin
        next_state = S0;
      end

      S0: begin
        if (a_count == a_end) begin
          next_state = S1;
        end
      end

      S1: begin
        if (c_count == c_end)
          next_state = IDLE;
        else
          next_state = POST_WRITE;
      end
    endcase
  end

// Assign read addresses
  always_comb begin
    dut__tb__sram_input_read_address = a_count;
    dut__tb__sram_weight_read_address = b_count;
    dut__tb__sram_result_write_address = c_count;
    dut__tb__sram_result_write_data = z_out;
  end


  // Instantiate MAC module
  DW_fp_mac_inst FP_MAC (
    .inst_a(tb__dut__sram_input_read_data),    // Fixed: Use read data instead of address
    .inst_b(tb__dut__sram_weight_read_data),   // Fixed: Use read data instead of address
    .inst_c(mac_result_z),
    .inst_rnd(inst_rnd),
    .z_inst(z_out),
    .status_inst()
  );

endmodule

// MAC module definition remains the same
module DW_fp_mac_inst #(
  parameter inst_sig_width = 23,
  parameter inst_exp_width = 8,
  parameter inst_ieee_compliance = 0
) (
  input wire [inst_sig_width+inst_exp_width : 0] inst_a,
  input wire [inst_sig_width+inst_exp_width : 0] inst_b,
  input wire [inst_sig_width+inst_exp_width : 0] inst_c,
  input wire [2 : 0] inst_rnd,
  output wire [inst_sig_width+inst_exp_width : 0] z_inst,
  output wire [7 : 0] status_inst
);

  DW_fp_mac #(inst_sig_width, inst_exp_width, inst_ieee_compliance) U1 (
    .a(inst_a),
    .b(inst_b),
    .c(inst_c),
    .rnd('0),
    .z(z_inst),
    .status(status_inst)
  );

endmodule
