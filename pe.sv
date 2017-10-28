import  GLOBAL_PARAM::DATA_W;
import  GLOBAL_PARAM::BATCH;
import  GLOBAL_PARAM::RES_W;

module pe#(
    parameter   GRP_ID_X    = 0,
    parameter   GRP_ID_Y    = 0,
    parameter   BUF_DEPTH   = 256,
    parameter   IDX_DEPTH   = 256
    )(
    input   clk,
    input   rst,
    
    input   switch_i,
    input   switch_d,
    input   switch_p,
    input   switch_a,
    
    input               start,
    output              done,
    input   [2  -1 : 0] mode,
    input   [8  -1 : 0] idx_cnt,  
    input   [8  -1 : 0] trip_cnt, 
    input               is_new,
    input   [4  -1 : 0] pad_code, 
    input               cut_y,
    
    input   [3 : 0][DATA_W * BATCH  -1 : 0] share_data_in;
    output  [DATA_W * BATCH -1 : 0] share_data_out;
    
    input   [IDX_W*2        -1 : 0] idx_wr_data,
    input   [bw(IDX_DEPTH)  -1 : 0] idx_wr_addr,
    input                           idx_wr_en,
    
    input   [bw(BUF_DEPTH)  -1 : 0] dbuf_wr_addr,
    input   [DATA_W * BATCH -1 : 0] dbuf_wr_data,
    input                           dbuf_wr_en,
    
    input   [bw(BUF_DEPTH)  -1 : 0] pbuf_wr_addr,
    input   [DATA_W * BATCH -1 : 0] pbuf_wr_data,
    input                           pbuf_wr_en,
    
    input   [bw(BUF_DEPTH)  -1 : 0] abuf_wr_addr,
    input   [BATCH * RES_W  -1 : 0] abuf_wr_data,
    input                           abuf_wr_en,    
    input   [bw(BUF_DEPTH)  -1 : 0] abuf_rd_addr,
    output  [BATCH * RES_W  -1 : 0] abuf_rd_data
    );
    
//=============================================================================
// Address Generation Unit
//=============================================================================
    
    wire    [ADDR_W     -1 : 0] dbuf_addr;  
    wire                        dbuf_mask;  
    wire    [2          -1 : 0] dbuf_mux;   
    
    wire    [ADDR_W     -1 : 0] pbuf_addr;  
    wire    [bw(BATCH)  -1 : 0] pbuf_sel;   
    
    wire    [ADDR_W     -1 : 0] abuf_addr;  
    wire    [BATCH      -1 : 0] abuf_acc_en;
    wire                        abuf_acc_new;
    
    pe_agu#(
        .ADDR_W     (ADDR_W     ),
        .IDX_DEPTH  (IDX_DEPTH  ),
        .GRP_ID_X   (GRP_ID_X   ),
        .GRP_ID_Y   (GRP_ID_Y   )
    ) agu_inst (
        .clk            (clk            ),
        .rst            (rst            ),
    
        .switch_idx_buf (switch_i       ), 
    
        .start          (start          ),
        .done           (done           ),
        .mode           (mode           ),
        .idx_cnt        (idx_cnt        ),  
        .trip_cnt       (trip_cnt       ), 
        .is_new         (is_new         ),
        .pad_code       (pad_code       ), 
        .cut_y          (cut_y          ),
    
        .idx_wr_data    (idx_wr_data    ),
        .idx_wr_addr    (idx_wr_addr    ),
        .idx_wr_en      (idx_wr_en      ),
            
        .dbuf_addr      (dbuf_addr      ),
        .dbuf_mask      (dbuf_mask      ),
        .dbuf_mux       (dbuf_mux       ), 
            
        .pbuf_addr      (pbuf_addr      ),
        .pbuf_sel       (pbuf_sel       ), 
    
        .abuf_addr      (abuf_addr      ),  
        .abuf_acc_en    (abuf_acc_en    ),
        .abuf_acc_new   (abuf_acc_new   )
    );
    
//=============================================================================
// Datapath
//=============================================================================
    
    wire    [BATCH  -1 : 0][DATA_W -1 : 0] data_vec;
    wire    [BATCH  -1 : 0][DATA_W -1 : 0] param_vec;
    
    // parameter selection
    reg     [BATCH  -1 : 0][DATA_W -1 : 0] param_vec_sel_r;
    wire    [bw(BATCH)  -1 : 0] pbuf_sel_d;
    
    Pipe#(.DW(bw(BATCH)), .L(2)) pbuf_sel_pipe (.clk, .s(pbuf_sel), .d(pbuf_sel_d));
    
    genvar i;
    generate
        for (i = 0; i < BATCH; i = i + 1) begin: PARAM_SEL
            always @ (posedge clk) begin
                if (~mode[1]) begin
                    param_vec_sel_r[i] <= param_vec[pbuf_sel_d];
                end
                else begin
                    param_vec_sel_r[i] <= param_vec[i];
                end
            end
        end
    endgenerate
    
    
    // data selection
    wire                dbuf_mask_d;  
    wire    [2  -1 : 0] dbuf_mux_d;
    reg     [BATCH  -1 : 0][DATA_W -1 : 0] data_vec_sel_r;
    
    Pipe#(.DW(bw(BATCH)), .L(3)) dbuf_sel_pipe (.clk, 
        .s({dbuf_mask, dbuf_mux}), .d({dbuf_mask_d, dbuf_mux_d}));
        
    generate
        for (i = 1; i < BATCH; i++) begin: DATA_SEL
            always @ (posedge clk) begin
                if (dbuf_mask_d) begin
                    case(dbuf_mux)
                    2'b00: data_vec_sel_r[i] <= share_data_in[0][i];
                    2'b01: data_vec_sel_r[i] <= share_data_in[1][i];
                    2'b10: data_vec_sel_r[i] <= share_data_in[2][i];
                    2'b11: data_vec_sel_r[i] <= share_data_in[3][i];
                    endcase
                end
                else begin
                    data_vec_sel_r[i] <= 0;
                end
            end
        end
    endgenerate
    
    
    mac_array#(
        .BATCH  (BATCH  ),
        .DATA_W (DATA_W ),
        .RES_W  (RES_W  )
    ) mac_array_inst (
        .clk    (clk    ),
        .rst    (rst    ),
    
        .new_acc(),
        .vec_a  (data_vec_sel_r ),
        .vec_b  (param_vec_sel_r),
    
        .vec_out(),
        .sca_out()
    );
    
//=============================================================================
// Buffers
//=============================================================================
    
    ping_pong_ram#(
        .DEPTH      (BUF_DEPTH      ),  
        .WIDTH      (DATA_W * BATCH ),   
        .RAM_TYPE   ("block"        )
    ) data_buffer (
        .clk    (clk            ),
        .rst    (rst            ),
        
        .switch (switch_d       ),
    
        .wr_addr(dbuf_wr_addr   ),
        .wr_data(dbuf_wr_data   ),
        .wr_en  (dbuf_wr_en     ),
    
        .rd_addr(dbuf_addr      ),
        .rd_data(data_vec       )
    );
    
    ping_pong_ram#(
        .DEPTH      (BUF_DEPTH      ),  
        .WIDTH      (DATA_W * BATCH ),   
        .RAM_TYPE   ("block"        )
    ) param_buffer (
        .clk    (clk            ),
        .rst    (rst            ),
        
        .switch (switch_p       ),
    
        .wr_addr(pbuf_wr_addr   ),
        .wr_data(pbuf_wr_data   ),
        .wr_en  (pbuf_wr_en     ),
    
        .rd_addr(pbuf_addr      ),
        .rd_data(param_vec      )
    );
    
    accum_buf#(
        .DEPTH  (BUF_DEPTH  )
    ) acc_buffer (
        .clk    (clk            ),
        .rst    (rst            ),
    
        .switch (switch_a       ),
    
        .accum_en   (abuf_acc_en    ),
        .accum_new  (abuf_acc_new   ),
        .accum_addr (abuf_addr      ),
        .accum_data (),
    
        .wr_addr    (abuf_wr_addr   ),
        .wr_data    (abuf_wr_data   ),
        .wr_en      (abuf_wr_en     ),
    
        .rd_addr    (abuf_rd_addr   ),
        .rd_data    (abuf_rd_data   )
    );
    
    
endmodule