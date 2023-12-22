const std = @import("std");
const wasm = @import("../wasm.zig");

index: u32,
offset: wasm.InitExpression,
data: []const u8,

pub fn deinit(self: *@This(), allocator: std.mem.Allocator) void {
    allocator.free(self.data);
}
