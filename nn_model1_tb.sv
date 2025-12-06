`timescale 1ns / 1ps
module nn_model1_tb #(
    parameter LAYER1_DATA_WIDTH   = 32'd32,
    parameter LAYER1_NEURON_WIDTH = 32'd784,
    parameter LAYER1_NEURON_NUM   = 32'd64,
    parameter LAYER1_B_BITS       = 32'd32,

    parameter LAYER2_DATA_WIDTH   = 32'd32,
    parameter LAYER2_NEURON_WIDTH = 32'd64,
    parameter LAYER2_NEURON_NUM   = 32'd10,
    parameter LAYER2_B_BITS       = 32'd32
);
  reg signed [31:0] weight_layer1[0:LAYER1_NEURON_NUM-1] [0:LAYER1_NEURON_WIDTH-1];
  
  reg signed [31:0] data_in [0:LAYER1_NEURON_WIDTH-1];
  
  reg signed [31:0] weight_layer2[0:LAYER2_NEURON_NUM-1] [0:LAYER2_NEURON_WIDTH-1];
  
  reg signed [LAYER1_B_BITS-1:0] b1 [0:LAYER1_NEURON_NUM-1];
  reg signed [LAYER2_B_BITS-1:0] b2 [0:LAYER2_NEURON_NUM-1];
  
  reg clk;
  reg rst_n;
  
//   wire signed [LAYER2_DATA_WIDTH-1:0] neuralnet_out [0:LAYER2_NEURON_NUM-1];
    wire signed [LAYER2_DATA_WIDTH-1:0] neuralnet_out [0:LAYER2_NEURON_NUM-1];
  
  nn_model1 #(
    .LAYER1_DATA_WIDTH(LAYER1_DATA_WIDTH),
    .LAYER1_NEURON_WIDTH(LAYER1_NEURON_WIDTH),
    .LAYER1_NEURON_NUM(LAYER1_NEURON_NUM),
    .LAYER1_B_BITS(LAYER1_B_BITS),
    .LAYER2_DATA_WIDTH(LAYER2_DATA_WIDTH),
    .LAYER2_NEURON_WIDTH(LAYER2_NEURON_WIDTH),
    .LAYER2_NEURON_NUM(LAYER2_NEURON_NUM),
    .LAYER2_B_BITS(LAYER2_B_BITS)
  ) uut (
    .clk(clk),
    .rst_n(rst_n),
    .input_data(data_in),
    .weight_layer1(weight_layer1),
    .bias_layer1(b1),
    .weight_layer2(weight_layer2),
    .bias_layer2(b2),
    .output_data(neuralnet_out)
  );
  
  always #5 clk = ~clk;
  
    integer k;

    initial begin
        $readmemh("ann_torch/weights_hex/model1_no_bin/fc1_weight.mem", weight_layer1);
        $readmemh("ann_torch/weights_hex/model1_no_bin/fc2_weight.mem", weight_layer2);
        $readmemh("ann_torch/weights_hex/model1_no_bin/input.mem",      data_in);
        $readmemh("ann_torch/weights_hex/model1_no_bin/fc1_bias.mem",   b1);
        $readmemh("ann_torch/weights_hex/model1_no_bin/fc2_bias.mem",   b2);
        
        clk   <= 0;
        rst_n <= 0;
        
        #20 rst_n <= 1;
        #20000;
        
        $display("==== RAW LOGITS (Q8.24) ====");
        for (k = 0; k < LAYER2_NEURON_NUM; k = k + 1) begin
            $display("logit[%0d] = %h (%0d)", 
                    k, neuralnet_out[k], neuralnet_out[k]);
        end

        #20 $finish;
    end
endmodule
