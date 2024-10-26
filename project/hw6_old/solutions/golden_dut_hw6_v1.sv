
//---------------------------------------------------------------------------
// DUT 
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

  reg [15:0] M;
  wire  [31:0] sum_w;
  reg   [31:0] sum_r;
  reg  [31:0] in;
  wire  [7:0] status;

  typedef enum bit[2:0] {
    IDLE  = 3'd0, 
    S0    = 3'd1,   
    S1    = 3'd2,   
    S2    = 3'd3,   
    S3    = 3'd4,   
    S4    = 3'd5,   
    S5    = 3'd6,   
    COMPLETE  = 3'd7} states;

  reg dut_ready_r;

  always@(posedge clk)
  begin
    if(reset_n)
      if(dut_ready_r)
        dut_ready_r <= ~dut_valid;
      else
        dut_ready_r <= compute_complete;
    else
      dut_ready_r <= 1'b1;
  end
  assign dut_ready = dut_ready_r;

  states system_state;

  always@(posedge clk)
  begin
    if(reset_n)
    begin
      case(system_state)
        IDLE : system_state <= dut_valid ? S0 : IDLE;
        S0   : system_state <= S1;  
        S1   : system_state <= S2;
        S2   : system_state <=  sram_read_address_r < M-1 ? S2 : S3;
        S3   : system_state <= S4;
        S4   : system_state <= S5;
        S5   : system_state <= COMPLETE;
        COMPLETE : system_state <= IDLE; 
      endcase
    end else
      system_state <= IDLE;
  end

  always@(posedge clk)
  begin
    if(reset_n)
      case(system_state)
        COMPLETE :compute_complete <= 1'b1;
        default : compute_complete <= 1'b0;
      endcase
    else
      compute_complete <= 1'b0;
  end

  always@(posedge clk)
  begin
    if(reset_n)
      case(system_state)
        S5 : sram_write_enable_r <= 1'b1;
        default : sram_write_enable_r <= 1'b0;
      endcase
    else
      sram_write_enable_r <= 1'b0;
  end

  assign sram_write_enable = sram_write_enable_r;


  always@(posedge clk)
  begin
    case(system_state)
      IDLE :sram_read_address_r <= 'd0;
      default : sram_read_address_r <= sram_read_address_r + 1'd1;
    endcase
  end
  assign sram_read_address = sram_read_address_r;

  always@(posedge clk)
  begin
    sram_write_address_r <= M+1;
  end

  assign sram_write_address = sram_write_address_r;

  always@(posedge clk)
  begin
    case(system_state)
      IDLE : M <= 'd0;
      S1   : M <= sram_read_data[15:0];
      default : M <= M;
    endcase
  end

// declaration of inputs and outputs

  always@(posedge clk)
  begin
    case(system_state)
      S2 : in <= sram_read_data;
      S3 : in <= sram_read_data;
      S4 : in <= sram_read_data;
      default : in <= 'b0;
    endcase
  end

  always@(posedge clk)
  begin
    case(system_state)
      S1 : sum_r <= 'b0;
      default : sum_r <= sum_w;
    endcase
  end

  assign sram_write_data = sum_r; 
// synopsys translate_off
  shortreal test_val;
  assign test_val = $bitstoshortreal(sum_r);
// synopsys translate_on

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

endmodule
