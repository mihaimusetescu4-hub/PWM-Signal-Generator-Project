module regs (
    // peripheral clock signals
    input clk, // Main clock (synchronous domain for all logic)
    input rst_n, // Asynchronous reset
    // decoder facing signals
    input read, // Pulse indicating a read transaction is active
    input write, // Pulse indicating a write transaction is active
    input[5:0] addr, // 6-bit address + High/Low bit (addr[5])
    output[7:0] data_read, // 8-bit data sent back to the SPI Master
    input[7:0] data_write, // 8-bit data received from the SPI Master
    // counter programming signals
    input[15:0] counter_val, // Current value of the counter (used for readbacks)
    output[15:0] period, // N value for the counter's rollover (16-bit)
    output en, // Enable/Disable the counter
    output count_reset, // One-cycle pulse to force counter reset
    output upnotdown, // Direction control: 1=Up, 0=Down
    output[7:0] prescale, // Prescaler value for clock division
    // PWM signal programming values
    output pwm_en, // Enable/Disable the PWM generator output
    output[7:0] functions, // 2-bit PWM mode selection (Normal, Inverse, Dual)
    output[15:0] compare1, // 1st 16-bit compare value (Duty Cycle 1)
    output[15:0] compare2 // 2nd 16-bit compare value (Duty Cycle 2 / Dual mode)
);


/*
    All registers that appear in this block should be similar to this. Please try to abide
    to sizes as specified in the architecture documentation.
*/

// Internal Register Storage (r_prefix)
// These are the actual registers (D-FF based) that hold the configuration values

reg [15:0] r_period;
reg [0:0]  r_count_en;
reg [15:0] r_compare1;
reg [15:0] r_compare2;
reg [0:0]  r_upnotdown;
reg [7:0]  r_prescale;
reg [0:0]  r_pwm_en;
reg [1:0]  r_functions;

// Combinational assignment: Connect internal registers to module outputs
// This is the "read-port" for other modules (counter, pwm_gen)

assign period    = r_period;
assign en  = r_count_en;
assign upnotdown = r_upnotdown;
assign prescale  = r_prescale;
assign pwm_en    = r_pwm_en;
assign functions = r_functions;
assign compare1  = r_compare1;
assign compare2  = r_compare2;

// The High/Low bit is important for handling 16-bit registers over an 8-bit bus
// It comes from addr[5] in our instruction mapping
wire hl_bit = addr[5];

// Special register for the one-shot reset pulse (COUNT_RESET)
reg r_count_reset_flag;

// Connects the flag to the output pin
assign count_reset = r_count_reset_flag;

// SEQUENTIAL LOGIC BLOCK
always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
	// Initialize all registers to a safe, known state
        r_period <= 16'h0000;
	r_compare1  <= 16'h0000;
        r_compare2  <= 16'h0000;
        r_prescale  <= 8'h00;
        r_count_en  <= 1'b0; // Counter disabled by default
        r_upnotdown <= 1'b1;
        r_pwm_en    <= 1'b0; // PWM output disabled
        r_functions <= 2'b00;
        r_count_reset_flag <= 1'b0; // Reset flag cleared
    end
    else begin
        // Here should be the rest of the implementation
	r_count_reset_flag <= 1'b0; // Always clear the count_reset flag at the start of the clock cycle

	// Write Logic: Only execute register updates if the decoder asserted the 'write' signal
	if(write) begin
	    // Use only addr[4:0] for the register index; addr[5] is the High/Low byte selector
            case (addr[4:0])

		// 16-BITS REGISTER: PERIOD (ADDR 0x00)
                5'h00: begin
                    if (hl_bit == 1'b0)
                        r_period[7:0] <= data_write; // Write to Low Byte (LSB)
                    else
                        r_period[15:8] <= data_write; // Write to High Byte (MSB)
                end
                
		// 1-BIT REGISTER: COUNT_EN (ADDR 0x02)
                5'h02: r_count_en <= data_write[0];  // Only need the LSB for 1-bit flags
                
		// 16-BITS REGISTER: COMPARE1 (ADDR 0x03)
                5'h03: begin
                    if (hl_bit == 1'b0)
                        r_compare1[7:0] <= data_write;
                    else
                        r_compare1[15:8] <= data_write;
                end
                
		// 16-BITS REGISTER: COMPARE2 (ADDR 0x05)
                5'h05: begin
                    if (hl_bit == 1'b0)    
                        r_compare2[7:0] <= data_write;
                    else                  
                        r_compare2[15:8] <= data_write;
                end

		// COMMAND REGISTER: COUNT_RESET (ADDR 0x07)
		5'h07: begin
		    // This is a special command register: writing to it triggers the one-shot reset pulse
                    r_count_reset_flag <= 1'b1; 
                end
                
		// 8-BITS REGISTER: PRESCALE (ADDR 0x0A)
                5'h0A: r_prescale <= data_write;
                
		// 1-BIT REGISTER: UPNOTDOWN (ADDR 0x0B)
                5'h0B: r_upnotdown <= data_write[0];
                
		// 1-BIT REGISTER: PWM_EN (ADDR 0x0C)
                5'h0C: r_pwm_en <= data_write[0];
                
		// 2-BITS REGISTER: FUNCTIONS (ADDR 0x0D)
                5'h0D: r_functions <= data_write[1:0];
                
                default: ;
            endcase
        end
    end
end

// COMBINATIONAL LOGIC BLOCK (Read/MISO Data)
// This block determines what data to put on the MISO line (data_read) for the master
// It is combinational because the master needs the data immediately when 'read' is asserted

always @(*) begin
    data_read = 8'h00; // Default value if no read is active or address is invalid

    if(read) begin
	// Similar address decoding, but now for read operations
        case (addr[4:0])
            // READ PERIOD (ADDR 0x00)
            5'h00: begin
                if (hl_bit == 1'b0) 
                    data_read = r_period[7:0]; // Read Low Byte
                else
                    data_read = r_period[15:8]; // Read High Byte
            end

	    // READ COUNT_EN (ADDR 0x02)
            5'h02: data_read = {7'b0, r_count_en}; // Pad 1-bit value to 8 bits
            
	    // READ COMPARE1 (ADDR 0x03)
            5'h03: begin
                if (hl_bit == 1'b0)
                    data_read = r_compare1[7:0];
                else 
                    data_read = r_compare1[15:8];
            end
            
	    // READ COMPARE2 (ADDR 0x05)
            5'h05: begin
                if (hl_bit == 1'b0) 
                    data_read = r_compare2[7:0];
                else          
                    data_read = r_compare2[15:8];
            end
            
	    // READ COUNTER_VAL (ADDR 0x08)
            5'h08: begin
                if (hl_bit == 1'b0)
                    data_read = counter_val[7:0]; // Read Low Byte of the current counter state
                else       
                    data_read = counter_val[15:8]; // Read High Byte of the current counter state
            end
            
	    // READ PRESCALE (ADDR 0x0A)
            5'h0A: data_read = r_prescale;

            // READ UPNOTDOWN (ADDR 0x0B)
            5'h0B: data_read = {7'b0, r_upnotdown};

            // READ PWM_EN (ADDR 0x0C)
            5'h0C: data_read = {7'b0, r_pwm_en};

            // READ FUNCTIONS (ADDR 0x0D)
            5'h0D: data_read = {6'b0, r_functions};
            
            default: data_read = 8'hFF; // Reserved/unmapped address reads back 0xFF (Error indication)
        endcase
    end
end

endmodule