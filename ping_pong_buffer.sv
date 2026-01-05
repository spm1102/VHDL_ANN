module ping_pong_buffer #(
    parameter DATA_WIDTH = 32,
    parameter IMG_W      = 14,
    parameter IMG_H      = 14,
    parameter IMG_SIZE   = IMG_W * IMG_H,         
    parameter ADDR_WIDTH = $clog2(IMG_SIZE)
)(
    input  wire                   clk,
    input  wire                   rst,

    // Write 
    input  wire                   wr_en,  
    input  wire [DATA_WIDTH-1:0]  wr_data,

    output reg                    img_done,  
    output reg                    wr_bank_sel, 

    // Read 
    input  wire [ADDR_WIDTH-1:0]  rd_addr,
    input  wire                   rd_bank_sel,
    output reg  [DATA_WIDTH-1:0]  rd_data
);
    reg [DATA_WIDTH-1:0] bank0 [0:IMG_SIZE-1];
    reg [DATA_WIDTH-1:0] bank1 [0:IMG_SIZE-1];


    reg [ADDR_WIDTH-1:0] wr_addr;

    // WRITE 
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            wr_addr     <= 0;
            wr_bank_sel <= 0;
            img_done    <= 0;
        end else begin
            img_done <= 0; 

            if (wr_en) begin
                if (wr_bank_sel == 1'b0)
                    bank0[wr_addr] <= wr_data;
                else
                    bank1[wr_addr] <= wr_data;

                if (wr_addr == IMG_SIZE-1) begin
                    wr_addr     <= 0;
                    wr_bank_sel <= ~wr_bank_sel; 
                    img_done    <= 1'b1;         
                end else begin
                    wr_addr <= wr_addr + 1'b1;
                end
            end
        end
    end

    // READ 
    always @(posedge clk) begin
        if (rd_bank_sel == 1'b1)
            rd_data <= bank0[rd_addr];
        else
            rd_data <= bank1[rd_addr];
    end
endmodule
