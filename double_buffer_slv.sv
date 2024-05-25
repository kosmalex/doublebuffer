module double_buffer_slv #(
  AXI_DW_g = 64,
  AXI_AW_g = 32
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

logic       avail_buffer_s[2];
logic       continue_buffer_s[2];
logic [2:0] aw_size_s[2];
logic [2:0] aw_burst_type_s[2];
logic       grant_buffer_s[2];

logic                s_axi_awready_s[2];
logic                s_axi_awvalid_s[2];
logic [AXI_AW_g-1:0] s_axi_awaddr_s[2];
logic [7:0]          s_axi_awlen_s[2];
logic [2:0]          s_axi_awsize_s[2];
logic [1:0]          s_axi_awburst_s[2];
logic [2:0]          s_axi_awprot_s[2];
logic [3:0]          s_axi_awcache_s[2];
logic                s_axi_wready_s[2];
logic                s_axi_wvalid_s[2];
logic [AXI_DW_g-1:0] s_axi_wdata_s[2];
logic [3:0]          s_axi_wstrb_s[2];
logic                s_axi_wlast_s[2];
logic                s_axi_bready_s[2];
logic                s_axi_bvalid_s[2];
logic [1:0]          s_axi_bresp_s[2];

generate
  genvar i;
  for (i = 0; i < 2; i++) begin : buffer_module
    blocking_buffer_slv # (
      .AXI_DW_g(AXI_DW_g),
      .AXI_AW_g(AXI_AW_g)
    )
    buffer (
      .clk_i           (clk_i),
      .rst_n_i         (rst_n_i),

      .s_axi_awready_o (s_axi_awready_s[i]),
      .s_axi_awvalid_i (s_axi_awvalid_i),
      .s_axi_awaddr_i  (s_axi_awaddr_i),
      .s_axi_awlen_i   (s_axi_awlen_i),
      .s_axi_awsize_i  (s_axi_awsize_i),
      .s_axi_awburst_i (s_axi_awburst_i),
      .s_axi_awprot_i  (s_axi_awprot_i),
      .s_axi_awcache_i (s_axi_awcache_i),
      .s_axi_wready_o  (s_axi_wready_s[i]),
      .s_axi_wvalid_i  (s_axi_wvalid_i),
      .s_axi_wdata_i   (s_axi_wdata_i),
      .s_axi_wstrb_i   (s_axi_wstrb_i),
      .s_axi_wlast_i   (s_axi_wlast_i),
      .s_axi_bready_i  (s_axi_bready_i),
      .s_axi_bvalid_o  (s_axi_bvalid_s[i]),
      .s_axi_bresp_o   (s_axi_bresp_s[i]),
      
      .grant_i         (grant_buffer_s[i]),
      .aw_burst_type_i (aw_burst_type_s[1-i]),
      .aw_size_i       (aw_size_s[1-i]),
      .continue_i      (continue_buffer_s[1-i]),
      .continue_o      (continue_buffer_s[i]),
      .aw_size_o       (aw_size_s[i]),
      .aw_burst_type_o (aw_burst_type_s[i]),

      .available_o     (avail_buffer_s[i])
    );
  end
endgenerate

always_comb begin
  if (avail_buffer_s[0]) begin
    grant_buffer_s[0] = 1'b1;
    grant_buffer_s[1] = 1'b0;
  end else if (avail_buffer_s[1]) begin
    grant_buffer_s[0] = 1'b0;
    grant_buffer_s[1] = 1'b1;
  end else begin
    grant_buffer_s[0] = 1'b0;
    grant_buffer_s[1] = 1'b0;
  end
end

always_comb begin
  if (avail_buffer_s[0]) begin
    s_axi_awready_o    = s_axi_awready_s[0];
    s_axi_awvalid_s[0] = s_axi_awvalid_i;
    s_axi_awaddr_s[0]  = s_axi_awaddr_i;
    s_axi_awlen_s[0]   = s_axi_awlen_i;
    s_axi_awsize_s[0]  = s_axi_awsize_i;
    s_axi_awburst_s[0] = s_axi_awburst_i;
    s_axi_awprot_s[0]  = s_axi_awprot_i;
    s_axi_awcache_s[0] = s_axi_awcache_i;
    s_axi_wready_o     = s_axi_wready_s[0];
    s_axi_wvalid_s[0]  = s_axi_wvalid_i;
    s_axi_wdata_s[0]   = s_axi_wdata_i;
    s_axi_wstrb_s[0]   = s_axi_wstrb_i;
    s_axi_wlast_s[0]   = s_axi_wlast_i;
    s_axi_bready_s[0]  = s_axi_bready_i;
    s_axi_bvalid_o     = s_axi_bvalid_s[0];
    s_axi_bresp_o      = s_axi_bresp_s[0];
  end else begin
    s_axi_awready_o    = s_axi_awready_s[1];
    s_axi_awvalid_s[1] = s_axi_awvalid_i;
    s_axi_awaddr_s[1]  = s_axi_awaddr_i;
    s_axi_awlen_s[1]   = s_axi_awlen_i;
    s_axi_awsize_s[1]  = s_axi_awsize_i;
    s_axi_awburst_s[1] = s_axi_awburst_i;
    s_axi_awprot_s[1]  = s_axi_awprot_i;
    s_axi_awcache_s[1] = s_axi_awcache_i;
    s_axi_wready_o     = s_axi_wready_s[1];
    s_axi_wvalid_s[1]  = s_axi_wvalid_i;
    s_axi_wdata_s[1]   = s_axi_wdata_i;
    s_axi_wstrb_s[1]   = s_axi_wstrb_i;
    s_axi_wlast_s[1]   = s_axi_wlast_i;
    s_axi_bready_s[1]  = s_axi_bready_i;
    s_axi_bvalid_o     = s_axi_bvalid_s[1];
    s_axi_bresp_o      = s_axi_bresp_s[1];
  end
end

endmodule