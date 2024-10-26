// Verilog file for the FSM for the pattern matching engine
module fsm (
    input clock,            // 100 MHz clock
    input reset,            // resets the FSM
    input start,            // starts the search
    input [8:0] match_address, // address for the pattern match
    input done_flag,        // signal from compare module that search is finished
    
    output reg inc_flag,    // used to increment the address location
    output reg [8:0] location, // location output for pattern match
    output reg [8:0] outcell  // A hash on location
);

// State encoding
parameter s0 = 1'b0;
parameter s1 = 1'b1;

reg current_state, next_state;

// Synchronous reset and state transition
always @(posedge clock or negedge reset) begin
    if (!reset)
        current_state <= s0;
    else
        current_state <= next_state;
end

// Next state logic and output logic
always @(current_state or start or done_flag) begin
    // Default values
    next_state = current_state; // remain in current state unless changed
    inc_flag = 1'b0;            // default to no increment
    
    case (current_state)
        s0: begin
            if (start) begin
                location = 9'd0;   // reset location
                next_state = s1;   // move to state S1
            end else begin
                inc_flag = 1'b0;   // remain in state S0
            end
        end
        
        s1: begin
            if (done_flag) begin
                location = match_address; // set location to match address
                next_state = s0;          // move back to state S0
            end else begin
                inc_flag = 1'b1;    // continue incrementing location
                next_state = s1;    // stay in state S1
            end
        end
    endcase
end

// Hash calculation on location
always @(posedge clock) begin
    outcell <= location ^ (location << 1); // example hash, could adjust
end

endmodule

