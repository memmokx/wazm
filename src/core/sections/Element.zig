const std = @import("std");
const leb = std.leb;
const ArrayList = std.ArrayList;
const wasm = @import("../wasm.zig");

index: u32,
offset: wasm.InitExpression,
elements: ?ArrayList(u32),

pub fn write(self: @This(), writer: anytype) !void {
    try leb.writeULEB128(writer, self.index);
    try self.offset.write(writer);

    if (self.elements) |elements| {
        try leb.writeULEB128(writer, @as(u32, @intCast(elements.items.len)));
        for (elements.items) |entry| {
            try leb.writeULEB128(writer, entry);
        }
    }
}

pub fn encodedSize(self: @This()) u32 {
    var size: u32 = wasm.lebEncodedSize(self.index);

    size += self.offset.lebSize();
    if (self.elements) |elements| {
        size += wasm.lebEncodedSize(@as(u32, @intCast(elements.items.len)));
        for (elements.items) |entry| {
            size += wasm.lebEncodedSize(entry);
        }
    }

    return size;
}
