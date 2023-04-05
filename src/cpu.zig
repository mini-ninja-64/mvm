const std = @import("std");
const expect = @import("std").testing.expect;

fn getOperation(instruction: u32) u4 {
    return @intCast(u4, (instruction >> 3 * 4) & 0b1111);
}

fn getRegisterArgument(instruction: u32, registerIndex: u4) u4 {
    return @intCast(u4, (instruction >> ((2 - registerIndex) * 4)) & 0b1111);
}

test "Successfully extracts registers" {
    try expect(getRegisterArgument(0b1111000011111111, 0) == 0b0000);
    try expect(getRegisterArgument(0b1111111100001111, 1) == 0b0000);
}

fn getConstantArgument(instruction: u32) u8 {
    return @intCast(u8, instruction & 0xFF);
}

pub const cpu = struct {
    registers: [16]u32 = std.mem.zeroes([16]u32),

    pub fn execute(self: *cpu, instruction: u32) void {
        // TODO: carry flags
        const operation: u4 = getOperation(instruction);
        switch (operation) {
            // Add
            0 => {
                var rx: *u32 = &self.registers[getRegisterArgument(instruction, 0)];
                const ryValue = self.registers[getRegisterArgument(instruction, 1)];
                const rzValue = self.registers[getRegisterArgument(instruction, 2)];
                rx.* = ryValue + rzValue;
            },
            // Add Constant
            1 => {
                var rx: *u32 = &self.registers[getRegisterArgument(instruction, 0)];
                const constantValue = getConstantArgument(instruction);
                rx.* += constantValue;
            },

            // Subtract
            2 => {
                var rx: *u32 = &self.registers[getRegisterArgument(instruction, 0)];
                const ryValue = self.registers[getRegisterArgument(instruction, 1)];
                const rzValue = self.registers[getRegisterArgument(instruction, 2)];
                rx.* = ryValue - rzValue;
            },
            // Subtract Constant
            3 => {
                var rx: *u32 = &self.registers[getRegisterArgument(instruction, 0)];
                const constantValue = getConstantArgument(instruction);
                rx.* -= constantValue;
            },

            // Write constant to register
            4 => {
                var rx: *u32 = &self.registers[getRegisterArgument(instruction, 0)];
                const constantValue = getConstantArgument(instruction);
                rx.* = constantValue;
            },
            // Copy Register Value
            5 => {
                var rx: *u32 = &self.registers[getRegisterArgument(instruction, 0)];
                var ry: *u32 = &self.registers[getRegisterArgument(instruction, 1)];
                rx.* = ry.*;
            },
            // Copy Address Value
            6 => {},

            // Branch
            7 => {},
            // Branch on zero
            8 => {},
            // Branch and set link
            9 => {},

            // Push
            10 => {},
            // Pop
            11 => {},

            else => std.debug.print("Error unknown instruction: '{}'", .{operation}),
        }
    }
};
