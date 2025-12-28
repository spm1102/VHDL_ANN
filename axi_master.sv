module axi_master #(
    parameter addr_width = 32,
    parameter data_width = 32,
    parameter id_width   = 4
) (
    input clk, rst,
    // AW
    input awready,
    output reg awvalid,
    output reg [id_width-1:0] awid,
    output reg [addr_width-1:0] awaddr,
    output reg [7:0] awlen,
    output reg [2:0] awsize,
    output reg [1:0] awburst,

    // W
    input wready,
    output reg wvalid,
    output reg wlast,
    output wire [data_width-1:0] wdata,
    output reg [(data_width/8)-1:0] wstrb,

    // B
    input [id_width-1:0] bid,
    input [1:0] bresp,
    input bvalid,
    output reg bready,

    // AR
    input arready,
    output reg arvalid,
    output reg [id_width-1:0] arid,
    output reg [addr_width-1:0] araddr,
    output reg [7:0] arlen,
    output reg [2:0] arsize,
    output reg [1:0] arburst,

    // R
    input [id_width-1:0] rid,
    input [data_width-1:0] rdata,
    input [1:0] rresp,
    input rlast,
    input rvalid,
    output reg rready,

    // User Interface
    input start_wr, start_rd,
    input [addr_width-1:0] wr_addr, rd_addr,
    input [7:0] wr_len, rd_len,
    // Status
    output reg wr_done, rd_done,
    // Write Stream
    input [data_width-1:0] wr_data_in,
    output wire wr_next,
    // Read Stream
    output reg [data_width-1:0] rd_data_out,
    output reg rd_valid_out
);

    localparam BURST_INCR = 2'b01;
    localparam DATA_SIZE  = $clog2(data_width/8);

    localparam S_RD_IDLE  = 2'd0;
    localparam S_RD_AR    = 2'd1;
    localparam S_RD_DATA  = 2'd2;
    localparam S_RD_DONE  = 2'd3;

    reg [1:0] rd_curr_state, rd_next_state;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            rd_curr_state <= S_RD_IDLE;
        end else begin
            rd_curr_state <= rd_next_state;
        end
    end

    always @(*) begin
        rd_next_state = rd_curr_state; 

        case (rd_curr_state)
            S_RD_IDLE: begin
                if (start_rd) 
                    rd_next_state = S_RD_AR;
            end

            S_RD_AR: begin
                if (arvalid && arready) 
                    rd_next_state = S_RD_DATA;
            end

            S_RD_DATA: begin
                if (rvalid && rready && rlast) 
                    rd_next_state = S_RD_DONE;
            end

            S_RD_DONE: begin
                rd_next_state = S_RD_IDLE;
            end
            
            default: rd_next_state = S_RD_IDLE;
        endcase
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            arvalid      <= 0;
            arid         <= 0;
            araddr       <= 0;
            arlen        <= 0;
            arsize       <= 0;
            arburst      <= 0;
            
            rready       <= 0;
            
            rd_data_out  <= 0;
            rd_valid_out <= 0;
            rd_done      <= 0;
        end else begin
            rd_valid_out <= 0; 

            case (rd_curr_state)
                S_RD_IDLE: begin
                    rd_done <= 0;
                    rd_valid_out <= 0;
                    if (start_rd) begin
                        arid    <= 4'd1;      
                        araddr  <= rd_addr;
                        arlen   <= rd_len - 1; 
                        arsize  <= DATA_SIZE;
                        arburst <= BURST_INCR;
                        arvalid <= 1;           
                    end
                end

                S_RD_AR: begin
                    if (arvalid && arready) begin
                        arvalid <= 0; 
                        rready  <= 1; 
                    end
                end

                S_RD_DATA: begin
                    if (rvalid && rready) begin
                        rd_data_out  <= rdata;
                        rd_valid_out <= 1; 
                        
                        if (rlast) begin
                            rready  <= 0;
                            rd_done <= 1; 
                        end
                    end 
                end

                S_RD_DONE: begin
                    rd_done <= 0;
                    rd_valid_out <= 0;
                    arvalid <= 0;
                end
            endcase
        end
    end


    // WRITE

    localparam S_WR_IDLE  = 3'd0,
               S_WR_AW    = 3'd1,
               S_WR_DATA  = 3'd2,
               S_WR_BRESP = 3'd3,
               S_WR_DONE  = 3'd4;

    reg [2:0] wr_curr_state, wr_next_state;
    reg [7:0] wr_cnt;

    assign wr_next = (wr_curr_state == S_WR_DATA) && (wvalid && wready);
    assign wdata   = wr_data_in;

    always @(posedge clk or posedge rst) begin
        if (rst) wr_curr_state <= S_WR_IDLE;
        else     wr_curr_state <= wr_next_state;
    end

    always @(*) begin
        wr_next_state = wr_curr_state;
        case (wr_curr_state)
            S_WR_IDLE: begin
                if (start_wr) wr_next_state = S_WR_AW;
            end

            S_WR_AW: begin
                if (awvalid && awready) wr_next_state = S_WR_DATA;
            end

            S_WR_DATA: begin
                if (wvalid && wready) begin
                    if (wr_cnt == awlen) 
                        wr_next_state = S_WR_BRESP;
                end
            end

            S_WR_BRESP: begin
                if (bvalid && bready) wr_next_state = S_WR_DONE;
            end

            S_WR_DONE: begin
                wr_next_state = S_WR_IDLE;
            end
            
            default: wr_next_state = S_WR_IDLE;
        endcase
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            awvalid <= 0; awid  <= 0; awaddr <= 0;
            awlen   <= 0; awsize <= 0; awburst <= 0;
            
            wvalid  <= 0; wlast <= 0; wstrb <= 0;
            bready  <= 0;
            wr_done <= 0;
            wr_cnt  <= 0;
        end else begin
            case (wr_curr_state)
                S_WR_IDLE: begin
                    wr_done <= 0;
                    if (start_wr) begin
                        awid    <= 4'd1; 
                        awaddr  <= wr_addr;
                        awlen   <= wr_len - 1;
                        awsize  <= DATA_SIZE;
                        awburst <= BURST_INCR;
                        
                        awvalid <= 1;
                        wr_cnt  <= 0;
                    end
                end

                S_WR_AW: begin
                    if (awvalid && awready) begin
                        awvalid <= 0;
                        
                        wvalid <= 1;
                        wstrb  <= {(data_width/8){1'b1}};
                        wlast  <= (awlen == 0);
                    end
                end

                S_WR_DATA: begin
                    if (wvalid && wready) begin
                        if (wr_cnt == awlen) begin
                            wvalid <= 0;
                            wlast  <= 0;
                            wstrb  <= 0;
                            bready <= 1;
                        end else begin
                            wr_cnt <= wr_cnt + 1;
                            if (wr_cnt + 1 == awlen) 
                                wlast <= 1;
                        end
                    end
                end

                S_WR_BRESP: begin
                    if (bvalid && bready) begin
                        bready  <= 0;
                        wr_done <= 1;
                    end
                end

                S_WR_DONE: begin
                    wr_done <= 0;
                end
            endcase
        end
    end

endmodule



// module axi_master #(
//     parameter addr_width = 32,
//     parameter data_width = 32,
//     parameter id_width   = 4
// ) (
//     input clk, rst,
//     // AW
//     input awready,
//     output reg awvalid,
//     output reg [id_width-1:0] awid,
//     output reg [addr_width-1:0] awaddr,
//     output reg [7:0] awlen,
//     output reg [2:0] awsize,
//     output reg [1:0] awburst,

//     // W
//     input wready,
//     output reg wvalid,
//     output reg wlast,
//     output wire [data_width-1:0] wdata,
//     output reg [(data_width/8)-1:0] wstrb,

//     // B
//     input [id_width-1:0] bid,
//     input [1:0] bresp,
//     input bvalid,
//     output reg bready,

//     // AR
//     input arready,
//     output reg arvalid,
//     output reg [id_width-1:0] arid,
//     output reg [addr_width-1:0] araddr,
//     output reg [7:0] arlen,
//     output reg [2:0] arsize,
//     output reg [1:0] arburst,

//     // R
//     input [id_width-1:0] rid,
//     input [data_width-1:0] rdata,
//     input [1:0] rresp,
//     input rlast,
//     input rvalid,
//     output reg rready,

//     // User Interface
//     input start_wr, start_rd,
//     input [addr_width-1:0] wr_addr, rd_addr,
//     input [7:0] wr_len, rd_len,
//     // Status
//     output reg wr_done, rd_done,
//     // Write Stream
//     input [data_width-1:0] wr_data_in,
//     output wire wr_next,
//     // Read Stream
//     output reg [data_width-1:0] rd_data_out,
//     output reg rd_valid_out
// );

    // localparam BURST_INCR = 2'b01;
    // localparam DATA_SIZE  = $clog2(data_width/8);

    // // Write
    // reg [2:0] wr_state;
    // reg [7:0] wr_cnt;

    // localparam S_WR_IDLE  = 3'd0,
    //            S_WR_AW    = 3'd1,
    //            S_WR_DATA  = 3'd2,
    //            S_WR_BRESP = 3'd3,
    //            S_WR_DONE  = 3'd4;

    // // Tín hiệu báo cho user chuẩn bị data tiếp theo (tương đương pop FIFO)
    // // Kích hoạt khi module đang gửi data và slave chấp nhận (handshake thành công)
    // assign wr_next = (wr_state == S_WR_DATA) && (wvalid && wready);
    // assign wdata = wr_data_in;

    // always @(posedge clk or posedge rst) begin
    //     if (rst) begin
    //         wr_state <= S_WR_IDLE;
    //         awvalid  <= 0;
    //         awid     <= 0;
    //         wvalid   <= 0;
    //         wlast    <= 0;
    //         bready   <= 0;
    //         wr_done  <= 0;
    //         wr_cnt   <= 0;
    //         // wdata    <= 0;
    //         wstrb    <= 0;

    //         awaddr   <= 0;
    //         awlen    <= 0;
    //         awsize   <= 0;
    //         awburst  <= 0;
    //     end else begin
    //         case (wr_state)
    //             S_WR_IDLE: begin
    //                 wr_done <= 0;
    //                 if (start_wr) begin
    //                     awid    <= 4'd1; 
    //                     awaddr  <= wr_addr;
    //                     awlen   <= wr_len - 1;
    //                     awsize  <= DATA_SIZE;
    //                     awburst <= BURST_INCR;
                        
    //                     awvalid <= 1;
    //                     wr_cnt  <= 0;
    //                     wr_state <= S_WR_AW;
    //                 end
    //             end

    //             S_WR_AW: begin
    //                 // Gửi địa chỉ
    //                 if (awvalid && awready) begin
    //                     awvalid <= 0;
                        
    //                     // Chuẩn bị vào pha data
    //                     wvalid <= 1;
    //                     // Map data từ input vào port wdata
    //                     // wdata  <= wr_data_in; 
    //                     wstrb  <= {(data_width/8){1'b1}};
    //                     // Kiểm tra nếu chỉ burst 1 beat
    //                     wlast  <= (awlen == 0);
                        
    //                     wr_state <= S_WR_DATA;
    //                 end
    //             end

    //             S_WR_DATA: begin
    //                 // Luôn cập nhật data mới nhất từ user vào bus
    //                 // (Lưu ý: user cần dùng wr_next để đổi data tại wr_data_in)
    //                 // wdata <= wr_data_in; 

    //                 if (wvalid && wready) begin
    //                     if (wr_cnt == awlen) begin
    //                         // Beat cuối cùng đã được gửi xong
    //                         wvalid <= 0;
    //                         wlast  <= 0;
    //                         wstrb  <= 0;
    //                         bready <= 1; // Sẵn sàng nhận response
    //                         wr_state <= S_WR_BRESP;
    //                     end else begin
    //                         // Tiếp tục gửi beat tiếp theo
    //                         wr_cnt <= wr_cnt + 1;
    //                         // Kiểm tra xem beat tiếp theo có phải beat cuối không
    //                         if (wr_cnt + 1 == awlen) 
    //                             wlast <= 1;
    //                     end
    //                 end
    //             end

    //             S_WR_BRESP: begin
    //                 // Chờ phản hồi từ Slave
    //                 if (bvalid && bready) begin
    //                     bready <= 0;
    //                     wr_done <= 1;
    //                     wr_state <= S_WR_DONE;
    //                 end
    //             end

    //             S_WR_DONE: begin
    //                 // Giữ wr_done 1 chu kỳ để user biết
    //                 wr_done <= 0;
    //                 wr_state <= S_WR_IDLE;
    //             end
    //         endcase
    //     end
    // end

//     // Read
//     reg [1:0] rd_state;
    
//     localparam S_RD_IDLE  = 2'd0,
//                S_RD_AR    = 2'd1,
//                S_RD_DATA  = 2'd2,
//                S_RD_DONE  = 2'd3;

//     always @(posedge clk or posedge rst) begin
//         if (rst) begin
//             rd_state     <= S_RD_IDLE;
//             arvalid      <= 0;
//             arid         <= 0;
//             rready       <= 0;
//             rd_done      <= 0;
            
//             araddr       <= 0;
//             arlen        <= 0;
//             arsize       <= 0;
//             arburst      <= 0;
            
//             rd_data_out  <= 0;
//             rd_valid_out <= 0;
//         end else begin
//             case (rd_state)
//                 S_RD_IDLE: begin
//                     rd_done <= 0;
//                     rd_valid_out <= 0; // Reset valid signal
//                     if (start_rd) begin
//                         arid    <= 4'd1;
//                         araddr  <= rd_addr;
//                         arlen   <= rd_len - 1;
//                         arsize  <= DATA_SIZE;
//                         arburst <= BURST_INCR;
                        
//                         arvalid <= 1;
//                         rd_state <= S_RD_AR;
//                     end
//                 end

//                 S_RD_AR: begin
//                     if (arvalid && arready) begin
//                         arvalid <= 0;
//                         rready  <= 1;
//                         rd_state <= S_RD_DATA;
//                     end
//                 end

//                 S_RD_DATA: begin
//                     // Mặc định valid out mức thấp, chỉ lên 1 khi handshake thành công
//                     rd_valid_out <= 0;

//                     if (rvalid && rready) begin
//                         // Đẩy data ra cho user
//                         rd_data_out <= rdata;
//                         rd_valid_out <= 1; // Báo hiệu data valid 1 chu kỳ

//                         // Kiểm tra tín hiệu last beat từ Slave
//                         if (rlast) begin
//                             rready <= 0;
//                             rd_done <= 1;
//                             rd_state <= S_RD_DONE;
//                         end
//                     end
//                 end

//                 S_RD_DONE: begin
//                     rd_valid_out <= 0;
//                     rd_done <= 0;
//                     rd_state <= S_RD_IDLE;
//                 end
//             endcase
//         end
//     end
// endmodule