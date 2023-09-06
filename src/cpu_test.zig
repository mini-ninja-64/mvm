const std = @import("std");
const testing = @import("std").testing;

const cpu = @import("cpu.zig");

const ZERO_MEMORY = [_]u8{};

fn generate3RegisterInstruction(opcode: u4, rx: u4, ry: u4, rz: u4) u16 {
    return @as(u16, opcode) << 12 | @as(u16, rx) << 8 | @as(u16, ry) << 4 | rz;
}
fn generate1RegisterConstantInstruction(opcode: u4, rx: u4, constant: u8) u16 {
    return @as(u16, opcode) << 12 | @as(u16, rx) << 8 | constant;
}
fn generate2RegisterInstruction(opcode: u8, rx: u4, ry: u4) u16 {
    return @as(u16, opcode) << 8 | @as(u16, rx) << 4 | ry;
}

fn carried(register: u32) bool {
    return (register & cpu.CPU.CarryMask) > 0;
}

fn overflowed(register: u32) bool {
    return (register & cpu.CPU.OverflowMask) > 0;
}

test "Adds constants" {
    var mvmCpu = cpu.CPU{ .memory = &ZERO_MEMORY };

    const register = 0;
    mvmCpu.registers[register] = 100;

    const instruction = generate1RegisterConstantInstruction(0b0000, register, 9);

    mvmCpu.execute(instruction);
    try testing.expect(mvmCpu.registers[register] == 100 + 9);
}

test "Adds registers" {
    var mvmCpu = cpu.CPU{ .memory = &ZERO_MEMORY };

    mvmCpu.registers[1] = 40;
    mvmCpu.registers[2] = 15;

    const instruction = generate3RegisterInstruction(0b0001, 0, 1, 2);

    mvmCpu.execute(instruction);
    try testing.expectEqual(@as(u32, 40 + 15), mvmCpu.registers[0]);
}

test "Subtracts constants" {
    var mvmCpu = cpu.CPU{ .memory = &ZERO_MEMORY };

    const register = 0;
    mvmCpu.registers[register] = 100;

    const instruction = generate1RegisterConstantInstruction(0b0010, register, 9);

    mvmCpu.execute(instruction);
    try testing.expectEqual(@as(u32, 100 - 9), mvmCpu.registers[register]);

    // Test 2's complement behaviour
    mvmCpu.registers[register] = 5;
    const instruction2 = generate1RegisterConstantInstruction(0b0010, register, 25);
    mvmCpu.execute(instruction2);
    const expected: u32 = @bitCast(@as(i32, 5 -% 25));
    try testing.expectEqual(expected, mvmCpu.registers[register]);
}

test "Subtracts registers" {
    var mvmCpu = cpu.CPU{ .memory = &ZERO_MEMORY };

    mvmCpu.registers[1] = 40;
    mvmCpu.registers[2] = 15;

    const instruction = generate3RegisterInstruction(0b0011, 0, 1, 2);

    mvmCpu.execute(instruction);
    try testing.expectEqual(@as(u32, 40 - 15), mvmCpu.registers[0]);
}

test "Updates overflow and carry flags on arithmetic operations" {
    var mvmCpu = cpu.CPU{ .memory = &ZERO_MEMORY };

    const MAX: u32 = 0xFFFFFFFF;
    const MAX_SIGNED: u32 = 0x7FFFFFFF;
    const MIN_SIGNED: u32 = 0x80000000;
    const POSITIVE_1: u32 = @as(u32, @intCast(1));
    const NEGATIVE_1: u32 = @as(u32, @bitCast(@as(i32, @intCast(-1))));
    const ZERO: u32 = 0;

    // MAX + 1 = 0 or -1 + 1 = 0 (carry)
    mvmCpu.registers[0] = MAX;
    mvmCpu.execute(generate1RegisterConstantInstruction(0b0000, 0, POSITIVE_1));
    try testing.expectEqual(ZERO, mvmCpu.registers[0]);
    try testing.expect(carried(mvmCpu.registers[4]));
    try testing.expect(!overflowed(mvmCpu.registers[4]));

    // MAX_SIGNED + 1 = N/A or MAX_SIGNED + 1 = MIN_SIGNED (overflow)
    mvmCpu.registers[0] = MAX_SIGNED;
    mvmCpu.execute(generate1RegisterConstantInstruction(0b0000, 0, 1));
    try testing.expectEqual(MIN_SIGNED, mvmCpu.registers[0]);
    try testing.expect(!carried(mvmCpu.registers[4]));
    try testing.expect(overflowed(mvmCpu.registers[4]));

    // MIN_SIGNED + (-1) = MAX_SIGNED (carry & overflow)
    mvmCpu.registers[0] = MIN_SIGNED;
    mvmCpu.registers[1] = NEGATIVE_1;
    mvmCpu.execute(generate3RegisterInstruction(0b0001, 0, 0, 1));
    try testing.expectEqual(MAX_SIGNED, mvmCpu.registers[0]);
    try testing.expect(carried(mvmCpu.registers[4]));
    try testing.expect(overflowed(mvmCpu.registers[4]));

    // MAX_SIGNED - (-1) = MIN_SIGNED (overflow)
    mvmCpu.registers[0] = MAX_SIGNED;
    mvmCpu.registers[1] = NEGATIVE_1;
    mvmCpu.execute(generate3RegisterInstruction(0b0011, 0, 0, 1));
    try testing.expectEqual(MIN_SIGNED, mvmCpu.registers[0]);
    try testing.expect(carried(mvmCpu.registers[4]));
    try testing.expect(overflowed(mvmCpu.registers[4]));

    // MIN_SIGNED - (+1) = MAX_SIGNED (overflow)
    mvmCpu.registers[0] = MIN_SIGNED;
    mvmCpu.registers[1] = POSITIVE_1;
    mvmCpu.execute(generate3RegisterInstruction(0b0011, 0, 0, 1));
    try testing.expectEqual(MAX_SIGNED, mvmCpu.registers[0]);
    try testing.expect(!carried(mvmCpu.registers[4]));
    try testing.expect(overflowed(mvmCpu.registers[4]));

    // 0 - (+1) = -1 or 0 - (+1) = MAX (carry)
    mvmCpu.registers[0] = ZERO;
    mvmCpu.registers[1] = POSITIVE_1;
    mvmCpu.execute(generate3RegisterInstruction(0b0011, 0, 0, 1));
    try testing.expectEqual(NEGATIVE_1, mvmCpu.registers[0]);
    try testing.expect(carried(mvmCpu.registers[4]));
    try testing.expect(!overflowed(mvmCpu.registers[4]));
}

test "Resets overflow and carry flags on arithmetic operations" {
    var mvmCpu = cpu.CPU{ .memory = &ZERO_MEMORY };

    mvmCpu.registers[0] = 0x7FFFFFFF;
    mvmCpu.registers[1] = 0xFFFFFFFF;
    mvmCpu.execute(generate3RegisterInstruction(0b0011, 0, 0, 1));
    try testing.expect(carried(mvmCpu.registers[4]));
    try testing.expect(overflowed(mvmCpu.registers[4]));

    mvmCpu.registers[0] = 0;
    mvmCpu.execute(generate3RegisterInstruction(0b0001, 0, 0, 0));
    try testing.expect(!carried(mvmCpu.registers[4]));
    try testing.expect(!overflowed(mvmCpu.registers[4]));
}

test "Writes constants to registers" {
    var mvmCpu = cpu.CPU{ .memory = &ZERO_MEMORY };

    const instruction = generate1RegisterConstantInstruction(0b0100, 0, 0xFF);
    mvmCpu.execute(instruction);

    try testing.expectEqual(@as(u32, 0xFF), mvmCpu.registers[0]);
}

test "Bitwise left shift correctly shifts a register" {
    var mvmCpu = cpu.CPU{ .memory = &ZERO_MEMORY };

    mvmCpu.registers[0] = 0xAABBCCDD;
    mvmCpu.registers[1] = 8;
    mvmCpu.execute(generate3RegisterInstruction(0b0101, 0, 0, 1));
    try testing.expectEqual(@as(u32, 0xBBCCDD00), mvmCpu.registers[0]);
}

test "Bitwise right shift correctly shifts a register" {
    var mvmCpu = cpu.CPU{ .memory = &ZERO_MEMORY };

    mvmCpu.registers[0] = 0xAABBCCDD;
    mvmCpu.registers[1] = 8;
    mvmCpu.execute(generate3RegisterInstruction(0b0110, 0, 0, 1));
    try testing.expectEqual(@as(u32, 0x00AABBCC), mvmCpu.registers[0]);
}

test "Bitwise or correctly or's registers" {
    var mvmCpu = cpu.CPU{ .memory = &ZERO_MEMORY };

    mvmCpu.registers[0] = 0xAABBCCDD;
    mvmCpu.registers[1] = 0xDDCCBBAA;
    mvmCpu.execute(generate3RegisterInstruction(0b0111, 2, 0, 1));
    try testing.expectEqual(@as(u32, 0xffffffff), mvmCpu.registers[2]);
}

test "Bitwise and correctly and's registers" {
    var mvmCpu = cpu.CPU{ .memory = &ZERO_MEMORY };

    mvmCpu.registers[0] = 0xAABBCCDD;
    mvmCpu.registers[1] = 0xDDCCBBAA;
    mvmCpu.execute(generate3RegisterInstruction(0b1000, 2, 0, 1));
    try testing.expectEqual(@as(u32, 0x88888888), mvmCpu.registers[2]);
}

test "Bitwise flip correctly flips a register" {
    var mvmCpu = cpu.CPU{ .memory = &ZERO_MEMORY };

    mvmCpu.registers[0] = 0xAABBCCFF;
    mvmCpu.execute(generate3RegisterInstruction(0b1001, 1, 0, 0));
    try testing.expectEqual(@as(u32, 0x55443300), mvmCpu.registers[1]);
}

test "Bitwise xor correctly xor's registers" {
    var mvmCpu = cpu.CPU{ .memory = &ZERO_MEMORY };

    mvmCpu.registers[0] = 0xAABBCCF0;
    mvmCpu.registers[1] = 0xDDCCBBFF;
    mvmCpu.execute(generate3RegisterInstruction(0b1010, 2, 0, 1));
    try testing.expectEqual(@as(u32, 0x7777770f), mvmCpu.registers[2]);
}

test "Copies registers correctly" {
    var mvmCpu = cpu.CPU{ .memory = &ZERO_MEMORY };

    mvmCpu.registers[0] = 0;
    mvmCpu.registers[1] = 0xAABBCCDD;

    mvmCpu.execute(generate2RegisterInstruction(0b11100000, 0, 1));
    try testing.expectEqual(@as(u32, 0xAABBCCDD), mvmCpu.registers[0]);
}

// TODO: Define behaviour if memory not big enough etc
test "Copies data from memory address to register" {
    var memory = [_]u8{ 0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF, 0xAA, 0xBB };
    var mvmCpu = cpu.CPU{ .memory = &memory };

    mvmCpu.registers[0] = 0;
    mvmCpu.registers[1] = 4;

    mvmCpu.execute(generate2RegisterInstruction(0b11100001, 0, 1));
    try testing.expectEqual(@as(u32, 0xEEFFAABB), mvmCpu.registers[0]);
}

test "Copies data from register to memory address" {
    var memory = [_]u8{0} ** 8;
    var mvmCpu = cpu.CPU{ .memory = &memory };

    mvmCpu.registers[0] = 0xAABBCCDD;
    mvmCpu.registers[1] = 2;

    mvmCpu.execute(generate2RegisterInstruction(0b11100010, 0, 1));
    try testing.expectEqual(@as(u8, 0x00), memory[0]);
    try testing.expectEqual(@as(u8, 0x00), memory[1]);
    try testing.expectEqual(@as(u8, 0xAA), memory[2]);
    try testing.expectEqual(@as(u8, 0xBB), memory[3]);
    try testing.expectEqual(@as(u8, 0xCC), memory[4]);
    try testing.expectEqual(@as(u8, 0xDD), memory[5]);
    try testing.expectEqual(@as(u8, 0x00), memory[6]);
    try testing.expectEqual(@as(u8, 0x00), memory[7]);
}

test "Compares provided registers" {
    // TODO
}

test "Push should add the current register to the stack" {
    // TODO
}

test "Pop should remove 32-bits from the stack and store it in the provided register" {
    // TODO
}

// TODO: branching tests
