const std = @import("std");
const wasm = @import("wasm.zig");

const Instruction = @This();

pub const Values = enum {
    none,
    index,
    u32,
    i32,
    i64,
    f32,
    f64,
    ref_type,
    block_type,
    mem_arg,
    multi,
    table,
};

pub const MemArg = struct {
    @"align": u32,
    offset: u32,
};

pub const Value = union(Values) {
    none: void,
    index: u32,
    u32: u32,
    i32: i32,
    i64: i64,
    f32: f32,
    f64: f64,
    ref_type: wasm.Reftype,
    block_type: wasm.BlockType,
    mem_arg: MemArg,
    multi: struct {
        x: u32,
        y: u32,
    },
    table: struct {
        table: []const u32,
        default: u32,
    },
};

opcode: wasm.Opcode,
value: Value,

fn decodeMisc(reader: anytype) !Value {
    return switch (try wasm.readEnum(wasm.MiscOpcode, reader)) {
        .table_init, .table_copy => .{ .multi = .{
            .x = try wasm.readLeb(u32, reader),
            .y = try wasm.readLeb(u32, reader),
        } },
        .data_drop,
        .elem_drop,
        .table_grow,
        .table_size,
        .table_fill,
        => .{ .index = try wasm.readLeb(u32, reader) },
        .memory_init, .memory_copy, .memory_fill => return error.UnimplementedInstruction,
        else => .{ .none = {} },
    };
}

fn decodeSimd(allocator: std.mem.Allocator, reader: anytype) !Value {
    _ = allocator;
    return switch (try wasm.readEnum(wasm.SimdOpcode, reader)) {
        .v128_load,
        .v128_load8x8_s,
        .v128_load8x8_u,
        .v128_load16x4_s,
        .v128_load16x4_u,
        .v128_load32x2_s,
        .v128_load32x2_u,
        .v128_load8_splat,
        .v128_load16_splat,
        .v128_load32_splat,
        .v128_load64_splat,
        .v128_store,
        => .{ .mem_arg = .{
            .@"align" = try wasm.readLeb(u32, reader),
            .offset = try wasm.readLeb(u32, reader),
        } },

        else => .{ .none = {} },
    };
}

fn readTable(allocator: std.mem.Allocator, reader: anytype) !Value {
    const len = try wasm.readLeb(u32, reader);
    var indices = try std.ArrayList(u32).initCapacity(allocator, len);
    errdefer indices.deinit();

    for (0..len) |_| {
        try indices.append(try wasm.readLeb(u32, reader));
    }

    return .{ .table = .{ .table = try indices.toOwnedSlice(), .default = try wasm.readLeb(u32, reader) } };
}

pub fn fromOpcode(opcode: wasm.Opcode, allocator: std.mem.Allocator, reader: anytype) !Instruction {
    var instruction: Instruction = .{
        .opcode = opcode,
        .value = undefined,
    };

    instruction.value = switch (opcode) {
        //Control Instructions
        .@"unreachable", .nop, .@"return" => .{ .none = {} },
        .block, .loop, .@"if" => .{ .block_type = try wasm.readEnum(wasm.BlockType, reader) }, // blocktype
        .br, .br_if, .call => .{ .index = try wasm.readLeb(u32, reader) },
        .br_table => try readTable(allocator, reader),
        .call_indirect => .{ .multi = .{
            .x = try wasm.readLeb(u32, reader),
            .y = try wasm.readLeb(u32, reader),
        } },
        // Reference Instructions
        .ref_null => .{ .ref_type = try wasm.readEnum(wasm.Reftype, reader) },
        .ref_is_null => .{ .none = {} },
        .ref_func => .{ .index = try wasm.readLeb(u32, reader) },
        // Parametric Instructions
        .drop, .select => .{ .none = {} },
        //TODO: 0x1C
        // Variable Instructions
        .local_get,
        .local_set,
        .local_tee,
        .global_get,
        .global_set,
        => .{ .index = try wasm.readLeb(u32, reader) },
        // Table Instructions
        .table_get,
        .table_set,
        => .{ .index = try wasm.readLeb(u32, reader) },
        // Memory Instructions
        .i32_load,
        .i64_load,
        .f32_load,
        .f64_load,
        .i32_load8_s,
        .i32_load8_u,
        .i32_load16_s,
        .i32_load16_u,
        .i64_load8_s,
        .i64_load8_u,
        .i64_load16_s,
        .i64_load16_u,
        .i64_load32_s,
        .i64_load32_u,
        .i32_store,
        .i64_store,
        .f32_store,
        .f64_store,
        .i32_store8,
        .i32_store16,
        .i64_store8,
        .i64_store16,
        .i64_store32,
        => .{ .mem_arg = .{
            .@"align" = try wasm.readLeb(u32, reader),
            .offset = try wasm.readLeb(u32, reader),
        } },
        .memory_size, .memory_grow => blk: {
            _ = try reader.readByte();
            break :blk .{ .none = {} };
        },
        // Numeric Instructions
        .i32_const => .{ .i32 = try wasm.readLeb(i32, reader) },
        .i64_const => .{ .i64 = try wasm.readLeb(i64, reader) },
        .f32_const => .{ .f32 = @bitCast(try wasm.readLeb(u32, reader)) },
        .f64_const => .{ .f64 = @bitCast(try wasm.readLeb(u64, reader)) },
        .misc_prefix => try decodeMisc(reader),
        .simd_prefix => try decodeSimd(allocator, reader),
        .atomics_prefix => unreachable,
        else => .{ .none = {} },
    };

    return instruction;
}
