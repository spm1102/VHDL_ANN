module neuron_layer1 #(
    parameter LAYER_DATA_WIDTH = 32,
    parameter NEURON_WIDTH     = 784,
    parameter B_BITS           = 32,
    parameter FRAC_BITS         = 24
) (
    input  clk,
    input  rst_n,
    input  activation_func,
    input  signed [LAYER_DATA_WIDTH-1:0] weights [0:NEURON_WIDTH-1],
    input  signed [LAYER_DATA_WIDTH-1:0] data_in [0:NEURON_WIDTH-1], 
    input  signed [B_BITS-1:0]           bias,

    output reg signed [LAYER_DATA_WIDTH-1:0] neuron_out
);
    localparam ACC_WIDTH = LAYER_DATA_WIDTH + 10 + 2; 

    reg signed [ACC_WIDTH-1:0] acc;
    reg signed [ACC_WIDTH-1:0] w_ext;
    reg signed [ACC_WIDTH-1:0] b_ext;

    // Saturation bounds
    localparam signed [31:0] MAX_POS = 32'sh7FFF_FFFF;
    localparam signed [31:0] MIN_NEG = 32'sh8000_0000;

    wire signed [ACC_WIDTH-1:0] max_ext;
    wire signed [ACC_WIDTH-1:0] min_ext;

    integer i;

    assign max_ext = {{(ACC_WIDTH-LAYER_DATA_WIDTH){MAX_POS[LAYER_DATA_WIDTH-1]}}, MAX_POS};
    assign min_ext = {{(ACC_WIDTH-LAYER_DATA_WIDTH){MIN_NEG[LAYER_DATA_WIDTH-1]}}, MIN_NEG};

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            neuron_out <= 32'd0;
        end else begin
            b_ext = {{(ACC_WIDTH-B_BITS){bias[B_BITS-1]}}, bias};
            acc   = b_ext;

            for (i = 0; i < NEURON_WIDTH; i = i + 1) begin
                if (data_in[i] != 32'd0) begin
                    w_ext = {{(ACC_WIDTH-LAYER_DATA_WIDTH){weights[i][LAYER_DATA_WIDTH-1]}}, weights[i]};
                    acc   = acc + w_ext;
                end
            end

            // ReLU & Saturation
            if (activation_func && (acc < 0)) begin 
                neuron_out <= 32'd0;
            end else begin
                if (acc > max_ext) begin
                    neuron_out <= MAX_POS;
                end else if (acc < min_ext) begin
                    neuron_out <= MIN_NEG;
                end else begin
                    neuron_out <= acc[LAYER_DATA_WIDTH-1:0];
                end
            end
        end
    end

endmodule