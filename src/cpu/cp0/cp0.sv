`include "cpu_defs.svh"

module cp0(
	input  logic clk,
	input  logic rst,

	input  reg_addr_t    raddr,
	input  logic [2:0]   rsel,
	input  cp0_req_t     wreq,
	input  except_req_t  except_req,

	input  logic         tlbr_req,
	input  tlb_entry_t   tlbr_res,
	input  logic         tlbp_req,
	input  uint32_t      tlbp_res,
	input  logic         tlbwr_req,

	output uint32_t      rdata,
	output cp0_regs_t    regs,
	output logic [7:0]   asid,
	output logic         user_mode,
	output logic         timer_int
);

cp0_regs_t regs_now, regs_nxt;
assign regs = regs_now;
assign asid = regs.entry_hi[7:0];
assign user_mode = (regs.status[4:1] == 4'b1000);

always_comb
begin
	if(rsel == 3'b0)
	begin
		rdata = regs[raddr * 32 +: 32];
	end else begin
		rdata = 32'b0;
	end
end

always @(posedge clk or posedge rst)
begin
	if(rst)
	begin
		regs_now.index     <= '0;
		regs_now.random    <= `TLB_ENTRIES_NUM - 1;
		regs_now.entry_lo0 <= '0;
		regs_now.entry_lo1 <= '0;
		regs_now.context_  <= '0;
		regs_now.page_mask <= '0;
		regs_now.wired     <= '0;
		regs_now.bad_vaddr <= '0;
		regs_now.count     <= '0;
		regs_now.entry_hi  <= '0;
		regs_now.compare   <= '0;
		regs_now.status    <= 32'b0001_0000_0100_0000_0000_0000_0000_0000;
		regs_now.cause     <= '0;
		regs_now.epc       <= '0;
		regs_now.error_epc <= '0;
		regs_now.ebase     <= 32'h80000001;
	end else begin
		regs_now <= regs_nxt;
	end
end

always @(posedge clk or posedge rst)
begin
	if(rst)
		timer_int <= 1'b0;
	else if(regs.compare != 32'b0 && regs.compare == regs.count)
		timer_int <= 1'b1;
	else if(wreq.we && wreq.wsel == 3'b0 && wreq.waddr == 5'd11)
		timer_int <= 1'b0;
end

uint32_t wmask, wdata;
cp0_write_mask cp0_write_mask_inst(
	.rst,
	.sel  ( wreq.wsel   ),
	.addr ( wreq.waddr ),
	.mask ( wmask      )
);

always_comb begin
	regs_nxt = regs_now;
	regs_nxt.count  = regs_nxt.count + 32'b1;
	regs_nxt.random = regs_now.random + tlbwr_req;

	/* write register (WB stage) */
	if(wreq.we)
	begin
		if(wreq.wsel == 3'b0)
		begin
			wdata = regs_nxt[wreq.waddr * 32 +: 32];
			wdata = (wreq.wdata & wmask) | (wdata & ~wmask);
			regs_nxt[wreq.waddr * 32 +: 32] = wdata;
		end else if(wreq.wsel == 3'b1) begin
			if(wreq.waddr == 5'd15)
				regs_nxt.ebase[29:12] = wreq.wdata[29:12];
		end
	end

	/* TLBR/TLBP instruction (WB stage) */
	if(tlbr_req)
	begin
		regs_nxt.entry_hi[31:13] = tlbr_res.vpn2;
		regs_nxt.entry_hi[7:0]   = tlbr_res.asid;
		regs_nxt.entry_lo1 = {
			2'b0, tlbr_res.pfn1, tlbr_res.c1,
			tlbr_res.d1, tlbr_res.v1, tlbr_res.G };
		regs_nxt.entry_lo0 = {
			2'b0, tlbr_res.pfn0, tlbr_res.c0,
			tlbr_res.d0, tlbr_res.v0, tlbr_res.G };
	end

	if(tlbp_req) regs_nxt.index = tlbp_res;

	/* exception (MEM stage) */
	if(except_req.valid) begin
		if(except_req.eret) begin
			if(regs_nxt.status.erl)
				regs_nxt.status.erl = 1'b0;
			else regs_nxt.status.exl = 1'b0;
		end else begin
			if(regs_nxt.status.exl == 1'b0)
			begin
				if(except_req.delayslot)
				begin
					regs_nxt.epc = except_req.pc - 32'h4;
					regs_nxt.cause.bd = 1'b1;
				end else begin
					regs_nxt.epc = except_req.pc;
					regs_nxt.cause.bd = 1'b0;
				end
			end

			regs_nxt.status.exl = 1'b1;
			regs_nxt.cause.ce   = except_req.extra[1:0];
			regs_nxt.cause.exc_code = except_req.code;

			if(except_req.code == `EXCCODE_INT)
				regs_nxt.cause.ip = except_req.extra[7:0];

			if(except_req.code == `EXCCODE_ADEL || except_req.code == `EXCCODE_ADES) begin
				regs_nxt.bad_vaddr = except_req.extra;
			end else if(except_req.code == `EXCCODE_TLBL || except_req.code == `EXCCODE_TLBS) begin
				regs_nxt.bad_vaddr = except_req.extra;
				regs_nxt.context_[22:4] = except_req.extra[31:13];   // context.bad_vpn2
				regs_nxt.entry_hi[31:13] = except_req.extra[31:13];  // entry_hi.vpn2
			end
		end
	end
end

endmodule