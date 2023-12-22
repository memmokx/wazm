const std = @import("std");
const leb = std.leb;
const wasm = @import("../wasm.zig");

type_index: u32,

pub fn write(self: @This(), writer: anytype) !void {
    try leb.writeULEB128(writer, self.type_index);
}

pub fn encodedSize(self: @This()) u32 {
    return wasm.lebEncodedSize(self.type_index);
}

pub fn deinit(self: *@This(), allocator: std.mem.Allocator) void {
    _ = allocator;
    _ = self;
}
