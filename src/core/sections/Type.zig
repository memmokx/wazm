const std = @import("std");
const ArrayList = std.ArrayList;
const wasm = @import("../wasm.zig");

params: ArrayList(wasm.ValType),
returns: ArrayList(wasm.ValType),
