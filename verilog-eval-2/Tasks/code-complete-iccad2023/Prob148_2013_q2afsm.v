
// -------------------------  Description -------------------------
Consider the FSM described by the state diagram shown below:

  A --r1=0,r2=0,r3=0--> A
  A --r1=1--> B
  A --r1=0,r2=1--> C
  A --r1=0,r2=0,r3=0--> D
  B (g1=1) --r1=1--> B
  B (g1=1) --r1=0--> A
  C (g2=1) --r2=1--> C
  C (g2=1) --r2=0--> A

Resetn is an active-low synchronous reset that resets into state A. This FSM acts as an arbiter circuit, which controls access to some type of resource by three requesting devices. Each device makes its request for the resource by setting a signal _r[i]_ = 1, where _r[i]_ is either _r[1]_, _r[2]_, or _r[3]_. Each r[i] is an input signal to the FSM, and represents one of the three devices. The FSM stays in state _A_ as long as there are no requests. When one or more request occurs, then the FSM decides which device receives a grant to use the resource and changes to a state that sets that device's _g[i]_ signal to 1. Each _g[i]_ is an output from the FSM. There is a priority system, in that device 1 has a higher priority than device 2, and device 3 has the lowest priority. Hence, for example, device 3 will only receive a grant if it is the only device making a request when the FSM is in state _A_. Once a device, _i_, is given a grant by the FSM, that device continues to receive the grant as long as its request, _r[i]_ = 1.

Write complete Verilog code that represents this FSM. Use separate always blocks for the state table and the state flip-flops, as done in lectures. Describe the FSM outputs, _g[i]_, using either continuous assignment statement(s) or an always block (at your discretion). Assign any state codes that you wish to use.ß

module TopModule (
  input clk,
  input resetn,
  input [3:1] r,
  output [3:1] g
);

// -------------------------  Referred Module -------------------------
module RefModule (
  input clk,
  input resetn,
  input [3:1] r,
  output [3:1] g
);

  parameter A=0, B=1, C=2, D=3;
  reg [1:0] state, next;

  always @(posedge clk) begin
    if (~resetn) state <= A;
    else state <= next;
  end

  always@(state,r) begin
    case (state)
      A: if (r[1]) next = B;
         else if (r[2]) next = C;
         else if (r[3]) next = D;
         else next = A;
      B: next = r[1] ? B : A;
      C: next = r[2] ? C : A;
      D: next = r[3] ? D : A;
      default: next = 'x;
    endcase
  end

  assign g[1] = (state == B);
  assign g[2] = (state == C);
  assign g[3] = (state == D);

endmodule

// -------------------------  Testbench -------------------------
`timescale 1 ps/1 ps
`define OK 12
`define INCORRECT 13


module stimulus_gen (
	input clk,
	output logic resetn,
	output logic [3:1] r,
	output reg[511:0] wavedrom_title,
	output reg wavedrom_enable,
	input tb_match
);
	reg reset;
	assign resetn = ~reset;

	task reset_test(input async=0);
		bit arfail, srfail, datafail;
	
		@(posedge clk);
		@(posedge clk) reset <= 0;
		repeat(3) @(posedge clk);
	
		@(negedge clk) begin datafail = !tb_match ; reset <= 1; end
		@(posedge clk) arfail = !tb_match;
		@(posedge clk) begin
			srfail = !tb_match;
			reset <= 0;
		end
		if (srfail)
			$display("Hint: Your reset doesn't seem to be working.");
		else if (arfail && (async || !datafail))
			$display("Hint: Your reset should be %0s, but doesn't appear to be.", async ? "asynchronous" : "synchronous");
		// Don't warn about synchronous reset if the half-cycle before is already wrong. It's more likely
		// a functionality error than the reset being implemented asynchronously.
	
	endtask


// Add two ports to module stimulus_gen:
//    output [511:0] wavedrom_title
//    output reg wavedrom_enable

	task wavedrom_start(input[511:0] title = "");
	endtask
	
	task wavedrom_stop;
		#1;
	endtask	


	
	initial begin
		reset <= 1;
		r <= 0;
		@(posedge clk);
		
		r <= 1;
		reset_test();
		
		r <= 0;
		wavedrom_start("");
		@(posedge clk) r <= 0;
		@(posedge clk) r <= 7;
		@(posedge clk) r <= 7;
		@(posedge clk) r <= 7;
		@(posedge clk) r <= 6;
		@(posedge clk) r <= 6;
		@(posedge clk) r <= 6;
		@(posedge clk) r <= 4;
		@(posedge clk) r <= 4;
		@(posedge clk) r <= 4;
		@(posedge clk) r <= 0;
		@(posedge clk) r <= 0;
		@(posedge clk) r <= 4;
		@(posedge clk) r <= 6;
		@(posedge clk) r <= 7;
		@(posedge clk) r <= 7;
		@(posedge clk) r <= 7;
		@(negedge clk);
		wavedrom_stop();
		
		@(posedge clk);
		reset <= 0;
		@(posedge clk);
		@(posedge clk);
		
		repeat(500) @(negedge clk) begin
			reset <= ($random & 63) == 0;
			r <= $random;
		end
		
		#1 $finish;
	end
	
endmodule

module tb();

	typedef struct packed {
		int errors;
		int errortime;
		int errors_g;
		int errortime_g;

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
	logic [3:1] r;
	logic [3:1] g_ref;
	logic [3:1] g_dut;

	initial begin 
		$dumpfile("wave.vcd");
		$dumpvars(1, stim1.clk, tb_mismatch ,clk,resetn,r,g_ref,g_dut );
	end


	wire tb_match;		// Verification
	wire tb_mismatch = ~tb_match;
	
	stimulus_gen stim1 (
		.clk,
		.* ,
		.resetn,
		.r );
	RefModule good1 (
		.clk,
		.resetn,
		.r,
		.g(g_ref) );
		
	TopModule top_module1 (
		.clk,
		.resetn,
		.r,
		.g(g_dut) );

	
	bit strobe = 0;
	task wait_for_end_of_timestep;
		repeat(5) begin
			strobe <= !strobe;  // Try to delay until the very end of the time step.
			@(strobe);
		end
	endtask	

	
	final begin
		if (stats1.errors_g) $display("Hint: Output '%s' has %0d mismatches. First mismatch occurred at time %0d.", "g", stats1.errors_g, stats1.errortime_g);
		else $display("Hint: Output '%s' has no mismatches.", "g");

		$display("Hint: Total mismatched samples is %1d out of %1d samples\n", stats1.errors, stats1.clocks);
		$display("Simulation finished at %0d ps", $time);
		$display("Mismatches: %1d in %1d samples", stats1.errors, stats1.clocks);
	end
	
	// Verification: XORs on the right makes any X in good_vector match anything, but X in dut_vector will only match X.
	assign tb_match = ( { g_ref } === ( { g_ref } ^ { g_dut } ^ { g_ref } ) );
	// Use explicit sensitivity list here. @(*) causes NetProc::nex_input() to be called when trying to compute
	// the sensitivity list of the @(strobe) process, which isn't implemented.
	always @(posedge clk, negedge clk) begin

		stats1.clocks++;
		if (!tb_match) begin
			if (stats1.errors == 0) stats1.errortime = $time;
			stats1.errors++;
		end
		if (g_ref !== ( g_ref ^ g_dut ^ g_ref ))
		begin if (stats1.errors_g == 0) stats1.errortime_g = $time;
			stats1.errors_g = stats1.errors_g+1'b1; end

	end

   // add timeout after 100K cycles
   initial begin
     #1000000
     $display("TIMEOUT");
     $finish();
   end

endmodule
