
// -------------------------  Description -------------------------
 This Verilog module is a 4-bit shift register. It has four ports: a clock input (clk), a reset input (resetn), an input (in) and an output (out). The clock input is used to synchronize the shift register, the reset input is used to reset the register to all zeros, the input is used to load data into the register and the output is used to read data from the register.  The module contains a 4-bit register (sr) which is used to store the data. The register is updated on the positive edge of the clock signal. When the resetn signal is low, the register is reset to all zeros. When the resetn signal is high, the register is shifted left by one bit and the input is loaded into the least significant bit. The output is taken from the most significant bit of the register.

// -------------------------  Whole Module -------------------------
module top_module (
	input clk,
	input resetn,
	input in,
	output out
);


	reg [3:0] sr;
	always @(posedge clk) begin
		if (~resetn)
			sr <= '0;
		else 
			sr <= {sr[2:0], in};
	end
	
	assign out = sr[3];
	

endmodule


// -------------------------  Testbench -------------------------
`timescale 1 ps/1 ps
`define OK 12
`define INCORRECT 13
module reference_module (
	input clk,
	input resetn,
	input in,
	output out
);

	reg [3:0] sr;
	always @(posedge clk) begin
		if (~resetn)
			sr <= '0;
		else 
			sr <= {sr[2:0], in};
	end
	
	assign out = sr[3];
	

endmodule


module stimulus_gen (
	input clk,
	output logic in, resetn
);

	initial begin
		repeat(100) @(posedge clk) begin
			in <= $random;
			resetn <= ($random & 7) != 0;
		end
		repeat(100) @(posedge clk, negedge clk) begin
			in <= $random;
			resetn <= ($random & 7) != 0;
		end
		
		#1 $finish;
	end
	
endmodule

module tb();

	typedef struct packed {
		int errors;
		int errortime;
		int errors_out;
		int errortime_out;

		int clocks;
	} stats;
	
	stats stats1;
	
	
	wire[511:0] wavedrom_title;
	wire wavedrom_enable;
	int wavedrom_hide_after_time;
	
	reg clk=0;
	initial forever
		#5 clk = ~clk;

	logic resetn;
	logic in;
	logic out_ref;
	logic out_dut;

	initial begin 
		$dumpfile("wave.vcd");
		$dumpvars(1, stim1.clk, tb_mismatch ,clk,resetn,in,out_ref,out_dut );
	end


	wire tb_match;		// Verification
	wire tb_mismatch = ~tb_match;
	
	stimulus_gen stim1 (
		.clk,
		.* ,
		.resetn,
		.in );
	reference_module good1 (
		.clk,
		.resetn,
		.in,
		.out(out_ref) );
		
	top_module top_module1 (
		.clk,
		.resetn,
		.in,
		.out(out_dut) );

	
	bit strobe = 0;
	task wait_for_end_of_timestep;
		repeat(5) begin
			strobe <= !strobe;  // Try to delay until the very end of the time step.
			@(strobe);
		end
	endtask	

	
	final begin
		if (stats1.errors_out) $display("Hint: Output '%s' has %0d mismatches. First mismatch occurred at time %0d.", "out", stats1.errors_out, stats1.errortime_out);
		else $display("Hint: Output '%s' has no mismatches.", "out");

		$display("Hint: Total mismatched samples is %1d out of %1d samples\n", stats1.errors, stats1.clocks);
		$display("Simulation finished at %0d ps", $time);
		$display("Mismatches: %1d in %1d samples", stats1.errors, stats1.clocks);
	end
	
	// Verification: XORs on the right makes any X in good_vector match anything, but X in dut_vector will only match X.
	assign tb_match = ( { out_ref } === ( { out_ref } ^ { out_dut } ^ { out_ref } ) );
	// Use explicit sensitivity list here. @(*) causes NetProc::nex_input() to be called when trying to compute
	// the sensitivity list of the @(strobe) process, which isn't implemented.
	always @(posedge clk, negedge clk) begin

		stats1.clocks++;
		if (!tb_match) begin
			if (stats1.errors == 0) stats1.errortime = $time;
			stats1.errors++;
		end
		if (out_ref !== ( out_ref ^ out_dut ^ out_ref ))
		begin if (stats1.errors_out == 0) stats1.errortime_out = $time;
			stats1.errors_out = stats1.errors_out+1'b1; end

	end
endmodule

