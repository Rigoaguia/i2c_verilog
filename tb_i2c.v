`timescale 1ns / 1ps

// Testbench I2C

module tb_i2c;
    
    	// Inputs
	reg clk;
	reg rst;
	reg [6:0] addr;
	reg [7:0] data_write_master;
    	reg [7:0] data_write_slave;
	reg enable;
	reg rw;

	// Outputs
	wire [7:0] data_read_master;
    	wire [7:0] data_read_slave;
	wire ready;
    
    	//Inout
	wire i2c_sda;
	wire i2c_scl;
    
    	wire data_read;
  
  	i2c_master i2c_master2(
  		.clk(clk), 
		.rst(rst), 
		.addr(addr), 
		.data_write_master(data_write_master), 
		.enable(enable), 
		.rw(rw), 
		.data_read_master(data_read_master), 
		.ready(ready), 
		.i2c_sda(i2c_sda), 
		.i2c_scl(i2c_scl)
  	);
    	i2c_slave slave (
        	.sda(i2c_sda), 
        	.scl(i2c_scl),
        	.data_write_slave(data_write_slave),
        	.data_read_slave(data_read_slave)
    	);
  
  	initial begin
    	//$dumpfile("dump.vcd");
   		//$dumpvars(1,tb_i2c);

		clk = 0;
		rst = 1;

		#100; 

		rst = 0;		
		addr = 7'b1010101; // Endereco do modulo SLAVE
		data_write_master = 8'b10101010; // Dados a ser enviado pelo modulo MASTER
		data_write_slave = 8'b00101001; // Dados a ser lido pelo modulo SLAVE
		rw = 0;	// write(0) e read(1)
		//rw = 1; 
		enable = 1; // enable do modulo MASTER
		
		#100;
		enable = 0;
		
		#5000
		$finish;
    
 	end
  
  	always #5 clk = ~clk;
  
endmodule
