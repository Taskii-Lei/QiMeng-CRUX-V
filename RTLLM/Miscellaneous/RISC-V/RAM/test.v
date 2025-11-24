module RAM (
	input clk,
	input rst_n,
	
	input write_en,
	input [7:0]write_addr,
	input [5:0]write_data,
	
	input read_en,
	input [7:0]read_addr,
	output reg [5:0]read_data
);
    
parameter WIDTH = 6;
parameter DEPTH = 8;
reg [WIDTH-1:0] RAM [DEPTH-1:0];
integer i;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        for (i = 0; i < DEPTH; i = i + 1) begin
            RAM[i] <= 6'b000000;
        end
    end
    else if (write_en) begin
        RAM[write_addr] <= write_data;
    end
end
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        read_data <= 6'b000000;
    end
    else if (read_en) begin
        read_data <= RAM[read_addr];
    end
end
endmodule

`timescale 1ns/1ns

module tb_RAM;

    // Parameters
    parameter CLK_PERIOD = 10; // Clock period in simulation time units
    
    // Inputs
    reg clk;
    reg rst_n;
    reg write_en;
    reg [7:0] write_addr;
    reg [5:0] write_data;
    reg read_en;
    reg [7:0] read_addr;
    
    // Outputs
    wire [5:0] read_data;

    // Instantiate the module
    RAM uut (
        .clk(clk),
        .rst_n(rst_n),
        .write_en(write_en),
        .write_addr(write_addr),
        .write_data(write_data),
        .read_en(read_en),
        .read_addr(read_addr),
        .read_data(read_data)
    );
    
    // Clock generation
    always #((CLK_PERIOD)/2) clk = ~clk;

    integer error = 0;
    // Initial block for stimulus generation
    initial begin
        // Initialize inputs
        clk = 0;
        rst_n = 1;
        repeat(100) begin
            write_en = 0;
            write_addr = 0;
            write_data = 0;
            read_en = 0;
            read_addr = 0;
            // Wait for a few clock cycles
            #((CLK_PERIOD) * 5);
            // Release reset
            rst_n = 0;
            #((CLK_PERIOD) * 2);
            rst_n = 1;
            // Write operation
            write_en = 1;
            write_addr = 3'b000;
            write_data = $random;
            #((CLK_PERIOD) * 1);
            write_en = 0;
            #((CLK_PERIOD) * 1);
            
            // Read operation
            read_en = 1;
            read_addr = 3'b000;
            #((CLK_PERIOD) * 1);
            // $display("read_data = %b", read_data); 
            error = (read_data == write_data) ? error : error+1;
            read_en = 0;
            #((CLK_PERIOD) * 1);
            // $display("read_data = %b", read_data); 
            error = (read_data == 0) ? error : error+1;
        end
        if (error == 0) begin
            $display("===========Your Design Passed===========");
        end
        else begin
        $display("===========Error===========", error);
        end
        // Finish simulation
        $finish;
    end

endmodule
