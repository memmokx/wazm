const std = @import("std");
const wasm_core = @import("../core.zig");
const Stack = @import("stack.zig").Stack;

pub const BinaryOperator = enum {
    Add,
    Sub,
    Mul,
    Div,
    And,
    Or,
    Xor,
    Shr,
};

pub const BinaryOp = struct {
    lhs: Operand,
    rhs: Operand,
    op: BinaryOperator,
    result: Operand,

    pub fn getOperand(self: BinaryOp, comptime i: usize) Operand {
        return switch (i) {
            0 => self.lhs,
            1 => self.rhs,
            else => @compileError("unknown operand value, valid values are '0' or '1'"),
        };
    }

    pub fn format(
        self: BinaryOp,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;

        try writer.print("{} = {s} {}, {}", .{ self.result, @tagName(self.op), self.lhs, self.rhs });
    }
};

pub const Instruction = union(enum) {
    Add: BinaryOp,
    Sub: BinaryOp,
    Mul: BinaryOp,
    Div: BinaryOp,
    And: BinaryOp,
    Or: BinaryOp,
    Xor: BinaryOp,
    Shr: BinaryOp,
    Call: void,

    pub fn isBinaryOp(self: Instruction) bool {
        return switch (self) {
            .Add, .Sub, .Mul, .Div, .And, .Or, .Xor, .Shr => true,
            else => false,
        };
    }

    pub fn getResult(self: Instruction) Operand {
        return switch (self) {
            .Add, .Sub, .Mul, .Div, .And, .Or, .Xor, .Shr => |op| op.result,
            else => @panic("getResult on instruction that has no return"),
        };
    }

    pub fn format(
        self: Instruction,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;

        switch (self) {
            inline else => |value| try writer.print("{}", .{value}),
        }
    }
};

pub const Operand = union(enum) {
    Const: union(enum) { i64: i64, i32: i32, f32: f32, f64: f64 },
    Var: u32,
    Local: u32,

    pub fn format(
        self: Operand,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;

        switch (self) {
            .Var => |idx| try writer.print("%{d}", .{idx}),
            .Local => |idx| try writer.print("local({d})", .{idx}),
            .Const => |v| switch (v) {
                inline else => |value| try writer.print("{}", .{value}),
            },
        }
    }
};

pub const Builder = struct {
    allocator: std.mem.Allocator,
    var_idx: u32 = 0,

    pub fn init(allocator: std.mem.Allocator) Builder {
        return .{
            .allocator = allocator,
        };
    }

    pub fn createXor(self: *Builder, lhs: Operand, rhs: Operand) Instruction {
        defer self.var_idx += 1;
        return .{ .Xor = .{
            .lhs = lhs,
            .rhs = rhs,
            .op = .Xor,
            .result = createVar(self.var_idx),
        } };
    }

    pub fn createAnd(self: *Builder, lhs: Operand, rhs: Operand) Instruction {
        defer self.var_idx += 1;
        return .{ .And = .{
            .lhs = lhs,
            .rhs = rhs,
            .op = .And,
            .result = createVar(self.var_idx),
        } };
    }

    pub fn createAdd(self: *Builder, lhs: Operand, rhs: Operand) Instruction {
        defer self.var_idx += 1;
        return .{ .Add = .{
            .lhs = lhs,
            .rhs = rhs,
            .op = .Add,
            .result = createVar(self.var_idx),
        } };
    }

    pub fn createSub(self: *Builder, lhs: Operand, rhs: Operand) Instruction {
        defer self.var_idx += 1;
        return .{ .Sub = .{
            .lhs = lhs,
            .rhs = rhs,
            .op = .Sub,
            .result = createVar(self.var_idx),
        } };
    }

    pub fn createDiv(self: *Builder, lhs: Operand, rhs: Operand) Instruction {
        defer self.var_idx += 1;
        return .{ .Div = .{
            .lhs = lhs,
            .rhs = rhs,
            .op = .Div,
            .result = createVar(self.var_idx),
        } };
    }

    pub fn createMul(self: *Builder, lhs: Operand, rhs: Operand) Instruction {
        defer self.var_idx += 1;
        return .{ .Mul = .{
            .lhs = lhs,
            .rhs = rhs,
            .op = .Mul,
            .result = createVar(self.var_idx),
        } };
    }

    pub fn createShr(self: *Builder, lhs: Operand, rhs: Operand) Instruction {
        defer self.var_idx += 1;
        return .{ .Shr = .{
            .lhs = lhs,
            .rhs = rhs,
            .op = .Shr,
            .result = createVar(self.var_idx),
        } };
    }

    pub fn createLocal(idx: u32) Operand {
        return .{ .Local = idx };
    }

    pub fn createVar(idx: u32) Operand {
        return .{ .Var = idx };
    }

    pub fn createConst(comptime T: type, value: T) Operand {
        return switch (T) {
            i32 => .{ .Const = .{ .i32 = value } },
            i64 => .{ .Const = .{ .i64 = value } },
            else => @compileError("createConst only accepts 'i32' or 'i64'"),
        };
    }
};

pub fn convertModule(module: wasm_core.Module, allocator: std.mem.Allocator) ![]Instruction {
    const code = module.code.data[0];
    var builder = Builder.init(allocator);
    var instructions = std.ArrayList(Instruction).init(allocator);
    defer instructions.deinit();

    var stack = Stack(Instruction).init(allocator);

    for (code.body, 0..) |instruction, i| {
        if (!isBinaryOp(instruction)) continue;

        var generated_inst: Instruction = undefined;

        std.debug.print("------------\n", .{});
        stack.print();

        switch (instruction.opcode) {
            .i32_sub, .i64_sub => {
                if (i < 2)
                    continue;
                generated_inst = try createBinaryOp(&builder, &stack, code.body[i - 2], code.body[i - 1], Builder.createSub);
            },
            .i32_add, .i64_add => {
                if (i < 2)
                    continue;
                generated_inst = try createBinaryOp(&builder, &stack, code.body[i - 2], code.body[i - 1], Builder.createAdd);
            },
            .i32_mul, .i64_mul => {
                if (i < 2)
                    continue;
                generated_inst = try createBinaryOp(&builder, &stack, code.body[i - 2], code.body[i - 1], Builder.createMul);
            },
            .i32_xor, .i64_xor => {
                if (i < 2)
                    continue;
                generated_inst = try createBinaryOp(&builder, &stack, code.body[i - 2], code.body[i - 1], Builder.createXor);
            },
            .i32_and, .i64_and => {
                if (i < 2)
                    continue;
                generated_inst = try createBinaryOp(&builder, &stack, code.body[i - 2], code.body[i - 1], Builder.createAnd);
            },
            .i32_shr_u,
            .i32_shr_s,
            .i64_shr_u,
            .i64_shr_s,
            => {
                if (i < 2)
                    continue;
                generated_inst = try createBinaryOp(&builder, &stack, code.body[i - 2], code.body[i - 1], Builder.createShr);
            },
            else => continue,
        }

        try stack.push(generated_inst);
        try instructions.append(generated_inst);
    }

    return try instructions.toOwnedSlice();
}

fn createBinaryOp(
    builder: *Builder,
    stack: *Stack(Instruction),
    lhs: wasm_core.Instruction,
    rhs: wasm_core.Instruction,
    comptime func: *const fn (*Builder, Operand, Operand) Instruction,
) !Instruction {
    return @call(.auto, func, .{ builder, try toOperand(lhs, stack), try toOperand(rhs, stack) });
}

fn toOperand(inst: wasm_core.Instruction, stack: *Stack(Instruction)) !Operand {
    var operand: ?Operand = switch (inst.opcode) {
        .i32_const => .{ .Const = .{ .i32 = inst.value.i32 } },
        .i64_const => .{ .Const = .{ .i64 = inst.value.i64 } },
        .local_get => .{ .Local = inst.value.idx },
        .i32_sub,
        .i32_add,
        .i32_and,
        .i32_mul,
        .i32_div_s,
        .i32_div_u,
        .i32_xor,
        .i32_or,
        .i64_sub,
        .i64_add,
        .i64_and,
        .i64_mul,
        .i64_div_s,
        .i64_div_u,
        .i64_xor,
        .i64_or,
        .i64_shr_u,
        .i64_shr_s,
        .i32_shr_u,
        .i32_shr_s,
        => if (try stack.pop()) |binary_op| binary_op.getResult() else null,
        else => null,
    };

    if (operand) |op| {
        return op;
    }

    return error.InvalidInstruction;
}

pub fn isBinaryOp(inst: wasm_core.Instruction) bool {
    return switch (inst.opcode) {
        .i32_sub,
        .i32_add,
        .i32_and,
        .i32_mul,
        .i32_div_s,
        .i32_div_u,
        .i32_xor,
        .i32_or,
        .i64_sub,
        .i64_add,
        .i64_and,
        .i64_mul,
        .i64_div_s,
        .i64_div_u,
        .i64_xor,
        .i64_or,
        .i64_shr_u,
        .i64_shr_s,
        .i32_shr_u,
        .i32_shr_s,
        => true,
        else => false,
    };
}

test "simple binary op" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var allocator = arena.allocator();
    var builder = Builder.init(allocator);
    _ = builder;

    var instruction = Builder.createXor(
        Builder.createConst(i32, 256),
        Builder.createConst(i32, 259),
    );

    var n =
        std.debug.print("{}", .{instruction});
    _ = n;
    // if (instruction.is(.Or)) {
    //     std.debug.print("{}", .{instruction.Or.lhs});
    // }

    //    instruction.dump();
}
