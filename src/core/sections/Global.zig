const leb = @import("std").leb;
const wasm = @import("../wasm.zig");

val_type: wasm.ValType,
mutable: bool,
init: wasm.InitExpression,

pub fn write(self: @This(), writer: anytype) !void {
    try wasm.writeEnum(wasm.ValType, writer, self.val_type);
    try leb.writeULEB128(writer, @as(u8, @intFromBool(self.mutable)));
    try self.init.write(writer);
}

pub fn encodedSize(self: @This()) u32 {
    return wasm.lebEncodedSize(@as(u8, @intFromEnum(self.val_type))) + 1 + self.init.lebSize();
}
