
//---------------------------------------------------------------------------
// Filename    : golden_model_hw6_v2.sv
// Author      : Prasanth Prabu Ravichandiran
// Affiliation : North Carolina State University, Raleigh, NC
// Date        : Nov 2023
// Email       : pravich2@ncsu.edu
    
// Description : This file contains the FP accumulation from the SRAM.
//               It writes the accumulation result back to the SRAM's (N+1) address. 
//---------------------------------------------------------------------------
module MyDesign(
//---------------------------------------------------------------------------
//System signals
  input wire reset_n                      ,  
  input wire clk                          ,

//---------------------------------------------------------------------------
//Control signals
  input wire dut_valid                    , 
  output wire dut_ready                   ,

//---------------------------------------------------------------------------
//q_state_output SRAM interface
  output wire         sram_write_enable  ,
  output wire [15:0]  sram_write_address ,
  output wire [31:0]  sram_write_data    ,
  output wire [15:0]  sram_read_address  , 
  input  wire [31:0]  sram_read_data     

);

//---------------------------------------------------------------------------
//q_state_output SRAM interface
  reg        sram_write_enable_r  ;
  reg [15:0] sram_write_address_r ;
  reg [31:0] sram_write_data_r    ;
  reg [15:0] sram_read_address_r  ; 
  reg compute_complete;

// This is test sub for the DW_fp_add, do not change any of the inputs to the
// param list for the DW_fp_add, you will only need one DW_fp_add

// synopsys translate_off
  shortreal test_val;
  assign test_val = $bitstoshortreal(sum_r); 
  // This is a helper val for seeing the 32bit flaot value, you can repicate 
  // this for any signal, but keep it between the translate_off and
  // translate_on 
// synopsys translate_on

  wire  [31:0] sum_w;   // Result from FP_add
  reg   [31:0] sum_r;   // Input A of the FP_add 
  reg   [31:0] in;      // Input B of the FP_add
  wire  [7:0] status;   // Status register of the FP_add module is IGNORED

// Use define to parameterize the variable sizes
  `ifndef SRAM_ADDR_WIDTH
    `define SRAM_ADDR_WIDTH 16
  `endif

  `ifndef SRAM_DATA_WIDTH
    `define SRAM_DATA_WIDTH 32
  `endif

//---------------------------------------------------------------------------
//FSM registers for q_input_state
  `ifndef FSM_BIT_WIDTH
    `define FSM_BIT_WIDTH 8
  `endif

  typedef enum logic [`FSM_BIT_WIDTH-1:0] {
  IDLE                          = `FSM_BIT_WIDTH'b0000_0001,
  READ_SRAM_ZERO_ADDR           = `FSM_BIT_WIDTH'b0000_0010,
  READ_SRAM_FIRST_ARRAY_ELEMENT = `FSM_BIT_WIDTH'b0000_0100,
  READ_SRAM_2_N_ARRAY           = `FSM_BIT_WIDTH'b0000_1000,
  WAIT_FOR_READ_SRAM_N_TH_DATA  = `FSM_BIT_WIDTH'b0001_0000,
  WRITE_SRAM_ACCUMULATION       = `FSM_BIT_WIDTH'b0010_0000,
  COMPUTE_COMPLETE              = `FSM_BIT_WIDTH'b0100_0000
  } e_states;

  e_states current_state, next_state;

// Local control path variables
  reg                           set_dut_ready             ;
  reg                           get_array_size            ;
  reg [1:0]                     read_addr_sel             ;
  reg                           all_element_read_completed;
  reg                           compute_accumulation      ;
  reg                           save_array_size           ;
  reg                           write_enable_sel          ;

// Local data path variables 
  reg [`SRAM_DATA_WIDTH-1:0]      array_size              ;

// -------------------- Control path ------------------------
always @(posedge clk) begin : proc_current_state_fsm
  if(!reset_n) begin // Synchronous reset
    current_state <= IDLE;
  end else begin
    current_state <= next_state;
  end
end


always @(*) begin : proc_next_state_fsm
  case (current_state)

    IDLE                    : begin
      if (dut_valid) begin
        set_dut_ready       = 1'b0;
        get_array_size      = 1'b0;
        read_addr_sel       = 2'b00;
        compute_accumulation= 1'b0;
        save_array_size     = 1'b0;
        write_enable_sel    = 1'b0;
        next_state          = READ_SRAM_ZERO_ADDR;
      end
      else begin
        set_dut_ready       = 1'b1;
        get_array_size      = 1'b0;
        read_addr_sel       = 2'b00;
        compute_accumulation= 1'b0;
        write_enable_sel    = 1'b0;
        save_array_size     = 1'b0;
        next_state          = IDLE;
      end
    end
  
    READ_SRAM_ZERO_ADDR  : begin
      set_dut_ready         = 1'b0;
      get_array_size        = 1'b1;
      read_addr_sel         = 2'b01;  // Increment the read addr
      compute_accumulation  = 1'b0;
      save_array_size       = 1'b0;
      write_enable_sel      = 1'b0;
      next_state            = READ_SRAM_FIRST_ARRAY_ELEMENT;
    end 

    READ_SRAM_FIRST_ARRAY_ELEMENT: begin
      set_dut_ready         = 1'b0;
      get_array_size        = 1'b0;
      read_addr_sel         = 2'b01;  // Increment the read addr
      compute_accumulation  = 1'b0;
      save_array_size       = 1'b1;
      write_enable_sel      = 1'b0;
      next_state            = READ_SRAM_2_N_ARRAY;    
    end

    READ_SRAM_2_N_ARRAY     : begin
      set_dut_ready         = 1'b0;
      get_array_size        = 1'b0;
      read_addr_sel         = 2'b01;  // Keep incrementing the read addr
      compute_accumulation  = 1'b1;
      save_array_size       = 1'b1;
      write_enable_sel      = 1'b0;
      next_state            = all_element_read_completed ? WAIT_FOR_READ_SRAM_N_TH_DATA : READ_SRAM_2_N_ARRAY;
    end 

    WAIT_FOR_READ_SRAM_N_TH_DATA : begin
      set_dut_ready         = 1'b0;
      get_array_size        = 1'b0;
      read_addr_sel         = 2'b10;  // Hold the address
      compute_accumulation  = 1'b1;
      save_array_size       = 1'b1;
      write_enable_sel      = 1'b0;
      next_state            = WRITE_SRAM_ACCUMULATION;    
    end

    WRITE_SRAM_ACCUMULATION : begin
      set_dut_ready         = 1'b0;
      get_array_size        = 1'b0;
      read_addr_sel         = 2'b10;  // Hold the address
      compute_accumulation  = 1'b0;
      save_array_size       = 1'b1;
      write_enable_sel      = 1'b1;
      next_state            = COMPUTE_COMPLETE;
    end

    COMPUTE_COMPLETE        : begin
      set_dut_ready         = 1'b1;
      get_array_size        = 1'b0;
      read_addr_sel         = 2'b00;  
      compute_accumulation  = 1'b0;
      save_array_size       = 1'b0;
      write_enable_sel      = 1'b0;
      next_state            = IDLE;      
    end

    default                 :  begin
      set_dut_ready         = 1'b1;
      get_array_size        = 1'b0;
      read_addr_sel         = 2'b00;  
      compute_accumulation  = 1'b0;
      save_array_size       = 1'b0;
      write_enable_sel      = 1'b0;      
      next_state            = IDLE;
    end
  endcase
end


// DUT ready handshake logic
always @(posedge clk) begin : proc_compute_complete
  if(!reset_n) begin
    compute_complete <= 0;
  end else begin
    compute_complete <= (set_dut_ready) ? 1'b1 : 1'b0;
  end
end

assign dut_ready = compute_complete;

// Find the number of array elements 
always @(posedge clk) begin : proc_array_size
  if(!reset_n) begin
    array_size <= `SRAM_DATA_WIDTH'b0;
  end else begin
    array_size <= get_array_size ? sram_read_data : (save_array_size ? array_size : `SRAM_DATA_WIDTH'b0);
  end
end

// SRAM read address generator
always @(posedge clk) begin
    if (!reset_n) begin
      sram_read_address_r   <= 0;
    end
    else begin
      if (read_addr_sel == 2'b00)
        sram_read_address_r <= `SRAM_ADDR_WIDTH'b0;
      else if (read_addr_sel == 2'b01)
        sram_read_address_r <= sram_read_address_r + `SRAM_ADDR_WIDTH'b1;
      else if (read_addr_sel == 2'b10)
        sram_read_address_r <= sram_read_address_r;
      else if (read_addr_sel == 2'b11)
        sram_read_address_r <= `SRAM_ADDR_WIDTH'b01;
    end
end

assign sram_read_address = sram_read_address_r;

// READ N-elements in SRAM 
always @(posedge clk) begin : proc_read_completion
  if(!reset_n) begin
    all_element_read_completed <= 1'b0;
  end else begin
    all_element_read_completed <= (sram_read_address_r  == (array_size-1)) ? 1'b1 : 1'b0;
  end
end

// SRAM write enable logic
always @(posedge clk) begin : proc_sram_write_enable_r
  if(!reset_n) begin
    sram_write_enable_r <= 1'b0;
  end else begin
    sram_write_enable_r <= write_enable_sel ? 1'b1 : 1'b0;
  end
end

assign sram_write_enable = sram_write_enable_r;


// SRAM write address logic
always @(posedge clk) begin : proc_sram_write_address_r
  if(!reset_n) begin
    sram_write_address_r <= 1'b0;
  end else begin
    sram_write_address_r <= (write_enable_sel) ? sram_read_address_r : `SRAM_DATA_WIDTH'b0;  
  end
end

assign sram_write_address = sram_write_address_r;

// SRAM write data logic
always @(posedge clk) begin : proc_sram_write_data_r
  if(!reset_n) begin
    sram_write_data_r <= `SRAM_DATA_WIDTH'b0;
  end else begin
    sram_write_data_r <= (write_enable_sel) ? sum_w : `SRAM_DATA_WIDTH'b0;
  end
end

assign sram_write_data = sram_write_data_r;



// Accumulation logic 
always @(posedge clk) begin : proc_accumulation
  if(!reset_n) begin
    sum_r   <= `SRAM_DATA_WIDTH'b0;
    in      <= `SRAM_DATA_WIDTH'b0;
  end else begin
    if (compute_accumulation) begin
      sum_r <= sum_w;
      in    <= sram_read_data;
    end
    else begin
      sum_r <= `SRAM_DATA_WIDTH'b0;
      in    <= `SRAM_DATA_WIDTH'b0;
    end
  end
end


// ----------------- Designware FP_add instantiation -------- 
  DW_fp_add  #(
    .sig_width        (23),
    .exp_width        (8),
    .ieee_compliance  (3)
  ) fp_add_mod (
    .a                (sum_r), 
    .b                (in), 
    .rnd              (3'd0), 
    .z                (sum_w), 
    .status           (status));

// ----------------------------------------------------------

endmodule