const wasm = @import("../wasm.zig");

val_type: wasm.ValType,
mutable: bool,
init: wasm.InitExpression,
