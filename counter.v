module counter (
    // peripheral clock signals
    input clk, // Main clock (synchronous domain for all logic)
    input rst_n, // Asynchronous reset
    
    // register facing signals 
    output[15:0] count_val, // Current value of the counter
    input[15:0] period, // The final value 'N' (T_max) for the counter's rollover
    input en, // Counter Enable signal (from control register)
    input count_reset, // One-cycle pulse for explicit software reset
    input upnotdown, // Direction control: 1=Up-count, 0=Down-count
    input[7:0] prescale // Prescaler division factor (P)
);
    
// Internal registers
reg [15:0] r_count_val;
reg [7:0] r_prescale_count;

// Wire generation
wire count_tick; // Signal generated when the prescaler reaches its limit
assign count_val = r_count_val; // Expose the internal count value for readback

// Prescaler Logic (r_prescale_count)
// This sequential block generates the 'slowed down' clock signal (count_tick)
// The counter only increments when this prescaler ticks

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        r_prescale_count <= 8'h00; // Reset prescaler counter to 0
    end
    else if (en) begin // Only run the prescaler if the counter is enabled
        
        // Check for Hard Reset or Rollover Reset
        // If count_reset is asserted OR the main counter just hit PERIOD (Up-counting mode), it resets the prescaler counter back to zero immediately
        if (count_reset || (r_count_val == period && upnotdown == 1'b1)) begin 
             r_prescale_count <= 8'h00;
        end
        
        // Check for Prescaler Rollover
        else if (r_prescale_count == prescale) begin
            r_prescale_count <= 8'h00; // Reset prescaler counter to 0
        end
        
        // Default action: Increment the prescaler counter
        else begin
            r_prescale_count <= r_prescale_count + 1'b1;
        end
    end
end

// Combinational logic for the tick signal
// The main counter should increment/decrement only when the prescaler reaches the target
// This needs to be calculated before the reset in the next cycle, hence the combinational assignment

assign count_tick = (r_prescale_count == prescale) && en;


// Main Counter Logic (r_count_val)
// This sequential block handles the core 16-bit counting, direction, and rollover

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        r_count_val <= 16'h0000; // Initialize main counter to 0
    end
    
    // Explicit software reset
    else if (count_reset) begin
        r_count_val <= 16'h0000;
    end
    
    // Update only when the prescaler ticks
    else if (count_tick) begin

        // UP-COUNTING MODE (upnotdown = 1)
        if (upnotdown == 1'b1) begin
            if (r_count_val == period) begin
                // Rollover: If we hit PERIOD (N), reset back to 0
                r_count_val <= 16'h0000;
            end
            else begin
                // Normal operation: Increment counter
                r_count_val <= r_count_val + 1'b1;
            end
        end
        
        // DOWN-COUNTING MODE (upnotdown = 0)
        else begin
            // In pure down-counting, the rollover should theoretically wrap from 0 to N

            if (r_count_val == 16'h0000) begin
                // Down-count Rollover: 0 -> N (reload the period value)
                // This maintains the correct cycle length (N+1 clock cycles)
                r_count_val <= period;
            end
            else begin
                // Normal operation: Decrement counter
                r_count_val <= r_count_val - 1'b1;
            end
        end
    end
end


endmodule