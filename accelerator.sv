module accelerator #(
  AXI_DW_g = 64,
  AXI_AW_g = 32,

  W_g = 8,
  R_g = 8,
  K_g = 1
)(
  input  logic                clk_i,
  input  logic                rst_n_i,
  
  output logic                s_axi_awready_o,
  input  logic                s_axi_awvalid_i,
  input  logic [AXI_AW_g-1:0] s_axi_awaddr_i,
  input  logic [7:0]          s_axi_awlen_i,
  input  logic [2:0]          s_axi_awsize_i,
  input  logic [1:0]          s_axi_awburst_i,
  input  logic [2:0]          s_axi_awprot_i,  // Not used!
  input  logic [3:0]          s_axi_awcache_i, // Not used!
  
  output logic                s_axi_wready_o,
  input  logic                s_axi_wvalid_i,
  input  logic [AXI_DW_g-1:0] s_axi_wdata_i,
  input  logic [3:0]          s_axi_wstrb_i,
  input  logic                s_axi_wlast_i,

  input  logic                s_axi_bready_i,
  output logic                s_axi_bvalid_o,
  output logic [1:0]          s_axi_bresp_o
);

logic [W_g*R_g-1:0] data_s;
logic [W_g-1:0]     skew_regs_s[0:R_g/K_g-1][0:R_g/K_g-1];
logic [W_g-1:0]     A_s[0:R_g-1][0:K_g-1];

double_buffer_slv # (
  .AXI_DW_g(AXI_DW_g),
  .AXI_AW_g(AXI_AW_g)
)
input_buffer_0 (
  .*,
  .data_o(data_s)
);

always_ff @(posedge clk_i) begin
  if (!rst_n_i) begin
    for (int i = 0; i < R_g; i++) begin
      skew_regs_s[i] <= '{default: 'd0};
    end
  end else begin
    for (int i = 0; i < R_g; i++) begin
      skew_regs_s[i][0] <= data_s[i*W_g+:W_g];
    end

    for (int i = 1; i < R_g; i++) begin
      for (int j = 1; j <= i; j++) begin
        skew_regs_s[i][j] <= skew_regs_s[i][j-1];
      end
    end
  end
end

always_comb begin
  for (int i = 0; i < R_g; i++) begin
    A_s[i][0] = skew_regs_s[i][i]; // Expect K_g = 1
  end
end

systolic # (
  .W(W_g),
  .R(R_g),
  .K(K_g)
) systolic_0 (
  .clk     (clk_i),
  .load    ('d0),
  .a_in    (A_s),
  .w_in    (),
  .sum_in  ('{default: '0}),
  .sum_out (),
  .w_out   (),
  .a_out   ()
);

endmodule