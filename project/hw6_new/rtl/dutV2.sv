//---------------------------------------------------------------------------
// DUT - Mini project 
//---------------------------------------------------------------------------
`include "common.vh"

module MyDesign(
//---------------------------------------------------------------------------
//System signals
  input wire reset_n                      ,  
  input wire clk                          ,

//---------------------------------------------------------------------------
//Control signals
  input wire dut_valid                    , 
  output reg dut_ready                   , // Changed from wire to reg since it's assigned in sequential logic

//---------------------------------------------------------------------------
//input SRAM interface
  output wire                           dut__tb__sram_input_write_enable  ,
  output wire [`SRAM_ADDR_RANGE     ]   dut__tb__sram_input_write_address ,
  output wire [`SRAM_DATA_RANGE     ]   dut__tb__sram_input_write_data    ,
  output wire [`SRAM_ADDR_RANGE     ]   dut__tb__sram_input_read_address  , 
  input  wire [`SRAM_DATA_RANGE     ]   tb__dut__sram_input_read_data     ,     

//weight SRAM interface
  output wire                           dut__tb__sram_weight_write_enable  ,
  output wire [`SRAM_ADDR_RANGE     ]   dut__tb__sram_weight_write_address ,
  output wire [`SRAM_DATA_RANGE     ]   dut__tb__sram_weight_write_data    ,
  output wire [`SRAM_ADDR_RANGE     ]   dut__tb__sram_weight_read_address  , 
  input  wire [`SRAM_DATA_RANGE     ]   tb__dut__sram_weight_read_data     ,     

//result SRAM interface
  output wire                           dut__tb__sram_result_write_enable  ,
  output wire [`SRAM_ADDR_RANGE     ]   dut__tb__sram_result_write_address ,
  output wire [`SRAM_DATA_RANGE     ]   dut__tb__sram_result_write_data    ,
  output wire [`SRAM_ADDR_RANGE     ]   dut__tb__sram_result_read_address  , 
  input  wire [`SRAM_DATA_RANGE     ]   tb__dut__sram_result_read_data          
);

typedef enum logic [2:0] { // Changed bit to logic for better SystemVerilog compatibility
    IDLE  = 3'd0, 
    S0    = 3'd1,   
    S1    = 3'd2,   
    PARSE_MATRIX_DIMENSIONS = 3'd3   
} states;

states current_state, next_state; // Fixed variable names to match usage in code

// -------------------- Registers ---------------------------
reg [15:0] aCount;
reg [15:0] bCount;
reg [15:0] cCount;
reg [15:0] cWriteDataR;
reg        cWriteEnableR;

reg [15:0] aColumns;
reg [15:0] aRows;
reg [15:0] bColumns;
reg [15:0] aRowCount;

// Wire for MAC result
wire [`SRAM_DATA_RANGE] accum_result;
wire [`SRAM_DATA_RANGE] mac_result_z;
wire [2:0] inst_rnd;

// -------------------- Control path ------------------------
always @(posedge clk) begin
  if(!reset_n) begin
    current_state <= IDLE;
    dut_ready <= 1'b1;
    aColumns <= 16'd0;
    aRows <= 16'd0;
    bColumns <= 16'd0;
  end else begin
    current_state <= next_state;
  end
end

always @(*) begin // Changed to combinational logic for next state
  next_state = current_state; // Default assignment
  
  case (current_state)
    IDLE: begin
      if (dut_valid) begin
        next_state = PARSE_MATRIX_DIMENSIONS;
        dut_ready = 1'b0;
        aCount = 16'd1;
        bCount = 16'd1;
        cCount = 16'd1;
        aRowCount = 16'd1;
        cWriteDataR = 16'd0;
        cWriteEnableR = 1'b0;
      end
    end
    
    PARSE_MATRIX_DIMENSIONS: begin
      next_state = S0;
      aColumns = tb__dut__sram_input_read_data[15:0];
      aRows = tb__dut__sram_input_read_data[31:16];
      bColumns = tb__dut__sram_weight_read_data[15:0];
    end
    
    S0: begin
      if (aCount == (aColumns * aRowCount + 1)) begin 
        cWriteEnableR = 1'b1;
        cCount = cCount + 16'd1;
        next_state = S1;
      end
      else begin
        aCount = aCount + 16'd1;
        bCount = bCount + 16'd1;
        cWriteDataR = mac_result_z; // Fixed: Use MAC result instead of undefined accum_res
        next_state = S0;
      end
    end
    
    S1: begin
      cWriteEnableR = 1'b0;
      cWriteDataR = 16'd0;
      if (cCount == aRowCount * bColumns) begin
        bCount = 16'd1;
        if (cCount == aRows * bColumns) begin
          dut_ready = 1'b1;
          next_state = IDLE;
        end
        else begin
          aRowCount = aRowCount + 16'd1;
          next_state = S0;
        end
      end
      else begin
        aCount = 16'd1 + aColumns * (aRowCount - 16'd1);
        next_state = S0;
      end
    end
    
    default: next_state = IDLE;
  endcase
end

// Fixed assignments
assign dut__tb__sram_input_read_address = aCount;
assign dut__tb__sram_weight_read_address = bCount; // Fixed: Was duplicating input read address
assign dut__tb__sram_result_write_address = cCount;
assign dut__tb__sram_result_write_data = cWriteDataR;
assign dut__tb__sram_result_write_enable = cWriteEnableR;
assign inst_rnd = 3'b000; // Added missing rounding mode
assign accum_result = 32'd0; // Added missing accumulator initial value

DW_fp_mac_inst FP_MAC ( 
  .inst_a(tb__dut__sram_input_read_data),
  .inst_b(tb__dut__sram_weight_read_data),
  .inst_c(accum_result),
  .inst_rnd(inst_rnd),
  .z_inst(mac_result_z),
  .status_inst()
);

endmodule

module DW_fp_mac_inst #(
  parameter inst_sig_width = 23,
  parameter inst_exp_width = 8,
  parameter inst_ieee_compliance = 0 // These need to be fixed to decrease error
) ( 
  input wire [inst_sig_width+inst_exp_width : 0] inst_a,
  input wire [inst_sig_width+inst_exp_width : 0] inst_b,
  input wire [inst_sig_width+inst_exp_width : 0] inst_c,
  input wire [2 : 0] inst_rnd,
  output wire [inst_sig_width+inst_exp_width : 0] z_inst,
  output wire [7 : 0] status_inst
);

  // Instance of DW_fp_mac
  DW_fp_mac #(inst_sig_width, inst_exp_width, inst_ieee_compliance) U1 (
    .a(inst_a),
    .b(inst_b),
    .c(inst_c),
    .rnd(inst_rnd),
    .z(z_inst),
    .status(status_inst) 
  );

endmodule: DW_fp_mac_inst
