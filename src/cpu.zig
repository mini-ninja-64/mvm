const std = @import("std");
const expect = @import("std").testing.expect;

fn getNibble(instruction: u32, nibbleIndex: u2) u4 {
    return @intCast(u4, (instruction >> (@intCast(u5, 3 - nibbleIndex) * 4)) & 0b1111);
}

test "Successfully extracts nibbles" {
    try expect(getNibble(0b0000111111111111, 0) == 0b0000);
    try expect(getNibble(0b1111000011111111, 1) == 0b0000);
    try expect(getNibble(0b1111111100001111, 2) == 0b0000);
    try expect(getNibble(0b0000000000001010, 3) == 0b1010);
}

fn getByte(instruction: u32, byteIndex: u1) u8 {
    return @intCast(u8, (instruction >> (@intCast(u5, 1 - byteIndex) * 2)) & 0xFF);
}

test "Successfully extracts bytes" {
    try expect(getByte(0xFF00, 0) == 0xFF);
    try expect(getByte(0x00FF, 1) == 0xFF);
}

pub const cpu = struct {
    registers: [8]u32 = std.mem.zeroes([8]u32),

    pub fn execute(self: *cpu, instruction: u32) void {
        // TODO: carry flags
        const startNibble: u4 = getNibble(instruction, 0);
        switch (startNibble) {
            0b0000...0b1101 => {
                // 4 bit ops
                const opCode = startNibble;
                // TODO: should probably safety check instead of truncating
                const rx = @truncate(u3, getNibble(instruction, 1));
                const ry = @truncate(u3, getNibble(instruction, 2));
                const rz = @truncate(u3, getNibble(instruction, 3));
                const constant = getByte(instruction, 1);

                switch (opCode) {
                    0 => self.addConstantOp(rx, constant),
                    1 => self.addOp(rx, ry, rz),

                    2 => self.subtractConstantOp(rx, constant),
                    3 => self.subtractOp(rx, ry, rz),

                    4 => self.writeConstantOp(rx, constant),

                    5 => self.shiftRightOp(rx, ry, rz),
                    6 => self.shiftLeftOp(rx, ry, rz),
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
                const rx = @truncate(u3, getNibble(instruction, 2));
                const ry = @truncate(u3, getNibble(instruction, 3));

                switch (lowerOpCode) {
                    0 => self.copyRegisterOp(rx, ry),
                    1 => self.copyFromAddressOp(rx, ry),
                    2 => self.copyToAddressOp(rx, ry),

                    3 => self.compareOp(rx, ry),

                    4 => self.pushOp(rx),
                    5 => self.popOp(rx),
                    else => std.debug.print("Error unknown instruction: '{}'", .{instruction}),
                }
            },

            0b1111 => {
                // 14 bit ops
                const lowerOpCode: u6 = @intCast(u6, (instruction >> 10) & 0b111111);
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

    // TODO: write overflow status to register
    fn addConstantOp(self: *cpu, rx: u3, constant: u8) void {
        var result: u32 = undefined;
        const overflowed: bool = @addWithOverflow(u32, self.registers[rx], constant, &result);
        _ = overflowed;
        self.registers[rx] = result;
    }
    fn addOp(self: *cpu, rx: u3, ry: u3, rz: u3) void {
        var result: u32 = undefined;
        const overflowed: bool = @addWithOverflow(u32, self.registers[ry], self.registers[rz], &result);
        _ = overflowed;
        self.registers[rx] = result;
    }
    fn subtractConstantOp(self: *cpu, rx: u3, constant: u8) void {
        var result: u32 = undefined;
        const overflowed: bool = @subWithOverflow(u32, self.registers[rx], constant, &result);
        _ = overflowed;
        self.registers[rx] = result;
    }
    fn subtractOp(self: *cpu, rx: u3, ry: u3, rz: u3) void {
        var result: u32 = undefined;
        const overflowed: bool = @subWithOverflow(u32, self.registers[ry], self.registers[rz], &result);
        _ = overflowed;
        self.registers[rx] = result;
    }

    fn writeConstantOp(self: *cpu, rx: u3, constant: u8) void {
        self.registers[rx] = constant;
    }

    fn shiftRightOp(self: *cpu, rx: u3, ry: u3, rz: u3) void {
        _ = rz;
        _ = ry;
        _ = rx;
        _ = self;
    }
    fn shiftLeftOp(self: *cpu, rx: u3, ry: u3, rz: u3) void {
        _ = rz;
        _ = ry;
        _ = rx;
        _ = self;
    }
    fn orOp(self: *cpu, rx: u3, ry: u3, rz: u3) void {
        _ = rz;
        _ = ry;
        _ = rx;
        _ = self;
    }
    fn andOp(self: *cpu, rx: u3, ry: u3, rz: u3) void {
        _ = rz;
        _ = ry;
        _ = rx;
        _ = self;
    }
    fn flipOp(self: *cpu, rx: u3, ry: u3) void {
        _ = ry;
        _ = rx;
        _ = self;
    }
    fn xorOp(self: *cpu, rx: u3, ry: u3, rz: u3) void {
        _ = rz;
        _ = ry;
        _ = rx;
        _ = self;
    }

    fn copyRegisterOp(self: *cpu, rx: u3, ry: u3) void {
        self.registers[rx] = self.registers[ry];
    }
    fn copyFromAddressOp(self: *cpu, rx: u3, ry: u3) void {
        _ = ry;
        _ = rx;
        _ = self;
    }
    fn copyToAddressOp(self: *cpu, rx: u3, ry: u3) void {
        _ = ry;
        _ = rx;
        _ = self;
    }

    fn compareOp(self: *cpu, rx: u3, ry: u3) void {
        _ = ry;
        _ = rx;
        _ = self;
    }

    fn pushOp(self: *cpu, rx: u3) void {
        _ = rx;
        _ = self;
    }
    fn popOp(self: *cpu, rx: u3) void {
        _ = rx;
        _ = self;
    }
};
