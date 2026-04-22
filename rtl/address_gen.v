`timescale 1ns / 1ps
module address_gen #(
        parameter ADDR_WIDTH = 32,
        parameter DATA_WIDTH = 32,
        parameter LSB = $clog2(DATA_WIDTH)-3
    )(
        input wire                      rst_n,
        input wire[ADDR_WIDTH-1:0]      ip_address,
        input wire[1:0]                 arburst,
        input wire[2:0]                 arsize,
        input wire[7:0]                 arlen,
        output reg[ADDR_WIDTH-1:0]      op_address
    );
    
    reg[ADDR_WIDTH-1:0] w_warp_addr, w_end_addr;
    reg[15:0] w_num_bytes;
    
    reg w_captured;
    
    initial w_captured = 0;
    
    always@(*) begin
        if(!rst_n) begin
            w_captured = 0;
            w_warp_addr = 0;
            w_end_addr = 0;
            w_num_bytes = 0;
        end
        else if(arburst == 2'b10) begin
            w_num_bytes = (arlen+1) << arsize;
            w_warp_addr = ip_address & (~{{(ADDR_WIDTH-16){1'b0}}, w_num_bytes-1});
            w_end_addr = w_warp_addr + w_num_bytes;
            w_captured = 1;
        end
        else begin
            w_num_bytes = 0;
            w_warp_addr = 0;
            w_end_addr = 0;
            w_captured = 0;
        end
    end
    
    always@(*) begin
        if(!rst_n) op_address = 0;
        else begin
            case(arburst)
                2'b00: begin
                    op_address = ip_address;
                end
                2'b01: begin
                    op_address = (ip_address + ({{(ADDR_WIDTH-1){1'b0}},1'b1} << arsize)) & (~((1<<(arsize))-1));
                end
                2'b10: begin
                    if((ip_address + ({{(ADDR_WIDTH-1){1'b0}},1'b1} << arsize)) < w_end_addr) begin
                        op_address = ip_address + ({{(ADDR_WIDTH-1){1'b0}},1'b1} << arsize) & (~((1<<(arsize))-1));
                    end
                    else begin
                        op_address = w_warp_addr;
                    end
                end
                default: op_address = 32'bx;
            endcase
        end
    end
    
endmodule
