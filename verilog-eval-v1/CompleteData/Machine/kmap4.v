
// -------------------------  Description -------------------------
 This Verilog module is a combinational logic circuit that takes four binary inputs (a, b, c, and d) and produces one binary output (out). The output is determined by the combination of the four inputs. The module uses a case statement to determine the output based on the combination of the four inputs.   For example, if the inputs a, b, c, and d are all 0, then the output out is 0. If the inputs a, b, c, and d are all 1, then the output out is 1. Similarly, if the inputs a, b, c, and d are 0, 1, 0, and 1 respectively, then the output out is 0. The module will produce the same output for any combination of the four inputs.   The module is implemented using an always block with a case statement. The case statement is used to map the four input combinations to the corresponding output. The inputs are combined into a 4-bit vector and used as the case statement selector. The output is assigned to the corresponding case statement.   The module is used to implement a combinational logic circuit. It is used to produce a single output based on the combination of four binary inputs.

// -------------------------  Whole Module -------------------------
module top_module (
	input a, 
	input b,
	input c,
	input d,
	output reg out
);

	
    always @(*) begin
        case({a,b,c,d})
            4'h0: out = 0;
            4'h1: out = 1;
            4'h3: out = 0;
            4'h2: out = 1;
            4'h4: out = 1;
            4'h5: out = 0;
            4'h7: out = 1;
            4'h6: out = 0;
            4'hc: out = 0;
            4'hd: out = 1;
            4'hf: out = 0;
            4'he: out = 1;
            4'h8: out = 1;
            4'h9: out = 0;
            4'hb: out = 1;
            4'ha: out = 0;
        endcase
    end
endmodule


// -------------------------  Testbench -------------------------
`timescale 1 ps/1 ps
`define OK 12
`define INCORRECT 13
module reference_module (
	input a, 
	input b,
	input c,
	input d,
	output reg out
);
	
    always @(*) begin
        case({a,b,c,d})
            4'h0: out = 0;
            4'h1: out = 1;
            4'h3: out = 0;
            4'h2: out = 1;
            4'h4: out = 1;
            4'h5: out = 0;
            4'h7: out = 1;
            4'h6: out = 0;
            4'hc: out = 0;
            4'hd: out = 1;
            4'hf: out = 0;
            4'he: out = 1;
            4'h8: out = 1;
            4'h9: out = 0;
            4'hb: out = 1;
            4'ha: out = 0;
        endcase
    end
endmodule


module stimulus_gen (
	input clk,
	output reg a, b, c, d,
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
		int count; count = 0;
		{a,b,c,d} <= 4'b0;
		wavedrom_start();
		repeat(16) @(posedge clk)
			{a,b,c,d} <= count++;		
		@(negedge clk) wavedrom_stop();
		
		repeat(200) @(posedge clk, negedge clk)
			{d,c,b,a} <= $urandom;
			
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

	logic a;
	logic b;
	logic c;
	logic d;
	logic out_ref;
	logic out_dut;

	initial begin 
		$dumpfile("wave.vcd");
		$dumpvars(1, stim1.clk, tb_mismatch ,a,b,c,d,out_ref,out_dut );
	end


	wire tb_match;		// Verification
	wire tb_mismatch = ~tb_match;
	
	stimulus_gen stim1 (
		.clk,
		.* ,
		.a,
		.b,
		.c,
		.d );
	reference_module good1 (
		.a,
		.b,
		.c,
		.d,
		.out(out_ref) );
		
	top_module top_module1 (
		.a,
		.b,
		.c,
		.d,
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

