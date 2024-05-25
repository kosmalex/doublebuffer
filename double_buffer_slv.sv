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

typedef enum logic[1:0] { IDLE, BUSY } dbuffer_state_t;

dbuffer_state_t      st_s;

logic                avail_buffer_s[2];
logic                grant_buffer_s[2];
logic                valid_aw_in_s;

logic [2:0]          aw_size_s;
logic [1:0]          aw_burst_type_s;
logic [AXI_AW_g-1:0] aw_base_addr_s;

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
  for (i = 0; i < 2; i++) begin : blocking_buffer
    blocking_buffer_slv # (
      .AXI_DW_g(AXI_DW_g),
      .AXI_AW_g(AXI_AW_g)
    )
    buffer (
      .clk_i           (clk_i),
      .rst_n_i         (rst_n_i),

      .aw_burst_i      (aw_burst_type_s),
      .aw_size_i       (aw_size_s),

      .s_axi_wready_o  (s_axi_wready_s[i]),
      .s_axi_wvalid_i  (s_axi_wvalid_i),
      .s_axi_wdata_i   (s_axi_wdata_i),
      .s_axi_wstrb_i   (s_axi_wstrb_i),
      .s_axi_wlast_i   (s_axi_wlast_i),
      
      .grant_i         (grant_buffer_s[i]),
      .available_o     (avail_buffer_s[i])
    );
  end
endgenerate

always_ff @(posedge clk_i) begin
  if (rst_n_i) begin
    st_s <= IDLE;
  end else begin
    case(st_s)
      IDLE: begin
        st_s <= valid_aw_in_s ? BUSY : IDLE;
      end
      
      BUSY: begin
        st_s <= last_w_in_s ? IDLE : BUSY;
      end

      default: begin
        st_s <= IDLE;
      end
    endcase
  end
end

assign valid_aw_in_s   = (s_axi_awvalid_i && s_axi_awready_o);
assign last_w_in_s     = (s_axi_wlast_i   && s_axi_wready_o);
assign s_axi_awready_o = (st_s == IDLE);
assign s_axi_bresp_o   = 'd0;

always_ff @(posedge clk_i) begin
  if (!rst_n_i) begin
    { aw_size_s,
      aw_burst_type_s } <= 'd0;
  end else begin
    if ( valid_aw_in_s && (st_s == IDLE) ) begin
      aw_size_s       <= s_axi_awsize_i;
      aw_burst_type_s <= s_axi_awburst_i;
    end
  end
end

always_ff @(posedge clk_i) begin
  if (!rst_n_i) begin
    s_axi_bvalid_o <= 1'b0;
  end else begin
    if ( (st_s == BUSY) && s_axi_wlast_i && s_axi_wready_o ) begin 
      s_axi_bvalid_o <= 1'b1;
    end else begin
      s_axi_bvalid_o <= 1'b0;
    end
  end
end

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
    s_axi_wready_o    = s_axi_wready_s[0];
    s_axi_wvalid_s[0] = s_axi_wvalid_i;
    s_axi_wdata_s[0]  = s_axi_wdata_i;
    s_axi_wstrb_s[0]  = s_axi_wstrb_i;
    s_axi_wlast_s[0]  = s_axi_wlast_i;
  end else begin
    s_axi_wready_o    = s_axi_wready_s[1];
    s_axi_wvalid_s[1] = s_axi_wvalid_i;
    s_axi_wdata_s[1]  = s_axi_wdata_i;
    s_axi_wstrb_s[1]  = s_axi_wstrb_i;
    s_axi_wlast_s[1]  = s_axi_wlast_i;
  end
end

endmodule