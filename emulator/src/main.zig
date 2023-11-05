const std = @import("std");
const cpu = @import("cpu.zig");

pub fn registerAsArgument(register: u4, argumentIndex: u4) u16 {
    return @as(u16, register) << (2 - argumentIndex) * 4;
}

pub fn constantAsArgument(constant: u8) u16 {
    return constant;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    const binaryPath = args[1];
    const binary = try std.fs.cwd().openFile(binaryPath, std.fs.File.OpenFlags{});

    const memorySize = try std.fmt.parseInt(u32, args[2], 10);
    const memoryBuffer = try allocator.alloc(u8, memorySize);
    defer allocator.free(memoryBuffer);
    _ = try binary.readAll(memoryBuffer);
    binary.close();

    // var memory = [_]u8{ 0b0100_0000, 0b0000_0010, 0b0100_0001, 0b0000_0011 };
    var mvmCpu = cpu.CPU{ .memory = memoryBuffer };
    var errored = false;
    while (!errored) {
        mvmCpu.cycle() catch {
            errored = true;
        };

        // try waitForInput();
    }

    printRegisters(&mvmCpu);
}

fn printRegisters(c: *cpu.CPU) void {
    for (c.registers, 0..) |register, index| {
        std.debug.print("Reg {}: {}\n", .{ index, register });
    }
}

fn waitForInput() !void {
    var buf: [1]u8 = undefined;
    _ = std.io.getStdIn().reader().readUntilDelimiterOrEof(&buf, '\n') catch {};
}
