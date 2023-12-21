const wasm = @import("../wasm.zig");

limits: wasm.Limits,

pub fn write(self: @This(), writer: anytype) !void {
    try wasm.writeLimits(self.limits, writer);
}

pub fn encodedSize(self: @This()) u32 {
    return self.limits.lebSize();
}
