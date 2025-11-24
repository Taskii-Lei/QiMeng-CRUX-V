
// -------------------------  Description -------------------------
 This Verilog module is a top-level module that controls the ringer and motor of a device. It has four ports: two inputs (ring and vibrate_mode) and two outputs (ringer and motor).   The ring input is a signal that is used to indicate when the device should be ringing or vibrating. The vibrate_mode input is a signal that indicates whether the device should be ringing or vibrating.   The ringer output is a signal that is used to control the ringer of the device. It is set to 1 when the device should be ringing and 0 when it should not be ringing. The motor output is a signal that is used to control the motor of the device. It is set to 1 when the device should be vibrating and 0 when it should not be vibrating.   The module uses two assign statements to control the ringer and motor outputs. The first assign statement sets the ringer output to the logical AND of the ring and the logical NOT of the vibrate_mode inputs. This means that the ringer output will be set to 1 when the ring input is 1 and the vibrate_mode input is 0, and it will be set to 0 otherwise.   The second assign statement sets the motor output to the logical AND of the ring and the vibrate_mode inputs. This means that the motor output will be set to 1 when both the ring input and the vibrate_mode input are 1, and it will be set to 0 otherwise.   This module is used to control the ringer and motor of a device based on the ring and vibrate_mode inputs. When the ring input is 1 and the vibrate_mode input is 0, the ringer output will be set to 1 and the motor output will be set to 0. When the ring input is 1 and the vibrate_mode input is 1, the ringer output will be set to 0 and the motor output will be set to 1.

// -------------------------  Whole Module -------------------------
module top_module(
	input ring, 
	input vibrate_mode,
	output ringer,
	output motor
);

	
	assign ringer = ring & ~vibrate_mode;
	assign motor = ring & vibrate_mode;
	
endmodule


// -------------------------  Testbench -------------------------
`timescale 1 ps/1 ps
`define OK 12
`define INCORRECT 13
module reference_module(
	input ring, 
	input vibrate_mode,
	output ringer,
	output motor
);
	
	assign ringer = ring & ~vibrate_mode;
	assign motor = ring & vibrate_mode;
	
endmodule


module stimulus_gen (
	input clk,
	output reg ring, vibrate_mode,
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
		{vibrate_mode,ring} <= 1'b0;
		wavedrom_start();
		repeat(10) @(posedge clk)
			{vibrate_mode,ring} <= count++;		
		wavedrom_stop();
		
		#1 $finish;
	end
	
endmodule

module tb();

	typedef struct packed {
		int errors;
		int errortime;
		int errors_ringer;
		int errortime_ringer;
		int errors_motor;
		int errortime_motor;

		int clocks;
	} stats;
	
	stats stats1;
	
	
	wire[511:0] wavedrom_title;
	wire wavedrom_enable;
	int wavedrom_hide_after_time;
	
	reg clk=0;
	initial forever
		#5 clk = ~clk;

	logic ring;
	logic vibrate_mode;
	logic ringer_ref;
	logic ringer_dut;
	logic motor_ref;
	logic motor_dut;

	initial begin 
		$dumpfile("wave.vcd");
		$dumpvars(1, stim1.clk, tb_mismatch ,ring,vibrate_mode,ringer_ref,ringer_dut,motor_ref,motor_dut );
	end


	wire tb_match;		// Verification
	wire tb_mismatch = ~tb_match;
	
	stimulus_gen stim1 (
		.clk,
		.* ,
		.ring,
		.vibrate_mode );
	reference_module good1 (
		.ring,
		.vibrate_mode,
		.ringer(ringer_ref),
		.motor(motor_ref) );
		
	top_module top_module1 (
		.ring,
		.vibrate_mode,
		.ringer(ringer_dut),
		.motor(motor_dut) );

	
	bit strobe = 0;
	task wait_for_end_of_timestep;
		repeat(5) begin
			strobe <= !strobe;  // Try to delay until the very end of the time step.
			@(strobe);
		end
	endtask	

	
	final begin
		if (stats1.errors_ringer) $display("Hint: Output '%s' has %0d mismatches. First mismatch occurred at time %0d.", "ringer", stats1.errors_ringer, stats1.errortime_ringer);
		else $display("Hint: Output '%s' has no mismatches.", "ringer");
		if (stats1.errors_motor) $display("Hint: Output '%s' has %0d mismatches. First mismatch occurred at time %0d.", "motor", stats1.errors_motor, stats1.errortime_motor);
		else $display("Hint: Output '%s' has no mismatches.", "motor");

		$display("Hint: Total mismatched samples is %1d out of %1d samples\n", stats1.errors, stats1.clocks);
		$display("Simulation finished at %0d ps", $time);
		$display("Mismatches: %1d in %1d samples", stats1.errors, stats1.clocks);
	end
	
	// Verification: XORs on the right makes any X in good_vector match anything, but X in dut_vector will only match X.
	assign tb_match = ( { ringer_ref, motor_ref } === ( { ringer_ref, motor_ref } ^ { ringer_dut, motor_dut } ^ { ringer_ref, motor_ref } ) );
	// Use explicit sensitivity list here. @(*) causes NetProc::nex_input() to be called when trying to compute
	// the sensitivity list of the @(strobe) process, which isn't implemented.
	always @(posedge clk, negedge clk) begin

		stats1.clocks++;
		if (!tb_match) begin
			if (stats1.errors == 0) stats1.errortime = $time;
			stats1.errors++;
		end
		if (ringer_ref !== ( ringer_ref ^ ringer_dut ^ ringer_ref ))
		begin if (stats1.errors_ringer == 0) stats1.errortime_ringer = $time;
			stats1.errors_ringer = stats1.errors_ringer+1'b1; end
		if (motor_ref !== ( motor_ref ^ motor_dut ^ motor_ref ))
		begin if (stats1.errors_motor == 0) stats1.errortime_motor = $time;
			stats1.errors_motor = stats1.errors_motor+1'b1; end

	end
endmodule

