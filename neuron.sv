module neuron #(
    parameter LAYER_DATA_WIDTH,
    parameter NEURON_WIDTH,
    parameter B_BITS,
    parameter FRAC_BITS // n
) (
    input clk,
    input rst_n,
    input activation_func,
    
    input reg signed [LAYER_DATA_WIDTH-1 : 0] weights [0 : NEURON_WIDTH-1],
    input reg signed [LAYER_DATA_WIDTH-1 : 0] data_in [0 : NEURON_WIDTH-1],
    input reg signed [B_BITS-1 : 0] bias, // ?

    output reg signed [LAYER_DATA_WIDTH-1: 0] neuron_out
);

    reg signed [LAYER_DATA_WIDTH-1 : 0] bus_w;
    reg signed [LAYER_DATA_WIDTH-1 : 0] bus_x;
    
    reg signed [63:0] mul_result;       // 32x32 -> 64 bit
    reg signed [63:0] adder_result;     // accumulator Q(2m).(2n)
    reg signed [63:0] adder_with_bias;
    reg signed [63:0] bias_ext;
    reg signed [LAYER_DATA_WIDTH-1 : 0] acc_q;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            neuron_out <= 0;
        else begin
            integer i;
            adder_result = 0;
            for (i = 0; i < NEURON_WIDTH; i = i + 1) begin
                bus_w = weights[i];
                bus_x = data_in[i];
                mul_result = bus_w * bus_x;
                // mul_result = $signed(bus_w) * $signed(bus_x);
                adder_result = adder_result + mul_result;
            end
            bias_ext = bias;
            // adder_result = adder_result + bias;
            adder_result = adder_result + (bias_ext <<< FRAC_BITS); // align bias
            acc_q = adder_result >> (FRAC_BITS);
            // ReLU
            if (activation_func) begin
                if (acc_q > 0)
                    neuron_out <= acc_q;
                else
                    neuron_out <= 0;
            end
            else
                neuron_out <= acc_q;
        end
    end
endmodule