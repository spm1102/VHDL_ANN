module nn_model1 #(
    // Layer 1: 784 -> 64
    parameter LAYER1_DATA_WIDTH   = 32'd32,
    parameter LAYER1_NEURON_WIDTH = 32'd784,
    parameter LAYER1_NEURON_NUM   = 32'd64,
    parameter LAYER1_B_BITS       = 32'd32,

    // Layer 2: 64 -> 10
    parameter LAYER2_DATA_WIDTH   = LAYER1_DATA_WIDTH,
    parameter LAYER2_NEURON_WIDTH = LAYER1_NEURON_NUM,
    parameter LAYER2_NEURON_NUM   = 32'd10,
    parameter LAYER2_B_BITS       = 32'd32,

    parameter FRAC_BITS           = 24
) (
    input clk,
    input rst_n,

    input  reg signed [LAYER1_DATA_WIDTH-1:0] input_data   [0:LAYER1_NEURON_WIDTH-1],

    // output img_ready,
    output reg signed [LAYER2_DATA_WIDTH-1:0] output_data [0:LAYER2_NEURON_NUM-1]
);
    reg signed [LAYER1_DATA_WIDTH-1:0] weight_layer1 [0:LAYER1_NEURON_NUM-1][0:LAYER1_NEURON_WIDTH-1];
    reg signed [LAYER1_B_BITS-1:0]     bias_layer1   [0:LAYER1_NEURON_NUM-1];
    
    reg signed [LAYER2_DATA_WIDTH-1:0] weight_layer2 [0:LAYER2_NEURON_NUM-1][0:LAYER2_NEURON_WIDTH-1];
    reg signed [LAYER2_B_BITS-1:0]     bias_layer2   [0:LAYER2_NEURON_NUM-1];


    initial begin
        $readmemh("D:/HUST/2025.1/vhdl/model1_no_bin/196_bin/fc1_weight196_bin.mem", weight_layer1);
        $readmemh("D:/HUST/2025.1/vhdl/model1_no_bin/196_bin/fc1_bias196_bin.mem",   bias_layer1);
        $readmemh("D:/HUST/2025.1/vhdl/model1_no_bin/196_bin/fc2_weight196_bin.mem", weight_layer2);
        $readmemh("D:/HUST/2025.1/vhdl/model1_no_bin/196_bin/fc2_bias196_bin.mem",   bias_layer2);
    end
    wire signed [LAYER2_DATA_WIDTH-1:0] layer1_out [0:LAYER2_NEURON_WIDTH-1];

    layer1 #(
        .LAYER_DATA_WIDTH(LAYER1_DATA_WIDTH),
        .NEURON_NUM      (LAYER1_NEURON_NUM),
        .NEURON_WIDTH    (LAYER1_NEURON_WIDTH),
        .B_BITS          (LAYER1_B_BITS),
        .FRAC_BITS       (FRAC_BITS)
    ) u_layer1 (
        .clk            (clk),
        .rst_n          (rst_n),
        .bias           (bias_layer1),
        .data_in        (input_data),
        .weights        (weight_layer1),
        .activation_func(1'b1),           // ReLU
        .data_out       (layer1_out)
    );

    layer #(
        .LAYER_DATA_WIDTH(LAYER2_DATA_WIDTH),
        .NEURON_NUM      (LAYER2_NEURON_NUM),
        .NEURON_WIDTH    (LAYER2_NEURON_WIDTH),
        .B_BITS          (LAYER2_B_BITS),
        .FRAC_BITS       (FRAC_BITS)
    ) u_layer2 (
        .clk            (clk),
        .rst_n          (rst_n),
        .bias           (bias_layer2),
        .data_in        (layer1_out),
        .weights        (weight_layer2),
        .activation_func(1'b0),           // Linear
        .data_out       (output_data)
    );


endmodule
