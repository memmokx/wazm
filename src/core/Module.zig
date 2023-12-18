const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const sections = @import("sections/sections.zig");
const wasm = @import("wasm.zig");
const Instruction = @import("Instruction.zig");

pub fn SectionData(comptime T: type) type {
    return struct {
        data: ArrayList(T) = undefined,
        len: usize = 0,

        const Self = @This();

        pub fn push(self: *Self, item: T) !void {
            try self.data.append(item);
            self.len += 1;
        }

        pub fn initCapacity(self: *Self, allocator: Allocator, capacity: usize) !void {
            self.data = try ArrayList(T).initCapacity(allocator, capacity);
        }

        pub fn deinit(self: Self) void {
            self.data.deinit();
        }
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

    while (wasm.readEnum(wasm.SectionId, reader)) |section_id| {
        const section_len = try wasm.readLeb(u32, reader);

        std.log.debug("section: {any}, section length: 0x{x}", .{ section_id, section_len });

        switch (section_id) {
            .Custom => return error.UnimplementedSection,
            .Type => try readTypesSection(&module, allocator, reader),
            .Import => try readImportSection(&module, allocator, reader),
            .Function => {
                const funcs_len = try wasm.readLeb(u32, reader);
                try module.funcs.initCapacity(allocator, funcs_len);
                errdefer module.funcs.deinit();

                for (0..funcs_len) |_| {
                    try module.funcs.push(.{ .type_idx = try wasm.readLeb(u32, reader) });
                }
            },
            .Table => return error.UnimplementedSection,
            .Memory => {
                const memories_len = try wasm.readLeb(u32, reader);
                try module.memories.initCapacity(allocator, memories_len);
                errdefer module.memories.deinit();

                for (0..memories_len) |_| {
                    try module.memories.push(.{ .limits = try wasm.readLimits(reader) });
                }
            },
            .Global => {
                const globals_len = try wasm.readLeb(u32, reader);
                try module.globals.initCapacity(allocator, globals_len);
                errdefer module.globals.deinit();

                for (0..globals_len) |_| {
                    try module.globals.push(.{
                        .val_type = try wasm.readEnum(wasm.ValType, reader),
                        .mutable = (try reader.readByte()) == 0x01,
                        .init = try wasm.readInit(reader),
                    });
                }
            },
            .Export => try readExportsSection(&module, allocator, reader),
            .Start => return error.UnimplementedSection,
            .Element => return error.UnimplementedSection,
            .Code => try readCodeSection(&module, allocator, reader),
            .Data => return error.UnimplementedSection,
            .DataCount => return error.UnimplementedSection,
        }
    } else |err| switch (err) {
        error.EndOfStream => {},
        else => |e| return e,
    }

    return module;
}

fn readTypesSection(module: *Module, allocator: Allocator, reader: anytype) !void {
    const len = try wasm.readLeb(u32, reader);
    try module.types.initCapacity(allocator, len);
    errdefer module.types.deinit();

    for (0..len) |_| {
        if (try reader.readByte() != std.wasm.function_type) return error.UnexpectedType;

        const params_len = try wasm.readLeb(u32, reader);
        var params = try ArrayList(wasm.ValType).initCapacity(allocator, params_len);
        errdefer params.deinit();

        for (0..params_len) |_| {
            try params.append(try wasm.readEnum(wasm.ValType, reader));
        }

        const returns_len = try wasm.readLeb(u32, reader);
        var returns = try ArrayList(wasm.ValType).initCapacity(allocator, params_len);
        errdefer returns.deinit();

        for (0..returns_len) |_| {
            try returns.append(try wasm.readEnum(wasm.ValType, reader));
        }

        try module.types.push(.{ .params = params, .returns = returns });
    }
}

fn readImportSection(module: *Module, allocator: Allocator, reader: anytype) !void {
    const len = try wasm.readLeb(u32, reader);
    try module.imports.initCapacity(allocator, len);
    errdefer module.imports.deinit();

    for (0..len) |_| {
        const module_len = try wasm.readLeb(u32, reader);
        const module_name = try allocator.alloc(u8, module_len);
        errdefer allocator.free(module_name);

        try reader.readNoEof(module_name);

        const name_len = try wasm.readLeb(u32, reader);
        const name = try allocator.alloc(u8, name_len);
        errdefer allocator.free(name);

        try reader.readNoEof(name);

        const desc = try wasm.readEnum(wasm.ExternalKind, reader);
        const import: sections.Import = .{ .module_name = module_name, .name = name, .desc = switch (desc) {
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
        } };

        try module.imports.push(import);
    }
}

fn readExportsSection(module: *Module, allocator: Allocator, reader: anytype) !void {
    const exports_len = try wasm.readLeb(u32, reader);
    try module.exports.initCapacity(allocator, exports_len);
    errdefer module.exports.deinit();

    for (0..exports_len) |_| {
        const name_len = try wasm.readLeb(u32, reader);
        const name = try allocator.alloc(u8, name_len);
        errdefer allocator.free(name);

        try reader.readNoEof(name);

        try module.exports.push(.{
            .name = name,
            .desc = try wasm.readEnum(wasm.ExternalKind, reader),
            .index = try wasm.readLeb(u32, reader),
        });
    }
}

fn readCodeSection(module: *Module, allocator: Allocator, reader: anytype) !void {
    const code_length = try wasm.readLeb(u32, reader);
    try module.code.initCapacity(allocator, code_length);
    errdefer module.code.deinit();

    for (0..code_length) |_| {
        // "the u32 size of the function code in bytes" we dont really care about that
        _ = try wasm.readLeb(u32, reader);

        const locals_len = try wasm.readLeb(u32, reader);
        var locals = try ArrayList(sections.Code.Local).initCapacity(allocator, locals_len);
        errdefer locals.deinit();

        for (0..locals_len) |_| {
            try locals.append(.{
                .count = try wasm.readLeb(u32, reader),
                .val_type = try wasm.readEnum(wasm.ValType, reader),
            });
        }

        var instructions = ArrayList(Instruction).init(allocator);
        errdefer instructions.deinit();

        while (wasm.readEnum(wasm.Opcode, reader)) |opcode| {
            const instruction = try Instruction.fromOpcode(opcode, allocator, reader);
            if (instruction.opcode == .end)
                break;
            try instructions.append(instruction);
        } else |err| switch (err) {
            error.EndOfStream => {
                const last = instructions.popOrNull() orelse return error.MissingEnd;
                if (last.opcode != .end) return error.MissingEnd;
            },
            else => |e| return e,
        }

        try module.code.push(.{
            .body = instructions,
            .locals = locals,
        });
    }
}

test "simple wasm" {
    var file = try std.fs.cwd().openFile("test-data/add.wasm", .{});
    defer file.close();
    var reader = file.reader();
    var module = try Module.unmarshalWithReader(std.testing.allocator, reader);
    try std.testing.expect(module.version == 1);
}
