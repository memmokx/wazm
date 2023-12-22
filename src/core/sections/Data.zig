const std = @import("std");
const wasm = @import("../wasm.zig");

index: u32,
offset: wasm.InitExpression,
data: []const u8