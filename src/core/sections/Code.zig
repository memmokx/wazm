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

pub fn deinit(self: *@This(), allocator: std.mem.Allocator) void {
    for (self.body.items) |instruction| {
        if (instruction.opcode == .br_table) {
            allocator.free(instruction.value.table.table);
        }
    }
    self.body.deinit();
    self.locals.deinit();
}
