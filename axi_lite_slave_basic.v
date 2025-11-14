//============================================================
// Simple AXI-Lite Slave (4 registers)
// - Works on ModelSim 2020.4 Windows
// - Supports 1 write + 1 read transaction
//============================================================
module axi_lite_slave_basic (
    input  wire         ACLK,
    input  wire         ARESETn,

    // Write address
    input  wire [3:0]   S_AWADDR,
    input  wire          S_AWVALID,
    output reg           S_AWREADY,

    // Write data
    input  wire [31:0]  S_WDATA,
    input  wire          S_WVALID,
    output reg           S_WREADY,

    // Write response
    output reg  [1:0]   S_BRESP,
    output reg           S_BVALID,
    input  wire          S_BREADY,

    // Read address
    input  wire [3:0]   S_ARADDR,
    input  wire          S_ARVALID,
    output reg           S_ARREADY,

    // Read data
    output reg  [31:0]  S_RDATA,
    output reg  [1:0]   S_RRESP,
    output reg           S_RVALID,
    input  wire          S_RREADY
);

    // Internal registers
    reg [31:0] reg0, reg1, reg2, reg3;

    always @(posedge ACLK) begin
        if (!ARESETn) begin
            S_AWREADY <= 0; S_WREADY <= 0;
            S_BVALID  <= 0; S_ARREADY <= 0; S_RVALID <= 0;
            reg0 <= 0; reg1 <= 0; reg2 <= 0; reg3 <= 0;
        end else begin
            // --- WRITE HANDSHAKE ---
            if (S_AWVALID && !S_AWREADY) S_AWREADY <= 1;
            else S_AWREADY <= 0;

            if (S_WVALID && !S_WREADY) S_WREADY <= 1;
            else S_WREADY <= 0;

            if (S_AWVALID && S_AWREADY && S_WVALID && S_WREADY) begin
                case (S_AWADDR[3:2])
                    2'b00: reg0 <= S_WDATA;
                    2'b01: reg1 <= S_WDATA;
                    2'b10: reg2 <= S_WDATA;
                    2'b11: reg3 <= S_WDATA;
                endcase
                S_BRESP  <= 2'b00;   // OKAY
                S_BVALID <= 1;
                $display("[%0t] WRITE: addr=%h data=%h", $time, S_AWADDR, S_WDATA);
            end else if (S_BREADY) S_BVALID <= 0;

            // --- READ HANDSHAKE ---
            if (S_ARVALID && !S_ARREADY) begin
                S_ARREADY <= 1;
                case (S_ARADDR[3:2])
                    2'b00: S_RDATA <= reg0;
                    2'b01: S_RDATA <= reg1;
                    2'b10: S_RDATA <= reg2;
                    2'b11: S_RDATA <= reg3;
                endcase
                S_RRESP  <= 2'b00;
                S_RVALID <= 1;
                $display("[%0t] READ REQ: addr=%h => data=%h", $time, S_ARADDR, S_RDATA);
            end else if (S_RREADY) begin
                S_ARREADY <= 0;
                S_RVALID  <= 0;
            end
        end
    end
endmodule

