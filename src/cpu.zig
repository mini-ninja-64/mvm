const std = @import("std");
const expect = @import("std").testing.expect;

fn getNibble(instruction: u32, nibbleIndex: u2) u4 {
    return @as(u4, @intCast((instruction >> (@as(u5, @intCast(3 - nibbleIndex)) * 4)) & 0b1111));
}

test "Successfully extracts nibbles" {
    try expect(getNibble(0b0000111111111111, 0) == 0b0000);
    try expect(getNibble(0b1111000011111111, 1) == 0b0000);
    try expect(getNibble(0b1111111100001111, 2) == 0b0000);
    try expect(getNibble(0b0000000000001010, 3) == 0b1010);
}

fn getByte(instruction: u32, byteIndex: u1) u8 {
    return @intCast((instruction >> (@as(u5, 1 - byteIndex) * 8)) & 0xFF);
}

test "Successfully extracts bytes" {
    try expect(getByte(0xFF00, 0) == 0xFF);
    try expect(getByte(0x00FF, 1) == 0xFF);
}

pub const CPU = struct {
    memory: []u8,
    registers: [8]u32 = std.mem.zeroes([8]u32),

    const StatusRegister: u3 = 4;
    const StackPointer: u3 = 5;
    const LinkRegister: u3 = 6;
    const ProgramCounter: u3 = 7;

    const EqualMask: u32 = 0b10000000000000000000000000000000;
    const NegativeMask: u32 = 0b01000000000000000000000000000000;
    // TODO: should be public?
    pub const CarryMask: u32 = 0b00100000000000000000000000000000;
    pub const OverflowMask: u32 = 0b00010000000000000000000000000000;

    pub fn execute(self: *CPU, instruction: u16) void {
        const startNibble: u4 = getNibble(instruction, 0);
        switch (startNibble) {
            0b0000...0b1101 => {
                // 4 bit ops
                const opCode = startNibble;
                // TODO: should probably safety check instead of truncating
                const rx = @as(u3, @truncate(getNibble(instruction, 1)));
                const ry = @as(u3, @truncate(getNibble(instruction, 2)));
                const rz = @as(u3, @truncate(getNibble(instruction, 3)));
                const constant = getByte(instruction, 1);

                switch (opCode) {
                    0 => self.addConstantOp(rx, constant),
                    1 => self.addOp(rx, ry, rz),

                    2 => self.subtractConstantOp(rx, constant),
                    3 => self.subtractOp(rx, ry, rz),

                    4 => self.writeConstantOp(rx, constant),

                    5 => self.shiftLeftOp(rx, ry, rz),
                    6 => self.shiftRightOp(rx, ry, rz),
                    7 => self.orOp(rx, ry, rz),
                    8 => self.andOp(rx, ry, rz),
                    9 => self.flipOp(rx, ry),
                    10 => self.xorOp(rx, ry, rz),
                    else => std.debug.print("Error unknown instruction: '{}'", .{instruction}),
                }
            },

            0b1110 => {
                // 8 bit ops
                const lowerOpCode: u4 = getNibble(instruction, 1);
                const rx = @as(u3, @truncate(getNibble(instruction, 2)));
                const ry = @as(u3, @truncate(getNibble(instruction, 3)));

                switch (lowerOpCode) {
                    0 => self.copyRegisterOp(rx, ry),
                    1 => self.copyFromAddress(rx, ry, 4),
                    2 => self.copyToAddress(rx, ry, 4),
                    3 => self.copyFromAddress(rx, ry, 2),
                    4 => self.copyToAddress(rx, ry, 2),
                    5 => self.copyFromAddress(rx, ry, 1),
                    6 => self.copyToAddress(rx, ry, 1),
                    7 => self.compareOp(rx, ry),

                    else => std.debug.print("Error unknown instruction: '{}'", .{instruction}),
                }
            },

            0b1111 => {
                // 14 bit ops
                const lowerOpCode: u6 = @as(u6, @intCast((instruction >> 10) & 0b111111));
                switch (lowerOpCode) {
                    0 => {}, // Branch always
                    1 => {}, // BranchEqual
                    2 => {}, // BranchNotEqual

                    3 => {}, // BranchMoreThanUnsigned
                    4 => {}, // BranchMoreThanSigned
                    5 => {}, // BranchMoreThanEqualUnsigned
                    6 => {}, // BranchMoreThanEqualSigned

                    7 => {}, // BranchLessThanUnsigned
                    8 => {}, // BranchLessThanSigned
                    9 => {}, // BranchLessThanEqualUnsigned
                    10 => {}, // BranchLessThanEqualSigned

                    11 => {}, // BranchLessThanUnsigned
                    12 => {}, // BranchLessThanSigned
                    13 => {}, // BranchLessThanEqualUnsigned
                    14 => {}, // BranchLessThanEqualSigned

                    15 => {}, // BranchLessThanUnsigned
                    16 => {}, // BranchLessThanSigned
                    17 => {}, // BranchLessThanEqualUnsigned
                    18 => {}, // BranchLessThanEqualSigned
                    else => std.debug.print("Error unknown instruction: '{}'", .{instruction}),
                }
            },
        }
    }
    const ArithmeticOperation = enum { plus, minus };
    const ArithmeticResult = struct { result: u32, carry: bool, overflow: bool };

    fn calculateArithmeticResult(a: u32, operation: ArithmeticOperation, b: u32) ArithmeticResult {
        var arithmeticResult = ArithmeticResult{
            .result = undefined,
            .carry = undefined,
            .overflow = undefined,
        };

        var overflowResult = switch (operation) {
            ArithmeticOperation.plus => @addWithOverflow(a, b),
            ArithmeticOperation.minus => @subWithOverflow(a, b),
        };
        arithmeticResult.result = overflowResult[0];
        arithmeticResult.carry = overflowResult[1] == 1;

        const signBitA: u1 = @as(u1, @intCast(a >> 31));
        const signBitB: u1 = @as(u1, @intCast(b >> 31));
        const signBitResult: u1 = @as(u1, @intCast(arithmeticResult.result >> 31));

        arithmeticResult.overflow = switch (operation) {
            // Two inputs with same sign resulting in different sign then the overflow flag should be set
            // (~(a ^ b) & (a ^ result)) >> 31 != 0;
            ArithmeticOperation.plus => (signBitA == signBitB) and (signBitA != signBitResult),
            // Two inputs with different sign resulting in same sign as b then the overflow flag should be set
            // ((a ^ b) & ~(b ^ result)) >> 31 != 0;
            ArithmeticOperation.minus => (signBitA != signBitB) and (signBitB == signBitResult),
        };

        return arithmeticResult;
    }

    fn storeArithmeticStatus(self: *CPU, arithmeticResult: ArithmeticResult) void {
        self.registers[StatusRegister] &= ~CarryMask;
        self.registers[StatusRegister] &= ~OverflowMask;

        if (arithmeticResult.carry) {
            self.registers[StatusRegister] |= CarryMask;
        }

        if (arithmeticResult.overflow) {
            self.registers[StatusRegister] |= OverflowMask;
        }
    }

    fn addConstantOp(self: *CPU, rx: u3, constant: u8) void {
        const result = calculateArithmeticResult(self.registers[rx], ArithmeticOperation.plus, constant);
        self.storeArithmeticStatus(result);
        self.registers[rx] = result.result;
    }
    fn addOp(self: *CPU, rx: u3, ry: u3, rz: u3) void {
        const result = calculateArithmeticResult(self.registers[ry], ArithmeticOperation.plus, self.registers[rz]);
        self.storeArithmeticStatus(result);
        self.registers[rx] = result.result;
    }
    fn subtractConstantOp(self: *CPU, rx: u3, constant: u8) void {
        const result = calculateArithmeticResult(self.registers[rx], ArithmeticOperation.minus, constant);
        self.storeArithmeticStatus(result);
        self.registers[rx] = result.result;
    }
    fn subtractOp(self: *CPU, rx: u3, ry: u3, rz: u3) void {
        const result = calculateArithmeticResult(self.registers[ry], ArithmeticOperation.minus, self.registers[rz]);
        self.storeArithmeticStatus(result);
        self.registers[rx] = result.result;
    }

    fn writeConstantOp(self: *CPU, rx: u3, constant: u8) void {
        self.registers[rx] = constant;
    }

    fn shiftRightOp(self: *CPU, rx: u3, ry: u3, rz: u3) void {
        self.registers[rx] = self.registers[ry] >> @truncate(self.registers[rz]);
    }
    fn shiftLeftOp(self: *CPU, rx: u3, ry: u3, rz: u3) void {
        self.registers[rx] = self.registers[ry] << @truncate(self.registers[rz]);
    }
    fn orOp(self: *CPU, rx: u3, ry: u3, rz: u3) void {
        self.registers[rx] = self.registers[ry] | self.registers[rz];
    }
    fn andOp(self: *CPU, rx: u3, ry: u3, rz: u3) void {
        self.registers[rx] = self.registers[ry] & self.registers[rz];
    }
    fn flipOp(self: *CPU, rx: u3, ry: u3) void {
        self.registers[rx] = ~self.registers[ry];
    }
    fn xorOp(self: *CPU, rx: u3, ry: u3, rz: u3) void {
        self.registers[rx] = self.registers[ry] ^ self.registers[rz];
    }

    fn copyRegisterOp(self: *CPU, rx: u3, ry: u3) void {
        self.registers[rx] = self.registers[ry];
    }
    fn copyFromAddress(self: *CPU, rx: u3, ry: u3, comptime length: usize) void {
        comptime {
            try std.testing.expect(length <= 4);
        }
        const memoryAddress = self.registers[ry];
        for (0..length) |i| {
            var shiftLength = @as(u5, @truncate(((length - 1) - i) * 8));
            self.registers[rx] |= @as(u32, self.memory[memoryAddress + i]) << shiftLength;
        }
    }
    fn copyToAddress(self: *CPU, rx: u3, ry: u3, comptime length: usize) void {
        comptime {
            try std.testing.expect(length <= 4);
        }
        const memoryAddress = self.registers[ry];
        for (0..length) |i| {
            var shiftLength = @as(u5, @truncate(((length - 1) - i) * 8));
            self.memory[memoryAddress + i] = @as(u8, @truncate(self.registers[rx] >> shiftLength));
        }
    }

    fn compareOp(self: *CPU, rx: u3, ry: u3) void {
        const result = calculateArithmeticResult(self.registers[rx], ArithmeticOperation.minus, self.registers[ry]);
        self.storeArithmeticStatus(result);
    }
};
