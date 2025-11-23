`timescale 1ns/1ps


module instr_dcd (
    // peripheral clock signals
    input clk,
    input rst_n,
    // towards SPI slave interface signals
    input byte_sync,
    input[7:0] data_in,
    output[7:0] data_out,
    // register access signals
    output read,
    output write,
    output[5:0] addr,
    input[7:0] data_read,
    output[7:0] data_write
);

    // simple 2-state FSM
    localparam ST_SETUP = 1'b0;
    localparam ST_DATA  = 1'b1;
    reg state;

    //for the SETUP 
    reg       rw_reg;        // 1 = write, 0 = read
    reg       hi_lo_reg;     // 1 = high byte, 0 = low byte (for later use)
    reg [5:0] addr_reg;

    // registered outputs
    reg       read_reg;
    reg       write_reg;
    reg [7:0] data_out_reg;
    reg [7:0] data_write_reg;

    // byte_sync edge detect (into clk domain)
    reg  byte_sync_d;
    wire byte_sync_rise = byte_sync & ~byte_sync_d;

    // map internal regs to outputs
    assign read       = read_reg;
    assign write      = write_reg;
    assign addr       = addr_reg;
    assign data_out   = data_out_reg;
    assign data_write = data_write_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // reset all signals
            state          <= ST_SETUP;
            byte_sync_d    <= 1'b0;

            rw_reg         <= 1'b0;
            hi_lo_reg      <= 1'b0;
            addr_reg       <= 6'd0;

            read_reg       <= 1'b0;
            write_reg      <= 1'b0;
            data_out_reg   <= 8'd0;
            data_write_reg <= 8'd0;
        end else begin
            // save previous value of byte_sync
            byte_sync_d <= byte_sync;

            // default: no read or write in this clock
            read_reg  <= 1'b0;
            write_reg <= 1'b0;

            // do something only when one byte is ready from SPI
            if (byte_sync_rise) begin
                case (state)
                    ST_SETUP: begin
                        // first byte: command and address
                        rw_reg    <= data_in[7];   // read or write bit
                        hi_lo_reg <= data_in[6];   // low or high part of register
                        addr_reg  <= data_in[5:0]; // address of register

                        // if it is read command, take data from regfile
                        if (data_in[7] == 1'b0) begin
                            read_reg     <= 1'b1;      // read pulse
                            data_out_reg <= data_read; // send this back over SPI
                        end

                        // next byte is data phase
                        state <= ST_DATA;
                    end

                    ST_DATA: begin
                        // second byte: only useful for write
                        if (rw_reg == 1'b1) begin
                            write_reg      <= 1'b1;   // write pulse
                            data_write_reg <= data_in; // send data_in to registers
                        end
                        // after data byte go back to setup
                        state <= ST_SETUP;
                    end

                    default: state <= ST_SETUP;
                endcase
            end
        end
    end

endmodule