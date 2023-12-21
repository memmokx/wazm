const wasm = @import("../wasm.zig");

limits: wasm.Limits,

pub fn write(self: @This(), writer: anytype) !void {
    try self.limits.write(writer);
}

pub fn encodedSize(self: @This()) u32 {
    return self.limits.lebSize();
}
