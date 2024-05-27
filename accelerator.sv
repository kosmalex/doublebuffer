/// Add done status to double buffer.
/// Arbitrate between weight and activations buffer.

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
  output logic [1:0]          s_axi_bresp_o,

  output logic                s1_axi_awready_o,
  input  logic                s1_axi_awvalid_i,
  input  logic [AXI_AW_g-1:0] s1_axi_awaddr_i,
  input  logic [7:0]          s1_axi_awlen_i,
  input  logic [2:0]          s1_axi_awsize_i,
  input  logic [1:0]          s1_axi_awburst_i,
  input  logic [2:0]          s1_axi_awprot_i,  // Not used!
  input  logic [3:0]          s1_axi_awcache_i, // Not used!
  
  output logic                s1_axi_wready_o,
  input  logic                s1_axi_wvalid_i,
  input  logic [AXI_DW_g-1:0] s1_axi_wdata_i,
  input  logic [3:0]          s1_axi_wstrb_i,
  input  logic                s1_axi_wlast_i,

  input  logic                s1_axi_bready_i,
  output logic                s1_axi_bvalid_o,
  output logic [1:0]          s1_axi_bresp_o,

  input  logic [2:0]          dma_done_intr_i
);

typedef enum logic[1:0] { IDLE, LD_W, LD_A } accel_state_t;

accel_state_t                 st_s;

logic [W_g*R_g-1:0]           Arow_s;
logic [W_g*R_g-1:0]           Wrow_s;
logic [W_g-1:0]               skew_regs_s[0:R_g/K_g-1][0:R_g/K_g-1];

logic [W_g-1:0]               W_s[0:R_g-1][0:K_g-1];
logic [W_g-1:0]               A_s[0:R_g-1][0:K_g-1];
logic [2*W_g+$clog2(R_g)-1:0] C_s[0:R_g/K_g-1][0:K_g-1];

logic                         w8_buf_pushing_s;
logic                         ib_pushing_s;

logic                         stall_db_s;

double_buffer_slv # (
  .AXI_DW_g(AXI_DW_g),
  .AXI_AW_g(AXI_AW_g)
)
input_buffer_0 (
  .*,

  .stall_i   (st_s != LD_A),
  .pushing_o (ib_pushing_s),
  .data_o    (Arow_s)
);

full_blocking_buffer_slv #(
  .AXI_DW_g(AXI_DW_g),
  .AXI_AW_g(AXI_AW_g)
)
weight_buffer_0 (
  .*,
  .s_axi_awready_o (s1_axi_awready_o),
  .s_axi_awvalid_i (s1_axi_awvalid_i),
  .s_axi_awaddr_i  (s1_axi_awaddr_i),
  .s_axi_awlen_i   (s1_axi_awlen_i),
  .s_axi_awsize_i  (s1_axi_awsize_i),
  .s_axi_awburst_i (s1_axi_awburst_i),
  .s_axi_awprot_i  (s1_axi_awprot_i),  // Not used!
  .s_axi_awcache_i (s1_axi_awcache_i), // Not used!
  
  .s_axi_wready_o  (s1_axi_wready_o),
  .s_axi_wvalid_i  (s1_axi_wvalid_i),
  .s_axi_wdata_i   (s1_axi_wdata_i),
  .s_axi_wstrb_i   (s1_axi_wstrb_i),
  .s_axi_wlast_i   (s1_axi_wlast_i),

  .s_axi_bready_i  (s1_axi_bready_i),
  .s_axi_bvalid_o  (s1_axi_bvalid_o),
  .s_axi_bresp_o   (s1_axi_bresp_o),

  .stall_i         (st_s != LD_W),
  .pushing_o       (w8_buf_pushing_s),

  .data_o          (Wrow_s)
);

systolic # (
  .W(W_g),
  .R(R_g),
  .K(K_g)
) systolic_0 (
  .clk     (clk_i),
  .load    (w8_buf_pushing_s),
  .en      (ib_pushing_s),
  .a_in    (A_s),
  .w_in    (W_s),
  .sum_in  ('{default: '0}),
  .sum_out (C_s),
  .w_out   (),
  .a_out   ()
);

always_ff @(posedge clk_i) begin
  if (!rst_n_i) begin
    st_s <= IDLE;
  end else begin
    case(st_s)
      IDLE: begin
        if (s1_axi_awvalid_i) begin
          st_s <= LD_W;
        end else if (s_axi_awvalid_i) begin
          st_s <= LD_A;
        end
      end
      
      LD_W: begin
        st_s <= dma_done_intr_i[1] ? IDLE : LD_W;
      end

      LD_A: begin
        st_s <= dma_done_intr_i[0] ? IDLE : LD_A;
      end

      default: begin
        st_s <= IDLE;
      end
    endcase
  end
end

always_ff @(posedge clk_i) begin
  if (!rst_n_i) begin
    for (int i = 0; i < R_g; i++) begin
      skew_regs_s[i] <= '{default: 'd0};
    end
  end else if (ib_pushing_s) begin
    for (int i = 0; i < R_g; i++) begin
      skew_regs_s[i][0] <= Arow_s[i*W_g+:W_g];
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
    W_s[i][0] = Wrow_s[i*W_g+:W_g];
  end
end


endmodule