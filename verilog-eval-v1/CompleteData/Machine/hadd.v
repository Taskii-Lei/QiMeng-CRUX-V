
// -------------------------  Description -------------------------
 This top Verilog module is a simple adder module that takes two inputs, a and b, and produces two outputs, sum and cout. The sum output is the result of adding the two inputs together, while the cout output is the carry out of the addition.   The module begins by declaring the four ports, two inputs (a and b) and two outputs (sum and cout). The assign statement then assigns the two outputs to the result of the addition of the two inputs. The addition is done using the + operator, which adds the two inputs together and produces the sum output and the carry out, which is stored in the cout output.   This module is a simple, yet effective way to add two numbers together and produce the sum and carry out outputs. It is a useful module for any application that requires addition of two numbers.

// -------------------------  Whole Module -------------------------
module top_module (
	input a,
	input b,
	output sum,
	output cout
);


	assign {cout, sum} = a+b;
	
endmodule


// -------------------------  Testbench -------------------------
`timescale 1 ps/1 ps
`define OK 12
`define INCORRECT 13
module reference_module (
	input a,
	input b,
	output sum,
	output cout
);

	assign {cout, sum} = a+b;
	
endmodule


module stimulus_gen (
	input clk,
	output logic a,b
);

	always @(posedge clk, negedge clk)
		{a,b} <= $random;
	
	initial begin
		repeat(100) @(negedge clk);
		$finish;
	end
	
endmodule
module tb();

	typedef struct packed {
		int errors;
		int errortime;
		int errors_sum;
		int errortime_sum;
		int errors_cout;
		int errortime_cout;

		int clocks;
	} stats;
	
	stats stats1;
	
	
	wire[511:0] wavedrom_title;
	wire wavedrom_enable;
	int wavedrom_hide_after_time;
	
	reg clk=0;
	initial forever
		#5 clk = ~clk;

	logic a;
	logic b;
	logic sum_ref;
	logic sum_dut;
	logic cout_ref;
	logic cout_dut;

	initial begin 
		$dumpfile("wave.vcd");
		$dumpvars(1, stim1.clk, tb_mismatch ,a,b,sum_ref,sum_dut,cout_ref,cout_dut );
	end


	wire tb_match;		// Verification
	wire tb_mismatch = ~tb_match;
	
	stimulus_gen stim1 (
		.clk,
		.* ,
		.a,
		.b );
	reference_module good1 (
		.a,
		.b,
		.sum(sum_ref),
		.cout(cout_ref) );
		
	top_module top_module1 (
		.a,
		.b,
		.sum(sum_dut),
		.cout(cout_dut) );

	
	bit strobe = 0;
	task wait_for_end_of_timestep;
		repeat(5) begin
			strobe <= !strobe;  // Try to delay until the very end of the time step.
			@(strobe);
		end
	endtask	

	
	final begin
		if (stats1.errors_sum) $display("Hint: Output '%s' has %0d mismatches. First mismatch occurred at time %0d.", "sum", stats1.errors_sum, stats1.errortime_sum);
		else $display("Hint: Output '%s' has no mismatches.", "sum");
		if (stats1.errors_cout) $display("Hint: Output '%s' has %0d mismatches. First mismatch occurred at time %0d.", "cout", stats1.errors_cout, stats1.errortime_cout);
		else $display("Hint: Output '%s' has no mismatches.", "cout");

		$display("Hint: Total mismatched samples is %1d out of %1d samples\n", stats1.errors, stats1.clocks);
		$display("Simulation finished at %0d ps", $time);
		$display("Mismatches: %1d in %1d samples", stats1.errors, stats1.clocks);
	end
	
	// Verification: XORs on the right makes any X in good_vector match anything, but X in dut_vector will only match X.
	assign tb_match = ( { sum_ref, cout_ref } === ( { sum_ref, cout_ref } ^ { sum_dut, cout_dut } ^ { sum_ref, cout_ref } ) );
	// Use explicit sensitivity list here. @(*) causes NetProc::nex_input() to be called when trying to compute
	// the sensitivity list of the @(strobe) process, which isn't implemented.
	always @(posedge clk, negedge clk) begin

		stats1.clocks++;
		if (!tb_match) begin
			if (stats1.errors == 0) stats1.errortime = $time;
			stats1.errors++;
		end
		if (sum_ref !== ( sum_ref ^ sum_dut ^ sum_ref ))
		begin if (stats1.errors_sum == 0) stats1.errortime_sum = $time;
			stats1.errors_sum = stats1.errors_sum+1'b1; end
		if (cout_ref !== ( cout_ref ^ cout_dut ^ cout_ref ))
		begin if (stats1.errors_cout == 0) stats1.errortime_cout = $time;
			stats1.errors_cout = stats1.errors_cout+1'b1; end

	end
endmodule

