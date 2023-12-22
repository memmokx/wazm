const std = @import("std");
const leb = std.leb;
const ArrayList = std.ArrayList;
const wasm = @import("../wasm.zig");

params: ArrayList(wasm.ValType),
returns: ArrayList(wasm.ValType),

pub fn write(self: @This(), writer: anytype) !void {
    try leb.writeULEB128(writer, std.wasm.function_type);

    const params_len: u32 = @intCast(self.params.items.len);
    try leb.writeULEB128(writer, params_len);

    for (self.params.items) |entry| {
        try wasm.writeEnum(wasm.ValType, writer, entry);
    }

    const returns_len: u32 = @intCast(self.returns.items.len);
    try leb.writeULEB128(writer, returns_len);

    for (self.returns.items) |entry| {
        try wasm.writeEnum(wasm.ValType, writer, entry);
    }
}

pub fn encodedSize(self: @This()) u32 {
    var size: u32 = 0;
    const params_len: u32 = @intCast(self.params.items.len);
    const returns_len: u32 = @intCast(self.returns.items.len);

    size += wasm.lebEncodedSize(std.wasm.function_type);
    size += wasm.lebEncodedSize(params_len);
    size += wasm.lebEncodedSize(returns_len);

    for (self.params.items) |entry| {
        size += wasm.lebEncodedSize(@as(u8, @intFromEnum(entry)));
    }

    for (self.returns.items) |entry| {
        size += wasm.lebEncodedSize(@as(u8, @intFromEnum(entry)));
    }

    return size;
}

pub fn deinit(self: *@This(), allocator: std.mem.Allocator) void {
    _ = allocator;
    self.params.deinit();
    self.returns.deinit();
}
