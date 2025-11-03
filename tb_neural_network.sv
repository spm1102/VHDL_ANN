`timescale 1ns / 1ps
module tb_neural_network #(    
    parameter LAYER1_DATA_WIDTH = 32'd32,
    parameter LAYER1_NEURON_WIDTH = 32'd824,
    parameter LAYER1_NEURON_NUM = 32'd10,
    parameter LAYER1_B_BITS = 32'd32,

    parameter LAYER2_DATA_WIDTH = 32'd40,
    parameter LAYER2_NEURON_WIDTH = 32'd50,
    parameter LAYER2_NEURON_NUM = 32'd10,
    parameter LAYER2_B_BITS = 32'd64);
  //weights 1
  reg signed [31:0] weight_layer1[0:LAYER1_NEURON_NUM-1] [0:LAYER1_NEURON_WIDTH-1];
  
  //image data
  reg signed [31:0] data_in [0:LAYER1_NEURON_WIDTH-1];
  
  //weights 2
  reg signed [31:0] weight_layer2[0:LAYER2_NEURON_NUM-1] [0:LAYER2_NEURON_WIDTH-1];
  
  //b-values
  reg signed [LAYER1_B_BITS-1:0] b1 [0:LAYER1_NEURON_NUM-1];
  reg signed [LAYER2_B_BITS-1:0] b2 [0:LAYER2_NEURON_NUM-1];
  
  reg clk;
  reg rst_n;
  
  wire signed [LAYER2_DATA_WIDTH+7:0] neuralnet_out [0:LAYER2_NEURON_NUM-1];
  
  neural_network #(
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
  
  //always #10 $display("%h", layer_out[0]);
  
  initial begin
  
    $readmemh("D:\HUST\2025.1\vhdl\project_final\weight_layer1.mem", weight_layer1);
    
    $readmemh("D:\HUST\2025.1\vhdl\project_final\weight_layer2.mem", weight_layer2);
    
    $readmemh("D:\HUST\2025.1\vhdl\project_final\data_in.mem", data_in);
    
    $readmemh("D:\HUST\2025.1\vhdl\project_final\b1.mem", b1);
    $readmemh("D:\HUST\2025.1\vhdl\project_final\b2.mem", b2);
    $dumpfile("wave.vcd");
    $dumpvars();
    
    clk <= 0;
    rst_n <= 0;
    //b <= 16'hfe3d;
    
    #20 rst_n <= 1;
    //#80 rstn <= 0;
    //#50 rstn <= 1;
    #20000;
    
    #20 $finish;
    
  end
  
endmodule