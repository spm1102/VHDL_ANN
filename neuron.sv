module neuron #(
    parameter LAYER_DATA_WIDTH,
    parameter NEURON_NUM,
    parameter B_BITS
) (
    input clk,
    input rst_n,
    input activation_func,
    input reg signed [31 : 0] weights [0:NEURON_NUM - 1],
    input reg signed [LAYER_DATA_WIDTH-1 : 0] data_in [0:NEURON_NUM - 1],
    input reg signed [B_BITS-1 : 0] bias,
    
    output reg signed [LAYER_DATA_WIDTH + 7 : 0] neuron_out
); 

wire signed [31 : 0] bus_w;
wire signed [LAYER_DATA_WIDTH-1 : 0] bus_x;

reg signed [LAYER_DATA_WIDTH + 32 -1 : 0] mult_result;
reg signed [LAYER_DATA_WIDTH + 32 + 7 : 0] adder_result;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        neuron_out <= 0;
    end
    else begin
        integer i;
        adder_result = 0;
        for (i = 0; i < NEURON_NUM; i = i + 1) begin
            bus_w = weights[i];
            bus_x = data_in[i];
            mult_result = bus_w * bus_x;
            adder_result = adder_result + mult_result;
        end
        // Apply activation function (ReLU)
        if (activation_func) begin
            if (!adder_result[LAYER_DATA_WIDTH + 7]) begin
                neuron_out <= adder_result[LAYER_DATA_WIDTH + 7 : 0];
            end
            else begin
                neuron_out <= 0;
            end
        end
        else begin
            neuron_out <= adder_result[LAYER_DATA_WIDTH + 7 : 0];
        end
    end
end
endmodule