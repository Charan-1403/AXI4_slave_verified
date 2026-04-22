interface axi_if #(parameter DATA_WIDTH = 32,
                   parameter ADDR_WIDTH = 32,
                   parameter ID_WIDTH = 16,
                   parameter LSB = $clog2(ADDR_WIDTH)-3)
                   (input logic clk, 
                    input logic rst_n);
    
    logic[ID_WIDTH-1:0] arid;
    logic arready;
    logic arvalid;
    logic[ADDR_WIDTH-1:0] araddr;
    logic[7:0] arlen;
    logic[2:0] arsize;
    logic[1:0] arburst;
    
    logic[ID_WIDTH-1:0] rid;
    logic rready;
    logic rvalid;
    logic rlast;
    logic[DATA_WIDTH-1:0] rdata;
    logic[1:0] rresp;
    
    logic[ID_WIDTH-1:0] awid;
    logic awready;
    logic awvalid;
    logic[ADDR_WIDTH-1:0] awaddr;
    logic[7:0] awlen;
    logic[2:0] awsize;
    logic[1:0] awburst;
    
    logic wvalid;
    logic wready;
    logic[DATA_WIDTH-1:0] wdata;
    logic[(DATA_WIDTH/8)-1:0] wstrb;
    logic wlast;
    
    logic[ID_WIDTH-1:0] bid;
    logic[1:0] bresp;
    logic bvalid;
    logic bready;
    
    property rvalid_hold;
        @(posedge clk) disable iff(!rst_n)
        (rvalid && !rready) |=> rvalid;
    endproperty
    
    assert_rvalid_hold: assert property (rvalid_hold) else $fatal("PROTOCOL VIOLATED, RVALID FELL AFTER IT WAS ASSERTED!");
    
     
endinterface