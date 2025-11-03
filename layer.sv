module layer #(
    parameter LAYER_DATA_WIDTH,
    parameter NEURON_NUM,
    parameter NEURON_WIDTH,
    parameter B_BITS
)(
    input clk,
    input rst_n,

    input reg signed [B_BITS-1 : 0] bias [0: NEURON_NUM-1],
    input reg signed [LAYER_DATA_WIDTH-1:0]data_in [0: NEURON_WIDTH-1],
    input reg signed [31:0] weights [0: NEURON_NUM-1][0: NEURON_WIDTH-1],
    input activation_func,

    output signed [LAYER_DATA_WIDTH+7 : 0] data_out [0: NEURON_NUM - 1]
);

    genvar i;
    generate
        for (i = 0; i < NEURON_NUM; i = i + 1) begin : gen_neuron
            neuron #(
                .LAYER_DATA_WIDTH(LAYER_DATA_WIDTH),
                .NEURON_WIDTH(NEURON_WIDTH),
                .B_BITS(B_BITS)
            ) u_neuron (
                .clk(clk),
                .rst_n(rst_n),
                .activation_func(activation_func),
                .weights(weights[i]),
                .data_in(data_in),
                .bias(bias[i]),
                .neuron_out(data_out[i])
            );
        end
    endgenerate
endmodule