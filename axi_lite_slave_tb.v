`timescale 1ns/1ps
//============================================================
// Testbench for axi_lite_slave_basic
//============================================================
module axi_lite_slave_tb;
    reg  ACLK, ARESETn;
    reg  [3:0]  AWADDR;
    reg         AWVALID, WVALID, BREADY;
    reg  [31:0] WDATA;
    wire        AWREADY, WREADY, BVALID;
    wire [1:0]  BRESP;

    reg  [3:0]  ARADDR;
    reg         ARVALID, RREADY;
    wire        ARREADY, RVALID;
    wire [31:0] RDATA;
    wire [1:0]  RRESP;

    // Instantiate DUT
    axi_lite_slave_basic dut (
        .ACLK(ACLK), .ARESETn(ARESETn),
        .S_AWADDR(AWADDR), .S_AWVALID(AWVALID), .S_AWREADY(AWREADY),
        .S_WDATA(WDATA), .S_WVALID(WVALID), .S_WREADY(WREADY),
        .S_BRESP(BRESP), .S_BVALID(BVALID), .S_BREADY(BREADY),
        .S_ARADDR(ARADDR), .S_ARVALID(ARVALID), .S_ARREADY(ARREADY),
        .S_RDATA(RDATA), .S_RRESP(RRESP), .S_RVALID(RVALID), .S_RREADY(RREADY)
    );

    // Clock 100MHz
    always #5 ACLK = ~ACLK;

    // Monitor
    initial
        $monitor("[%0t] clk=%b rst=%b AWV=%b AWR=%b WV=%b WR=%b BV=%b ARV=%b RR=%b RV=%b RDATA=%h",
                 $time, ACLK, ARESETn, AWVALID, AWREADY, WVALID, WREADY, BVALID, ARVALID, ARREADY, RVALID, RDATA);

    // Test sequence
    initial begin
        ACLK = 0; ARESETn = 0;
        AWVALID = 0; WVALID = 0; BREADY = 0;
        ARVALID = 0; RREADY = 0;
        AWADDR = 0; ARADDR = 0; WDATA = 0;

        #20 ARESETn = 1;
        $display("==== AXI-Lite Slave Simulation Start ====");

        // === WRITE ===
        @(posedge ACLK);
        AWADDR = 4'h0; WDATA = 32'hA5A5A5A5;
        AWVALID = 1; WVALID = 1;
        repeat (3) @(posedge ACLK); // gi? VALID 3 chu k?
        AWVALID = 0; WVALID = 0;

        wait (BVALID);
        BREADY = 1; @(posedge ACLK); BREADY = 0;

        // === READ ===
        @(posedge ACLK);
        ARADDR = 4'h0; ARVALID = 1;
        repeat (3) @(posedge ACLK);
        ARVALID = 0;

        wait (RVALID);
        $display("[%0t] READ VALUE = %h", $time, RDATA);
        RREADY = 1; @(posedge ACLK); RREADY = 0;

        #100;
        $display("==== Simulation End ====");
        $finish;
    end
endmodule

