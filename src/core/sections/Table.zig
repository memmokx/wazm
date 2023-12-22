const std = @import("std");
const leb = std.leb;
const wasm = @import("../wasm.zig");

element_type: wasm.Reftype,
limits: wasm.Limits,

pub fn write(self: @This(), writer: anytype) !void {
    try wasm.writeEnum(wasm.Reftype, writer, self.element_type);
    try self.limits.write(writer);
}

pub fn encodedSize(self: @This()) u32 {
    return self.limits.lebSize() + wasm.lebEncodedSize(@as(u8, @intFromEnum(self.element_type)));
}

pub fn deinit(self: *@This(), allocator: std.mem.Allocator) void {
    _ = allocator;
    _ = self;
}
