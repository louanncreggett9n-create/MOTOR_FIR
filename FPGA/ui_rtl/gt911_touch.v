`timescale 1ns / 1ps
// GT911 via 40P J1 FPC/RN9: SCL=E16 SDA=D14 INT=E14 RST=D15, addr 0x5D, 50 kHz
// Reference design ideas: Miliangke uii2c state machine
// https://www.cnblogs.com/milianke/p/17935244.html
// GT911 reset/status notes: GT911ForESP
// https://gitee.com/taxue-vernon/GT911ForESP
module gt911_touch #(
    parameter [21:0] RST_LOW_CYCLES      = 22'd1000000,  // 20 ms INT-low reset setup
    parameter [21:0] RST_SETUP_CYCLES    = 22'd50000,    // 1 ms INT high before RST rise
    parameter [21:0] RST_RELEASE_CYCLES  = 22'd500000,   // 10 ms after RST rise
    parameter [21:0] INIT_WAIT_CYCLES    = 22'd2500000,  // 50 ms before first poll
    parameter [21:0] POLL_GAP_CYCLES     = 22'd500000
)(
    input  wire       clk, rst_n,
    inout  wire       tp_scl, tp_sda, tp_int,
    output reg        tp_rst,
    output reg [9:0]  x, y,
    output reg        down,
    output wire       ack_o,
    output wire [7:0] status_o,
    output wire [6:0] addr_o,
    output wire [7:0] id0_o, id1_o, id2_o,
    output wire [7:0] idb0_o, idb1_o, idb2_o,
    output wire [7:0] cfgver_o,
    output wire [7:0] trans_cnt_o,
    output wire [1:0] bus_idle_o,
    output wire       reg_wack_o,
    output reg [2:0]  state_o
);
    reg scl_lo, sda_lo, int_lo;
    assign tp_scl = scl_lo ? 1'b0 : 1'bz;
    wire sda_i;
    wire int_i;
    // Explicit IOBUFs avoid incomplete-buffer inference on the bidirectional pins.
    IOBUF iobuf_sda (.O(sda_i), .IO(tp_sda), .I(1'b0), .T(~sda_lo));
    (* keep = "true" *) IOBUF iobuf_int (.O(int_i), .IO(tp_int), .I(1'b0), .T(~int_lo));

    reg [7:0] qc;  wire qt = (qc == 8'd249);
    always @(posedge clk or negedge rst_n)
        if (!rst_n) qc <= 8'd0; else qc <= qt ? 8'd0 : qc + 8'd1;

    // ---------------- I2C engine ----------------
    localparam E_IDLE=0,E_START=1,E_TX=2,E_TACK=3,E_RX=4,E_RACK=5,E_STOP=6;
    reg [2:0] e; reg [2:0] ph; reg [3:0] bc; reg [7:0] sh; reg ackb; reg edone;
    reg [3:0] rxi; reg [3:0] rxn; reg [7:0] rb [0:7];
    reg [7:0] cmd;      // byte to send
    reg [7:0] id0, id1, id2, idb0, idb1, idb2, cfgver;
    reg [7:0] trans_cnt;
    reg [1:0] bus_idle;
    reg [15:0] bus_stable_cnt;
    reg       reg_wack;
    reg [6:0] dev_addr; // 0x14 or 0x5D, selected by INT at RST rising edge
    reg       addr_sel; // 0 = 0x14 (INT high), 1 = 0x5D (INT low)
    reg       split_read;
    reg       rd_mode;
    reg       ptr_only;
    reg       read_only;
    assign ack_o = ~ackb;   // 1 = slave ACKed the last addressed byte
    assign status_o = rb[0];
    assign addr_o = dev_addr;
    assign id0_o = id0; assign id1_o = id1; assign id2_o = id2;
    assign idb0_o = idb0; assign idb1_o = idb1; assign idb2_o = idb2;
    assign cfgver_o = cfgver;
    assign trans_cnt_o = trans_cnt;
    assign bus_idle_o = bus_idle;
    assign reg_wack_o = reg_wack;

    // ---------------- transaction ----------------
    localparam T_IDLE=0,T_ST=1,T_DEVW=2,T_RH=3,T_RL=4,T_WD=5,T_RST=6,T_DEVR=7,T_RX=8,T_SP=9;
    reg [3:0] ts; reg [3:0] step; reg [15:0] ra; reg [7:0] wd; reg go; reg done;

    // ---------------- delays ----------------
    reg [21:0] dly; reg dly_en;
    wire dly_end = (dly == 22'd0);

    // ---------------- top FSM ----------------
    localparam S_RST0=0,S_RST1=1,S_RST2=2,S_REL=3,S_POLL=4,S_CHK=5,S_RD=6,S_UPD=7,S_CLR=8,
                   S_ID=9,S_IDW=10,S_CFGW=11,S_PTRW=12,S_IDBW=13,S_INITCLR=14,S_INITCLRW=15;
    reg [3:0] st;
    reg [3:0] tcnt;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            scl_lo<=0; sda_lo<=0; int_lo<=1; e<=E_IDLE; ph<=0; bc<=0; sh<=0; ackb<=0; edone<=0;
            rxi<=0; rxn<=0; cmd<=0; dev_addr<=7'h14; addr_sel<=1'b0; split_read<=1'b0; rd_mode<=0; ptr_only<=0; read_only<=0;
            ts<=T_IDLE; step<=0; ra<=0; wd<=0; go<=0; done<=0;
            dly<=0; dly_en<=0; st<=S_RST0; tp_rst<=0;
            x<=0; y<=0; down<=0; state_o<=0; tcnt<=0;
            id0<=0; id1<=0; id2<=0; idb0<=0; idb1<=0; idb2<=0; cfgver<=0; trans_cnt<=0; bus_idle<=2'b11; bus_stable_cnt<=0; reg_wack<=1'b0;
        end else begin
            edone <= 1'b0;
            // Freeze the diagnostic while the bus is active. Update only after
            // the observed idle levels have been stable for about 1.3 ms.
            if (e==E_IDLE && ts==T_IDLE) begin
                if ({tp_scl, sda_i} != bus_idle) begin
                    if (bus_stable_cnt == 16'hFFFF) begin
                        bus_idle <= {tp_scl, sda_i};
                        bus_stable_cnt <= 16'd0;
                    end else begin
                        bus_stable_cnt <= bus_stable_cnt + 16'd1;
                    end
                end else begin
                    bus_stable_cnt <= 16'd0;
                end
            end else begin
                bus_stable_cnt <= 16'd0;
            end
            // ---- delays ----
            if (dly_en) begin
                if (dly_end) dly_en <= 1'b0; else dly <= dly - 22'd1;
            end

            // ---- engine ----
            if (qt) begin
                case (e)
                E_START: begin
                    case (ph)
                    0: begin scl_lo<=0; sda_lo<=0; end
                    1: sda_lo<=1;
                    2: scl_lo<=1;
                    default: begin ph<=0; e<=E_IDLE; edone<=1; end
                    endcase
                    if (ph!=3) ph<=ph+1;
                end
                E_TX: begin
                    case (ph)
                    0: begin scl_lo<=1; sda_lo<=~sh[7]; end
                    1: scl_lo<=0;
                    2: ;
                    default: begin
                        scl_lo<=1; ph<=0; sh<={sh[6:0],1'b0};
                        if (bc==7) begin bc<=0; e<=E_TACK; end else bc<=bc+1;
                    end
                    endcase
                    if (ph!=3) ph<=ph+1;
                end
                E_TACK: begin
                    case (ph)
                    0: begin scl_lo<=1; sda_lo<=0; end
                    1: scl_lo<=0;
                    2: ;
                    default: begin ackb<=sda_i; scl_lo<=1; sda_lo<=0; ph<=0; e<=E_IDLE; edone<=1; end
                    endcase
                    if (ph!=3) ph<=ph+1;
                end
                E_RX: begin
                    case (ph)
                    0: begin scl_lo<=1; sda_lo<=0; end
                    1: scl_lo<=0;
                    2: ;
                    default: begin
                        sh<={sh[6:0],sda_i};
                        scl_lo<=1; ph<=0;
                        if (bc==7) begin bc<=0; e<=E_RACK; end else bc<=bc+1;
                    end
                    endcase
                    if (ph!=3) ph<=ph+1;
                end
                E_RACK: begin
                    case (ph)
                    // Master ACK for every byte except the final byte (NACK).
                    0: begin scl_lo<=1; sda_lo<=(rxi + 4'd1 < rxn); end
                    1: scl_lo<=0;
                    2: ;
                    default: begin scl_lo<=1; sda_lo<=0; ph<=0; e<=E_IDLE; edone<=1; end
                    endcase
                    if (ph!=3) ph<=ph+1;
                end
                E_STOP: begin
                    case (ph)
                    // SDA low while SCL low, release SCL, then release SDA => STOP.
                    0: begin scl_lo<=1; sda_lo<=1; end
                    1: scl_lo<=0;
                    2: sda_lo<=0;
                    default: begin ph<=0; e<=E_IDLE; edone<=1; end
                    endcase
                    if (ph!=3) ph<=ph+1;
                end
                default: ;
                endcase
            end

            // ---- engine launch ----
            if (go && e==E_IDLE) begin
                go<=0; sh<=cmd; bc<=0; ph<=0;
                e <= (step==4'd0) ? E_START : ((step==4'd6 || step==4'd7) ? E_STOP :
                     (step==4'd8) ? E_RX : E_TX);
            end

            // ---- transaction ----
            case (ts)
            T_IDLE: if (done) begin done<=0; st<=S_CHK; end
            T_ST:  if (edone) begin
                        if (read_only) begin ts<=T_DEVR; step<=5; cmd<={dev_addr,1'b1}; go<=1; end
                        else begin ts<=T_DEVW; step<=1; cmd<={dev_addr,1'b0}; go<=1; end
                   end
            T_DEVW:if (edone) begin
                        if (ackb) begin
                            rb[0]<=8'h00;
                            ts<=T_SP; step<=6; go<=1;
                        end else begin
                            ts<=T_RH; step<=2; cmd<=ra[15:8]; go<=1;
                        end
                   end
            T_RH:  if (edone) begin
                        if (ackb) begin reg_wack<=1'b0; rb[0]<=8'h00; ts<=T_SP; step<=6; go<=1; end
                        else begin reg_wack<=1'b1; ts<=T_RL; step<=3; cmd<=ra[7:0]; go<=1; end
                   end
            T_RL:  if (edone) begin
                        if (ackb) begin reg_wack<=1'b0; rb[0]<=8'h00; ts<=T_SP; step<=6; go<=1; end
                        else begin
                            reg_wack<=reg_wack;
                            if (rd_mode) begin
                                split_read<=1'b1; read_only<=1'b1;
                                ts<=T_SP; step<=6; go<=1;
                            end
                            else if (ptr_only) begin ts<=T_SP; step<=6; go<=1; end
                            else begin ts<=T_WD; step<=5; cmd<=wd; go<=1; end
                        end
                   end
            T_WD:  if (edone) begin ts<=T_SP; step<=6; go<=1; end
            T_RST: if (edone) begin ts<=T_DEVR; step<=5; cmd<={dev_addr,1'b1}; go<=1; end
            T_DEVR:if (edone) begin
                        if (ackb) begin
                            rb[0]<=8'h00;
                            ts<=T_SP; step<=6; go<=1;
                        end else begin
                            ts<=T_RX; step<=4'd8; rxi<=0; go<=1;
                        end
                   end
            T_RX:  if (edone) begin
                        rb[rxi]<=sh;
                        if (rxi+4'd1>=rxn) begin ts<=T_SP; step<=7; go<=1; end
                        else begin rxi<=rxi+4'd1; go<=1; end
                   end
            T_SP:  if (edone) begin
                        trans_cnt<=trans_cnt+8'd1;
                        if (split_read) begin
                            split_read<=1'b0; read_only<=1'b1;
                            ts<=T_ST; step<=0; go<=1;
                        end else begin
                            ts<=T_IDLE; done<=1;
                        end
                   end
            default: ts<=T_IDLE;
            endcase

            // ---- top FSM ----
            case (st)
            S_RST0: begin
                dev_addr <= addr_sel ? 7'h5D : 7'h14;
                int_lo<=1; tp_rst<=0;
                if (!dly_en) begin dly<=RST_LOW_CYCLES; dly_en<=1; st<=S_RST1; end
            end
            S_RST1: begin
                // Vendor GT9xx sequence: INT high at RST rise selects
                // 0x14, INT low selects 0x5D. Hold the level for 1 ms.
                int_lo <= addr_sel;
                if (!dly_en) begin dly<=RST_SETUP_CYCLES; dly_en<=1; st<=S_RST2; end
            end
            S_RST2: begin
                tp_rst<=1;
                if (!dly_en) begin dly<=RST_RELEASE_CYCLES; dly_en<=1; st<=S_REL; end
            end
            S_REL: begin
                int_lo<=0;
                if (!dly_en) begin dly<=INIT_WAIT_CYCLES; dly_en<=1; st<=S_INITCLR; end
            end
            // Newer GT911 revisions do not reliably support the old 0x8040
            // software-reset command. Clear the status register after the
            // hardware reset, as recommended by current open-source drivers.
            S_INITCLR: begin
                        ra<=16'h814E; rd_mode<=0; wd<=8'h00; rxn<=0;
                        ptr_only<=0; read_only<=0;
                        ts<=T_ST; step<=0; go<=1; st<=S_INITCLRW;
                    end
            S_INITCLRW: if (ts==T_IDLE && done) begin
                        done<=0;
                        if (reg_wack) st<=S_ID;
                        else if (!addr_sel) begin addr_sel<=1'b1; st<=S_RST0; end
                        else st<=S_ID;
                    end
            S_ID: begin
                        ra<=16'h8140; rd_mode<=1; rxn<=3; ptr_only<=0; read_only<=0;
                        ts<=T_ST; step<=0; go<=1; st<=S_IDW;
                    end
            S_IDW: if (ts==T_IDLE && done) begin
                        done<=0;
                        id0<=rb[0]; id1<=rb[1]; id2<=rb[2];
                        ra<=16'h8140; rd_mode<=0; ptr_only<=1; read_only<=0; rxn<=0;
                        ts<=T_ST; step<=0; go<=1; st<=S_PTRW;
                    end
            S_PTRW: if (ts==T_IDLE && done) begin
                        done<=0;
                        ptr_only<=0; read_only<=1; rxn<=3;
                        ts<=T_ST; step<=0; go<=1; st<=S_IDBW;
                    end
            S_IDBW: if (ts==T_IDLE && done) begin
                        done<=0;
                        idb0<=rb[0]; idb1<=rb[1]; idb2<=rb[2];
                        read_only<=0;
                        ra<=16'h8047; rd_mode<=1; rxn<=1;
                        ts<=T_ST; step<=0; go<=1; st<=S_CFGW;
                    end
            S_CFGW: if (ts==T_IDLE && done) begin
                        done<=0;
                        cfgver<=rb[0];
                        dly<=POLL_GAP_CYCLES; dly_en<=1; st<=S_POLL;
                    end
            S_POLL: if (!dly_en) begin
                        ra<=16'h814E; rd_mode<=1; rxn<=1; ptr_only<=0; read_only<=0;
                        ts<=T_ST; step<=0; go<=1; st<=S_CHK;
                    end
            S_CHK: if (ts==T_IDLE && done) begin
                        done<=0;
                        tcnt <= rb[0][3:0];
                        if (rb[0][7]) st<=S_RD;
                        else begin
                            down <= 1'b0;
                            dly<=POLL_GAP_CYCLES; dly_en<=1; st<=S_POLL;
                        end
                    end
            S_RD:  begin
                        ra<=16'h8150; rd_mode<=1; rxn<=7; ptr_only<=0; read_only<=0;
                        ts<=T_ST; step<=0; go<=1; st<=S_UPD;
                    end
            S_UPD: if (ts==T_IDLE && done) begin
                        done<=0;
                        x <= {rb[2][7:0], rb[1][7:0]};
                        y <= {rb[4][7:0], rb[3][7:0]};
                        down <= (tcnt != 4'd0);
                        ra<=16'h814E; rd_mode<=0; wd<=8'h00; ptr_only<=0; read_only<=0;
                        ts<=T_ST; step<=0; go<=1; st<=S_CLR;
                    end
            S_CLR: if (ts==T_IDLE && done) begin
                        done<=0; dly<=POLL_GAP_CYCLES; dly_en<=1; st<=S_POLL;
                    end
            default: st<=S_RST0;
            endcase
            state_o <= st[2:0];
        end
    end
endmodule