const std = @import("std");
const MvmaSource = @import("./mvma.zig").MvmaSource;

pub const TokenType = enum { BlockOpen, BlockClose, BracketOpen, BracketClose, Dot, Colon, Identifier, Address, Number, Comment, Semicolon, Comma, Invalid };
pub fn Token(comptime T: type) type {
    if (T == void) return struct { value: void = {}, position: MvmaSource.FilePosition };
    return struct { value: T, position: MvmaSource.FilePosition };
}
pub const TokenUnion = union(TokenType) {
    BlockOpen: Token(void),
    BlockClose: Token(void),
    BracketOpen: Token(void),
    BracketClose: Token(void),
    Dot: Token(void),
    Colon: Token(void),
    Identifier: Token(std.ArrayList(u8)),
    Address: Token(std.ArrayList(u8)),
    Number: Token(u32),
    Comment: Token(std.ArrayList(u8)),
    Semicolon: Token(void),
    Comma: Token(void),
    Invalid: Token([]const u8),
};

pub fn printToken(token: TokenUnion) void {
    const tokenType: TokenType = token;
    switch (token) {
        .Address, .Identifier, .Comment => |string| {
            std.debug.print("{}: '{s}'\n", .{ tokenType, string.value.items });
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

pub fn toTokens(allocator: std.mem.Allocator, source: *MvmaSource) !std.ArrayList(TokenUnion) {
    var tokens = std.ArrayList(TokenUnion).init(allocator);
    var stringBuffer = std.ArrayList(u8).init(allocator);
    defer stringBuffer.clearAndFree();

    while (source.consumeNext()) |char| {
        switch (char) {
            '.', ':', '/', ',', ';', '{', '}', '(', ')' => {
                if (stringBuffer.items.len > 0) {
                    const identifierLeader = stringBuffer.items[0];
                    var token: TokenUnion = undefined;
                    var bufferClone = try stringBuffer.clone();
                    switch (identifierLeader) {
                        '#' => {
                            _ = bufferClone.orderedRemove(0);
                            defer bufferClone.clearAndFree();
                            var parsedInteger: std.fmt.ParseIntError!u32 = undefined;

                            if (bufferClone.items.len > 2 and bufferClone.items[0] == '0' and bufferClone.items[1] != '0') {
                                const len = bufferClone.items.len;
                                parsedInteger = switch (bufferClone.items[1]) {
                                    'x' => std.fmt.parseInt(u32, bufferClone.items[2..len], 16),
                                    'b' => std.fmt.parseInt(u32, bufferClone.items[2..len], 2),
                                    else => std.fmt.ParseIntError.InvalidCharacter,
                                };
                            } else {
                                parsedInteger = std.fmt.parseInt(u32, bufferClone.items, 10);
                            }

                            if (parsedInteger) |integer| {
                                token = TokenUnion{ .Number = Token(u32){ .value = integer, .position = source.currentPosition() } };
                            } else |err| {
                                std.debug.print("{}\n", .{err});
                                token = TokenUnion{ .Invalid = Token([]const u8){ .value = "Invalid number provided", .position = source.currentPosition() } };
                            }
                        },
                        '$' => {
                            _ = bufferClone.orderedRemove(0);
                            token = TokenUnion{ .Address = Token(std.ArrayList(u8)){ .value = bufferClone, .position = source.currentPosition() } };
                        },
                        else => {
                            token = TokenUnion{ .Identifier = Token(std.ArrayList(u8)){ .value = bufferClone, .position = source.currentPosition() } };
                        },
                    }
                    try tokens.append(token);
                    stringBuffer.clearRetainingCapacity();
                }

                const token: TokenUnion = switch (char) {
                    '.' => TokenUnion{ .Dot = Token(void){ .position = source.currentPosition() } },
                    ':' => TokenUnion{ .Colon = Token(void){ .position = source.currentPosition() } },
                    '/' => comment: {
                        if (source.peekNext() == '/') {
                            _ = source.consumeNext();
                            var commentValue = source.consumeUntil('\n');
                            break :comment TokenUnion{ .Comment = Token(std.ArrayList(u8)){ .value = commentValue, .position = source.currentPosition() } };
                        }
                        break :comment TokenUnion{ .Invalid = Token([]const u8){ .value = "Double slashes are required for comments", .position = source.currentPosition() } };
                    },
                    ',' => TokenUnion{ .Comma = Token(void){ .position = source.currentPosition() } },
                    ';' => TokenUnion{ .Semicolon = Token(void){ .position = source.currentPosition() } },
                    '{' => TokenUnion{ .BlockOpen = Token(void){ .position = source.currentPosition() } },
                    '}' => TokenUnion{ .BlockClose = Token(void){ .position = source.currentPosition() } },
                    '(' => TokenUnion{ .BracketOpen = Token(void){ .position = source.currentPosition() } },
                    ')' => TokenUnion{ .BracketClose = Token(void){ .position = source.currentPosition() } },
                    else => unreachable,
                };

                try tokens.append(token);
            },

            ' ', '\n', '\t' => {},

            else => try stringBuffer.append(char),
        }
    }
    return tokens;
}
