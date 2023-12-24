const std = @import("std");
const MvmaSource = @import("./mvma.zig").MvmaSource;
const tokenParser = @import("./token_parser.zig");
const statementParser = @import("./statement_parser.zig");

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

    var statements = try statementParser.toStatements(allocator, tokens.items);
    defer statements.clearAndFree();
    if (!statements.successful()) {
        std.debug.print("Parsing failed!!!\n", .{});
        for (statements.errors.items) |parserError| {
            if (parserError.token) |token| {
                std.debug.print("{s} @ {}:{}\n", .{
                    parserError.errorMessage,
                    token.getCommon().position.line,
                    token.getCommon().position.column,
                });
            } else {
                std.debug.print("{s}\n", .{parserError.errorMessage});
            }
        }
    } else {
        for (statements.parsed.items) |statement| {
            std.debug.print("{}\n", .{statement});
        }
    }
    // std.debug.print("------------All Tokens------------\n", .{});
    for (tokens.items) |*token| {
        switch (token.*) {
            .Address, .Identifier, .Comment => |*stringToken| {
                stringToken.value.clearAndFree();
            },
            else => {},
        }
    }
}
