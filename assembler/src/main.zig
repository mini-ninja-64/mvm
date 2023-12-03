const std = @import("std");
const MvmaSource = @import("./mvma.zig").MvmaSource;
const tokenParser = @import("./token_parser.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    const asmFilePath = args[1];
    const asmFile = try std.fs.cwd().openFile(asmFilePath, std.fs.File.OpenFlags{});
    defer asmFile.close();

    var source = MvmaSource{
        .allocator = allocator,
        .reader = asmFile.reader(),
    };

    var stringBuffer = std.ArrayList(u8).init(allocator);
    defer stringBuffer.clearAndFree();

    var tokens = try tokenParser.toTokens(allocator, &source);
    std.debug.print("Completed parsing\n", .{});
    defer tokens.clearAndFree();

    for (tokens.items) |*token| {
        const tokenType: tokenParser.TokenType = token.*;
        switch (token.*) {
            .Address, .Identifier, .Comment => |*stringToken| {
                std.debug.print("{}: '{s}'\n", .{ tokenType, stringToken.value.items });
                stringToken.value.clearAndFree();
            },
            .Number => |number| {
                std.debug.print("{}: {}\n", .{ tokenType, number.value });
            },
            .Invalid => |invalid| {
                std.debug.print("Error: {s} @ {}:{}\n", .{ invalid.value, invalid.position.line, invalid.position.column });
            },
            else => std.debug.print("{}\n", .{tokenType}),
        }
    }
}
