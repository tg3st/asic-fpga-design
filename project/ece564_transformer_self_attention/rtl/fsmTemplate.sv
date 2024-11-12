/*
  *
    * Made By: Thiago Gesteira
    * Last Edited: Oct. 30, 2024
  * 
*/

`include "common.vh"

module MyDesign(
  input wire reset_n,
  input wire clk,
  input wire dut_valid,
  output reg dut_ready,  

  // Input SRAM interface
  output reg dut__tb__sram_input_write_enable,
  output wire [`SRAM_ADDR_RANGE] dut__tb__sram_input_write_address,
  output wire [`SRAM_DATA_RANGE] dut__tb__sram_input_write_data,
  output reg [`SRAM_ADDR_RANGE] dut__tb__sram_input_read_address,  
  input wire [`SRAM_DATA_RANGE] tb__dut__sram_input_read_data,

  // Weight SRAM interface
  output reg dut__tb__sram_weight_write_enable,
  output wire [`SRAM_ADDR_RANGE] dut__tb__sram_weight_write_address,
  output wire [`SRAM_DATA_RANGE] dut__tb__sram_weight_write_data,
  output reg [`SRAM_ADDR_RANGE] dut__tb__sram_weight_read_address,  
  input wire [`SRAM_DATA_RANGE] tb__dut__sram_weight_read_data,

  // Result SRAM interface
  output reg dut__tb__sram_result_write_enable,  
  output reg [`SRAM_ADDR_RANGE] dut__tb__sram_result_write_address,
  output reg [`SRAM_DATA_RANGE] dut__tb__sram_result_write_data,    
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

  state_t current_state, next_state;  

  // Registers
  reg [`SRAM_ADDR_RANGE] a_count;  
  reg [`SRAM_ADDR_RANGE] b_count;
  reg [`SRAM_ADDR_RANGE] c_count;
  reg [15:0] a_columns;
  reg [15:0] a_rows;
  reg [15:0] b_columns;
  reg [15:0] a_row_count;
  reg [`SRAM_ADDR_RANGE] a_end;  
  reg [`SRAM_ADDR_RANGE] b_end;
  reg [`SRAM_ADDR_RANGE] c_end;
  reg [`SRAM_ADDR_RANGE] cPrime_end;


  // MAC interface signals
  wire [2:0] inst_rnd;
  reg [63:0] accum_c;
  reg [63:0] z_out;

  // Sequential logic for state transitions
  always_ff @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
      current_state <= IDLE;
      dut_ready <= 1'b1;
      dut__tb__sram_input_write_enable <= '0;
      dut__tb__sram_weight_write_enable <= '0;
    end else begin
      current_state <= next_state;

      case (current_state)
        IDLE: begin
          if (dut_valid) begin
            dut_ready <= 1'b0;
            dut__tb__sram_result_write_enable <= 1'b0;

            mac1_r <= '0;
            mac2_r <= '0;
            a_columns <= tb__dut__sram_input_read_data[15:0];
            a_rows <= tb__dut__sram_input_read_data[31:16];
            b_columns <= tb__dut__sram_weight_read_data[15:0];
            a_row_count <= 16'd1;
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

        COMPUTE_Q: begin
          // Q_r = I x Wq + Q_r
          // if (Q done) compute and write s
          //  Write (I x Wk + Kt_r)
          if (a_count == a_end) begin
            dut__tb__sram_result_write_enable <= 1'b1;
            if (c_count == cPrime_end) begin
              a_row_count <= a_row_count + 1'b1;
              a_count <= a_count + 1;
    	    end
    	    else begin
            a_count <= 1 + a_columns * (a_row_count - 1);
    	    end
          end else begin
            a_count <= a_count + 1'b1;
          end
          if (b_count == b_end) begin
            b_count <= 16'd1;
          end
          else begin
            b_count <= b_count + 1'b1;
          end
          mac1_r <= mac1;
        end


        WRITE_Q: begin
          a_count <= a_count + 1'b1;
          b_count <= b_count + 1'b1;
          accum_c <= '0;
          dut__tb__sram_result_write_enable <= 1'b0;
          c_count <= c_count + 1'b1;
          if (c_count == c_end) begin
              dut_ready <= 1'b1;
              a_count <= 0;
              b_count <= 0;
          end
          a_end <= a_columns * a_row_count;
          cPrime_end <= a_row_count * b_columns - 1;
        end

        COMPUTE_K: begin
          // Kt_r = I x Wk + Kt_r
          // Iterate through k elements in transpose order
          
          // if (K done) compute and write s
          //  Write (I x Wk + Kt_r)
          //  s = q x (I x Wk + Kt_r)
        end

        WRITE_K: begin
        end

        FINISH_S: begin
          // Compute and write rest of s
          // Starting at row after a_columns
        end

        COMPUTE_V: begin
          // V_r = I x Wv + V_r (compute v wire)
          // 
          // if (V done) compute and write z
          //  Write (I x Wv + V_r)
          //  z = s x (I x Wv + V_r)
        end

        FINISH_Z: begin
          // Compute and write rest of z
          // Starting at row after a_rows
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
        next_state = COMPUTE_Q;
      end

      COMPUTE_Q: begin
      end

      COMPUTE_K: begin
      end

      COMPUTE_V: begin
      end
    endcase
  end

// Assign read addresses with appropriate registers (counters)
  always_comb begin
    dut__tb__sram_input_read_address = a_count;
    dut__tb__sram_weight_read_address = b_count;

    dut__tb__sram_result_read_address = result_read_addr_r;
    dut__tb__sram_result_write_address = c_count;
    dut__tb__sram_result_write_data = mac1;
  end

  assign mac1 = dut__tb__sram_input_read_data *
    dut__tb__sram_weight_read_data + mac1_r;
  assign mac2 = tb__dut__sram_result_read_data *
    mac1 + mac2_r


endmodule
