const std = @import("std");

const FilePosition = struct {};

const ArgumentType = enum {
    Immediate,
    Address,
    Register,
};
const Argument = union {};

const Invocation = struct { name: std.ArrayList(u8), args: std.ArrayList(Argument), position: FilePosition };

const Comment = struct { content: std.ArrayList(u8), position: FilePosition };

const EnclosedBlock = struct { name: std.ArrayList(u8), statements: []Statement, position: FilePosition };

const StatementType = enum { pragma, instruction, comment, block };
const Statement = union(StatementType) { pragma: Invocation, instruction: Invocation, comment: Comment, block: EnclosedBlock };

const TokenType = enum { BlockOpen, BlockClose, BracketOpen, BracketClose, Dot, Colon, Dollar, Hashtag, Identifier, Comment, Semicolon };
const Token = struct { type: TokenType, value: ?std.ArrayList(u8), position: FilePosition };

pub fn toTokens(allocator: std.mem.Allocator, source: *MvmaSource) !std.ArrayList(Token) {
    var tokens = std.ArrayList(Token).init(allocator);
    var stringBuffer = std.ArrayList(u8).init(allocator);
    defer stringBuffer.clearAndFree();

    while (source.consumeNext()) |char| {
        switch (char) {
            '.' => try tokens.append(Token{ .type = TokenType.Dot, .value = null, .position = FilePosition{} }),
            ':' => try tokens.append(Token{ .type = TokenType.Colon, .value = null, .position = FilePosition{} }),
            '/' => {
                if (source.consumeNext() == '/') {
                    var commentString = source.consumeUntil('\n');
                    try tokens.append(Token{ .type = TokenType.Comment, .value = commentString, .position = FilePosition{} });
                }
            }, // start of comment
            '#' => try tokens.append(Token{ .type = TokenType.Hashtag, .value = null, .position = FilePosition{} }),
            '$' => try tokens.append(Token{ .type = TokenType.Dollar, .value = null, .position = FilePosition{} }),
            ';' => try tokens.append(Token{ .type = TokenType.Semicolon, .value = null, .position = FilePosition{} }),
            '{' => try tokens.append(Token{ .type = TokenType.BlockOpen, .value = null, .position = FilePosition{} }), // start of enclosed block
            '}' => try tokens.append(Token{ .type = TokenType.BlockClose, .value = null, .position = FilePosition{} }), // end of enclosed block
            '(' => try tokens.append(Token{ .type = TokenType.BracketOpen, .value = null, .position = FilePosition{} }), // start of arg list
            ')' => try tokens.append(Token{ .type = TokenType.BracketClose, .value = null, .position = FilePosition{} }), // end of arg list
            ' ' => {},
            '\n' => {},
            '\t' => {},

            else => {
                try stringBuffer.append(char);
            },
        }
    } else {
        std.debug.print("Completed!\n", .{});
    }
    return tokens;
}

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

    var sourceElements = std.ArrayList(Statement).init(allocator);
    defer sourceElements.clearAndFree();

    var currentStatementTypeStack = std.ArrayList(StatementType).init(allocator);
    defer currentStatementTypeStack.clearAndFree();
    var stringBuffer = std.ArrayList(u8).init(allocator);
    defer stringBuffer.clearAndFree();
    var tokens = try toTokens(allocator, &source);
    defer tokens.clearAndFree();

    for (tokens.items) |token| {
        std.debug.print("{}\n", .{token});
    }
}

const MvmaSource = struct {
    allocator: std.mem.Allocator,
    reader: std.fs.File.Reader,
    position: usize = 0,
    nextByte: ?u8 = null,

    pub fn peekNext(self: *MvmaSource) ?u8 {
        if (self.nextByte) |nextByte| return nextByte;

        const nextByte = self.reader.readByte() catch return null;
        self.nextByte = nextByte;
        return nextByte;
    }

    pub fn consumeNext(self: *MvmaSource) ?u8 {
        if (self.nextByte) |nextByte| {
            self.position += 1;
            self.nextByte = null;
            return nextByte;
        }

        const nextByte = self.reader.readByte() catch return null;
        self.position += 1;
        return nextByte;
    }

    pub fn consumeUntil(self: *MvmaSource, delimiter: u8) std.ArrayList(u8) {
        var string = std.ArrayList(u8).init(self.allocator);
        self.reader.streamUntilDelimiter(string.writer(), delimiter, null) catch {};
        self.position += string.items.len;
        self.nextByte = null;
        return string;
    }
};
