const std = @import("std");
const leb = std.leb;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const sections = @import("sections/sections.zig");
const wasm = @import("wasm.zig");
const Instruction = @import("Instruction.zig");

pub fn SectionData(comptime T: type) type {
    return struct {
        data: ArrayList(T),

        const Self = @This();

        pub fn init(allocator: Allocator) Self {
            return .{ .data = ArrayList(T).init(allocator) };
        }

        /// Returns the element at the current index
        /// if not found returns `null`
        pub fn at(self: Self, index: usize) ?T {
            if (index > self.size()) {
                return null;
            }
            return self.data.items[index];
        }

        /// Append the item to the internal `ArrayList`
        pub fn push(self: *Self, item: T) !void {
            try self.data.append(item);
        }

        /// Init the internal `ArrayList` with the specified capacity
        pub fn initCapacity(self: *Self, allocator: Allocator, capacity: usize) !void {
            self.data = try ArrayList(T).initCapacity(allocator, capacity);
        }

        pub fn size(self: Self) usize {
            return self.data.items.len;
        }

        /// Write the section according to the Wasm binary format
        pub fn write(self: Self, writer: anytype, section_id: wasm.SectionId) !void {
            try wasm.writeEnum(wasm.SectionId, writer, section_id);

            var sections_size: u32 = 0;
            const section_len: u32 = @intCast(self.size());

            sections_size += wasm.lebEncodedSize(section_len);
            for (self.data.items) |entry| {
                sections_size += entry.encodedSize();
            }

            try leb.writeULEB128(writer, sections_size);
            try leb.writeULEB128(writer, section_len);

            for (self.data.items) |entry| {
                try entry.write(writer);
            }
        }

        pub fn deinit(self: Self) void {
            self.data.deinit();
        }
    };
}

const Module = @This();

version: u32 = 1,
//custom: []const sections.Custom = &.{},
types: SectionData(sections.Type),
funcs: SectionData(sections.Function),
tables: SectionData(sections.Table),
memories: SectionData(sections.Memory),
globals: SectionData(sections.Global),
elements: SectionData(sections.Element),
datas: SectionData(sections.Data),
imports: SectionData(sections.Import),
exports: SectionData(sections.Export),
code: SectionData(sections.Code),
data_counts: SectionData(sections.DataCount),

pub fn init(allocator: Allocator) Module {
    return Module{
        .types = SectionData(sections.Type).init(allocator),
        .funcs = SectionData(sections.Function).init(allocator),
        .tables = SectionData(sections.Table).init(allocator),
        .memories = SectionData(sections.Memory).init(allocator),
        .globals = SectionData(sections.Global).init(allocator),
        .elements = SectionData(sections.Element).init(allocator),
        .datas = SectionData(sections.Data).init(allocator),
        .imports = SectionData(sections.Import).init(allocator),
        .exports = SectionData(sections.Export).init(allocator),
        .code = SectionData(sections.Code).init(allocator),
        .data_counts = SectionData(sections.DataCount).init(allocator),
    };
}

pub fn unmarshalWithReader(allocator: Allocator, reader: anytype) !Module {
    const magic = try reader.readBytesNoEof(4);
    if (!std.mem.eql(u8, &magic, "\x00asm")) {
        return error.InvalidMagic;
    }

    const version = try reader.readIntLittle(u32);
    if (version != 1) {
        return error.InvalidVersion;
    }

    var module: Module = Module.init(allocator);
    var timer = try std.time.Timer.start();
    while (wasm.readEnum(wasm.SectionId, reader)) |section_id| {
        const section_len = try wasm.readLeb(u32, reader);

        switch (section_id) {
            .Custom => try reader.skipBytes(section_len, .{}),
            .Type => try readTypesSection(&module, allocator, reader),
            .Import => try readImportSection(&module, allocator, reader),
            .Function => {
                const funcs_len = try wasm.readLeb(u32, reader);
                try module.funcs.initCapacity(allocator, funcs_len);
                errdefer module.funcs.deinit();

                for (0..funcs_len) |_| {
                    try module.funcs.push(.{ .type_index = try wasm.readLeb(u32, reader) });
                }
            },
            .Table => {
                const tables_len = try wasm.readLeb(u32, reader);
                try module.tables.initCapacity(allocator, tables_len);
                errdefer module.tables.deinit();

                for (0..tables_len) |_| {
                    try module.tables.push(.{
                        .element_type = try wasm.readEnum(wasm.Reftype, reader),
                        .limits = try wasm.readLimits(reader),
                    });
                }
            },
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
            .Element => {
                const elements_len = try wasm.readLeb(u32, reader);
                try module.elements.initCapacity(allocator, elements_len);
                errdefer module.elements.deinit();

                for (0..elements_len) |_| {
                    var elements: ?ArrayList(u32) = null;
                    const table_index = try wasm.readLeb(u32, reader);
                    const offset = try wasm.readInit(reader);

                    const table = module.tables.at(table_index) orelse return error.OutOfBoundsTable;
                    if (table.element_type == .funcref) {
                        const len = try wasm.readLeb(u32, reader);
                        elements = try ArrayList(u32).initCapacity(allocator, len);
                        errdefer elements.?.deinit();

                        for (0..len) |_| {
                            try elements.?.append(try wasm.readLeb(u32, reader));
                        }
                    }

                    try module.elements.push(.{ .index = table_index, .offset = offset, .elements = elements });
                }
            },
            .Code => try readCodeSection(&module, allocator, reader),
            .Data => {
                const datas_len = try wasm.readLeb(u32, reader);
                try module.datas.initCapacity(allocator, datas_len);
                errdefer module.datas.deinit();

                for (0..datas_len) |_| {
                    const index = try wasm.readLeb(u32, reader);
                    const offset = try wasm.readInit(reader);
                    const len = try wasm.readLeb(u32, reader);

                    var raw_data = try allocator.alloc(u8, len);
                    errdefer allocator.free(raw_data);

                    try reader.readNoEof(raw_data);

                    try module.datas.push(.{ .index = index, .offset = offset, .data = raw_data });
                }
            },
            .DataCount => return error.UnimplementedSection,
        }

        std.debug.print("section: {any}, section length: 0x{x} took: {}us\n", .{ section_id, section_len, timer.lap() / std.time.ns_per_us });
    } else |err| switch (err) {
        error.EndOfStream => {},
        else => |e| return e,
    }

    return module;
}

pub fn marshalModule(self: Module, writer: anytype) !void {
    try writer.writeAll("\x00asm");
    try writer.writeInt(u32, 1, .Little);

    try self.types.write(writer, .Type);
    try self.imports.write(writer, .Import);
    try self.funcs.write(writer, .Function);
    try self.tables.write(writer, .Table);
    try self.memories.write(writer, .Memory);
    try self.globals.write(writer, .Global);
    try self.exports.write(writer, .Export);
    try self.elements.write(writer, .Element);
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

fn readCodeSection(module: *Module, allocator: Allocator, internal_reader: anytype) !void {
    const code_length = try wasm.readLeb(u32, internal_reader);
    try module.code.initCapacity(allocator, code_length);
    errdefer module.code.deinit();

    for (0..code_length) |_| {
        // "the u32 size of the function code in bytes" we dont really care about that
        const bytes_left = try wasm.readLeb(u32, internal_reader);

        var limited_reader = std.io.limitedReader(internal_reader, @intCast(bytes_left));
        var reader = limited_reader.reader();
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

        while (wasm.readOpcode(reader)) |opcode| {
            const instruction = try Instruction.fromOpcode(opcode, allocator, reader);
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
