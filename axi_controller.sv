module axi_controller #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter IMG_SIZE   = 784,         
    parameter OUTPUT_SIZE= 10,
    parameter NUM_IMGS   = 10,
    parameter INPUT_BASE_ADDR  = 32'h0000_0000,
    parameter OUTPUT_BASE_ADDR = 32'h0000_8000 
)(
    input wire clk,
    input wire rst_n,

    // AXI Master
    output reg        axi_start_rd,
    output reg [31:0] axi_rd_addr,
    output reg [7:0]  axi_rd_len,
    input  wire       axi_rd_done,
    
    output reg        axi_start_wr,
    output reg [31:0] axi_wr_addr,
    output reg [7:0]  axi_wr_len,
    input  wire       axi_wr_next, 
    output reg [31:0] axi_wr_data, 
    input  wire       axi_wr_done,

    // Ping Pong Buffer
    input  wire       pp_img_done, 
    output reg        pp_rd_bank_sel, 

    // Neural Network Wrapper
    output reg        nn_start,
    input  wire       nn_done,
    input  wire [31:0] nn_result [0:9] 
);

    // FSM
    typedef enum logic [2:0] {
        IDLE,
        READ_IMG, 
        UPDATE_ADDR,      
        WAIT_PROCESS,   
        WRITE_RESULT,   
        DONE
    } state_t;

    state_t current_state, next_state;

    reg [3:0] img_count;       
    reg [2:0] burst_count;     
    reg [3:0] res_idx;         
    
    reg [31:0] curr_rd_addr;
    reg [31:0] curr_wr_addr;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            img_count     <= 0;
            burst_count   <= 0;
            res_idx       <= 0;
            curr_rd_addr  <= INPUT_BASE_ADDR;
            curr_wr_addr  <= OUTPUT_BASE_ADDR;
            pp_rd_bank_sel<= 0;
        end else begin
            current_state <= next_state;

            case (current_state)
                IDLE: begin
                        img_count    <= 0;
                        burst_count  <= 0;
                        res_idx      <= 0;
                        curr_rd_addr <= INPUT_BASE_ADDR;
                        curr_wr_addr <= OUTPUT_BASE_ADDR;
                        pp_rd_bank_sel<= 0;
                end
                READ_IMG: begin
                    //
                end
                UPDATE_ADDR: begin
                    if (burst_count == 3) begin
                        burst_count <= 0;
                        pp_rd_bank_sel <= ~pp_rd_bank_sel; 
                    end else begin
                        burst_count <= burst_count + 1;
                    end
                    curr_rd_addr <= curr_rd_addr + IMG_SIZE; 
                end

                WRITE_RESULT: begin
                    if (axi_wr_next) begin
                        res_idx <= res_idx + 1;
                    end
                    if (axi_wr_done) begin
                        res_idx <= 0;
                        img_count <= img_count + 1;
                        curr_wr_addr <= curr_wr_addr + 32'd40;
                    end
                end
            endcase
        end
    end

    always @(*) begin
        next_state = current_state;
        
        case (current_state)
            IDLE: begin
                next_state = READ_IMG;
            end

            READ_IMG: begin
                if(axi_rd_done) begin
                    next_state = UPDATE_ADDR;
                end
            end

            UPDATE_ADDR: begin
                if(burst_count == 3) begin
                    next_state = WAIT_PROCESS;
                end else begin
                    next_state = READ_IMG;
                end
            end

            WAIT_PROCESS: begin
                if (nn_done)
                    next_state = WRITE_RESULT;
            end

            WRITE_RESULT: begin
                if (axi_wr_done) begin
                    if (img_count == NUM_IMGS - 1)
                        next_state = DONE;
                    else
                        next_state = READ_IMG;
                end
            end

            DONE: begin
                next_state = DONE;
            end
            default: next_state = IDLE;
        endcase
    end

    always @(*) begin
        axi_start_rd = 0;
        axi_rd_len   = 0;
        axi_rd_addr  = curr_rd_addr;

        axi_start_wr = 0;
        axi_wr_len   = 0;
        axi_wr_addr  = curr_wr_addr;
        axi_wr_data  = 0;

        nn_start     = 0;

        case (current_state)
            READ_IMG: begin
                if (!axi_rd_done) begin
                    axi_start_rd = 1;
                    axi_rd_len   = 8'd195; 
                end
            end

            WAIT_PROCESS: begin
                nn_start = 1;
            end

            WRITE_RESULT: begin
                if (!axi_wr_done) begin
                    axi_start_wr = 1;
                    axi_wr_len   = 8'd10; 
                end
                
                if (res_idx < 10)
                    axi_wr_data = nn_result[res_idx];
                else 
                    axi_wr_data = 32'd0;
            end
        endcase
    end

endmodule
