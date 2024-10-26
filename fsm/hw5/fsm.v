// Code your design here
module simpleArbiter (
	input clk, 
	input rst,
	input r0,
	input r1,
	output reg g0,
	output reg g1
);
	parameter [1:0] S0 = 2'b00;
    parameter [1:0] S1 = 2'b01;
    parameter [1:0] S2 = 2'b10;
    parameter [1:0] S3 = 2'b11;

	reg [1:0] state, next_state;


  always @ (rst) begin
		state <= S0;
	end


	always @(*) begin
      reg [1:0] in;
      in = {r0,r1};

		g0 = 0;
		g1 = 0;

		case (state)
			S0: begin
				case (in) 
					2'b00: next_state <= S0;
					2'b01: next_state <= S2;
					2'b10: next_state <= S1;
					2'b11: next_state <= S3;
				endcase
			end
			S1: begin
				g0 = 1;
				next_state <= S0;
			end
			S2: begin
				g1 = 1;
				next_state <= S0;
			end
			S3: begin
				g0 = 1;
				next_state <= S2;
			end
		endcase
	end

	always @(posedge clk) begin
		state <= next_state;
	end

endmodule


