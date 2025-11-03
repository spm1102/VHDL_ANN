module neural_network #(
    parameter LAYER1_DATA_WIDTH = 32'd32,
    parameter LAYER1_NEURON_WIDTH = 32'd824,
    parameter LAYER1_NEURON_NUM = 32'd10,
    parameter LAYER1_B_BITS = 32'd32,

    parameter LAYER2_DATA_WIDTH = 32'd40,
    parameter LAYER2_NEURON_WIDTH = 32'd50,
    parameter LAYER2_NEURON_NUM = 32'd10,
    parameter LAYER2_B_BITS = 32'd64
) (
    input clk,
    input rst_n,

    input reg signed [LAYER1_DATA_WIDTH-1:0] input_data [0:LAYER1_NEURON_WIDTH-1],

    //weight & bias for layer 1
    input reg signed [LAYER1_DATA_WIDTH-1:0] weight_layer1[0:LAYER1_NEURON_NUM-1] [0:LAYER1_NEURON_WIDTH-1],
    input reg signed [LAYER1_B_BITS-1:0] bias_layer1 [0:LAYER1_NEURON_NUM-1],

    //weight & bias for layer 2
    input reg signed [LAYER2_DATA_WIDTH-1:0] weight_layer2[0:LAYER2_NEURON_NUM-1] [0:LAYER2_NEURON_WIDTH-1],
    input reg signed [LAYER2_B_BITS-1:0] bias_layer2 [0:LAYER2_NEURON_NUM-1],

    output reg signed [LAYER2_DATA_WIDTH+7:0] output_data [0:LAYER2_NEURON_NUM-1]
);
    wire signed [LAYER1_DATA_WIDTH+7:0] layer1_out [0:LAYER2_NEURON_WIDTH-1];

    assign layer1_out[0] = 40'h00000000;
    assign layer1_out[1] = 40'h00000000;
    assign layer1_out[2] = 40'h00000000;
    assign layer1_out[3] = 40'h00000000;
    assign layer1_out[4] = 40'h00000000;
    assign layer1_out[5] = 40'h00000000;
    assign layer1_out[6] = 40'h00000000;
    assign layer1_out[7] = 40'h00000000;
    assign layer1_out[8] = 40'h00000000;
    assign layer1_out[9] = 40'h00000000;
    assign layer1_out[10] = 40'h00000000;
    assign layer1_out[11] = 40'h00000000;
    assign layer1_out[12] = 40'h00000000;
    assign layer1_out[13] = 40'h00000000;
    assign layer1_out[14] = 40'h00000000;
    assign layer1_out[15] = 40'h00000000;
    assign layer1_out[16] = 40'h00000000;
    assign layer1_out[17] = 40'h00000000;
    assign layer1_out[18]= 40'h00000000;
    assign layer1_out[19] = 40'h00000000;
    assign layer1_out[30] = 40'h00000000;
    assign layer1_out[31] = 40'h00000000;
    assign layer1_out[32] = 40'h00000000;
    assign layer1_out[33] = 40'h00000000;
    assign layer1_out[34] = 40'h00000000;
    assign layer1_out[35] = 40'h00000000;
    assign layer1_out[36] = 40'h00000000;
    assign layer1_out[37] = 40'h00000000;
    assign layer1_out[38] = 40'h00000000;
    assign layer1_out[39] = 40'h00000000;
    assign layer1_out[40] = 40'h00000000;
    assign layer1_out[41] = 40'h00000000;
    assign layer1_out[42] = 40'h00000000;
    assign layer1_out[43] = 40'h00000000;
    assign layer1_out[44] = 40'h00000000;
    assign layer1_out[45] = 40'h00000000;
    assign layer1_out[46] = 40'h00000000;
    assign layer1_out[47] = 40'h00000000;
    assign layer1_out[48] = 40'h00000000;
    assign layer1_out[49] = 40'h00000000;

    layer #(
        .LAYER_DATA_WIDTH(LAYER1_DATA_WIDTH),
        .NEURON_NUM(LAYER1_NEURON_NUM),
        .NEURON_WIDTH(LAYER1_NEURON_WIDTH),
        .B_BITS(LAYER1_B_BITS)
    ) u_layer1 (
        .clk(clk),
        .rst_n(rst_n),
        .bias(bias_layer1),
        .data_in(input_data),
        .weights(weight_layer1),
        .activation_func(1'b1), // ReLU
        .data_out(layer1_out[20:29])
    );

    layer #(
        .LAYER_DATA_WIDTH(LAYER2_DATA_WIDTH),
        .NEURON_NUM(LAYER2_NEURON_NUM),
        .NEURON_WIDTH(LAYER2_NEURON_WIDTH),
        .B_BITS(LAYER2_B_BITS)
    ) u_layer2 (
        .clk(clk),
        .rst_n(rst_n),
        .bias(bias_layer2),
        .data_in(layer1_out),
        .weights(weight_layer2),
        .activation_func(1'b0), // Linear
        .data_out(output_data)
    );


endmodule