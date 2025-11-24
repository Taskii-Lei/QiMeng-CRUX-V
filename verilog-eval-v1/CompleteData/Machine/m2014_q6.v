
// -------------------------  Description -------------------------
 This top Verilog module is a state machine that outputs a one-bit signal z. The module has four ports: a clock (clk), a reset (reset), an input (w), and an output (z). The module has six states, A to F. The next state of the state machine is determined by the current state and the input w. The transition from state A to state B is taken when the input w is low. The transition from state A to state A is taken when the input w is high. The transition from state B to state D is taken when the input w is high. The transition from state B to state C is taken when the input w is low. The transition from state C to state D is taken when the input w is high. The transition from state C to state E is taken when the input w is low. The transition from state D to state A is taken when the input w is high. The transition from state D to state F is taken when the input w is low. The transition from state E to state D is taken when the input w is high. The transition from state E to state E is taken when the input w is low. The transition from state F to state D is taken when the input w is high. The transition from state F to state C is taken when the input w is low.  The state machine is triggered by the clk signal. When the clk signal is high, the state machine will check the reset signal. If the reset signal is high, the state machine will reset to state A, otherwise the state machine will transition to the next state. The output z is high when the state machine is in state E or F, and is low otherwise.




// -------------------------  Whole Module -------------------------
module top_module (
	input clk,
	input reset,
	input w,
	output z
);

	parameter A=0, B=1, C=2, D=3, E=4, F=5;
	reg [2:0] state, next;
	
	always @(posedge clk)
		if (reset)
			state <= A;
		else 
			state <= next;
			
			
	always_comb begin
		case(state)
			A: next = w ? A : B;
			B: next = w ? D : C;
			C: next = w ? D : E;
			D: next = w ? A : F;
			E: next = w ? D : E;
			F: next = w ? D : C;
			default: next = 'x;
		endcase
	end
	
	assign z = (state == E || state == F);

endmodule


// -------------------------  Testbench -------------------------
`timescale 1 ps/1 ps
`define OK 12
`define INCORRECT 13
module reference_module (
	input clk,
	input reset,
	input w,
	output z
);
	parameter A=0, B=1, C=2, D=3, E=4, F=5;
	reg [2:0] state, next;
	
	always @(posedge clk)
		if (reset)
			state <= A;
		else 
			state <= next;
			
			
	always_comb begin
		case(state)
			A: next = w ? A : B;
			B: next = w ? D : C;
			C: next = w ? D : E;
			D: next = w ? A : F;
			E: next = w ? D : E;
			F: next = w ? D : C;
			default: next = 'x;
		endcase
	end
	
	assign z = (state == E || state == F);

endmodule


module stimulus_gen (
	input clk,
	output logic reset,
	output logic w
);

	initial begin
		repeat(200) @(posedge clk, negedge clk) begin
			w <= $random;
			reset <= ($random & 15) == 0;
		end
		
		#1 $finish;
	end
	
endmodule

module tb();

	typedef struct packed {
		int errors;
		int errortime;
		int errors_z;
		int errortime_z;

		int clocks;
	} stats;
	
	stats stats1;
	
	
	wire[511:0] wavedrom_title;
	wire wavedrom_enable;
	int wavedrom_hide_after_time;
	
	reg clk=0;
	initial forever
		#5 clk = ~clk;

	logic reset;
	logic w;
	logic z_ref;
	logic z_dut;

	initial begin 
		$dumpfile("wave.vcd");
		$dumpvars(1, stim1.clk, tb_mismatch ,clk,reset,w,z_ref,z_dut );
	end


	wire tb_match;		// Verification
	wire tb_mismatch = ~tb_match;
	
	stimulus_gen stim1 (
		.clk,
		.* ,
		.reset,
		.w );
	reference_module good1 (
		.clk,
		.reset,
		.w,
		.z(z_ref) );
		
	top_module top_module1 (
		.clk,
		.reset,
		.w,
		.z(z_dut) );

	
	bit strobe = 0;
	task wait_for_end_of_timestep;
		repeat(5) begin
			strobe <= !strobe;  // Try to delay until the very end of the time step.
			@(strobe);
		end
	endtask	

	
	final begin
		if (stats1.errors_z) $display("Hint: Output '%s' has %0d mismatches. First mismatch occurred at time %0d.", "z", stats1.errors_z, stats1.errortime_z);
		else $display("Hint: Output '%s' has no mismatches.", "z");

		$display("Hint: Total mismatched samples is %1d out of %1d samples\n", stats1.errors, stats1.clocks);
		$display("Simulation finished at %0d ps", $time);
		$display("Mismatches: %1d in %1d samples", stats1.errors, stats1.clocks);
	end
	
	// Verification: XORs on the right makes any X in good_vector match anything, but X in dut_vector will only match X.
	assign tb_match = ( { z_ref } === ( { z_ref } ^ { z_dut } ^ { z_ref } ) );
	// Use explicit sensitivity list here. @(*) causes NetProc::nex_input() to be called when trying to compute
	// the sensitivity list of the @(strobe) process, which isn't implemented.
	always @(posedge clk, negedge clk) begin

		stats1.clocks++;
		if (!tb_match) begin
			if (stats1.errors == 0) stats1.errortime = $time;
			stats1.errors++;
		end
		if (z_ref !== ( z_ref ^ z_dut ^ z_ref ))
		begin if (stats1.errors_z == 0) stats1.errortime_z = $time;
			stats1.errors_z = stats1.errors_z+1'b1; end

	end
endmodule

