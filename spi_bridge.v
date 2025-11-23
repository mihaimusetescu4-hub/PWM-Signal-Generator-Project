`timescale 1ns / 1ps

module spi_bridge (
    // peripheral clock signals
    input        clk,
    input        rst_n,
    // SPI master facing signals
    input        sclk,
    input        cs_n,
    input        mosi,
    output       miso,
    // internal facing 
    output       byte_sync,
    output [7:0] data_in,
    input  [7:0] data_out
);

    reg [2:0] bit_cnt;
    reg [7:0] rx_shift;
    reg [7:0] tx_shift;

    // taking the MSB to send to the master
    assign miso = tx_shift[7];
    //logic for the byte_sync to be 1 when CS is low and the data_in has 8 bytes (starts from 0)
    assign byte_sync = (!cs_n && (bit_cnt == 3'b111));
    //logic to put the mosi bytes in the data_in
    assign data_in = {rx_shift[6:0], mosi};

    always @(posedge sclk or negedge rst_n or posedge cs_n) begin
        if (!rst_n) begin
        //if it is reseted
            bit_cnt  <= 3'd0;
            rx_shift <= 8'd0;
        end
     
        else if (cs_n) begin
        // if cs_n = 1 that means the slave is not listening
            bit_cnt  <= 3'd0;
            rx_shift <= 8'd0;
        end
        
        else
        begin
        // if the slave listens we save the mosi byte
            rx_shift <= {rx_shift[6:0], mosi};
        //bit_cnt  logic
            if (bit_cnt == 3'd7)
                bit_cnt <= 3'd0;
            else
                bit_cnt <= bit_cnt + 3'd1;
        end
    end


// this is for the miso we have the negative edge of the clock, it could ve been done with a neg_clk = ~clk
// but i don't know which is better
//this just take the bytes from data_out to send the last byte to the miso
    always @(negedge sclk or negedge rst_n or posedge cs_n) begin
        if (!rst_n) begin
            tx_shift <= 8'd0;
        end else if (cs_n) begin
            tx_shift <= data_out;
        end else begin
            tx_shift <= {tx_shift[6:0], 1'b0};
        end
    end

endmodule