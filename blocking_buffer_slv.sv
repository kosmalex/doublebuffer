module blocking_buffer_slv #(
  AXI_DW_g = 64,
  AXI_AW_g = 32
)(
  input  logic                clk_i,
  input  logic                rst_n_i,

  input  logic                aw_burst_i,
  input  logic                aw_size_i,
  
  output logic                s_axi_wready_o,
  input  logic                s_axi_wvalid_i,
  input  logic [AXI_DW_g-1:0] s_axi_wdata_i,
  input  logic [3:0]          s_axi_wstrb_i,
  input  logic                s_axi_wlast_i,

  input  logic                grant_i,
  output logic                available_o
);

typedef enum logic[2:0] { IDLE, LOADING, PUSHING } buffer_state_t;

buffer_state_t       buffer_state_s;

logic [AXI_AW_g-1:0] aw_base_addr_s;
logic                axi_write_in_progress_s;
logic [7:0]          element_counter_s;

logic                a_wen_s;
logic                a_en_s;
logic [3:0]          a_addr_s;
logic [AXI_DW_g-1:0] a_data_in_s;
logic [AXI_DW_g-1:0] a_data_out_s; // Not used!

logic                b_wen_s; // Not used!
logic                b_en_s;
logic [3:0]          b_addr_s;
logic [AXI_DW_g-1:0] b_data_in_s; // Not used!
logic [AXI_DW_g-1:0] b_data_out_s; 

blk_mem_gen_1 bram_0 (
  .clka  (clk_i),       // input wire clka
  .ena   (a_en_s),      // input wire ena
  .wea   (a_wen_s),     // input wire [0 : 0] wea
  .addra (a_addr_s),    // input wire [3 : 0] addra
  .dina  (a_data_in_s), // input wire [63 : 0] dina
  .douta (a_data_out_s),// output wire [63 : 0] douta

  .clkb  (clk_i),       // input wire clkb
  .enb   (b_en_s),      // input wire enb
  .web   (b_wen_s),     // input wire [0 : 0] web
  .addrb (b_addr_s),    // input wire [3 : 0] addrb
  .dinb  (b_data_in_s), // input wire [63 : 0] dinb
  .doutb (b_data_out_s) // output wire [63 : 0] doutb
);

always_ff @(posedge clk_i) begin
  if (!rst_n_i) begin
    buffer_state_s <= IDLE;
  end else begin
    case(buffer_state_s)
      IDLE: begin
        buffer_state_s <= grant_i ? LOADING : IDLE;
      end

      LOADING: begin
        if ( (element_counter_s == 'd15) && s_axi_wready_o ) begin
          buffer_state_s <= PUSHING;
        end else begin
          buffer_state_s <= LOADING;
        end
      end

      PUSHING: begin
        if (element_counter_s == 'd1) begin
          buffer_state_s <= IDLE;
        end else begin
          buffer_state_s <= PUSHING;
        end
      end
      
      default: begin
        buffer_state_s <= IDLE;
      end
    endcase
  end
end

assign axi_write_in_progress_s = (buffer_state_s  == LOADING) && 
                                 (aw_burst_i      == 2'b01  ) && 
                                 (s_axi_wvalid_i            ) && 
                                 (s_axi_wready_o            )  ;

always_ff @(posedge clk_i) begin
  if (!rst_n_i) begin
    aw_base_addr_s <= 'd0;
  end else begin
    if (axi_write_in_progress_s) begin
      aw_base_addr_s <= aw_base_addr_s + ('d1 << aw_size_i); // See ax_size encoding
    end else begin
      aw_base_addr_s <= 'd0;                                 // Buffer always starts filling from 0x0
    end
    // if ( grant_i && (buffer_state_s == IDLE) ) begin
    //   aw_base_addr_s  <= 'd0;                                // Buffer always starts filling from 0x0
    // end else if (axi_write_in_progress_s) begin
    //   aw_base_addr_s <= aw_base_addr_s + ('d1 << aw_size_s); // See ax_size encoding
    // end
  end
end

always_ff @(posedge clk_i) begin
  if (!rst_n_i) begin
    element_counter_s <= 'd0;
  end else if ( axi_write_in_progress_s && (element_counter_s < 'd15) ) begin
    element_counter_s <= element_counter_s + 'd1;
  end else if (buffer_state_s == PUSHING) begin
    element_counter_s <= element_counter_s - 'd1;
  end
end

assign a_en_s = 1'b1;
assign b_en_s = 1'b1;

assign a_wen_s = s_axi_wvalid_i & s_axi_wready_o;
assign b_wen_s = 1'b0;

assign a_addr_s = aw_base_addr_s[AXI_AW_g-1:3];
assign b_addr_s = 'd15 - element_counter_s;

assign a_data_in_s = s_axi_wdata_i;
assign b_data_in_s = 0;

assign available_o = (buffer_state_s != PUSHING) && !( (element_counter_s == 'd15) && s_axi_wready_o );

always_comb begin
  if ( (buffer_state_s == LOADING) && (element_counter_s < 'd16) ) begin
    s_axi_wready_o = 1'b1;
  end else begin
    s_axi_wready_o = 1'b0;
  end
end

endmodule