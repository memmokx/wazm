const Instruction = @import("../Instruction.zig");
const wasm = @import("../wasm.zig");

pub const Local = struct {
    val_type: wasm.ValType,
    count: u32,
};

locals: []const Local,
body: []const Instruction,
