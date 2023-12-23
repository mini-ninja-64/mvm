const std = @import("std");
const MvmaSource = @import("./mvma.zig").MvmaSource;
const tokenParser = @import("./token_parser.zig");
const parser = @import("./parser.zig");

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

    var statements = parser.toStatements(allocator, tokens.items);
    _ = statements;

    // std.debug.print("------------All Tokens------------\n", .{});
    for (tokens.items) |*token| {
        // tokenParser.printToken(token.*);
        switch (token.*) {
            .Address, .Identifier, .Comment => |*stringToken| {
                stringToken.value.clearAndFree();
            },
            else => {},
        }
    }
}
