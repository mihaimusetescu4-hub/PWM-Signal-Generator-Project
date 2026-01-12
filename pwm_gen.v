module pwm_gen (
    // peripheral clock signals
    input clk, // Main clock (synchronous domain)
    input rst_n, // Asynchronous reset
    
    // PWM signal register configuration
    input pwm_en, // Global PWM Output Enable flag
    input[15:0] period, // The maximum count value (N) - defines the PWM frequency
    input[7:0] functions, // Control register containing the operating mode bits
    input[15:0] compare1, // 1st 16-bits compare value (Duty Cycle 1/Rising Edge)
    input[15:0] compare2, // 2nd 16-bits compare value (Duty Cycle 2/Falling Edge or Dual)
    input[15:0] count_val, // The current, running count from the counter module
    
    // top facing signals
    output pwm_out // The final PWM output signal driven to the physical pin
);

// Internal state register for the PWM output
reg r_pwm_out;
assign pwm_out = (rst_n && pwm_en) ? r_pwm_out : 1'b0;t;

// Wire declarations for internal clarity
// wire compare1_match = (count_val >= compare1); // Check if counter has reached or passed Compare1
// wire compare2_match = (count_val >= compare2); // Check if counter has reached or passed Compare2
wire [1:0] function_mode = functions[1:0]; // Extract the 2-bit mode selector from the functions register

// SEQUENTIAL LOGIC BLOCK
// This block determines the state of the PWM output pin (r_pwm_out) synchronously
// The output state is updated on every clock edge, based on the current count_val

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        r_pwm_out <= 1'b0; // Reset: Output is forced low (safe state)
    end
    
    // If PWM is disabled (from regs.v), force the output low, regardless of the count
    else if (!pwm_en) begin
        r_pwm_out <= 1'b0; 
    end
    
    // PWM Generation Logic (Mode Selection)
    else begin
        case (function_mode)
            
            // MODE 00: ALIGN LEFT
            2'b00: begin
                if(compare1 != 16'd0)
                    r_pwm_out <= (count_val <= compare1);
                else
                    r_pwm_out <= 1'b0;
            end

            // MODE 01: ALIGN RIGHT
            // Pulse starts at 0 and ends when count hits compare1.
            // Duty Cycle = (Compare1 / Period)
            
            2'b01: begin
                if (count_val >= compare1) begin
                    r_pwm_out <= 1'b1; // Output HIGH during the pulse duration
                end
                else begin
                    r_pwm_out <= 1'b0; // Output LOW after the comparison match
                end
            end

            // MODE 10: UNALIGNED / DUAL COMPARE
            // Pulse is LOW when the counter is below C1, and HIGH otherwise
            // This is the logical inverse of Mode 01
            
            2'b10: begin
                if (compare1 < compare2) begin
                    r_pwm_out <= (count_val >= compare1) && (count_val <  compare2); // Output LOW during the pulse duration
                end
                else begin
                    r_pwm_out <= 1'b0; // Output HIGH after the comparison match
                end
            end
            
            default: r_pwm_out <= 1'b0; // Safety default
        endcase
    end
end

endmodule
