const std = @import("std");
const ArrayListUnmanaged = std.ArrayListUnmanaged;
const Allocator = std.mem.Allocator;
const leb = std.leb;
const meta = std.meta;

pub const Opcode = enum(u8) {
    @"unreachable" = 0x00,
    nop = 0x01,
    block = 0x02,
    loop = 0x03,
    @"if" = 0x04,
    @"else" = 0x05,
    end = 0x0B,
    br = 0x0C,
    br_if = 0x0D,
    br_table = 0x0E,
    @"return" = 0x0F,
    call = 0x10,
    call_indirect = 0x11,
    drop = 0x1A,
    select = 0x1B,
    local_get = 0x20,
    local_set = 0x21,
    local_tee = 0x22,
    global_get = 0x23,
    global_set = 0x24,
    table_get = 0x25,
    table_set = 0x26,
    i32_load = 0x28,
    i64_load = 0x29,
    f32_load = 0x2A,
    f64_load = 0x2B,
    i32_load8_s = 0x2C,
    i32_load8_u = 0x2D,
    i32_load16_s = 0x2E,
    i32_load16_u = 0x2F,
    i64_load8_s = 0x30,
    i64_load8_u = 0x31,
    i64_load16_s = 0x32,
    i64_load16_u = 0x33,
    i64_load32_s = 0x34,
    i64_load32_u = 0x35,
    i32_store = 0x36,
    i64_store = 0x37,
    f32_store = 0x38,
    f64_store = 0x39,
    i32_store8 = 0x3A,
    i32_store16 = 0x3B,
    i64_store8 = 0x3C,
    i64_store16 = 0x3D,
    i64_store32 = 0x3E,
    memory_size = 0x3F,
    memory_grow = 0x40,
    i32_const = 0x41,
    i64_const = 0x42,
    f32_const = 0x43,
    f64_const = 0x44,
    i32_eqz = 0x45,
    i32_eq = 0x46,
    i32_ne = 0x47,
    i32_lt_s = 0x48,
    i32_lt_u = 0x49,
    i32_gt_s = 0x4A,
    i32_gt_u = 0x4B,
    i32_le_s = 0x4C,
    i32_le_u = 0x4D,
    i32_ge_s = 0x4E,
    i32_ge_u = 0x4F,
    i64_eqz = 0x50,
    i64_eq = 0x51,
    i64_ne = 0x52,
    i64_lt_s = 0x53,
    i64_lt_u = 0x54,
    i64_gt_s = 0x55,
    i64_gt_u = 0x56,
    i64_le_s = 0x57,
    i64_le_u = 0x58,
    i64_ge_s = 0x59,
    i64_ge_u = 0x5A,
    f32_eq = 0x5B,
    f32_ne = 0x5C,
    f32_lt = 0x5D,
    f32_gt = 0x5E,
    f32_le = 0x5F,
    f32_ge = 0x60,
    f64_eq = 0x61,
    f64_ne = 0x62,
    f64_lt = 0x63,
    f64_gt = 0x64,
    f64_le = 0x65,
    f64_ge = 0x66,
    i32_clz = 0x67,
    i32_ctz = 0x68,
    i32_popcnt = 0x69,
    i32_add = 0x6A,
    i32_sub = 0x6B,
    i32_mul = 0x6C,
    i32_div_s = 0x6D,
    i32_div_u = 0x6E,
    i32_rem_s = 0x6F,
    i32_rem_u = 0x70,
    i32_and = 0x71,
    i32_or = 0x72,
    i32_xor = 0x73,
    i32_shl = 0x74,
    i32_shr_s = 0x75,
    i32_shr_u = 0x76,
    i32_rotl = 0x77,
    i32_rotr = 0x78,
    i64_clz = 0x79,
    i64_ctz = 0x7A,
    i64_popcnt = 0x7B,
    i64_add = 0x7C,
    i64_sub = 0x7D,
    i64_mul = 0x7E,
    i64_div_s = 0x7F,
    i64_div_u = 0x80,
    i64_rem_s = 0x81,
    i64_rem_u = 0x82,
    i64_and = 0x83,
    i64_or = 0x84,
    i64_xor = 0x85,
    i64_shl = 0x86,
    i64_shr_s = 0x87,
    i64_shr_u = 0x88,
    i64_rotl = 0x89,
    i64_rotr = 0x8A,
    f32_abs = 0x8B,
    f32_neg = 0x8C,
    f32_ceil = 0x8D,
    f32_floor = 0x8E,
    f32_trunc = 0x8F,
    f32_nearest = 0x90,
    f32_sqrt = 0x91,
    f32_add = 0x92,
    f32_sub = 0x93,
    f32_mul = 0x94,
    f32_div = 0x95,
    f32_min = 0x96,
    f32_max = 0x97,
    f32_copysign = 0x98,
    f64_abs = 0x99,
    f64_neg = 0x9A,
    f64_ceil = 0x9B,
    f64_floor = 0x9C,
    f64_trunc = 0x9D,
    f64_nearest = 0x9E,
    f64_sqrt = 0x9F,
    f64_add = 0xA0,
    f64_sub = 0xA1,
    f64_mul = 0xA2,
    f64_div = 0xA3,
    f64_min = 0xA4,
    f64_max = 0xA5,
    f64_copysign = 0xA6,
    i32_wrap_i64 = 0xA7,
    i32_trunc_f32_s = 0xA8,
    i32_trunc_f32_u = 0xA9,
    i32_trunc_f64_s = 0xAA,
    i32_trunc_f64_u = 0xAB,
    i64_extend_i32_s = 0xAC,
    i64_extend_i32_u = 0xAD,
    i64_trunc_f32_s = 0xAE,
    i64_trunc_f32_u = 0xAF,
    i64_trunc_f64_s = 0xB0,
    i64_trunc_f64_u = 0xB1,
    f32_convert_i32_s = 0xB2,
    f32_convert_i32_u = 0xB3,
    f32_convert_i64_s = 0xB4,
    f32_convert_i64_u = 0xB5,
    f32_demote_f64 = 0xB6,
    f64_convert_i32_s = 0xB7,
    f64_convert_i32_u = 0xB8,
    f64_convert_i64_s = 0xB9,
    f64_convert_i64_u = 0xBA,
    f64_promote_f32 = 0xBB,
    i32_reinterpret_f32 = 0xBC,
    i64_reinterpret_f64 = 0xBD,
    f32_reinterpret_i32 = 0xBE,
    f64_reinterpret_i64 = 0xBF,
    i32_extend8_s = 0xC0,
    i32_extend16_s = 0xC1,
    i64_extend8_s = 0xC2,
    i64_extend16_s = 0xC3,
    i64_extend32_s = 0xC4,
    ref_null = 0xD0,
    ref_is_null = 0xD1,
    ref_func = 0xD2,

    misc_prefix = 0xFC,
    simd_prefix = 0xFD,
    atomics_prefix = 0xFE,
    _,
};

pub const MiscOpcode = enum(u32) {
    i32_trunc_sat_f32_s = 0x00,
    i32_trunc_sat_f32_u = 0x01,
    i32_trunc_sat_f64_s = 0x02,
    i32_trunc_sat_f64_u = 0x03,
    i64_trunc_sat_f32_s = 0x04,
    i64_trunc_sat_f32_u = 0x05,
    i64_trunc_sat_f64_s = 0x06,
    i64_trunc_sat_f64_u = 0x07,
    memory_init = 0x08,
    data_drop = 0x09,
    memory_copy = 0x0A,
    memory_fill = 0x0B,
    table_init = 0x0C,
    elem_drop = 0x0D,
    table_copy = 0x0E,
    table_grow = 0x0F,
    table_size = 0x10,
    table_fill = 0x11,
    _,
};

pub const SimdOpcode = enum(u32) {
    v128_load = 0x00,
    v128_load8x8_s = 0x01,
    v128_load8x8_u = 0x02,
    v128_load16x4_s = 0x03,
    v128_load16x4_u = 0x04,
    v128_load32x2_s = 0x05,
    v128_load32x2_u = 0x06,
    v128_load8_splat = 0x07,
    v128_load16_splat = 0x08,
    v128_load32_splat = 0x09,
    v128_load64_splat = 0x0A,
    v128_store = 0x0B,
    v128_const = 0x0C,
    i8x16_shuffle = 0x0D,
    i8x16_swizzle = 0x0E,
    i8x16_splat = 0x0F,
    i16x8_splat = 0x10,
    i32x4_splat = 0x11,
    i64x2_splat = 0x12,
    f32x4_splat = 0x13,
    f64x2_splat = 0x14,
    i8x16_extract_lane_s = 0x15,
    i8x16_extract_lane_u = 0x16,
    i8x16_replace_lane = 0x17,
    i16x8_extract_lane_s = 0x18,
    i16x8_extract_lane_u = 0x19,
    i16x8_replace_lane = 0x1A,
    i32x4_extract_lane = 0x1B,
    i32x4_replace_lane = 0x1C,
    i64x2_extract_lane = 0x1D,
    i64x2_replace_lane = 0x1E,
    f32x4_extract_lane = 0x1F,
    f32x4_replace_lane = 0x20,
    f64x2_extract_lane = 0x21,
    f64x2_replace_lane = 0x22,
    i8x16_eq = 0x23,
    i16x8_eq = 0x2D,
    i32x4_eq = 0x37,
    i8x16_ne = 0x24,
    i16x8_ne = 0x2E,
    i32x4_ne = 0x38,
    i8x16_lt_s = 0x25,
    i16x8_lt_s = 0x2F,
    i32x4_lt_s = 0x39,
    i8x16_lt_u = 0x26,
    i16x8_lt_u = 0x30,
    i32x4_lt_u = 0x3A,
    i8x16_gt_s = 0x27,
    i16x8_gt_s = 0x31,
    i32x4_gt_s = 0x3B,
    i8x16_gt_u = 0x28,
    i16x8_gt_u = 0x32,
    i32x4_gt_u = 0x3C,
    i8x16_le_s = 0x29,
    i16x8_le_s = 0x33,
    i32x4_le_s = 0x3D,
    i8x16_le_u = 0x2A,
    i16x8_le_u = 0x34,
    i32x4_le_u = 0x3E,
    i8x16_ge_s = 0x2B,
    i16x8_ge_s = 0x35,
    i32x4_ge_s = 0x3F,
    i8x16_ge_u = 0x2C,
    i16x8_ge_u = 0x36,
    i32x4_ge_u = 0x40,
    f32x4_eq = 0x41,
    f64x2_eq = 0x47,
    f32x4_ne = 0x42,
    f64x2_ne = 0x48,
    f32x4_lt = 0x43,
    f64x2_lt = 0x49,
    f32x4_gt = 0x44,
    f64x2_gt = 0x4A,
    f32x4_le = 0x45,
    f64x2_le = 0x4B,
    f32x4_ge = 0x46,
    f64x2_ge = 0x4C,
    v128_not = 0x4D,
    v128_and = 0x4E,
    v128_andnot = 0x4F,
    v128_or = 0x50,
    v128_xor = 0x51,
    v128_bitselect = 0x52,
    v128_any_true = 0x53,
    v128_load8_lane = 0x54,
    v128_load16_lane = 0x55,
    v128_load32_lane = 0x56,
    v128_load64_lane = 0x57,
    v128_store8_lane = 0x58,
    v128_store16_lane = 0x59,
    v128_store32_lane = 0x5A,
    v128_store64_lane = 0x5B,
    v128_load32_zero = 0x5C,
    v128_load64_zero = 0x5D,
    f32x4_demote_f64x2_zero = 0x5E,
    f64x2_promote_low_f32x4 = 0x5F,
    i8x16_abs = 0x60,
    i16x8_abs = 0x80,
    i32x4_abs = 0xA0,
    i64x2_abs = 0xC0,
    i8x16_neg = 0x61,
    i16x8_neg = 0x81,
    i32x4_neg = 0xA1,
    i64x2_neg = 0xC1,
    i8x16_popcnt = 0x62,
    i16x8_q15mulr_sat_s = 0x82,
    i8x16_all_true = 0x63,
    i16x8_all_true = 0x83,
    i32x4_all_true = 0xA3,
    i64x2_all_true = 0xC3,
    i8x16_bitmask = 0x64,
    i16x8_bitmask = 0x84,
    i32x4_bitmask = 0xA4,
    i64x2_bitmask = 0xC4,
    i8x16_narrow_i16x8_s = 0x65,
    i16x8_narrow_i32x4_s = 0x85,
    i8x16_narrow_i16x8_u = 0x66,
    i16x8_narrow_i32x4_u = 0x86,
    f32x4_ceil = 0x67,
    i16x8_extend_low_i8x16_s = 0x87,
    i32x4_extend_low_i16x8_s = 0xA7,
    i64x2_extend_low_i32x4_s = 0xC7,
    f32x4_floor = 0x68,
    i16x8_extend_high_i8x16_s = 0x88,
    i32x4_extend_high_i16x8_s = 0xA8,
    i64x2_extend_high_i32x4_s = 0xC8,
    f32x4_trunc = 0x69,
    i16x8_extend_low_i8x16_u = 0x89,
    i32x4_extend_low_i16x8_u = 0xA9,
    i64x2_extend_low_i32x4_u = 0xC9,
    f32x4_nearest = 0x6A,
    i16x8_extend_high_i8x16_u = 0x8A,
    i32x4_extend_high_i16x8_u = 0xAA,
    i64x2_extend_high_i32x4_u = 0xCA,
    i8x16_shl = 0x6B,
    i16x8_shl = 0x8B,
    i32x4_shl = 0xAB,
    i64x2_shl = 0xCB,
    i8x16_shr_s = 0x6C,
    i16x8_shr_s = 0x8C,
    i32x4_shr_s = 0xAC,
    i64x2_shr_s = 0xCC,
    i8x16_shr_u = 0x6D,
    i16x8_shr_u = 0x8D,
    i32x4_shr_u = 0xAD,
    i64x2_shr_u = 0xCD,
    i8x16_add = 0x6E,
    i16x8_add = 0x8E,
    i32x4_add = 0xAE,
    i64x2_add = 0xCE,
    i8x16_add_sat_s = 0x6F,
    i16x8_add_sat_s = 0x8F,
    i8x16_add_sat_u = 0x70,
    i16x8_add_sat_u = 0x90,
    i8x16_sub = 0x71,
    i16x8_sub = 0x91,
    i32x4_sub = 0xB1,
    i64x2_sub = 0xD1,
    i8x16_sub_sat_s = 0x72,
    i16x8_sub_sat_s = 0x92,
    i8x16_sub_sat_u = 0x73,
    i16x8_sub_sat_u = 0x93,
    f64x2_ceil = 0x74,
    f64x2_nearest = 0x94,
    f64x2_floor = 0x75,
    i16x8_mul = 0x95,
    i32x4_mul = 0xB5,
    i64x2_mul = 0xD5,
    i8x16_min_s = 0x76,
    i16x8_min_s = 0x96,
    i32x4_min_s = 0xB6,
    i64x2_eq = 0xD6,
    i8x16_min_u = 0x77,
    i16x8_min_u = 0x97,
    i32x4_min_u = 0xB7,
    i64x2_ne = 0xD7,
    i8x16_max_s = 0x78,
    i16x8_max_s = 0x98,
    i32x4_max_s = 0xB8,
    i64x2_lt_s = 0xD8,
    i8x16_max_u = 0x79,
    i16x8_max_u = 0x99,
    i32x4_max_u = 0xB9,
    i64x2_gt_s = 0xD9,
    f64x2_trunc = 0x7A,
    i32x4_dot_i16x8_s = 0xBA,
    i64x2_le_s = 0xDA,
    i8x16_avgr_u = 0x7B,
    i16x8_avgr_u = 0x9B,
    i64x2_ge_s = 0xDB,
    i16x8_extadd_pairwise_i8x16_s = 0x7C,
    i16x8_extmul_low_i8x16_s = 0x9C,
    i32x4_extmul_low_i16x8_s = 0xBC,
    i64x2_extmul_low_i32x4_s = 0xDC,
    i16x8_extadd_pairwise_i8x16_u = 0x7D,
    i16x8_extmul_high_i8x16_s = 0x9D,
    i32x4_extmul_high_i16x8_s = 0xBD,
    i64x2_extmul_high_i32x4_s = 0xDD,
    i32x4_extadd_pairwise_i16x8_s = 0x7E,
    i16x8_extmul_low_i8x16_u = 0x9E,
    i32x4_extmul_low_i16x8_u = 0xBE,
    i64x2_extmul_low_i32x4_u = 0xDE,
    i32x4_extadd_pairwise_i16x8_u = 0x7F,
    i16x8_extmul_high_i8x16_u = 0x9F,
    i32x4_extmul_high_i16x8_u = 0xBF,
    i64x2_extmul_high_i32x4_u = 0xDF,
    f32x4_abs = 0xE0,
    f64x2_abs = 0xEC,
    f32x4_neg = 0xE1,
    f64x2_neg = 0xED,
    f32x4_sqrt = 0xE3,
    f64x2_sqrt = 0xEF,
    f32x4_add = 0xE4,
    f64x2_add = 0xF0,
    f32x4_sub = 0xE5,
    f64x2_sub = 0xF1,
    f32x4_mul = 0xE6,
    f64x2_mul = 0xF2,
    f32x4_div = 0xE7,
    f64x2_div = 0xF3,
    f32x4_min = 0xE8,
    f64x2_min = 0xF4,
    f32x4_max = 0xE9,
    f64x2_max = 0xF5,
    f32x4_pmin = 0xEA,
    f64x2_pmin = 0xF6,
    f32x4_pmax = 0xEB,
    f64x2_pmax = 0xF7,
    i32x4_trunc_sat_f32x4_s = 0xF8,
    i32x4_trunc_sat_f32x4_u = 0xF9,
    f32x4_convert_i32x4_s = 0xFA,
    f32x4_convert_i32x4_u = 0xFB,
    i32x4_trunc_sat_f64x2_s_zero = 0xFC,
    i32x4_trunc_sat_f64x2_u_zero = 0xFD,
    f64x2_convert_low_i32x4_s = 0xFE,
    f64x2_convert_low_i32x4_u = 0xFF,

    // relaxed-simd opcodes
    i8x16_relaxed_swizzle = 0x100,
    i32x4_relaxed_trunc_f32x4_s = 0x101,
    i32x4_relaxed_trunc_f32x4_u = 0x102,
    i32x4_relaxed_trunc_f64x2_s_zero = 0x103,
    i32x4_relaxed_trunc_f64x2_u_zero = 0x104,
    f32x4_relaxed_madd = 0x105,
    f32x4_relaxed_nmadd = 0x106,
    f64x2_relaxed_madd = 0x107,
    f64x2_relaxed_nmadd = 0x108,
    i8x16_relaxed_laneselect = 0x109,
    i16x8_relaxed_laneselect = 0x10a,
    i32x4_relaxed_laneselect = 0x10b,
    i64x2_relaxed_laneselect = 0x10c,
    f32x4_relaxed_min = 0x10d,
    f32x4_relaxed_max = 0x10e,
    f64x2_relaxed_min = 0x10f,
    f64x2_relaxed_max = 0x110,
    i16x8_relaxed_q15mulr_s = 0x111,
    i16x8_relaxed_dot_i8x16_i7x16_s = 0x112,
    i32x4_relaxed_dot_i8x16_i7x16_add_s = 0x113,
    f32x4_relaxed_dot_bf16x8_add_f32x4 = 0x114,
};

pub const Reftype = enum(u8) {
    funcref = 0x70,
    externref = 0x6f,
};

pub const NumType = enum(u8) {
    i32 = 0x7f,
    i64 = 0x7e,
    f32 = 0x7d,
    f64 = 0x7c,
};

pub const VecType = enum(u8) {
    v128 = 0x7b,
};

pub const ValType = enum(u8) {
    // NumType
    i32 = 0x7f,
    i64 = 0x7e,
    f32 = 0x7d,
    f64 = 0x7c,
    // VecType
    v128 = 0x7b,
    // RefType
    funcref = 0x70,
    externref = 0x6f,
};

pub const BlockType = enum(u8) {
    // NumType
    i32 = 0x7f,
    i64 = 0x7e,
    f32 = 0x7d,
    f64 = 0x7c,
    // VecType
    v128 = 0x7b,
    // RefType
    funcref = 0x70,
    externref = 0x6f,
    block_empty = 0x40,
};

pub const SectionId = enum(u8) {
    Custom = 0x00,
    Type = 0x01,
    Import = 0x02,
    Function = 0x03,
    Table = 0x04,
    Memory = 0x05,
    Global = 0x06,
    Export = 0x07,
    Start = 0x08,
    Element = 0x09,
    Code = 0x0A,
    Data = 0x0B,
    DataCount = 0x0C,
};

pub const Limits = struct {
    min: u32,
    max: ?u32,

    pub fn write(self: Limits, writer: anytype) !void {
        const flag: u1 = if (self.max == null) 0 else 1;

        try leb.writeULEB128(writer, flag);
        try leb.writeULEB128(writer, self.min);
        if (self.max) |max| {
            try leb.writeULEB128(writer, max);
        }
    }

    pub fn lebSize(self: Limits) u32 {
        if (self.max) |max| {
            return lebEncodedSize(self.min) + 1 + lebEncodedSize(max);
        }

        return lebEncodedSize(self.min) + 1;
    }
};

pub const InitExpression = union(enum) {
    i32_const: i32,
    /// Uses the value of a global at index `global_get`
    global_get: u32,

    pub fn write(self: InitExpression, writer: anytype) !void {
        switch (self) {
            .i32_const => |value| {
                try writeEnum(Opcode, writer, .i32_const);
                try leb.writeILEB128(writer, value);
            },
            .global_get => |value| {
                try writeEnum(Opcode, writer, .global_get);
                try leb.writeULEB128(writer, value);
            },
        }

        try writeEnum(Opcode, writer, .end);
    }

    pub fn lebSize(self: InitExpression) u32 {
        return switch (self) {
            .i32_const => |value| lebEncodedSize(@as(u8, @intFromEnum(Opcode.i32_const))) + lebEncodedSize(value),
            .global_get => |value| lebEncodedSize(@as(u8, @intFromEnum(Opcode.global_get))) + lebEncodedSize(value),
        } + lebEncodedSize(@as(u8, @intFromEnum(Opcode.end)));
    }
};

pub const ExternalKind = std.wasm.ExternalKind;

/// Uses either `readILEB128` or `readULEB128` depending on the
/// signedness of the given type `T`.
/// Asserts `T` is an integer.
pub fn readLeb(comptime T: type, reader: anytype) !T {
    return switch (@typeInfo(T).Int.signedness) {
        .signed => try leb.readILEB128(T, reader),
        .unsigned => try leb.readULEB128(T, reader),
    };
}

pub fn readOpcode(reader: anytype) !Opcode {
    return @enumFromInt(try reader.readByte());
}

/// Reads an enum type from the given reader.
/// Asserts `T` is an enum
pub fn readEnum(comptime T: type, reader: anytype) !T {
    switch (@typeInfo(T)) {
        .Enum => |enum_type| return @as(T, @enumFromInt(try readLeb(enum_type.tag_type, reader))),
        else => @compileError("T must be an enum. Instead was given type " ++ @typeName(T)),
    }
}

/// Reads the `Limits` type using leb
pub fn readLimits(reader: anytype) !Limits {
    const flag = try readLeb(u1, reader);
    const min = try readLeb(u32, reader);

    return .{
        .min = min,
        .max = if (flag == 0) null else try readLeb(u32, reader),
    };
}

/// Writes an enum `T` using leb
pub fn writeEnum(comptime T: type, writer: anytype, value: T) !void {
    switch (@typeInfo(T)) {
        .Enum => |enum_type| switch (@typeInfo(enum_type.tag_type).Int.signedness) {
            .signed => try leb.writeILEB128(writer, @as(enum_type.tag_type, @intFromEnum(value))),
            .unsigned => try leb.writeULEB128(writer, @as(enum_type.tag_type, @intFromEnum(value))),
        },
        else => @compileError("T must be an enum. Instead was given type " ++ @typeName(T)),
    }
}

//TODO: optimize it possibly with wayyy less branching
/// Returns the size in bytes of the value encoded using leb128
pub fn lebEncodedSize(value: anytype) u32 {
    return switch (@typeInfo(@TypeOf(value)).Int.signedness) {
        .signed => lebISize(value),
        .unsigned => lebUSize(value),
    };
}

fn lebUSize(uint_value: anytype) u32 {
    const T = @TypeOf(uint_value);
    const U = if (@typeInfo(T).Int.bits < 8) u8 else T;
    var value: U = @intCast(uint_value);

    var total: u32 = 0;

    while (true) : (total += 1) {
        value >>= 7;
        if (value == 0) {
            total += 1;
            break;
        }
    }

    return total;
}

fn lebISize(int_value: anytype) u32 {
    const T = @TypeOf(int_value);
    const S = if (@typeInfo(T).Int.bits < 8) i8 else T;

    var value: S = @intCast(int_value);
    var total: u32 = 0;

    while (true) : (total += 1) {
        value >>= 6;
        if (value == -1 or value == 0) {
            total += 1;
            break;
        } else {
            value >>= 1;
        }
    }

    return total;
}

pub fn readInit(reader: anytype) !InitExpression {
    const opcode = try reader.readByte();
    const init_expr: InitExpression = switch (@as(Opcode, @enumFromInt(opcode))) {
        .i32_const => .{ .i32_const = try readLeb(i32, reader) },
        .global_get => .{ .global_get = try readLeb(u32, reader) },
        else => @panic("TODO: initexpression for other opcodes"),
    };

    if ((try readEnum(Opcode, reader)) != .end) return error.MissingEndForExpression;
    return init_expr;
}
