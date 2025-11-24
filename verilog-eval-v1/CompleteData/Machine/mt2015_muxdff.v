
// -------------------------  Description -------------------------
 This Verilog module is a simple combinational logic circuit which implements a multiplexer. The module has five ports, four inputs and one output. The inputs are a clock signal (clk), a select signal (L), and two data inputs (q_in and r_in). The output is a single bit register (Q).  The module is triggered on the rising edge of the clock signal. When the clock signal is high, the logic circuit evaluates the select signal (L). If the select signal is high, the output register (Q) is set to the value of the second data input (r_in). If the select signal is low, the output register (Q) is set to the value of the first data input (q_in).  The initial value of the output register (Q) is set to 0. This ensures that the output register is in a known state before the first rising edge of the clock signal.  The module is useful for selecting between two data inputs based on a select signal. This allows for a single output to be driven by two different sources depending on the value of the select signal.

// -------------------------  Whole Module -------------------------
module top_module(
	input clk,
	input L,
	input q_in,
	input r_in,
	output reg Q);


	initial Q=0;
	always @(posedge clk)
		Q <= L ? r_in : q_in;
	
endmodule


// -------------------------  Testbench -------------------------
`timescale 1 ps/1 ps
`define OK 12
`define INCORRECT 13
/*
	Midterm 2015 Question 5a. Build a flip-flop with a 2-to-1 mux before it.
*/
module reference_module(
	input clk,
	input L,
	input q_in,
	input r_in,
	output reg Q);

	initial Q=0;
	always @(posedge clk)
		Q <= L ? r_in : q_in;
	
endmodule


module stimulus_gen (
	input clk,
	output logic L,
	output logic r_in,
	output logic q_in
);

	always @(posedge clk, negedge clk)
		{L, r_in, q_in} <= $random % 8;
	
	initial begin
		repeat(100) @(posedge clk);
		#1 $finish;
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

	logic L;
	logic q_in;
	logic r_in;
	logic Q_ref;
	logic Q_dut;

	initial begin 
		$dumpfile("wave.vcd");
		$dumpvars(1, stim1.clk, tb_mismatch ,clk,L,q_in,r_in,Q_ref,Q_dut );
	end


	wire tb_match;		// Verification
	wire tb_mismatch = ~tb_match;
	
	stimulus_gen stim1 (
		.clk,
		.* ,
		.L,
		.q_in,
		.r_in );
	reference_module good1 (
		.clk,
		.L,
		.q_in,
		.r_in,
		.Q(Q_ref) );
		
	top_module top_module1 (
		.clk,
		.L,
		.q_in,
		.r_in,
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

