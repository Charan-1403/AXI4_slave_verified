`timescale 1ns / 1ps
module skid_buffer #(parameter DATA_WIDTH = 63)(
    input wire                      clk,
    input wire                      rst_n,
    input wire[DATA_WIDTH-1:0]      i_payload,
    input wire                      i_valid,
    input wire                      i_ready,
    output reg[DATA_WIDTH-1:0]      o_payload,
    output reg                      o_valid,
    output wire                      o_ready
);
    
    reg[DATA_WIDTH-1:0] skid_payload_buffer;
    reg skid_valid_buffer;
    reg skid_buffer_full;
    
    assign o_ready = !skid_buffer_full;
    
    always@(posedge clk) begin
        if(!rst_n) begin
            skid_payload_buffer <= 0;
            skid_valid_buffer <= 0;
            skid_buffer_full <= 0;
            o_valid <= 0;
            o_payload <= 0;
        end
        else if(!skid_buffer_full) begin 
            if(i_ready) begin
                o_payload <= i_payload;
                o_valid <= i_valid;
            end
            else if(i_valid) begin
                if(!o_valid) begin
                    o_valid <= i_valid;
                    o_payload <= i_payload;
                end
                else begin
                    skid_buffer_full <= 1;
                    skid_valid_buffer <= i_valid;
                    skid_payload_buffer <= i_payload;
                end
            end
        end
        else begin
            if(i_ready) begin
                o_payload <= skid_payload_buffer;
                o_valid <= skid_valid_buffer;
                skid_buffer_full <= 0;
            end
        end
    end

endmodule
