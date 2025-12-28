module nn_wrapper #(
    parameter DATA_WIDTH = 32,
    parameter IMG_SIZE   = 784
)(
    input wire clk,
    input wire rst_n,
    
    // Control
    input  wire start,
    output reg  done,

    // Interface Ping Pong Buffer (Read Port)
    output reg [31:0] pp_rd_addr,
    input  wire [31:0] pp_rd_data,

    output reg [31:0] results [0:9]
);

    reg signed [31:0] nn_input_array [0:IMG_SIZE-1];
    
    // Output wire từ NN
    wire signed [31:0] nn_output_array [0:9];

    reg [9:0] load_cnt;
    reg       loading;
    reg       calculating;
    reg [3:0] calc_wait; 

    nn_model1 u_ann (
        .clk(clk),
        .rst_n(rst_n),
        .input_data(nn_input_array),
        .output_data(nn_output_array)
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            load_cnt    <= 0;
            pp_rd_addr  <= 0;
            loading     <= 0;
            calculating <= 0;
            done        <= 0;
            calc_wait   <= 0;
        end else begin
            done <= 0; // Pulse done

            if (start && !loading && !calculating) begin
                loading    <= 1;
                load_cnt   <= 0;
                pp_rd_addr <= 0;
            end

            if (loading) begin
                if (load_cnt > 0) begin
                    nn_input_array[load_cnt - 1] <= pp_rd_data;
                end

                if (load_cnt == IMG_SIZE) begin
                    loading     <= 0;
                    calculating <= 1;
                    load_cnt    <= 0;
                end else begin
                    load_cnt    <= load_cnt + 1;
                    pp_rd_addr  <= pp_rd_addr + 1;
                end
            end

            if (calculating) begin
                if (calc_wait == 10) begin 
                    for (int i=0; i<10; i++) begin
                        results[i] <= nn_output_array[i];
                    end
                    done        <= 1;
                    calculating <= 0;
                    calc_wait   <= 0;
                end else begin
                    calc_wait <= calc_wait + 1;
                end
            end
        end
    end

endmodule