
// -------------------------  Description -------------------------
 This Verilog module implements a JK flip-flop, which is a type of sequential logic circuit. It has three inputs (clk, j, and k) and one output (Q). The clock input (clk) is used to synchronize the circuit and the other two inputs (j and k) are used to control the state of the output (Q).   The module is declared with the keyword "module" followed by the name of the module ("top") and the list of ports (inputs and outputs). The module body contains an always block, which is triggered on the rising edge of the clock signal (posedge clk). Inside the always block, the output (Q) is assigned a value based on the logic expression given. The expression is a combination of two logic operations, an AND operation and an OR operation. The AND operation is between the input j and the NOT of the output Q, and the OR operation is between the NOT of the input k and the output Q.   This expression implements the JK flip-flop logic. When the input j is high and the input k is low, the output Q will be set to the value of j. When the input j is low and the input k is high, the output Q will be reset to the value of 0. When both the inputs j and k are high, the output Q will toggle its value. When both the inputs j and k are low, the output Q will remain unchanged.

// -------------------------  Whole Module -------------------------
module top_module (
	input clk,
	input j,
	input k,
	output reg Q
);


	always @(posedge clk)
		Q <= j&~Q | ~k&Q;
	
endmodule


// -------------------------  Testbench -------------------------
`timescale 1 ps/1 ps
`define OK 12
`define INCORRECT 13
module reference_module (
	input clk,
	input j,
	input k,
	output reg Q
);

	always @(posedge clk)
		Q <= j&~Q | ~k&Q;
	
endmodule


module stimulus_gen (
	input clk,
	output logic j, k,
	output reg[511:0] wavedrom_title,
	output reg wavedrom_enable
);

// Add two ports to module stimulus_gen:
//    output [511:0] wavedrom_title
//    output reg wavedrom_enable

	task wavedrom_start(input[511:0] title = "");
	endtask
	
	task wavedrom_stop;
		#1;
	endtask	



	initial begin
		{j,k} <= 1;
		
		@(negedge clk) wavedrom_start();
			@(posedge clk) {j,k} <= 2'h1;
			@(posedge clk) {j,k} <= 2'h2;
			@(posedge clk) {j,k} <= 2'h3;
			@(posedge clk) {j,k} <= 2'h3;
			@(posedge clk) {j,k} <= 2'h3;
			@(posedge clk) {j,k} <= 2'h0;
			@(posedge clk) {j,k} <= 2'h0;
			@(posedge clk) {j,k} <= 2'h0;
			@(posedge clk) {j,k} <= 2'h2;
			@(posedge clk) {j,k} <= 2'h2;
		@(negedge clk) wavedrom_stop();
		repeat(400) @(posedge clk, negedge clk)
			{j,k} <= $random;
		$finish;
	end
	
endmodule

module tb();

	typedef struct packed {
		int errors;
		int errortime;
		int errors_Q;
		int errortime_Q;

		int clocks;
	} stats;
	
	stats stats1;
	
	
	wire[511:0] wavedrom_title;
	wire wavedrom_enable;
	int wavedrom_hide_after_time;
	
	reg clk=0;
	initial forever
		#5 clk = ~clk;

	logic j;
	logic k;
	logic Q_ref;
	logic Q_dut;

	initial begin 
		$dumpfile("wave.vcd");
		$dumpvars(1, stim1.clk, tb_mismatch ,clk,j,k,Q_ref,Q_dut );
	end


	wire tb_match;		// Verification
	wire tb_mismatch = ~tb_match;
	
	stimulus_gen stim1 (
		.clk,
		.* ,
		.j,
		.k );
	reference_module good1 (
		.clk,
		.j,
		.k,
		.Q(Q_ref) );
		
	top_module top_module1 (
		.clk,
		.j,
		.k,
		.Q(Q_dut) );

	
	bit strobe = 0;
	task wait_for_end_of_timestep;
		repeat(5) begin
			strobe <= !strobe;  // Try to delay until the very end of the time step.
			@(strobe);
		end
	endtask	

	
	final begin
		if (stats1.errors_Q) $display("Hint: Output '%s' has %0d mismatches. First mismatch occurred at time %0d.", "Q", stats1.errors_Q, stats1.errortime_Q);
		else $display("Hint: Output '%s' has no mismatches.", "Q");

		$display("Hint: Total mismatched samples is %1d out of %1d samples\n", stats1.errors, stats1.clocks);
		$display("Simulation finished at %0d ps", $time);
		$display("Mismatches: %1d in %1d samples", stats1.errors, stats1.clocks);
	end
	
	// Verification: XORs on the right makes any X in good_vector match anything, but X in dut_vector will only match X.
	assign tb_match = ( { Q_ref } === ( { Q_ref } ^ { Q_dut } ^ { Q_ref } ) );
	// Use explicit sensitivity list here. @(*) causes NetProc::nex_input() to be called when trying to compute
	// the sensitivity list of the @(strobe) process, which isn't implemented.
	always @(posedge clk, negedge clk) begin

		stats1.clocks++;
		if (!tb_match) begin
			if (stats1.errors == 0) stats1.errortime = $time;
			stats1.errors++;
		end
		if (Q_ref !== ( Q_ref ^ Q_dut ^ Q_ref ))
		begin if (stats1.errors_Q == 0) stats1.errortime_Q = $time;
			stats1.errors_Q = stats1.errors_Q+1'b1; end

	end
endmodule

