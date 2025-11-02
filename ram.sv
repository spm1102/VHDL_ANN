module ram#(
    parameter ADDR_WIDTH = 8,
    parameter DATA_WIDTH = 16,
    parameter RAM_DEPTH = 256
)(
    input clk,
    input rst_n,
    input we,
    input [ADDR_WIDTH-1:0] addr,
    input [DATA_WIDTH-1:0] data_in,
    output reg [DATA_WIDTH-1:0] data_out
);
    reg [DATA_WIDTH-1:0] mem [0:RAM_DEPTH-1];
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            data_out <= 0;
        end else begin
            if(we) begin
                mem[addr] <= data_in;
            end else begin
                data_out <= mem[addr];
            end
        end
    end
endmodule

