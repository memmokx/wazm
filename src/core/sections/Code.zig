const std = @import("std");
const ArrayList = std.ArrayList;
const Instruction = @import("../Instruction.zig");
const wasm = @import("../wasm.zig");

pub const Local = struct {
    val_type: wasm.ValType,
    count: u32,
};

locals: ArrayList(Local),
body: ArrayList(Instruction),
