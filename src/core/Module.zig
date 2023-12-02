const std = @import("std");
const Allocator = std.mem.Allocator;
const sections = @import("sections/sections.zig");
const wasm = @import("wasm.zig");
const Instruction = @import("Instruction.zig");

pub fn SectionData(comptime T: type) type {
    return struct {
        data: []const T = &.{},
    };
}

const Module = @This();

version: u32,
custom: []const sections.Custom = &.{},
types: SectionData(sections.Type) = .{},
funcs: SectionData(sections.Function) = .{},
tables: SectionData(sections.Table) = .{},
memories: SectionData(sections.Memory) = .{},
globals: SectionData(sections.Global) = .{},
elements: SectionData(sections.Element) = .{},
datas: SectionData(sections.Data) = .{},
imports: SectionData(sections.Import) = .{},
exports: SectionData(sections.Export) = .{},
code: SectionData(sections.Code) = .{},
data_counts: SectionData(sections.DataCount) = .{},

// TODO: start https://webassembly.github.io/spec/core/syntax/modules.html#syntax-start

pub fn unmarshalWithReader(allocator: Allocator, reader: anytype) !Module {

    const magic = try reader.readBytesNoEof(4);
    if (!std.mem.eql(u8, &magic, "\x00asm")) {
        return error.InvalidMagic;
    }

    const version = try reader.readIntLittle(u32);
    if (version != 1) {
        return error.InvalidVersion;
    }

    var module: Module = .{ .version = version };

    var custom_sections = std.ArrayList(sections.Custom).init(allocator);
    while (wasm.readEnum(wasm.SectionId, reader)) |section_id| {
        const len = try wasm.readLeb(u32, reader);
        _ = len;
        switch (section_id) {
            .Custom => return error.UnimplementedSection,
            .Type => {
                for (try wasm.readVec(&module.types.data, reader, allocator)) |*t_val| {
                    if (try reader.readByte() != std.wasm.function_type) return error.UnexpectedType;

                    for (try wasm.readVec(&t_val.params, reader, allocator)) |*param| {
                        param.* = try wasm.readEnum(wasm.ValType, reader);
                    }

                    for (try wasm.readVec(&t_val.returns, reader, allocator)) |*ret| {
                        ret.* = try wasm.readEnum(wasm.ValType, reader);
                    }
                }
            },
            .Import => {
                for (try wasm.readVec(&module.imports.data, reader, allocator)) |*import| {
                    const module_len = try wasm.readLeb(u32, reader);
                    const module_name = try allocator.alloc(u8, module_len);
                    try reader.readNoEof(module_name);
                    errdefer allocator.free(module_name);

                    const name_len = try wasm.readLeb(u32, reader);
                    const name = try allocator.alloc(u8, name_len);
                    try reader.readNoEof(name);
                    errdefer allocator.free(name);

                    import.module_name = module_name;
                    import.name = name;

                    const desc = try wasm.readEnum(wasm.ExternalKind, reader);
                    import.desc = switch (desc) {
                        .function => .{ .function = try wasm.readLeb(u32, reader) },
                        .table => .{ .table = .{
                            .ref_type = try wasm.readEnum(wasm.Reftype, reader),
                            .limits = try wasm.readLimits(reader),
                        } },
                        .memory => .{ .memory = try wasm.readLimits(reader) },
                        .global => .{ .global = .{
                            .val_type = try wasm.readEnum(wasm.ValType, reader),
                            .mutable = (try reader.readByte()) == 0x1,
                        } },
                    };
                }
            },
            .Function => {
                for (try wasm.readVec(&module.funcs.data, reader, allocator)) |*func| {
                    func.*.type_idx = try wasm.readLeb(u32, reader);
                }
            },
            .Table => return error.UnimplementedSection,
            .Memory => {
                for (try wasm.readVec(&module.memories.data, reader, allocator)) |*memory| {
                    memory.* = .{ .limits = try wasm.readLimits(reader) };
                }
            },
            .Global => {
                for (try wasm.readVec(&module.globals.data, reader, allocator)) |*global| {
                    global.* = .{
                        .val_type = try wasm.readEnum(wasm.ValType, reader),
                        .mutable = (try reader.readByte()) == 0x01,
                        .init = try wasm.readInit(reader),
                    };
                }
            },
            .Export => {
                for (try wasm.readVec(&module.exports.data, reader, allocator)) |*exported| {
                    const name_len = try wasm.readLeb(u32, reader);
                    const name = try allocator.alloc(u8, name_len);
                    errdefer allocator.free(name);
                    try reader.readNoEof(name);

                    exported.* = .{
                        .name = name,
                        .desc = try wasm.readEnum(wasm.ExternalKind, reader),
                        .index = try wasm.readLeb(u32, reader),
                    };
                }
            },
            .Start => return error.UnimplementedSection,
            .Element => return error.UnimplementedSection,
            .Code => {
                for (try wasm.readVec(&module.code.data, reader, allocator)) |*code| {
                    _ = try wasm.readLeb(u32, reader);

                    const locals_len = try wasm.readLeb(u32, reader);
                    const locals = try allocator.alloc(sections.Code.Local, locals_len);
                    errdefer allocator.free(locals);

                    for (locals) |*local| {
                        local.* = .{
                            .count = try wasm.readLeb(u32, reader),
                            .val_type = try wasm.readEnum(wasm.ValType, reader),
                        };
                    }

                    code.locals = locals;

                    {
                        var instructions = std.ArrayList(Instruction).init(allocator);
                        defer instructions.deinit();

                        while (wasm.readEnum(wasm.Opcode, reader)) |opcode| {
                            const instruction = try Instruction.fromOpcode(opcode, allocator, reader);
                            try instructions.append(instruction);
                        } else |err| switch (err) {
                            error.EndOfStream => {
                                const last = instructions.popOrNull() orelse return error.MissingEnd;
                                if (last.opcode != .end) return error.MissingEnd;
                            },
                            else => |e| return e,
                        }

                        code.body = try instructions.toOwnedSlice();
                    }
                }
            },
            .Data => return error.UnimplementedSection,
            .DataCount => return error.UnimplementedSection,
        }
    } else |err| switch (err) {
        error.EndOfStream => {},
        else => |e| return e,
    }

    module.custom = try custom_sections.toOwnedSlice();

    return module;
}

test "simple wasm" {
    var file = try std.fs.cwd().openFile("test-data/add.wasm", .{});
    defer file.close();
    var reader = file.reader();
    var module = try Module.unmarshalWithReader(std.heap.page_allocator, reader);
    try std.testing.expect(module.version == 1);
    std.debug.print("{any}", .{module.code.data});
}
