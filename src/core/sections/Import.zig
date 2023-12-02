const wasm = @import("../wasm.zig");

pub const Kind = union(wasm.ExternalKind) {
    function: u32,
    table: struct {
        ref_type: wasm.Reftype,
        limits: wasm.Limits,
    },
    memory: wasm.Limits,
    global: struct {
        val_type: wasm.ValType,
        mutable: bool,
    },
};

module_name: []const u8,
name: []const u8,
desc: Kind,
