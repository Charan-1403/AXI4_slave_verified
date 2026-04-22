`timescale 1ns/1ps
module axi4_slave #(
        parameter DATA_WIDTH = 64,
        parameter ADDR_WIDTH = 32,
        parameter ID_WIDTH = 16, 
        parameter LSB = $clog2(DATA_WIDTH)-3)(
        
        input wire                      S_AXI_CLK,
        input wire                      S_AXI_RESETN,
        
        input wire[ID_WIDTH-1:0]        S_AXI_ARID,
        output reg                      S_AXI_ARREADY,
        input wire                      S_AXI_ARVALID,
        input wire[ADDR_WIDTH-1:0]      S_AXI_ARADDR,
        input wire[7:0]                 S_AXI_ARLEN,
        input wire[2:0]                 S_AXI_ARSIZE,
        input wire[1:0]                 S_AXI_ARBURST,
        
        output reg[ID_WIDTH-1:0]        S_AXI_RID,
        output reg                      S_AXI_RVALID,
        input wire                      S_AXI_RREADY,
        output reg                      S_AXI_RLAST,
        output reg[DATA_WIDTH-1:0]      S_AXI_RDATA,
        output reg[1:0]                 S_AXI_RRESP,
        
        input wire[ID_WIDTH-1:0]        S_AXI_AWID,
        input wire                      S_AXI_AWVALID,
        output wire                     S_AXI_AWREADY,
        input wire[ADDR_WIDTH-1:0]      S_AXI_AWADDR,
        input wire[7:0]                 S_AXI_AWLEN,
        input wire[2:0]                 S_AXI_AWSIZE,
        input wire[1:0]                 S_AXI_AWBURST,
        
        input wire                      S_AXI_WVALID,
        output reg                      S_AXI_WREADY,
        input wire[DATA_WIDTH-1:0]      S_AXI_WDATA,
        input wire[(DATA_WIDTH/8)-1:0]  S_AXI_WSTRB,
        input wire                      S_AXI_WLAST,
        
        output wire[ID_WIDTH-1:0]        S_AXI_BID,
        input wire                      S_AXI_BREADY,
        output wire                      S_AXI_BVALID,
        output wire[1:0]                 S_AXI_BRESP
    );
    
        
        reg[ADDR_WIDTH-1:0] raddr, next_raddr;
        wire[ADDR_WIDTH-1:0] next_raddr_wire;
        reg[8:0] rlen;
        reg[ID_WIDTH-1:0] axi_rid;
        
        reg r_en;
        
        reg[ID_WIDTH-1:0] axi_arid;
        reg[2:0] axi_arsize;
        reg[1:0] axi_arburst;
        reg[7:0] axi_arlen;
        
        reg axi_arready, axi_rvalid, axi_rlast;
        reg[DATA_WIDTH-1:0] axi_rdata;
        reg[DATA_WIDTH-1:0] memory [0:1023];
        reg[31:0] i;
        
        always@(*) next_raddr = next_raddr_wire;
        
        address_gen #(
                                .ADDR_WIDTH(ADDR_WIDTH),
                                .DATA_WIDTH(DATA_WIDTH),
                                .LSB(LSB)
                            ) a_gen
                            (
                                .ip_address(S_AXI_ARVALID ? S_AXI_ARADDR : raddr),
                                .arburst(S_AXI_ARVALID ? S_AXI_ARBURST : axi_arburst),
                                .arlen(S_AXI_ARVALID ? S_AXI_ARLEN : axi_arlen),
                                .arsize(S_AXI_ARVALID ? S_AXI_ARSIZE : axi_arsize),
                                .rst_n(S_AXI_RESETN),
                                .op_address(next_raddr_wire)
                            );
        reg[31:0] j;
        initial begin
            for(i = 0; i < 1024; i = i + 1) begin
                for(j = 0; j < (DATA_WIDTH/8); j = j + 1) begin
                    memory[i][j*8 +: 8] = i[7:0] + j[7:0];
                end
            end
        end
        
        reg[ADDR_WIDTH-1:0] mem_acc_addr;
        
        always@(*) mem_acc_addr = S_AXI_ARVALID ? S_AXI_ARADDR : next_raddr;
        
        always@(posedge S_AXI_CLK) begin
            if(r_en && S_AXI_ARVALID) begin
                axi_rdata <= memory[{mem_acc_addr[ADDR_WIDTH-1:LSB], {(LSB-1){1'b0}}}];
            end
            else if(r_en) begin
                axi_rdata <= memory[{mem_acc_addr[ADDR_WIDTH-1:LSB], {(LSB-1){1'b0}}}];
            end
        end
        
        always@(posedge S_AXI_CLK) begin
            if(!S_AXI_RESETN) begin
                axi_arburst <= 0;
                axi_arsize <= 0;
                axi_arlen <= 0;
                axi_arid <= 0;
            end
            else if(S_AXI_ARVALID && S_AXI_ARREADY)begin
                axi_arburst <= S_AXI_ARBURST;
                axi_arlen <= S_AXI_ARLEN;
                axi_arid <= S_AXI_ARID;
                axi_arsize <= S_AXI_ARSIZE;
            end
        end
        
        reg[(DATA_WIDTH/8)-1:0] byte_mask;
        reg[DATA_WIDTH-1:0] bit_mask;
        reg[7:0] num_bytes;
        
        always@(*) begin
            for(i = 0; i < DATA_WIDTH/8; i = i + 1)begin
                if(byte_mask[i] == 1) bit_mask[i*8+:8] = 8'b11111111;
                else bit_mask[i*8+:8] = 8'b0;
            end
        end
        
        always@(*) begin
            if(!S_AXI_RESETN) byte_mask = 0;
            else begin
              num_bytes = 1 << axi_arsize;
              byte_mask = ((1 << num_bytes) - 1) << (S_AXI_ARVALID ? S_AXI_ARADDR[LSB-1:0] : raddr[LSB-1:0]);
            end
        end
        
        always@(*) begin
            S_AXI_ARREADY = axi_arready;
            S_AXI_RVALID = axi_rvalid;
            S_AXI_RLAST = axi_rlast;
            S_AXI_RDATA = axi_rdata & bit_mask;
            S_AXI_RRESP = 0;
            S_AXI_RID = axi_rid;
        end
        

        
        initial begin
            axi_arready = 1;
        end
        
        always@(*) begin
            if(!S_AXI_RVALID || S_AXI_RREADY) r_en = (S_AXI_ARVALID || !S_AXI_ARREADY);
            else r_en = 0;
        end
        
        always@(posedge S_AXI_CLK) begin
            if(!S_AXI_RESETN) begin
                axi_arready <= 1;
            end
            
            else if(S_AXI_ARVALID && S_AXI_ARREADY) begin
                axi_arready <= (S_AXI_ARLEN == 0) && (!S_AXI_RVALID || S_AXI_RREADY);
            end
            else if(S_AXI_RREADY && S_AXI_RVALID) begin
                axi_arready <= (rlen <= 2);
            end
        end
        
        always@(posedge S_AXI_CLK) begin
            if(!S_AXI_RESETN) begin
                rlen <= 0;
            end
            else if(S_AXI_ARREADY && S_AXI_ARVALID) begin
                if(S_AXI_RVALID && !S_AXI_RREADY) 
                    rlen <= S_AXI_ARLEN + 1 + 1;
                else rlen <= S_AXI_ARLEN + 1;
            end
            else if(S_AXI_RREADY && S_AXI_RVALID) begin
                rlen <= rlen - 1;
            end
        end
        
        always@(posedge S_AXI_CLK) begin
            if(!S_AXI_RESETN) axi_rlast <= 0;
            else if(!S_AXI_RVALID || S_AXI_RREADY) begin
                if (S_AXI_ARREADY && S_AXI_ARVALID) begin
                    axi_rlast <= (S_AXI_ARLEN == 0);
                end
                else if (S_AXI_RREADY && S_AXI_RVALID) begin
                    axi_rlast <= (rlen <= 2);
                end
                else axi_rlast <= (rlen <= 1);
            end
        end
        
        always@(posedge S_AXI_CLK) begin
            if(!S_AXI_RESETN) axi_rvalid <= 0;
            else if(r_en) axi_rvalid <= 1;
            else if(S_AXI_RREADY)axi_rvalid <= 0;
        end
        
        always@(posedge S_AXI_CLK) begin
            if(!S_AXI_RESETN) begin
                raddr <= 0;
            end
            else if((S_AXI_ARREADY && S_AXI_ARVALID)) begin
                raddr <= S_AXI_ARADDR;
            end
            else if(S_AXI_RREADY && S_AXI_RVALID) begin
                raddr <= next_raddr;
            end
        end
        
        always@(posedge S_AXI_CLK) begin
            if(!S_AXI_RESETN) begin
                axi_rid <= 0;
            end
            else if(!S_AXI_RVALID || S_AXI_RREADY) begin
                if(S_AXI_ARVALID && S_AXI_ARREADY) begin
                    axi_rid <= S_AXI_ARID;
                end
            end
        end
        
    //WRITE LOGIC STARTS HERE    
    
    wire m_axi_awvalid;
    wire[13+ADDR_WIDTH+ID_WIDTH-1:0] m_axi_awpayload;
    reg[13+ADDR_WIDTH+ID_WIDTH-1:0] i_axi_awpayload;
    reg m_axi_awready;
    
    always@(*) i_axi_awpayload = {S_AXI_AWID, S_AXI_AWADDR, S_AXI_AWLEN, S_AXI_AWBURST, S_AXI_AWSIZE};
    
    skid_buffer #(.DATA_WIDTH(13+ADDR_WIDTH+ID_WIDTH)) aw_skid (
            .clk(S_AXI_CLK),
            .rst_n(S_AXI_RESETN),
            
            .i_payload(i_axi_awpayload),
            .i_valid(S_AXI_AWVALID),
            .o_ready(S_AXI_AWREADY),
            
            .o_payload(m_axi_awpayload),
            .o_valid(m_axi_awvalid),
            .i_ready(m_axi_awready)
    );
    
    reg axi_awready, axi_wready;
    initial begin
        axi_awready = 1;
        axi_wready = 0;
    end
   
    reg[7:0] axi_awlen;
    reg[1:0] axi_awburst;
    reg[2:0] axi_awsize;
    reg[ADDR_WIDTH-1:0] axi_awaddr;
    reg[ID_WIDTH-1:0] axi_awid;
    
    reg[DATA_WIDTH-1:0] w_bit_mask;
    integer x;
    
    always@(*) begin
            for(x = 0; x < DATA_WIDTH/8; x = x + 1)begin
                if(S_AXI_WSTRB[x] == 1) w_bit_mask[x*8+:8] = 8'b11111111;
                else w_bit_mask[x*8+:8] = 8'b0;
            end
     end
     
     reg[ADDR_WIDTH-1:0] axi_next_awaddr;
     wire[ADDR_WIDTH-1:0] axi_next_awaddr_wire;
     
    always@(*) axi_next_awaddr = axi_next_awaddr_wire;
        
    address_gen #(
                                .ADDR_WIDTH(ADDR_WIDTH),
                                .DATA_WIDTH(DATA_WIDTH),
                                .LSB(LSB)
                            ) a_gen_write
                            (
                                .ip_address(axi_awaddr),
                                .arburst(axi_awburst),
                                .arlen(axi_awlen),
                                .arsize(axi_awsize),
                                .rst_n(S_AXI_RESETN),
                                .op_address(axi_next_awaddr_wire)
                            );
                            
    wire r_bvalid;
    
    always@(posedge S_AXI_CLK)begin
        if(!S_AXI_RESETN) begin
            axi_awready <= 1;
            axi_wready <= 0;
        end
        else if(m_axi_awready && m_axi_awvalid) begin
            axi_awready <= 0;
            axi_wready <= 1;
        end
        else if(S_AXI_WREADY && S_AXI_WVALID) begin
            axi_awready <= (S_AXI_WLAST) && (!S_AXI_BVALID || S_AXI_BREADY);
            axi_wready <= !S_AXI_WLAST;
        end
        else if(!axi_awready) begin
            if(S_AXI_WREADY) axi_awready <= 0;
            else if(!r_bvalid && !S_AXI_BREADY) axi_awready <= 0;
            else axi_awready <= 1;
        end
    end
    
    always@(*) begin
        m_axi_awready = axi_awready;
        if((S_AXI_WREADY && S_AXI_WVALID && S_AXI_WLAST) && (!S_AXI_BVALID || S_AXI_BREADY)) m_axi_awready = 1'b1;
    end
    
    always@(posedge S_AXI_CLK) begin
        if(S_AXI_WREADY && S_AXI_WVALID) begin
            memory[{axi_awaddr[ADDR_WIDTH-1:LSB],{(LSB-1){1'b0}}}] <= S_AXI_WDATA & w_bit_mask;
        end
    end
    
    always@(posedge S_AXI_CLK) begin
        if(!S_AXI_RESETN) begin
            axi_awsize <= 0;
            axi_awburst <= 0;
            axi_awlen <= 0;
            axi_awaddr <= 0;
            axi_awid <= 0;
        end
        else if(m_axi_awready && m_axi_awvalid) begin
            axi_awsize <= m_axi_awpayload[2:0];
            axi_awburst <= m_axi_awpayload[4:3];
            axi_awlen <= m_axi_awpayload[12:5];
            axi_awaddr <= m_axi_awpayload[ADDR_WIDTH-1+13:13];
            axi_awid <= m_axi_awpayload[ID_WIDTH + ADDR_WIDTH + 13 - 1: ADDR_WIDTH + 13];
        end
        else if(S_AXI_WREADY && S_AXI_WVALID) axi_awaddr <= axi_next_awaddr;
    end
    
    reg[ID_WIDTH+2-1:0] b_axi_payload_in;
    wire b_axi_valid_in;
    
    always@(*) b_axi_payload_in = {axi_awid, 2'b00};
    assign b_axi_valid_in = S_AXI_WLAST && S_AXI_WREADY && S_AXI_WVALID;
    
    skid_buffer #(.DATA_WIDTH(ID_WIDTH+2)) b_skid_buffer (
            .clk(S_AXI_CLK),
            .rst_n(S_AXI_RESETN),
            
            .i_payload(b_axi_payload_in),
            .i_valid(b_axi_valid_in),
            .o_ready(r_bvalid),
            
            .o_payload({S_AXI_BID, S_AXI_BRESP}),
            .o_valid(S_AXI_BVALID),
            .i_ready(S_AXI_BREADY)      
    );
    
    always@(*) begin
        S_AXI_WREADY = axi_wready;
    end
        
        
endmodule
