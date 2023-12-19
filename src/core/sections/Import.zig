const std = @import("std");
const leb = std.leb;
const wasm = @import("../wasm.zig");

pub const Kind = union(wasm.ExternalKind) {
    function: u32,
    table: struct {
        ref_type: wasm.Reftype,
        limits: wasm.Limits,
    },
    memory: wasm.Limits,
    global: struct {
        val_type: wasm.ValType,
        mutable: bool,
    },
};

module_name: []const u8,
name: []const u8,
desc: Kind,

pub fn write(self: @This(), writer: anytype) !void {
    const module_name_len: u32 = @intCast(self.module_name.len);
    const name_len: u32 = @intCast(self.name.len);

    try leb.writeULEB128(writer, module_name_len);
    try writer.writeAll(self.module_name);

    try leb.writeULEB128(writer, name_len);
    try writer.writeAll(self.name);

    switch (self.desc) {
        .function => |func| {
            try wasm.writeEnum(wasm.ExternalKind, writer, .function);
            try leb.writeULEB128(writer, func);
        },
        .table => |table| {
            try wasm.writeEnum(wasm.ExternalKind, writer, .table);
            try wasm.writeEnum(wasm.Reftype, writer, table.ref_type);
            try wasm.writeLimits(table.limits, writer);
        },
        .memory => |memory| {
            try wasm.writeEnum(wasm.ExternalKind, writer, .memory);
            try wasm.writeLimits(memory, writer);
        },
        .global => |global| {
            try wasm.writeEnum(wasm.ExternalKind, writer, .global);
            const mutable: u8 = @intFromBool(global.mutable);
            try leb.writeULEB128(writer, mutable);
        },
    }
}

pub fn encodedSize(self: @This()) u32 {
    var size: u32 = 0;
    const module_name_len: u32 = @intCast(self.module_name.len);
    const name_len: u32 = @intCast(self.name.len);

    size += wasm.lebEncodedSize(module_name_len);
    size += wasm.lebEncodedSize(name_len);
    size += module_name_len;
    size += name_len;

    switch (self.desc) {
        .function => |func| {
            size += wasm.lebEncodedSize(@as(u8, @intFromEnum(wasm.ExternalKind.function)));
            size += wasm.lebEncodedSize(func);
        },
        .table => |table| {
            size += wasm.lebEncodedSize(@as(u8, @intFromEnum(wasm.ExternalKind.table)));
            size += wasm.lebEncodedSize(@as(u8, @intFromEnum(table.ref_type)));
            size += table.limits.lebSize();
        },
        .memory => |memory| {
            size += wasm.lebEncodedSize(@as(u8, @intFromEnum(wasm.ExternalKind.memory)));
            size += memory.lebSize();
        },
        .global => {
            size += wasm.lebEncodedSize(@as(u8, @intFromEnum(wasm.ExternalKind.global))) + 1;
        },
    }

    return size;
}
