module (input data, input sumSelect, input checkError, output reg sum, output reg error);
	always@ (posedge clock) begin
		case (sumSelect)
			2'b00 : sum <= Data;
			2'b01 : sum <= sum + Data;
		endcase
		case (checkError)
			2'b01 : error <= !(sum == Data);
			2'b10 : error <= 0;
		endcase
	end
endmodule
	

