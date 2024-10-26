/*module************************************
*
* NAME:  counter
*
* DESCRIPTION:
*  downcounter with zero flag and synchronous clear
*
* NOTES:
*
* REVISION HISTORY
*    Date     Programmer          Description
*    9/17/24  Thiago Gesteira    ece564-8-bit-down-counter
*
*/

/*======Declarations===============================*/

module counter (clock, in, latch, dec, divByTwo, zero);


/*-----------Inputs--------------------------------*/

input       clock;  /* clock */
input [7:0] in;  /* input initial count */
input       latch;  /* `latch input' */
input       dec;   /* decrement */
input       divByTwo;  /* divide by two */

/*-----------Outputs--------------------------------*/

output      zero;  /* zero flag */

/*----------------Nets and Registers----------------*/
/*---(See input and output for unexplained variables)---*/

reg [7:0] value;       /* current count value */
wire      zero;

// Count Flip-flops with input multiplexor
/*
always @(posedge clock) begin
  if (latch) 
    value <= in;
  else if (dec && !zero) 
    value <= value - 1;
  else if (!dec && !zero && divByTwo) 
    value <= value >> 1;
end
*/
always@(posedge clock)
  begin  // begin-end not actually need here as there is only one statement
    casex ({latch, dec, zero, divByTwo}) 
      4'b1???: value <= in;
      4'b010?: value <= value - 1'b1;
      4'b0001: value <= value >> 1;
      default: value <= value;
    endcase
  end

// combinational logic for zero flag
assign zero = ~|value;

endmodule /* counter */




