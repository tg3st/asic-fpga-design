module ();
	input [15:0] A;
	input [2:0] rot;
	input [3:0] count;
	output [15:0] B;
	reg signed [15:0] A, B;
	reg signed [31:0] C;
	
	always @ (*) begin
		C = x;
		casex (rot)
			000: b = A << count;
			001: B = A >> count;
			010: B = A <<< count;

			011: B = A >>> count;
			100: B = {A,A} >> count;
			101: begin
				C = {A,A} << count;
				B = C[31:16];
			end
			default: B=x;
		endcase
	end

endmodule
