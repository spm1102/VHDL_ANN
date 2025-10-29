module neuron #(
    parameter DATA_WIDTH ,
    parameter NEURON_WIDTH,
    parameter NEURON_BITS,
    parameter COUNTER_END,
    parameter B_BITS
) (
    input clk,
    input rst_n,
    input activation_func,
    input reg signed [DATA_WIDTH-1 : 0] weights [0:NEURON_WIDTH - 1],
    input reg signed [NEURON_BITS-1 : 0] data_in [0:NEURON_WIDTH - 1],
    input reg signed [B_BITS-1 : 0] bias,
    
    output reg signed [NEURON_BITS + 7 : 0] neuron_out
); 

wire signed [DATA_WIDTH-1 : 0] bus_w;
wire signed [NEURON_BITS-1 : 0] bus_x;

reg signed [DATA_WIDTH + NEURON_BITS -1 : 0] mult_result;
reg signed [DATA_WIDTH + NEURON_BITS + 7 : 0] adder_result;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        neuron_out <= 0;
    end
    else begin
        integer i;
        adder_result = 0;
        for (i = 0; i < NEURON_WIDTH; i = i + 1) begin
            bus_w = weights[i];
            bus_x = data_in[i];
            mult_result = bus_w * bus_x;
            adder_result = adder_result + mult_result;
        end
        // Apply activation function (ReLU)
        if (activation_func) begin
            if (adder_result > 0) begin
                neuron_out <= adder_result[NEURON_BITS + 7 : 0];
            end
            else begin
                neuron_out <= 0;
            end
        end
        else begin
            neuron_out <= adder_result[NEURON_BITS + 7 : 0];
        end
    end
end
endmodule