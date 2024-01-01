const std = @import("std");
const MvmaSource = @import("./mvma.zig").MvmaSource;

pub const TokenType = enum {
    BlockOpen,
    BlockClose,
    BracketOpen,
    BracketClose,
    Dot,
    Colon,
    Identifier,
    Address,
    Number,
    Comment,
    Semicolon,
    Comma,
    Invalid,
};
pub fn Token(comptime T: type) type {
    if (T == void) return struct { value: void = {}, position: MvmaSource.FilePosition };
    return struct { value: T, position: MvmaSource.FilePosition };
}

pub const AddressToken = struct {
    scoped: bool,
    elements: std.ArrayList(std.ArrayList(u8)),

    pub fn clearAndFree(self: *AddressToken) void {
        for (self.elements.items) |*element| {
            element.clearAndFree();
        }
        self.elements.clearAndFree();
    }
};

pub const TokenUnion = union(TokenType) {
    BlockOpen: Token(void),
    BlockClose: Token(void),
    BracketOpen: Token(void),
    BracketClose: Token(void),
    Dot: Token(void),
    Colon: Token(void),
    Identifier: Token(std.ArrayList(u8)),
    Address: Token(AddressToken),
    Number: Token(u32),
    Comment: Token(std.ArrayList(u8)),
    Semicolon: Token(void),
    Comma: Token(void),
    Invalid: Token([]const u8),

    pub fn getCommon(self: *const TokenUnion) Token(void) {
        return switch (self.*) {
            TokenType.BlockOpen,
            TokenType.BlockClose,
            TokenType.BracketOpen,
            TokenType.BracketClose,
            TokenType.Dot,
            TokenType.Colon,
            TokenType.Semicolon,
            TokenType.Comma,
            => |t| t,
            TokenType.Identifier,
            TokenType.Comment,
            => |t| Token(void){ .position = t.position },
            TokenType.Address => |t| Token(void){ .position = t.position },
            TokenType.Invalid => |t| Token(void){ .position = t.position },
            TokenType.Number => |t| Token(void){ .position = t.position },
        };
    }
};

pub fn printToken(token: TokenUnion) void {
    const tokenType: TokenType = token;
    switch (token) {
        .Address => |address| {
            std.debug.print("{}: scoped: {}, elements: [ ", .{ tokenType, address.value.scoped });
            for (address.value.elements.items) |addressElement| {
                std.debug.print("'{s}', ", .{addressElement.items});
            }
            std.debug.print("] \n", .{});
        },
        .Identifier, .Comment => |string| {
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
                            var commentValue = source.consumeUntil(&[_]u8{'\n'});
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

            '$' => {
                //TODO: Bit hacky as does not account for newlines & whitespace
                //      in the middle of things e.t.c, maybe this should go into
                //      statement parser layer?
                var addressString = source.consumeUntil(&[_]u8{ ',', ')', ' ' });
                defer addressString.clearAndFree();

                const scoped = addressString.items[0] == '.';

                const normalisedAddress = if (scoped) addressString.items[1..addressString.items.len] else addressString.items;
                var splitAddress = std.mem.split(u8, normalisedAddress, ".");
                var addressStack = std.ArrayList(std.ArrayList(u8)).init(allocator);
                while (splitAddress.next()) |addressElement| {
                    var element = std.ArrayList(u8).init(allocator);
                    try element.appendSlice(addressElement);
                    try addressStack.append(element);
                }

                try tokens.append(TokenUnion{
                    .Address = Token(AddressToken){
                        .value = AddressToken{
                            .scoped = scoped,
                            .elements = addressStack,
                        },
                        .position = source.currentPosition(),
                    },
                });
                if (source.peekNext() == '.') try stringBuffer.append(source.consumeNext().?);
            },

            else => try stringBuffer.append(char),
        }
    }
    return tokens;
}
