
// -------------------------  Description -------------------------
 This Verilog module is a top-level module that takes in a 3-bit input 'a' and outputs a 16-bit register 'q'. The module uses an always block to continuously check the input 'a' and assign the corresponding value to the output 'q'. The always block uses a case statement to check the value of 'a' and assign the corresponding value to 'q'. If 'a' is 0, then 'q' is assigned the value 4658. If 'a' is 1, then 'q' is assigned the value 44768. If 'a' is 2, then 'q' is assigned the value 10196. If 'a' is 3, then 'q' is assigned the value 23054. If 'a' is 4, then 'q' is assigned the value 8294. If 'a' is 5, then 'q' is assigned the value 25806. If 'a' is 6, then 'q' is assigned the value 50470. Finally, if 'a' is 7, then 'q' is assigned the value 12057.

// -------------------------  Whole Module -------------------------
module top_module (
	input [2:0] a, 
	output reg [15:0] q
);


	always @(*) 
		case (a)
			0: q = 4658;
			1: q = 44768;
			2: q = 10196;
			3: q = 23054;
			4: q = 8294;
			5: q = 25806;
			6: q = 50470;
			7: q = 12057;
		endcase
	
endmodule


// -------------------------  Testbench -------------------------
`timescale 1 ps/1 ps
`define OK 12
`define INCORRECT 13
module reference_module (
	input [2:0] a, 
	output reg [15:0] q
);

	always @(*) 
		case (a)
			0: q = 4658;
			1: q = 44768;
			2: q = 10196;
			3: q = 23054;
			4: q = 8294;
			5: q = 25806;
			6: q = 50470;
			7: q = 12057;
		endcase
	
endmodule


module stimulus_gen (
	input clk,
	output logic [2:0] a,
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
		@(negedge clk) wavedrom_start("Unknown circuit");
			@(posedge clk) {a} <= 0;
			repeat(10) @(posedge clk,negedge clk) a <= a + 1;
		wavedrom_stop();

		repeat(100) @(posedge clk, negedge clk)
			a <= $urandom;
		$finish;
	end
	
endmodule

module tb();

	typedef struct packed {
		int errors;
		int errortime;
		int errors_q;
		int errortime_q;

		int clocks;
	} stats;
	
	stats stats1;
	
	
	wire[511:0] wavedrom_title;
	wire wavedrom_enable;
	int wavedrom_hide_after_time;
	
	reg clk=0;
	initial forever
		#5 clk = ~clk;

	logic [2:0] a;
	logic [15:0] q_ref;
	logic [15:0] q_dut;

	initial begin 
		$dumpfile("wave.vcd");
		$dumpvars(1, stim1.clk, tb_mismatch ,a,q_ref,q_dut );
	end


	wire tb_match;		// Verification
	wire tb_mismatch = ~tb_match;
	
	stimulus_gen stim1 (
		.clk,
		.* ,
		.a );
	reference_module good1 (
		.a,
		.q(q_ref) );
		
	top_module top_module1 (
		.a,
		.q(q_dut) );

	
	bit strobe = 0;
	task wait_for_end_of_timestep;
		repeat(5) begin
			strobe <= !strobe;  // Try to delay until the very end of the time step.
			@(strobe);
		end
	endtask	

	
	final begin
		if (stats1.errors_q) $display("Hint: Output '%s' has %0d mismatches. First mismatch occurred at time %0d.", "q", stats1.errors_q, stats1.errortime_q);
		else $display("Hint: Output '%s' has no mismatches.", "q");

		$display("Hint: Total mismatched samples is %1d out of %1d samples\n", stats1.errors, stats1.clocks);
		$display("Simulation finished at %0d ps", $time);
		$display("Mismatches: %1d in %1d samples", stats1.errors, stats1.clocks);
	end
	
	// Verification: XORs on the right makes any X in good_vector match anything, but X in dut_vector will only match X.
	assign tb_match = ( { q_ref } === ( { q_ref } ^ { q_dut } ^ { q_ref } ) );
	// Use explicit sensitivity list here. @(*) causes NetProc::nex_input() to be called when trying to compute
	// the sensitivity list of the @(strobe) process, which isn't implemented.
	always @(posedge clk, negedge clk) begin

		stats1.clocks++;
		if (!tb_match) begin
			if (stats1.errors == 0) stats1.errortime = $time;
			stats1.errors++;
		end
		if (q_ref !== ( q_ref ^ q_dut ^ q_ref ))
		begin if (stats1.errors_q == 0) stats1.errortime_q = $time;
			stats1.errors_q = stats1.errors_q+1'b1; end

	end
endmodule

