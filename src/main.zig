const std = @import("std");
const cpu = @import("cpu.zig").cpu;

const ADD: u32 = 0b0000000000000000;
const ADD_CONSTANT: u32 = 0b0001000000000000;
const SUBTRACT: u32 = 0b0010000000000000;
const SUBTRACT_CONSTANT: u32 = 0b0011000000000000;

const WRITE_CONSTANT: u32 = 0b0100000000000000;

pub fn registerAsArgument(register: u4, argumentIndex: u4) u32 {
    return @intCast(u32, register) << (2 - argumentIndex) * 4;
}

pub fn constantAsArgument(constant: u8) u32 {
    return constant;
}

pub fn main() !void {
    var c = cpu{};
    c.execute(WRITE_CONSTANT |
        registerAsArgument(1, 0) |
        constantAsArgument(90));

    c.execute(WRITE_CONSTANT |
        registerAsArgument(2, 0) |
        constantAsArgument(7));

    c.execute(ADD |
        registerAsArgument(0, 0) |
        registerAsArgument(1, 1) |
        registerAsArgument(2, 2));

    c.execute(ADD_CONSTANT |
        registerAsArgument(0, 0) |
        constantAsArgument(8));

    c.execute(SUBTRACT_CONSTANT |
        registerAsArgument(0, 0) |
        constantAsArgument(5));

    std.debug.print("Reg 0: {}\n", .{c.registers[0]});
    std.debug.print("Reg 1: {}\n", .{c.registers[1]});
    std.debug.print("Reg 2: {}\n", .{c.registers[2]});
    std.debug.print("Reg 3: {}\n", .{c.registers[3]});
    std.debug.print("Reg 4: {}\n", .{c.registers[4]});
    std.debug.print("Reg 5: {}\n", .{c.registers[5]});
    std.debug.print("Reg 6: {}\n", .{c.registers[6]});
    std.debug.print("Reg 7: {}\n", .{c.registers[7]});
}
