`timescale 1ns / 1ps

/* 
----------------------------Descricao----------------------------------------------------------------------------------------
I2C
Read
    __    ___ ___ ___ ___ ___ ___ ___ __      ___ ___ ___ ___ ___ ___ ___ ___       _____
sda   \__/_6_X_5_X_4_X_3_X_2_X_1_X_0_\ R  A_/_7_X_6_X_5_X_4_X_3_X_2_X_1_X_0_\_A____/
    ____   _   _   _   _   _   _   _   _   _   _   _   _   _   _   _   _   _    _   _   _  
scl  ST \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ \__/ \_/ \_/ SP

Write
    __    ___ ___ ___ ___ ___ ___ ___            ___ ___ ___ ___ ___ ___ ___  __       ___ 
sda   \__/_6_X_5_X_4_X_3_X_2_X_1_X_0_/_ W__ \_A_/_7_X_6_X_5_X_4_X_3_X_2_X_1_X_0_\_A___/
    ____   _   _   _   _   _   _   _   _   _   _   _   _   _   _   _   _   _   _   _    _    
scl  ST \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ \__/ SP


- Modulo MASTER: O modulo MASTER ira enviar um endereco ao modulo SLAVE. 
Assim que o SLAVE receber esse endereco, ele verifica se o endereco pertence a ele. 
Se o endereco pertencer a ele(ADDRESS_SLAVE = ADDRESS ENVIADO PELO MODULO MASTER), 
o modulo SLAVE ira confirmar com um ACK colocando o SDA em nivel logico baixo. 
Senão, o modulo MASTER interrompera a transmissao. O modulo SLAVE confirmando com um ACK, o modulo MASTER
ira iniciar a transmissao dos dados. Apos o MASTER finalizar a transmissao dos dados, o modulo SLAVE 
precisa confirmar com um novo ACK o recebimentos desses dados e assim o modulo MASTER finaliza a trasnmissao.


---------------------------INPUT/OUTPUT---------------------------------------------------------------------------------------
- sda: canal SDA;
- slc: canal SCL;
- data_write_master: dados a ser enviado ao modulo SLAVE; 
- data_read_master : dados recebidos do modulo SLAVE;
- clk: clock;
- rst: reset;
- addr: endereco do modulo SLAVE que pretende acessar;
- enable: enable do sistema;
- rw: 1 para read e 0 para write;
- ready: terminou uma transmissao.
-----------------------------------------------------------------------------------------------------------------------------
*/


module i2c_master(
	input wire clk,
	input wire rst,
	input wire [6:0] addr,
	input wire [7:0] data_write_master,
	input wire enable,
	input wire rw,

	output reg [7:0] data_read_master,
	output wire ready,

	inout wire i2c_sda,
	inout wire i2c_scl
	);

    // Estados
	localparam STATE_IDLE = 0;
	localparam STATE_START = 1;
	localparam STATE_ADDRESS = 2;
	localparam STATE_READ_ACK = 3;
	localparam STATE_WRITE_DATA = 4;
	localparam STATE_WRITE_ACK = 5;
	localparam STATE_READ_DATA = 6;
	localparam STATE_READ_ACK2 = 7;
	localparam STATE_STOP = 8;
	
	localparam DIVIDE_BY = 4;

	reg [7:0] state;
	reg [7:0] save_addr;
	reg [7:0] save_data;
	reg [7:0] counter;
	reg [7:0] counter2 = 0;
	reg write_enable;
	reg sda_out;
	reg i2c_scl_enable = 0;
	reg i2c_clk = 1;

	assign ready = ((rst == 0) && (state == STATE_IDLE)) ? 1 : 0;
	assign i2c_scl = (i2c_scl_enable == 0 ) ? 1 : i2c_clk;
	assign i2c_sda = (write_enable == 1) ? sda_out : 'bz;
	
	always @(posedge clk) begin
		if (counter2 == (DIVIDE_BY/2) - 1) begin
			i2c_clk <= ~i2c_clk;
			counter2 <= 0;
		end
		else counter2 <= counter2 + 1;
	end 
	
	always @(negedge i2c_clk, posedge rst) begin
		if(rst == 1) begin
			i2c_scl_enable <= 0;
		end else begin
			if ((state == STATE_IDLE) || (state == STATE_START) || (state == STATE_STOP)) begin
				i2c_scl_enable <= 0; // Mantem o SCL em nivel logico alto nos estados IDLE,START e STOP
			end else begin
				i2c_scl_enable <= 1; 
			end
		end
	
	end


	always @(posedge i2c_clk, posedge rst) begin
		if(rst == 1) begin
			state <= STATE_IDLE; // Estado inicial da transmissao
		end		
		else begin
			case(state)
			
				STATE_IDLE: begin // Estado inicial
					if (enable) begin
						state <= STATE_START;
						save_addr <= {addr, rw}; // 'save_addr' recebe o addr a ser enviado ao SLAVE + o bit de write ou read
						save_data <= data_write_master; // dados a ser enviados
					end
					else state <= STATE_IDLE;
				end

				STATE_START: begin  // Inicia a transmissao
					counter <= 7;
					state <= STATE_ADDRESS;
				end

				STATE_ADDRESS: begin // Envia o endereco ao SLAVE
					if (counter == 0) begin 
						state <= STATE_READ_ACK;
					end else counter <= counter - 1;
				end

				STATE_READ_ACK: begin // Verifica se o SLAVE confirmou o recebimento do endereco, ou seja, se o SLAVE colocou SDA em nivelo logico baixo
					if (i2c_sda == 0) begin
						counter <= 7;
						if(save_addr[0] == 0) state <= STATE_WRITE_DATA;
						else state <= STATE_READ_DATA;
					end else state <= STATE_STOP; // Se o SLAVE nao confirmar com um ACK finaliza a transmissao
				end

				STATE_WRITE_DATA: begin // Envia os dados ao modulo SLAVE
					if(counter == 0) begin
						state <= STATE_READ_ACK2; 
					end else counter <= counter - 1;
				end
				
				STATE_READ_ACK2: begin // Verifica se o SLAVE confirmou o recebimento dos dados,ou seja, se o SLAVE colocou SDA em nivel logico baixo
					if ((i2c_sda == 0) && (enable == 1)) state <= STATE_IDLE;
					else state <= STATE_STOP;
				end

				STATE_READ_DATA: begin // Recebe os dados enviados pelo modulo SLAVE
					data_read_master[counter] <= i2c_sda;
					if (counter == 0) state <= STATE_WRITE_ACK;
					else counter <= counter - 1;
				end
				
				STATE_WRITE_ACK: begin // Confirma o recebimento dos dados ao modulo SLAVE
					state <= STATE_STOP;
				end

				STATE_STOP: begin // stop
					state <= STATE_IDLE;
				end
			endcase
		end
	end
	
	always @(negedge i2c_clk, posedge rst) begin
		if(rst == 1) begin
			write_enable <= 1;
			sda_out <= 1;
		end else begin
			case(state)
				
				STATE_START: begin // Inicia a transmissao
					write_enable <= 1;
					sda_out <= 0;
				end
				
				STATE_ADDRESS: begin
					write_enable <= 1;					
					sda_out <= save_addr[counter]; // Envia o endereco ao SLAVE
				end
				
				STATE_READ_ACK: begin // Verifica se o SLAVE confirmou o recebimento do endereco, ou seja, se o SLAVE colocou SDA em nivelo logico baixo
					write_enable <= 0;
				end
				
				STATE_WRITE_DATA: begin // Envia os dados ao modulo SLAVE
					write_enable <= 1;
					sda_out <= save_data[counter];
				end
				
				STATE_WRITE_ACK: begin // Confirma o recebimento dos dados ao modulo SLAVE
					write_enable <= 1;
					sda_out <= 0;
				end
				
				STATE_READ_DATA: begin // Recebe os dados enviados pelo modulo SLAVE
					write_enable <= 0;				
				end
				
				STATE_STOP: begin // stop
					write_enable <= 1;		
					sda_out <= 1;
				end
			endcase
		end
	end

endmodule
