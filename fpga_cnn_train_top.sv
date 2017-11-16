module fpga_cnn_train_top#(
    parameter   PE_NUM  = 32
    )(
    input   clk,
    input   rst,
    
    input                   ins_valid,
    output                  ins_ready,
    input   [INST_W -1 : 0] ins,
    
    input   [DDR_W      -1 : 0] ddr1_in_data,
    input                       ddr1_in_valid,
    output                      ddr1_in_ready,
    
    output  [DDR_ADDR_W -1 : 0] ddr1_in_addr,
    output  [BURST_W    -1 : 0] ddr1_in_size,
    output                      ddr1_in_addr_valid,
    input                       ddr1_in_addr_ready
    
    input   [DDR_W      -1 : 0] ddr2_in_data,
    input                       ddr2_in_valid,
    output                      ddr2_in_ready,
    
    output  [DDR_ADDR_W -1 : 0] ddr2_in_addr,
    output  [BURST_W    -1 : 0] ddr2_in_size,
    output                      ddr2_in_addr_valid,
    input                       ddr2_in_addr_ready,
    
    input   [DDR_W      -1 : 0] ddr1_out_data,
    input                       ddr1_out_valid,
    output                      ddr1_out_ready,
                                     
    output  [DDR_ADDR_W -1 : 0] ddr1_out_addr,
    output  [BURST_W    -1 : 0] ddr1_out_size,
    output                      ddr1_out_addr_valid,
    input                       ddr1_out_addr_ready
                                     
    input   [DDR_W      -1 : 0] ddr2_out_data,
    input                       ddr2_out_valid,
    output                      ddr2_out_ready,
                                     
    output  [DDR_ADDR_W -1 : 0] ddr2_out_addr,
    output  [BURST_W    -1 : 0] ddr2_out_size,
    output                      ddr2_out_addr_valid,
    input                       ddr2_out_addr_ready
    );
    
    localparam BUF_DEPTH = 256;
    localparam IDX_DEPTH = 256;
    
    wire    [4      -1 : 0] layer_type;
    wire    [8      -1 : 0] image_width;
    wire    [4      -1 : 0] in_ch_seg;
    
    wire                    ddr2pe_ins_valid;
    wire                    ddr2pe_ins_ready;
    wire    [INST_W -1 : 0] ddr2pe_ins;
    
    wire    [IDX_W*2        -1 : 0] idx_wr_data;
    wire    [bw(IDX_DEPTH)  -1 : 0] idx_wr_addr;
    wire    [PE_NUM         -1 : 0] idx_wr_en;

    wire           [ADDR_W         -1 : 0] dbuf_wr_addr;
    wire    [3 : 0][DATA_W * BATCH -1 : 0] dbuf_wr_data;
    wire    [PE_NUM -1 : 0]                dbuf_wr_en;

    wire    [3 : 0][ADDR_W         -1 : 0] pbuf_wr_addr;
    wire    [3 : 0][DATA_W * BATCH -1 : 0] pbuf_wr_data;
    wire    [PE_NUM -1 : 0]                pbuf_wr_en;

    wire    [3 : 0][ADDR_W         -1 : 0] abuf_wr_addr;
    wire    [3 : 0][BATCH * DATA_W -1 : 0] abuf_wr_data;
    wire    [PE_NUM -1 : 0]                abuf_wr_data_en;
    wire    [3 : 0][BATCH * TAIL_W -1 : 0] abuf_wr_tail;
    wire    [PE_NUM -1 : 0]                abuf_wr_tail_en;
    
    wire                    bbuf_acc_en;
    wire                    bbuf_acc_new;
    wire    [ADDR_W -1 : 0] bbuf_acc_addr;
    wire    [RES_W  -1 : 0] bbuf_acc_data;
 
    wire    [ADDR_W -1 : 0] bbuf_wr_addr;
    wire    [DATA_W -1 : 0] bbuf_wr_data;
    wire                    bbuf_wr_data_en;
    wire    [TAIL_W -1 : 0] bbuf_wr_tail;
    wire                    bbuf_wr_tail_en;
    
    wire           [ADDR_W         -1 : 0] abuf_rd_addr;
    wire    [3 : 0][BATCH * RES_W  -1 : 0] abuf_rd_data;
    
    wire    [ADDR_W -1 : 0] bbuf_rd_addr,
    wire    [RES_W  -1 : 0] bbuf_rd_data
    
    ddr2pe#(
        .BUF_DEPTH  (BUF_DEPTH  ),
        .IDX_DEPTH  (IDX_DEPTH  ),
        .PE_NUM     (PE_NUM     )
    ) ddr2pe_inst (
        .clk    (clk    ),
        .rst    (rst    ),
    
        .layer_type     (layer_type         ),
        .image_width    (image_width        ),
        .in_ch_seg      (in_ch_seg          ),
    
        .ins_valid      (ddr2pe_ins_valid   ),
        .ins_ready      (ddr2pe_ins_ready   ),
        .ins            (ddr2pe_ins         ),
    
        .ddr1_data      (ddr1_in_data       ),
        .ddr1_valid     (ddr1_in_valid      ),
        .ddr1_ready     (ddr1_in_ready      ),
                                
        .ddr1_addr      (ddr1_in_addr       ),
        .ddr1_size      (ddr1_in_size       ),
        .ddr1_addr_valid(ddr1_in_addr_valid ),
        .ddr1_addr_ready(ddr1_in_addr_ready ),
                                
        .ddr2_data      (ddr2_in_data       ),
        .ddr2_valid     (ddr2_in_valid      ),
        .ddr2_ready     (ddr2_in_ready      ),
                                
        .ddr2_addr      (ddr2_in_addr       ),
        .ddr2_size      (ddr2_in_size       ),
        .ddr2_addr_valid(ddr2_in_addr_valid ),
        .ddr2_addr_ready(ddr2_in_addr_ready ),
    
        .idx_wr_data    (idx_wr_data        ),
        .idx_wr_addr    (idx_wr_addr        ),
        .idx_wr_en      (idx_wr_en          ),
    
        .dbuf_wr_addr   (dbuf_wr_addr       ),
        .dbuf_wr_data   (dbuf_wr_data       ),
        .dbuf_wr_en     (dbuf_wr_en         ),
    
        .pbuf_wr_addr   (pbuf_wr_addr       ),
        .pbuf_wr_data   (pbuf_wr_data       ),
        .pbuf_wr_en     (pbuf_wr_en         ),
    
        .bbuf_accum_en  (bbuf_accum_en      ),
        .bbuf_accum_new (bbuf_accum_new     ),
        .bbuf_accum_addr(bbuf_accum_addr    ),
        .bbuf_accum_data(bbuf_accum_data    ),
    
        .abuf_wr_addr   (abuf_wr_addr       ),
        .abuf_wr_data   (abuf_wr_data       ),
        .abuf_wr_data_en(abuf_wr_data_en    ),
        .abuf_wr_tail   (abuf_wr_tail       ),
        .abuf_wr_tail_en(abuf_wr_tail_en    ),
    
        .bbuf_wr_addr   (bbuf_wr_addr       ),
        .bbuf_wr_data   (bbuf_wr_data       ),
        .bbuf_wr_data_en(bbuf_wr_data_en    ),
        .bbuf_wr_tail   (bbuf_wr_tail       ),
        .bbuf_wr_tail_en(bbuf_wr_tail_en    )
    );
    
    pe_array#(
        .BUF_DEPTH  (BUF_DEPTH  ),
        .IDX_DEPTH  (IDX_DEPTH  ),
        .PE_NUM     (PE_NUM     )
    ) pe_array_inst (
        .clk    (clk    ),
        .rst    (rst    ),
    
    // PE control interface
    input   [PE_NUM -1 : 0] switch_d,   // switch the ping pong buffer data
    input   [PE_NUM -1 : 0] switch_p,   // switch the ping pong buffer param
    input   [PE_NUM -1 : 0] switch_i,   // switch the ping pong buffer idx
    input   [PE_NUM -1 : 0] switch_a,   // switch the ping pong buffer accum
    input                   switch_b,
    
    input   [PE_NUM -1 : 0] start,
    output  [PE_NUM -1 : 0] done,
    input   [3      -1 : 0] mode,
    input   [8      -1 : 0] idx_cnt,  
    input   [8      -1 : 0] trip_cnt, 
    input                   is_new,
    input   [4      -1 : 0] pad_code, 
    input                   cut_y,
    
    input   [bw(PE_NUM / 4) -1 : 0] rd_sel,
    
        .idx_wr_data    (idx_wr_data        ),
        .idx_wr_addr    (idx_wr_addr        ),
        .idx_wr_en      (idx_wr_en          ),
    
        .dbuf_wr_addr   (dbuf_wr_addr       ),
        .dbuf_wr_data   (dbuf_wr_data       ),
        .dbuf_wr_en     (dbuf_wr_en         ),
    
        .pbuf_wr_addr   (pbuf_wr_addr       ),
        .pbuf_wr_data   (pbuf_wr_data       ),
        .pbuf_wr_en     (pbuf_wr_en         ),
    
        .bbuf_accum_en  (bbuf_accum_en      ),
        .bbuf_accum_new (bbuf_accum_new     ),
        .bbuf_accum_addr(bbuf_accum_addr    ),
        .bbuf_accum_data(bbuf_accum_data    ),
    
        .abuf_wr_addr   (abuf_wr_addr       ),
        .abuf_wr_data   (abuf_wr_data       ),
        .abuf_wr_data_en(abuf_wr_data_en    ),
        .abuf_wr_tail   (abuf_wr_tail       ),
        .abuf_wr_tail_en(abuf_wr_tail_en    ),
        
        .abuf_rd_addr   (abuf_rd_addr       ),
        .abuf_rd_data   (abuf_rd_data       ),
    
        .bbuf_wr_addr   (bbuf_wr_addr       ),
        .bbuf_wr_data   (bbuf_wr_data       ),
        .bbuf_wr_data_en(bbuf_wr_data_en    ),
        .bbuf_wr_tail   (bbuf_wr_tail       ),
        .bbuf_wr_tail_en(bbuf_wr_tail_en    ),
        
        .bbuf_rd_addr   (bbuf_rd_addr       ),
        .bbuf_rd_data   (bbuf_rd_data       )
    );
    
    
endmodule