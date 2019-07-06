`include "common_defs.svh"

module nontrivial_mips_impl(
    // external signals
    input  wire        aclk   ,
    input  wire        reset_n,
    input  wire [4 :0] intr   ,
    // AXI AR signals
    output wire [3 :0] arid   ,
    output wire [31:0] araddr ,
    output wire [3 :0] arlen  ,
    output wire [2 :0] arsize ,
    output wire [1 :0] arburst,
    output wire [1 :0] arlock ,
    output wire [3 :0] arcache,
    output wire [2 :0] arprot ,
    output wire        arvalid,
    input  wire        arready,
    // AXI R signals
    input  wire [3 :0] rid    ,
    input  wire [31:0] rdata  ,
    input  wire [1 :0] rresp  ,
    input  wire        rlast  ,
    input  wire        rvalid ,
    output wire        rready ,
    // AXI AW signals
    output wire [3 :0] awid   ,
    output wire [31:0] awaddr ,
    output wire [3 :0] awlen  ,
    output wire [2 :0] awsize ,
    output wire [1 :0] awburst,
    output wire [1 :0] awlock ,
    output wire [3 :0] awcache,
    output wire [2 :0] awprot ,
    output wire        awvalid,
    input  wire        awready,
    // AXI W signals
    output wire [3 :0] wid    ,
    output wire [31:0] wdata  ,
    output wire [3 :0] wstrb  ,
    output wire        wlast  ,
    output wire        wvalid ,
    input  wire        wready ,
    // AXI B signals
    input  wire [3 :0] bid    ,
    input  wire [1 :0] bresp  ,
    input  wire        bvalid ,
    output wire        bready
);

    // initialization of bus interfaces
    cpu_ibus_if ibus_if();
    cpu_dbus_if dbus_if();

    wire clk = aclk;
    wire rst = ~reset_n;

    // initialization of cache
    cache_controller cache_controller_inst(
        .*, // connect all AXI signals
        .clk,
        .rst_n(~rst),
        .ibus(ibus_if.slave),
        .dbus(dbus_if.slave)
    );

    // initialization of CPU
    cpu_core cpu_core_inst(
        .clk,
        .intr,
        .rst_n(~rst),
        .ibus(ibus_if.master),
        .dbus(dbus_if.master)
    );


endmodule
