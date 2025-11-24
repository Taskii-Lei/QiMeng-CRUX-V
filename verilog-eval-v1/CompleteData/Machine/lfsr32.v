
// -------------------------  Description -------------------------
 This top Verilog module implements a 32-bit shift register. The module has 3 ports: clk, reset, and q. The clk port is an input port that is used to synchronize the register. The reset port is an input port that is used to reset the register to the initial value. The q port is an output port that is used to output the value of the register. The module has two registers, q and q_next. The q_next register stores the next value of the register. The q register is updated on the rising edge of the clk signal. If the reset port is high, the register is reset to the initial value, 32'h1. Otherwise, the q register is updated with the value stored in the q_next register. The q_next register is updated on every clock cycle, and stores the value of the q register shifted by 1 bit. If the value of the q register is shifted out of bit 0, it is sent back to bit 31. Bits 21 and 1 are XORed with the value of bit 0. Bit 0 is also XORed with the value of bit 0.




// -------------------------  Whole Module -------------------------
module top_module(
	input clk,
	input reset,
	output reg [31:0] q);

	
	logic [31:0] q_next;
	always@(q) begin
		q_next = q[31:1];
		q_next[31] = q[0];
		q_next[21] ^= q[0];
		q_next[1] ^= q[0];
		q_next[0] ^= q[0];
	end
	
	always @(posedge clk) begin
		if (reset)
			q <= 32'h1;
		else
			q <= q_next;
	end
endmodule


// -------------------------  Testbench -------------------------
`timescale 1 ps/1 ps
`define OK 12
`define INCORRECT 13
module reference_module(
	input clk,
	input reset,
	output reg [31:0] q);
	
	logic [31:0] q_next;
	always@(q) begin
		q_next = q[31:1];
		q_next[31] = q[0];
		q_next[21] ^= q[0];
		q_next[1] ^= q[0];
		q_next[0] ^= q[0];
	end
	
	always @(posedge clk) begin
		if (reset)
			q <= 32'h1;
		else
			q <= q_next;
	end
endmodule


module stimulus_gen (
	input clk,
	output reg reset
);

	
	initial begin
		repeat(400) @(posedge clk, negedge clk) begin
			reset <= !($random & 31);
		end
		@(posedge clk) reset <= 1'b0;
		repeat(200000) @(posedge clk);
		reset <= 1'b1;
		repeat(5) @(posedge clk);
		#1 $finish;
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

	logic reset;
	logic [31:0] q_ref;
	logic [31:0] q_dut;

	initial begin 
		$dumpfile("wave.vcd");
		$dumpvars(1, stim1.clk, tb_mismatch ,clk,reset,q_ref,q_dut );
	end


	wire tb_match;		// Verification
	wire tb_mismatch = ~tb_match;
	
	stimulus_gen stim1 (
		.clk,
		.* ,
		.reset );
	reference_module good1 (
		.clk,
		.reset,
		.q(q_ref) );
		
	top_module top_module1 (
		.clk,
		.reset,
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

