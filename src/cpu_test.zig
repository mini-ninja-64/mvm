const std = @import("std");
const testing = @import("std").testing;

const cpu = @import("cpu.zig");

fn generate3RegisterInstruction(opcode: u4, rx: u4, ry: u4, rz: u4) u16 {
    return @as(u16, opcode) << 12 | @as(u16, rx) << 8 | @as(u16, ry) << 4 | rz;
}
fn generate1RegisterConstantInstruction(opcode: u4, rx: u4, constant: u8) u16 {
    return @as(u16, opcode) << 12 | @as(u16, rx) << 8 | constant;
}
fn generate2RegisterInstruction(opcode: u8, rx: u4, ry: u4) u16 {
    return @as(u16, opcode) << 8 | @as(u16, rx) << 4 | ry;
}

test "Adds constants" {
    var mvmCpu = cpu.CPU{};

    const register = 0;
    mvmCpu.registers[register] = 100;

    const instruction = generate1RegisterConstantInstruction(0b0000, register, 9);

    mvmCpu.execute(instruction);
    try testing.expect(mvmCpu.registers[register] == 100 + 9);
}

test "Adds registers" {
    var mvmCpu = cpu.CPU{};

    mvmCpu.registers[1] = 40;
    mvmCpu.registers[2] = 15;

    const instruction = generate3RegisterInstruction(0b0001, 0, 1, 2);

    mvmCpu.execute(instruction);
    try testing.expectEqual(@as(u32, 40 + 15), mvmCpu.registers[0]);
}

test "Subtracts constants" {
    var mvmCpu = cpu.CPU{};

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
    var mvmCpu = cpu.CPU{};

    mvmCpu.registers[1] = 40;
    mvmCpu.registers[2] = 15;

    const instruction = generate3RegisterInstruction(0b0011, 0, 1, 2);

    mvmCpu.execute(instruction);
    try testing.expectEqual(@as(u32, 40 - 15), mvmCpu.registers[0]);
}

test "Updates zero, negative, overflow and carry flags on arithmetic operations" {
    var mvmCpu = cpu.CPU{};

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
    var status = mvmCpu.getStatus();
    try testing.expect(status.zero);
    try testing.expect(!status.negative);
    try testing.expect(status.carry);
    try testing.expect(!status.overflow);

    // MAX_SIGNED + 1 = N/A or MAX_SIGNED + 1 = MIN_SIGNED (overflow)
    mvmCpu.registers[0] = MAX_SIGNED;
    mvmCpu.execute(generate1RegisterConstantInstruction(0b0000, 0, 1));
    try testing.expectEqual(MIN_SIGNED, mvmCpu.registers[0]);
    status = mvmCpu.getStatus();
    try testing.expect(!status.zero);
    try testing.expect(status.negative);
    try testing.expect(!status.carry);
    try testing.expect(status.overflow);

    // MIN_SIGNED + (-1) = MAX_SIGNED (carry & overflow)
    mvmCpu.registers[0] = MIN_SIGNED;
    mvmCpu.registers[1] = NEGATIVE_1;
    mvmCpu.execute(generate3RegisterInstruction(0b0001, 0, 0, 1));
    try testing.expectEqual(MAX_SIGNED, mvmCpu.registers[0]);
    status = mvmCpu.getStatus();
    try testing.expect(!status.zero);
    try testing.expect(!status.negative);
    try testing.expect(status.carry);
    try testing.expect(status.overflow);

    // MAX_SIGNED - (-1) = MIN_SIGNED (overflow)
    mvmCpu.registers[0] = MAX_SIGNED;
    mvmCpu.registers[1] = NEGATIVE_1;
    mvmCpu.execute(generate3RegisterInstruction(0b0011, 0, 0, 1));
    try testing.expectEqual(MIN_SIGNED, mvmCpu.registers[0]);
    status = mvmCpu.getStatus();
    try testing.expect(!status.zero);
    try testing.expect(status.negative);
    try testing.expect(status.carry);
    try testing.expect(status.overflow);

    // MIN_SIGNED - (+1) = MAX_SIGNED (overflow)
    mvmCpu.registers[0] = MIN_SIGNED;
    mvmCpu.registers[1] = POSITIVE_1;
    mvmCpu.execute(generate3RegisterInstruction(0b0011, 0, 0, 1));
    try testing.expectEqual(MAX_SIGNED, mvmCpu.registers[0]);
    status = mvmCpu.getStatus();
    try testing.expect(!status.zero);
    try testing.expect(!status.negative);
    try testing.expect(!status.carry);
    try testing.expect(status.overflow);

    // 0 - (+1) = -1 or 0 - (+1) = MAX (carry)
    mvmCpu.registers[0] = ZERO;
    mvmCpu.registers[1] = POSITIVE_1;
    mvmCpu.execute(generate3RegisterInstruction(0b0011, 0, 0, 1));
    try testing.expectEqual(NEGATIVE_1, mvmCpu.registers[0]);
    status = mvmCpu.getStatus();
    try testing.expect(!status.zero);
    try testing.expect(status.negative);
    try testing.expect(status.carry);
    try testing.expect(!status.overflow);
}

test "Resets zero, negative overflow and carry flags on arithmetic operations" {
    var mvmCpu = cpu.CPU{};

    mvmCpu.registers[0] = 0x7FFFFFFF;
    mvmCpu.registers[1] = 0xFFFFFFFF;
    mvmCpu.execute(generate3RegisterInstruction(0b0011, 0, 0, 1));
    var status = mvmCpu.getStatus();
    try testing.expect(status.carry);
    try testing.expect(status.overflow);
    try testing.expect(status.negative);
    try testing.expect(!status.zero);

    mvmCpu.registers[0] = 0;
    mvmCpu.execute(generate3RegisterInstruction(0b0001, 0, 0, 0));
    status = mvmCpu.getStatus();
    try testing.expect(!status.carry);
    try testing.expect(!status.overflow);
    try testing.expect(!status.negative);
    try testing.expect(status.zero);
}

test "Writes constants to registers" {
    var mvmCpu = cpu.CPU{};

    const instruction = generate1RegisterConstantInstruction(0b0100, 0, 0xFF);
    mvmCpu.execute(instruction);

    try testing.expectEqual(@as(u32, 0xFF), mvmCpu.registers[0]);
}

test "Bitwise left shift correctly shifts a register" {
    var mvmCpu = cpu.CPU{};

    mvmCpu.registers[0] = 0xAABBCCDD;
    mvmCpu.registers[1] = 8;
    mvmCpu.execute(generate3RegisterInstruction(0b0101, 0, 0, 1));
    try testing.expectEqual(@as(u32, 0xBBCCDD00), mvmCpu.registers[0]);
}

test "Bitwise right shift correctly shifts a register" {
    var mvmCpu = cpu.CPU{};

    mvmCpu.registers[0] = 0xAABBCCDD;
    mvmCpu.registers[1] = 8;
    mvmCpu.execute(generate3RegisterInstruction(0b0110, 0, 0, 1));
    try testing.expectEqual(@as(u32, 0x00AABBCC), mvmCpu.registers[0]);
}

test "Bitwise or correctly or's registers" {
    var mvmCpu = cpu.CPU{};

    mvmCpu.registers[0] = 0xAABBCCDD;
    mvmCpu.registers[1] = 0xDDCCBBAA;
    mvmCpu.execute(generate3RegisterInstruction(0b0111, 2, 0, 1));
    try testing.expectEqual(@as(u32, 0xffffffff), mvmCpu.registers[2]);
}

test "Bitwise and correctly and's registers" {
    var mvmCpu = cpu.CPU{};

    mvmCpu.registers[0] = 0xAABBCCDD;
    mvmCpu.registers[1] = 0xDDCCBBAA;
    mvmCpu.execute(generate3RegisterInstruction(0b1000, 2, 0, 1));
    try testing.expectEqual(@as(u32, 0x88888888), mvmCpu.registers[2]);
}

test "Bitwise flip correctly flips a register" {
    var mvmCpu = cpu.CPU{};

    mvmCpu.registers[0] = 0xAABBCCFF;
    mvmCpu.execute(generate3RegisterInstruction(0b1001, 1, 0, 0));
    try testing.expectEqual(@as(u32, 0x55443300), mvmCpu.registers[1]);
}

test "Bitwise xor correctly xor's registers" {
    var mvmCpu = cpu.CPU{};

    mvmCpu.registers[0] = 0xAABBCCF0;
    mvmCpu.registers[1] = 0xDDCCBBFF;
    mvmCpu.execute(generate3RegisterInstruction(0b1010, 2, 0, 1));
    try testing.expectEqual(@as(u32, 0x7777770f), mvmCpu.registers[2]);
}

test "Copies registers correctly" {
    var mvmCpu = cpu.CPU{};

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
    try testing.expectEqualSlices(u8, &[_]u8{ 0x00, 0x00, 0xAA, 0xBB, 0xCC, 0xDD, 0x00, 0x00 }, memory[0..8]);
}

test "Copies half word from memory address to register" {
    var memory = [_]u8{ 0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF, 0xAA, 0xBB };
    var mvmCpu = cpu.CPU{ .memory = &memory };

    mvmCpu.registers[0] = 0;
    mvmCpu.registers[1] = 1;

    mvmCpu.execute(generate2RegisterInstruction(0b11100011, 0, 1));
    try testing.expectEqual(@as(u32, 0xBBCC), mvmCpu.registers[0]);
}

test "Copies half word from register to memory address" {
    var memory = [_]u8{0} ** 8;
    var mvmCpu = cpu.CPU{ .memory = &memory };

    mvmCpu.registers[0] = 0xAABBCCDD;
    mvmCpu.registers[1] = 2;

    mvmCpu.execute(generate2RegisterInstruction(0b11100100, 0, 1));
    try testing.expectEqualSlices(u8, &[_]u8{ 0x00, 0x00, 0xCC, 0xDD, 0x00, 0x00, 0x00, 0x00 }, memory[0..8]);
}

test "Copies byte from memory address to register" {
    var memory = [_]u8{ 0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF, 0xAA, 0xBB };
    var mvmCpu = cpu.CPU{ .memory = &memory };

    mvmCpu.registers[0] = 0;
    mvmCpu.registers[1] = 5;

    mvmCpu.execute(generate2RegisterInstruction(0b11100101, 0, 1));
    try testing.expectEqual(@as(u32, 0xFF), mvmCpu.registers[0]);
}

test "Copies byte from register to memory address" {
    var memory = [_]u8{0} ** 8;
    var mvmCpu = cpu.CPU{ .memory = &memory };

    mvmCpu.registers[0] = 0xAABBCCDD;
    mvmCpu.registers[1] = 2;

    mvmCpu.execute(generate2RegisterInstruction(0b11100110, 0, 1));
    try testing.expectEqualSlices(u8, &[_]u8{ 0x00, 0x00, 0xDD, 0x00, 0x00, 0x00, 0x00, 0x00 }, memory[0..8]);
}

test "Compares provided registers" {
    // TODO
}

fn generateBranchInstruction(opcode: u10, updateLinkRegister: bool, rx: u4) u16 {
    const branchConfigBinary: u2 = if (updateLinkRegister)
        0b01
    else
        0b00;
    return @as(u16, opcode) << 6 | @as(u16, branchConfigBinary) << 4 | rx;
}

const AluStatus = struct { zero: bool = false, negative: bool = false, carry: bool = false, overflow: bool = false };
const BranchTestConfig = struct { opCode: u10, status: AluStatus, address: u32, shouldJump: bool, initialProgramCounter: u32 = 0 };

test "Unconditional branch always jumps to the new address" {
    try testBranch(BranchTestConfig{
        .opCode = 0b1111_00_0000,
        .status = AluStatus{},
        .initialProgramCounter = 0xDDCCBBAA,
        .address = 0xAABBCCDD,
        .shouldJump = true,
    });
    try testBranch(BranchTestConfig{
        .opCode = 0b1111_00_0000,
        .status = AluStatus{ .zero = true, .negative = true, .carry = true, .overflow = true },
        .initialProgramCounter = 0xDDCCBBAA,
        .address = 0xAABBCCDD,
        .shouldJump = true,
    });
}

test "Branch equal jumps to the new address when zero status is set" {
    try testBranch(BranchTestConfig{
        .opCode = 0b1111_00_0001,
        .status = AluStatus{ .zero = true },
        .initialProgramCounter = 0xDDCCBBAA,
        .address = 0xAABBCCDD,
        .shouldJump = true,
    });

    try testBranch(BranchTestConfig{
        .opCode = 0b1111_00_0001,
        .status = AluStatus{ .zero = false, .negative = true, .carry = true, .overflow = true },
        .initialProgramCounter = 0xDDCCBBAA,
        .address = 0xAABBCCDD,
        .shouldJump = false,
    });
}

test "Branch not equal jumps to the new address when zero status is not set" {
    try testBranch(BranchTestConfig{
        .opCode = 0b1111_00_0010,
        .status = AluStatus{},
        .initialProgramCounter = 0xDDCCBBAA,
        .address = 0xAABBCCDD,
        .shouldJump = true,
    });

    try testBranch(BranchTestConfig{
        .opCode = 0b1111_00_0010,
        .status = AluStatus{ .zero = false, .negative = true, .carry = true, .overflow = true },
        .initialProgramCounter = 0xDDCCBBAA,
        .address = 0xAABBCCDD,
        .shouldJump = true,
    });

    try testBranch(BranchTestConfig{
        .opCode = 0b1111_00_0010,
        .status = AluStatus{ .zero = true, .negative = true, .carry = true, .overflow = true },
        .initialProgramCounter = 0xDDCCBBAA,
        .address = 0xAABBCCDD,
        .shouldJump = false,
    });
}

test "Branch greater than jumps to the new address when zero is not set and negative is equal to overflow" {
    try testBranch(BranchTestConfig{
        .opCode = 0b1111_00_0011,
        .status = AluStatus{ .negative = true, .overflow = true },
        .initialProgramCounter = 0xDDCCBBAA,
        .address = 0xAABBCCDD,
        .shouldJump = true,
    });

    try testBranch(BranchTestConfig{
        .opCode = 0b1111_00_0011,
        .status = AluStatus{ .negative = false, .overflow = false },
        .initialProgramCounter = 0xDDCCBBAA,
        .address = 0xAABBCCDD,
        .shouldJump = true,
    });

    try testBranch(BranchTestConfig{
        .opCode = 0b1111_00_0011,
        .status = AluStatus{ .negative = true, .overflow = false },
        .initialProgramCounter = 0xDDCCBBAA,
        .address = 0xAABBCCDD,
        .shouldJump = false,
    });

    try testBranch(BranchTestConfig{
        .opCode = 0b1111_00_0011,
        .status = AluStatus{ .zero = true, .negative = true, .overflow = true },
        .initialProgramCounter = 0xDDCCBBAA,
        .address = 0xAABBCCDD,
        .shouldJump = false,
    });
}

test "Branch greater than equal jumps to the new address when negative is equal to overflow" {
    try testBranch(BranchTestConfig{
        .opCode = 0b1111_00_0100,
        .status = AluStatus{ .negative = true, .overflow = true },
        .initialProgramCounter = 0xDDCCBBAA,
        .address = 0xAABBCCDD,
        .shouldJump = true,
    });

    try testBranch(BranchTestConfig{
        .opCode = 0b1111_00_0100,
        .status = AluStatus{ .negative = false, .overflow = false },
        .initialProgramCounter = 0xDDCCBBAA,
        .address = 0xAABBCCDD,
        .shouldJump = true,
    });

    try testBranch(BranchTestConfig{
        .opCode = 0b1111_00_0100,
        .status = AluStatus{ .negative = false, .overflow = true },
        .initialProgramCounter = 0xDDCCBBAA,
        .address = 0xAABBCCDD,
        .shouldJump = false,
    });
}

test "Branch less than jumps to the new address when negative is not equal to overflow" {
    try testBranch(BranchTestConfig{
        .opCode = 0b1111_00_0101,
        .status = AluStatus{ .negative = false, .overflow = true },
        .initialProgramCounter = 0xDDCCBBAA,
        .address = 0xAABBCCDD,
        .shouldJump = true,
    });

    try testBranch(BranchTestConfig{
        .opCode = 0b1111_00_0101,
        .status = AluStatus{ .negative = true, .overflow = false },
        .initialProgramCounter = 0xDDCCBBAA,
        .address = 0xAABBCCDD,
        .shouldJump = true,
    });

    try testBranch(BranchTestConfig{
        .opCode = 0b1111_00_0101,
        .status = AluStatus{ .negative = true, .overflow = true },
        .initialProgramCounter = 0xDDCCBBAA,
        .address = 0xAABBCCDD,
        .shouldJump = false,
    });
}

test "Branch less than equal jumps to the new address when zero is set or negative is not equal to overflow" {
    try testBranch(BranchTestConfig{
        .opCode = 0b1111_00_0110,
        .status = AluStatus{ .negative = false, .overflow = true },
        .initialProgramCounter = 0xDDCCBBAA,
        .address = 0xAABBCCDD,
        .shouldJump = true,
    });

    try testBranch(BranchTestConfig{
        .opCode = 0b1111_00_0110,
        .status = AluStatus{ .negative = true, .overflow = false },
        .initialProgramCounter = 0xDDCCBBAA,
        .address = 0xAABBCCDD,
        .shouldJump = true,
    });

    try testBranch(BranchTestConfig{
        .opCode = 0b1111_00_0110,
        .status = AluStatus{ .negative = true, .overflow = true },
        .initialProgramCounter = 0xDDCCBBAA,
        .address = 0xAABBCCDD,
        .shouldJump = false,
    });

    try testBranch(BranchTestConfig{
        .opCode = 0b1111_00_0110,
        .status = AluStatus{ .zero = true },
        .initialProgramCounter = 0xDDCCBBAA,
        .address = 0xAABBCCDD,
        .shouldJump = true,
    });

    try testBranch(BranchTestConfig{
        .opCode = 0b1111_00_0110,
        .status = AluStatus{ .zero = true, .negative = false, .overflow = true },
        .initialProgramCounter = 0xDDCCBBAA,
        .address = 0xAABBCCDD,
        .shouldJump = true,
    });

    try testBranch(BranchTestConfig{
        .opCode = 0b1111_00_0110,
        .status = AluStatus{ .zero = true, .negative = true, .overflow = true },
        .initialProgramCounter = 0xDDCCBBAA,
        .address = 0xAABBCCDD,
        .shouldJump = true,
    });
}

fn testBranch(testConfig: BranchTestConfig) !void {
    for ([_]bool{ true, false }) |updateLinkRegister| {
        const rx = 0;
        var mvmCpu = cpu.CPU{};
        mvmCpu.registers[rx] = testConfig.address;

        if (testConfig.status.negative) mvmCpu.registers[4] |= cpu.CPU.NegativeMask;
        if (testConfig.status.zero) mvmCpu.registers[4] |= cpu.CPU.ZeroMask;
        if (testConfig.status.carry) mvmCpu.registers[4] |= cpu.CPU.CarryMask;
        if (testConfig.status.overflow) mvmCpu.registers[4] |= cpu.CPU.OverflowMask;

        const previousPC = mvmCpu.registers[cpu.CPU.ProgramCounter];
        const previousLinkRegister = mvmCpu.registers[cpu.CPU.LinkRegister];
        mvmCpu.execute(generateBranchInstruction(testConfig.opCode, updateLinkRegister, rx));

        const newAddress = mvmCpu.registers[cpu.CPU.ProgramCounter];
        if (testConfig.shouldJump) {
            try testing.expectEqual(testConfig.address, newAddress);
        } else {
            try testing.expect(testConfig.address != newAddress);
        }

        const linkRegister = mvmCpu.registers[cpu.CPU.LinkRegister];
        if (updateLinkRegister) {
            try testing.expectEqual(previousPC, linkRegister);
        } else {
            try testing.expectEqual(previousLinkRegister, linkRegister);
        }
    }
}
