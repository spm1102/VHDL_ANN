`timescale 1ns / 1ps

module system_top_tb;

    parameter AXI_ADDR_WIDTH = 32;
    parameter AXI_DATA_WIDTH = 32;
    parameter AXI_ID_WIDTH   = 4;
    
    parameter INPUT_BASE_ADDR  = 32'h0000_0000;
    parameter OUTPUT_BASE_ADDR = 32'h0000_5000; 
    parameter NUM_IMGS         = 10;             
    parameter IMG_SIZE         = 196;          

    reg clk;
    reg rst_n;

    // AXI Slave 
    wire [AXI_ID_WIDTH-1:0] awid;
    wire [AXI_ADDR_WIDTH-1:0] awaddr;
    wire [7:0] awlen;
    wire [2:0] awsize;
    wire [1:0] awburst;
    wire awvalid;
    reg  awready;

    wire [AXI_DATA_WIDTH-1:0] wdata;
    wire [(AXI_DATA_WIDTH/8)-1:0] wstrb;
    wire wlast;
    wire wvalid;
    reg  wready;

    reg  [AXI_ID_WIDTH-1:0] bid;
    reg  [1:0] bresp;
    reg  bvalid;
    wire bready;

    wire [AXI_ID_WIDTH-1:0] arid;
    wire [AXI_ADDR_WIDTH-1:0] araddr;
    wire [7:0] arlen;
    wire [2:0] arsize;
    wire [1:0] arburst;
    wire arvalid;
    reg  arready;

    reg  [AXI_ID_WIDTH-1:0] rid;
    reg  [AXI_DATA_WIDTH-1:0] rdata;
    reg  [1:0] rresp;
    reg  rlast;
    reg  rvalid;
    wire rready;

    // 128KB RAM mô phỏng
    reg [31:0] ram_memory [0:32767]; 

    system_top #(
        .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
        .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
        .AXI_ID_WIDTH(AXI_ID_WIDTH)
    ) u_dut (
        .clk(clk),
        .rst_n(rst_n),
        
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
        .rready(rready)
    );

    initial begin
        clk = 0;
        forever #5 clk = ~clk; 
    end

    integer i;
    initial begin
        rst_n = 0;
        init_axi_slave();
        init_ram_data(); 

        #100;
        rst_n = 1;
        $display("[%0t] Reset released. System start.", $time);

        #45000; 

        check_results();

        $display("[%0t] Simulation Finished.", $time);
        $stop;
    end

// task init_ram_data();
//         integer img, px;
//         // Dùng integer để tránh tràn số khi tính toán địa chỉ byte
//         integer ram_idx; 
//         begin
//             // 1. Xóa sạch RAM
//             $display("[%0t] INIT_RAM: Clearing memory...", $time);
//             for(i=0; i<16384; i=i+1) ram_memory[i] = 32'd0;

//             // 2. Tính chỉ số bắt đầu trong mảng RAM (Word Index)
//             // INPUT_BASE_ADDR là địa chỉ Byte, chia 4 để ra địa chỉ Word cho mảng ram_memory
//             ram_idx = INPUT_BASE_ADDR / 4; 
            
//             // 3. Vòng lặp nạp dữ liệu
//             for (img = 0; img < NUM_IMGS; img = img + 1) begin
//                 $display("[%0t] INIT_RAM: Generating Image %0d starting at RAM_INDEX %0d", $time, img, ram_idx);
                
//                 for (px = 0; px < IMG_SIZE; px = px + 1) begin
//                     // Ghi dữ liệu: Pixel 0, 1, 2...
//                     ram_memory[ram_idx + px] = px; 
//                 end
                
//                 // Debug kiểm tra điểm cuối của ảnh này
//                 $display("    -> Wrote up to RAM_INDEX %0d (Value: %h)", 
//                          ram_idx + IMG_SIZE - 1, ram_memory[ram_idx + IMG_SIZE - 1]);

//                 // Nhảy đến vùng nhớ ảnh tiếp theo (784 words)
//                 ram_idx = ram_idx + IMG_SIZE; 
//             end
//             $display("[%0t] INIT_RAM: Done.", $time);
//         end
//     endtask

    task init_ram_data();
        begin
            for(i=0; i<32767; i=i+1) ram_memory[i] = 32'd0;

            $readmemh("D:/HUST/2025.1/vhdl/model1_no_bin/input_10_3_29.mem", ram_memory, 0); 
            $display("Data loaded from input_images.mem");
        end
    endtask

    task check_results();
        integer img, cls;
        reg [31:0] res_base_ptr;
        reg [31:0] val;
        begin
            $display("\n--- CHECKING OUTPUT RESULTS ---");
            res_base_ptr = OUTPUT_BASE_ADDR >> 2; 

            for (img = 0; img < NUM_IMGS; img = img + 1) begin
                $display("Result for Image %0d (Starts at RAM index %h):", img, res_base_ptr);
                for (cls = 0; cls < 10; cls = cls + 1) begin
                    val = ram_memory[res_base_ptr + cls];
                    $display("  Class %0d: %d (Hex: %h)", cls, $signed(val), val);
                end
                res_base_ptr = res_base_ptr + 10;
            end
            $display("-------------------------------\n");
        end
    endtask

    task init_axi_slave();
        begin
            awready = 0;
            wready  = 0;
            bvalid  = 0;
            bresp   = 0;
            bid     = 0;
            arready = 0;
            rvalid  = 0;
            rdata   = 0;
            rresp   = 0;
            rlast   = 0;
            rid     = 0;
        end
    endtask


    // AXI4 SLAVE

    
    reg [AXI_ADDR_WIDTH-1:0] r_addr_latch;
    reg [7:0]                r_len_latch;
    reg [7:0]                r_count;
    reg                      r_busy;

    wire [31:0] internal_rdata;
    assign internal_rdata = ram_memory[(r_addr_latch >> 2) + r_count];

    always @(*) rdata = internal_rdata; 

    always @(posedge clk) begin
        if (!rst_n) begin
            arready <= 0;
            rvalid  <= 0;
            rlast   <= 0;
            r_busy  <= 0;
            r_count <= 0;
        end else begin
            // AR Handshake
            if (!r_busy) begin
                arready <= 1; 
                if (arvalid && arready) begin
                    r_addr_latch <= araddr;
                    r_len_latch  <= arlen;
                    rid          <= arid;
                    r_count      <= 0;
                    r_busy       <= 1;
                    arready      <= 0; 
                    rvalid       <= 1; 
                end
            end 
            
            if (r_busy) begin
                
                if (r_count == r_len_latch) rlast <= 1;
                else                        rlast <= 0;
                if (rvalid && rready) begin
                    if (rlast) begin
                        r_busy  <= 0;
                        rvalid  <= 0;
                        rlast   <= 0;
                        arready <= 1; 
                        r_count <= 0;
                    end else begin
                        r_count <= r_count + 1; 
                    end
                end
            end
        end
    end

    // WRITE CHANNEL LOGIC 
    reg [AXI_ADDR_WIDTH-1:0] w_addr_latch;
    reg                      w_active; 

    always @(posedge clk) begin
        if (!rst_n) begin
            awready  <= 0;
            wready   <= 0;
            bvalid   <= 0;
            bresp    <= 2'b00;
            bid      <= 0;
            w_active <= 0;
            w_addr_latch <= 0;
        end else begin
            //  AW: Address Write
            if (!w_active && !bvalid) begin
                awready <= 1;
                if (awvalid) begin
                    w_addr_latch <= awaddr;
                    bid          <= awid;
                    w_active     <= 1; 
                    awready      <= 0; 
                end
            end else begin
                awready <= 0;
            end


            //  W: Write Data
            if (w_active) begin
                if (!wready) begin
                    wready <= 1; 
                end else if (wvalid) begin                   
                    ram_memory[w_addr_latch >> 2] <= wdata;
                    $display("[%0t] RAM Write: Addr=0x%h, Data=%d", $time, w_addr_latch, $signed(wdata));
                    w_addr_latch <= w_addr_latch + 4;
                    wready <= 0; 

                    if (wlast) begin
                        w_active <= 0; 
                        bvalid   <= 1; 
                        wready   <= 0; 
                    end
                end
            end

            // B: Write Response
            if (bvalid && bready) begin
                bvalid <= 0; 
            end
        end
    end

endmodule