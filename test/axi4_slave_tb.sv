`timescale 1ns / 1ps

module axi4_slave_tb();
    import axi_pkg::*;
    
    logic clk = 0;
    logic rstn = 0;
    always #5 clk = ~clk;
    
    axi_if vif (clk, rstn);
    axi4_slave dut (
            .S_AXI_CLK(vif.clk),
            .S_AXI_RESETN(vif.rst_n),
            
            .S_AXI_ARID(vif.arid),
            .S_AXI_ARREADY(vif.arready),
            .S_AXI_ARVALID(vif.arvalid),
            .S_AXI_ARADDR(vif.araddr),
            .S_AXI_ARLEN(vif.arlen),
            .S_AXI_ARBURST(vif.arburst),
            .S_AXI_ARSIZE(vif.arsize),
            
            .S_AXI_RVALID(vif.rvalid),
            .S_AXI_RREADY(vif.rready),
            .S_AXI_RDATA(vif.rdata),
            .S_AXI_RLAST(vif.rlast),
            .S_AXI_RID(vif.rid),
            .S_AXI_RRESP(vif.rresp),
            
            .S_AXI_AWID(vif.awid),
            .S_AXI_AWVALID(vif.awvalid),
            .S_AXI_AWREADY(vif.awready),
            .S_AXI_AWLEN(vif.awlen),
            .S_AXI_AWBURST(vif.awburst),
            .S_AXI_AWSIZE(vif.awsize),
            .S_AXI_AWADDR(vif.awaddr),
            
            .S_AXI_WDATA(vif.wdata),
            .S_AXI_WVALID(vif.wvalid),
            .S_AXI_WREADY(vif.wready),
            .S_AXI_WLAST(vif.wlast),
            .S_AXI_WSTRB(vif.wstrb),
            
            .S_AXI_BID(vif.bid),
            .S_AXI_BRESP(vif.bresp),
            .S_AXI_BVALID(vif.bvalid),
            .S_AXI_BREADY(vif.bready)
            
    );
    
    environment env;
    
    always@(posedge clk) begin
        if(dut.S_AXI_RVALID && dut.S_AXI_RREADY)begin
            $display("Address: %b - %d| Data: %b | Mask : %b", dut.raddr, dut.raddr, dut.S_AXI_RDATA, dut.bit_mask);
        end
    end
    
    initial begin
        env = new(vif);
        
        rstn = 0;
        #20ns;
        rstn = 1;
        
        env.run();
        $display("DONE!\n");
        #20ns;
        $finish;
    end
    
endmodule
