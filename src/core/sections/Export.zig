const std = @import("std");
const leb = std.leb;
const wasm = @import("../wasm.zig");

name: []const u8,
desc: wasm.ExternalKind,
index: u32,

pub fn write(self: @This(), writer: anytype) !void {
    const name_len: u32 = @intCast(self.name.len);

    try leb.writeULEB128(writer, name_len);
    try writer.writeAll(self.name);
    try wasm.writeEnum(wasm.ExternalKind, writer, self.desc);
    try leb.writeULEB128(writer, self.index);
}

pub fn encodedSize(self: @This()) u32 {
    var size: u32 = 0;
    const name_len: u32 = @intCast(self.name.len);

    size += wasm.lebEncodedSize(name_len);
    size += name_len;
    size += wasm.lebEncodedSize(@as(u8, @intFromEnum(self.desc)));

    return size + wasm.lebEncodedSize(self.index);
}

pub fn deinit(self: *@This(), allocator: std.mem.Allocator) void {
    allocator.free(self.name);
}
