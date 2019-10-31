`timescale 1ns / 1ps

/* 
----------------------------Descricao-------------------------------------------------------------------------
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

- Modulo SLAVE: O modulo MASTER ira enviar um endereco ao modulo SLAVE. 
Assim que o SLAVE receber esse endereco, ele verifica se o endereco pertence a ele. 
Se o endereco pertencer a ele(ADDRESS_SLAVE = ADDRESS ENVIADO PELO MODULO MASTER), 
o modulo SLAVE ira confirmar com um ACK colocando o SDA em nivel logico baixo. 
Senão, o modulo MASTER interrompera a transmissao. O modulo SLAVE confirmando com um ACK, o modulo MASTER
ira iniciar a transmissao dos dados. Apos o MASTER finalizar a transmissao dos dados, o modulo SLAVE 
precisa confirmar com um novo ACK o recebimentos desses dados e assim o modulo MASTER finaliza a trasnmissao.

---------------------------INPUT/OUTPUT-----------------------------------------------------------------------
- sda: canal SDA;
- slc: canal SCL;
- data_write_slave: dados a ser enviado ao modulo MASTER;
- data_read_slave : dados recebidos do modulo MASTER.
--------------------------------------------------------------------------------------------------------------
*/


module i2c_slave(
	inout  wire sda,              
	inout  wire scl,               
    	input  wire [7:0] data_write_slave,  
    	output reg [7:0] data_read_slave    
	);
	
    localparam ADDRESS_SLAVE = 7'b1010101; // Address do modulo SLAVE(Endereco que identifica esse modulo SLAVE)    
    
    // Estados
	localparam STATE_READ_ADDR = 0; 
	localparam STATE_SEND_ACK = 1;
	localparam STATE_READ_DATA = 2;
	localparam STATE_WRITE_DATA = 3;
	localparam STATE_SEND_ACK2 = 4;
	
	reg [7:0] addr;
	reg [7:0] counter;
	reg [7:0] state = 0;
	reg sda_out = 0;
	reg sda_in = 0;
	reg start = 0;
	reg write_enable = 0;
	
	assign sda = (write_enable == 1) ? sda_out : 'bz;
	
	always @(negedge sda) begin // Modulo MASTER start transmissao.
		if ((start == 0) && (scl == 1)) begin
			start <= 1;	
			counter <= 7;
		end
	end
	
	always @(posedge sda) begin 
		if ((start == 1) && (scl == 1)) begin
			state <= STATE_READ_ADDR;
			start <= 0;
			write_enable <= 0;
		end
	end
	
	always @(posedge scl) begin
		if (start == 1) begin
			case(state)
				STATE_READ_ADDR: begin  // Ira efetuar a leitura do endereco enviado pelo modulo MASTER
					addr[counter] <= sda;
					if(counter == 0) state <= STATE_SEND_ACK;
					else counter <= counter - 1;					
				end
				
				STATE_SEND_ACK: begin   // Verificara se o endereco enviado pelo MASTER corresponde a esse SLAVE
					if(addr[7:1] == ADDRESS_SLAVE) begin
						counter <= 7;
						if(addr[0] == 0) begin // Verificara se o MASTER esta tentando efetuar uma leitura ou escrita
							state <= STATE_READ_DATA;
						end
						else state <= STATE_WRITE_DATA;
					end
				end
				
				STATE_READ_DATA: begin  // Ira ler os dados enviado pelo modulo MASTER no barramento SDA
					data_read_slave[counter] <= sda;
					if(counter == 0) begin
						state <= STATE_SEND_ACK2;
					end else counter <= counter - 1;
				end
				
				STATE_SEND_ACK2: begin // Enviara um ack confirmando o recebimento dos dados
					state <= STATE_READ_ADDR;					
				end
				
				STATE_WRITE_DATA: begin // Ira escrever os dados no barramento SDA
					if(counter == 0) state <= STATE_READ_ADDR;
					else counter <= counter - 1;		
				end
				
			endcase
		end
	end
	
	always @(negedge scl) begin
		case(state)
			
			STATE_READ_ADDR: begin // Leitura do endereco enviado pelo MASTER
				write_enable <= 0; // Mantem o barramento em z para recebimento dos dados 			
			end
			
			STATE_SEND_ACK: begin // Envia um ACK(SDA = 0) para o MASTER confirmando o recebimento 
				sda_out <= 0;     
				write_enable <= 1;	
			end
			
			STATE_READ_DATA: begin // Mantem o barramento em z para recebimento dos dados
				write_enable <= 0;
			end
			
			STATE_WRITE_DATA: begin // Envia os dados de 'data_write' ao modulo MASTER
				sda_out <= data_write_slave[counter];
				write_enable <= 1; // Ativa a saida SDA para envio dos dados
			end
			
			STATE_SEND_ACK2: begin // Envia um ACK(SDA = 0) para o MASTER confirmando o recebimento
				sda_out <= 0;
				write_enable <= 1;
			end
		endcase
	end
endmodule
