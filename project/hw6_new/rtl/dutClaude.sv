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
  output reg dut_ready                   ,

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

typedef enum logic [2:0] {
    IDLE  = 3'd0, 
    S0    = 3'd1,   // MAC Operation State    
    S1    = 3'd2,   // Write Result State
    PARSE_MATRIX_DIMENSIONS = 3'd3   
} states;

states current_state, next_state;

// -------------------- Registers ---------------------------
reg [15:0] aRowBase;      // Base address for current row in A
reg [15:0] bColBase;      // Base address for current column in B
reg [15:0] dotProdCount;  // Counter for dot product calculation
reg [`SRAM_DATA_RANGE] cWriteDataR;
reg        cWriteEnableR;

reg [15:0] aColumns;      // Width of matrix A
reg [15:0] aRows;         // Height of matrix A
reg [15:0] bColumns;      // Width of matrix B
reg [15:0] currRow;       // Current row being processed
reg [15:0] currCol;       // Current column being processed
reg first_mac;            // First MAC operation flag

// Wire for MAC result
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
    cWriteDataR <= 32'd0;
    first_mac <= 1'b1;
  end else begin
    current_state <= next_state;
    
    case(current_state)
      S0: begin
        if(first_mac) begin
          cWriteDataR <= mac_result_z;
          first_mac <= 1'b0;
        end else if (dotProdCount < aColumns) begin
          cWriteDataR <= mac_result_z;
        end
      end
      S1: begin
        first_mac <= 1'b1;
        cWriteDataR <= 32'd0;
      end
    endcase
  end
end

always @(*) begin
  next_state = current_state;
  
  case (current_state)
    IDLE: begin
      if (dut_valid) begin
        next_state = PARSE_MATRIX_DIMENSIONS;
        dut_ready = 1'b0;
        currRow = 16'd0;
        currCol = 16'd0;
        dotProdCount = 16'd0;
        aRowBase = 16'd1;  // Start at address 1 since address 0 has dimensions
        bColBase = 16'd1;  // Start at address 1 since address 0 has dimensions
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
      if (dotProdCount == aColumns) begin  // Finished one element of C
        cWriteEnableR = 1'b1;
        next_state = S1;
      end else begin
        dotProdCount = dotProdCount + 1;
      end
    end
    
    S1: begin
      cWriteEnableR = 1'b0;
      dotProdCount = 16'd0;
      
      if (currCol == bColumns - 1) begin  // Finished a row
        if (currRow == aRows - 1) begin   // Finished all rows
          dut_ready = 1'b1;
          next_state = IDLE;
        end else begin
          currRow = currRow + 1;
          currCol = 16'd0;
          aRowBase = aRowBase + aColumns;  // Move to next row of A
          bColBase = 16'd1;               // Reset to first column of B
          next_state = S0;
        end
      end else begin
        currCol = currCol + 1;
        bColBase = bColBase + 1;          // Move to next column of B
        next_state = S0;
      end
    end
    
    default: next_state = IDLE;
  endcase
end

// Address generation for reading A and B matrices
wire [15:0] aReadAddr = aRowBase + dotProdCount;
wire [15:0] bReadAddr = bColBase + (dotProdCount * bColumns);
wire [15:0] cWriteAddr = currRow * bColumns + currCol + 1;

// Fixed assignments
assign dut__tb__sram_input_read_address = aReadAddr;
assign dut__tb__sram_weight_read_address = bReadAddr;
assign dut__tb__sram_result_write_address = cWriteAddr;
assign dut__tb__sram_result_write_data = cWriteDataR;
assign dut__tb__sram_result_write_enable = cWriteEnableR;
assign inst_rnd = 3'b000;  // Round to nearest even

DW_fp_mac_inst FP_MAC ( 
  .inst_a(tb__dut__sram_input_read_data),
  .inst_b(tb__dut__sram_weight_read_data),
  .inst_c(first_mac ? 32'd0 : cWriteDataR),  // Start with 0 for first MAC
  .inst_rnd(inst_rnd),
  .z_inst(mac_result_z),
  .status_inst()
);

endmodule
