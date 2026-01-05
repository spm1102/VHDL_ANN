module system_top #(
    parameter AXI_ADDR_WIDTH = 32,
    parameter AXI_DATA_WIDTH = 32,
    parameter AXI_ID_WIDTH   = 4
)(
    input wire clk,
    input wire rst_n,

    // AXI4 Master Interface 
    // AW
    input  wire awready,
    output wire awvalid,
    output wire [AXI_ID_WIDTH-1:0] awid,
    output wire [AXI_ADDR_WIDTH-1:0] awaddr,
    output wire [7:0] awlen,
    output wire [2:0] awsize,
    output wire [1:0] awburst,
    // W
    input  wire wready,
    output wire wvalid,
    output wire wlast,
    output wire [AXI_DATA_WIDTH-1:0] wdata,
    output wire [(AXI_DATA_WIDTH/8)-1:0] wstrb,
    // B
    input  wire [AXI_ID_WIDTH-1:0] bid,
    input  wire [1:0] bresp,
    input  wire bvalid,
    output wire bready,
    // AR
    input  wire arready,
    output wire arvalid,
    output wire [AXI_ID_WIDTH-1:0] arid,
    output wire [AXI_ADDR_WIDTH-1:0] araddr,
    output wire [7:0] arlen,
    output wire [2:0] arsize,
    output wire [1:0] arburst,
    // R
    input  wire [AXI_ID_WIDTH-1:0] rid,
    input  wire [AXI_DATA_WIDTH-1:0] rdata,
    input  wire [1:0] rresp,
    input  wire rlast,
    input  wire rvalid,
    output wire rready
);


    // Controller <-> AXI Master
    wire ctrl_start_rd, ctrl_start_wr;
    wire [31:0] ctrl_rd_addr, ctrl_wr_addr;
    wire [7:0] ctrl_rd_len, ctrl_wr_len;
    wire axi_rd_done, axi_wr_done, axi_wr_next;
    wire [31:0] ctrl_wr_data;

    // AXI Master <-> Ping Pong (Read Stream)
    wire [31:0] axi_rd_data_out; 
    wire axi_rd_valid_out;       

    // Controller <-> Ping Pong
    wire pp_img_done;
    wire pp_rd_bank_sel;

    // NN Wrapper <-> Ping Pong
    wire [31:0] nn_rd_addr;
    wire [31:0] nn_rd_data;
    
    // Controller <-> NN Wrapper
    wire nn_start, nn_done;
    wire [31:0] nn_results [0:9];

    // AXI Master
    axi_master #(
        .addr_width(AXI_ADDR_WIDTH),
        .data_width(AXI_DATA_WIDTH),
        .id_width(AXI_ID_WIDTH)
    ) u_axi_master (
        .clk(clk), .rst(~rst_n), 
        // AXI Ports
        .awready(awready), 
        .awvalid(awvalid), 
        .awid(awid), 
        .awaddr(awaddr), 
        .awlen(awlen), 
        .awsize(awsize), 
        .awburst(awburst),

        .wready(wready), 
        .wvalid(wvalid), 
        .wlast(wlast), 
        .wdata(wdata), 
        .wstrb(wstrb),

        .bid(bid), 
        .bresp(bresp), 
        .bvalid(bvalid), 
        .bready(bready),

        .arready(arready), 
        .arvalid(arvalid), 
        .arid(arid), 
        .araddr(araddr), 
        .arlen(arlen), 
        .arsize(arsize), 
        .arburst(arburst),

        .rid(rid), 
        .rdata(rdata), 
        .rresp(rresp), 
        .rlast(rlast), 
        .rvalid(rvalid), 
        .rready(rready),
        
        // User Interface
        .start_rd(ctrl_start_rd),
        .rd_addr(ctrl_rd_addr),
        .rd_len(ctrl_rd_len),
        .rd_done(axi_rd_done),
        .rd_data_out(axi_rd_data_out),
        .rd_valid_out(axi_rd_valid_out),

        .start_wr(ctrl_start_wr),
        .wr_addr(ctrl_wr_addr),
        .wr_len(ctrl_wr_len),
        .wr_data_in(ctrl_wr_data),
        .wr_next(axi_wr_next),
        .wr_done(axi_wr_done)
    );

    // AXI Controller 
    axi_controller #(
        .INPUT_BASE_ADDR(32'h0000_0000),
        .OUTPUT_BASE_ADDR(32'h0000_5000) 
    ) u_controller (
        .clk(clk), 
        .rst_n(rst_n),

        .axi_start_rd(ctrl_start_rd), 
        .axi_rd_addr(ctrl_rd_addr), 
        .axi_rd_len(ctrl_rd_len), 
        .axi_rd_done(axi_rd_done),
        .axi_start_wr(ctrl_start_wr), 
        .axi_wr_addr(ctrl_wr_addr), 
        .axi_wr_len(ctrl_wr_len), 
        .axi_wr_next(axi_wr_next), 
        .axi_wr_data(ctrl_wr_data), 
        .axi_wr_done(axi_wr_done),
        .pp_img_done(pp_img_done), 
        .pp_rd_bank_sel(pp_rd_bank_sel),
        .nn_start(nn_start), 
        .nn_done(nn_done), 
        .nn_result(nn_results)
    );

    // Ping Pong Buffer
    ping_pong_buffer #(
        .DATA_WIDTH(32),
        .IMG_W(14), .IMG_H(14)
    ) u_buffer (
        .clk(clk), 
        .rst(~rst_n),
        // Write
        .wr_en(axi_rd_valid_out),
        .wr_data(axi_rd_data_out),
        .img_done(pp_img_done),
        .wr_bank_sel(), 
        
        // Read 
        .rd_addr(nn_rd_addr[7:0]),
        .rd_bank_sel(pp_rd_bank_sel),
        .rd_data(nn_rd_data)
    );

    // Neural Network Wrapper
    nn_wrapper u_nn_wrapper (
        .clk(clk), 
        .rst_n(rst_n),
        
        .start(nn_start),
        .done(nn_done),
        .pp_rd_addr(nn_rd_addr),
        .pp_rd_data(nn_rd_data),
        .results(nn_results)
    );

endmodule