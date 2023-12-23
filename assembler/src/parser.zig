const std = @import("std");
const tokenParser = @import("./token_parser.zig");
const TokenType = tokenParser.TokenType;
const TokenUnion = tokenParser.TokenUnion;

const Number = u32;
const Identifier = std.ArrayList(u8);
const Address = std.ArrayList(u8);

const ArgType = enum { identifier, number, address };
const Arg = union(ArgType) {
    identifier: Identifier,
    number: Number,
    address: Address,
};
const ArgList = std.ArrayList(Arg);

const Invocation = struct {
    identifier: Identifier,
    args: ArgList,
};
const Pragma = Invocation;
const InvokingStatementType = enum { pragma, invocation };
const InvokingStatement = union(InvokingStatementType) {
    pragma: Pragma,
    invocation: Invocation,
};
const Block = struct {
    identifier: Identifier,
    statements: std.ArrayList(InvokingStatement),
};

const StatementType = enum { Block, InvokingStatement };
const Statement = union(StatementType) {
    Block: Block,
    InvokingStatement: InvokingStatement,
};

const ParserError = struct {};
pub fn Parseable(comptime T: type) type {
    return struct {
        valid: bool,
        parsed: ?T = null,
        errors: ?std.ArrayList(ParserError) = null,
    };
}

const TokenReader = struct {
    tokens: []TokenUnion,
    position: usize = 0,
    allocator: std.mem.Allocator,
    firstConsumption: bool = true,

    pub fn next(self: *TokenReader) ?TokenUnion {
        if (self.position >= self.tokens.len - 1) return null;
        const offset: u8 = if (self.firstConsumption) 0 else 1;
        return self.tokens[self.position + offset];
    }

    pub fn previous(self: *TokenReader) ?TokenUnion {
        if (self.position == 0) return null;
        return self.tokens[self.position - 1];
    }

    pub fn consume(self: *TokenReader) ?TokenUnion {
        if (self.position >= self.tokens.len - 1) return null;
        if (self.firstConsumption) {
            self.firstConsumption = false;
        } else {
            self.position += 1;
        }
        return self.tokens[self.position];
    }

    pub fn current(self: *TokenReader) ?TokenUnion {
        if (self.firstConsumption) return null;
        if (self.position >= self.tokens.len) return null;
        return self.tokens[self.position];
    }
};

const IdentifierToken = std.meta.TagPayloadByName(TokenUnion, "Identifier");

fn handleBlock(identifier: IdentifierToken, tokenReader: *TokenReader) Parseable(Block) {
    _ = identifier;
    const token = tokenReader.consume();
    if (typeOfToken(token) == TokenType.BlockOpen) {
        handleStatementsUntil(tokenReader, TokenType.BlockClose);
        return Parseable(Block){ .valid = true };
    } else {
        return Parseable(Block){ .valid = false };
    }
}

fn handleDefiniteInvocation(tokenReader: *TokenReader) Parseable(Invocation) {
    if (typeOfToken(tokenReader.next()) != TokenType.Identifier) {
        return Parseable(Invocation){ .valid = false };
    }

    return handleInvocation(tokenReader.consume().?.Identifier, tokenReader);
}

fn handleInvocation(identifier: IdentifierToken, tokenReader: *TokenReader) Parseable(Invocation) {
    _ = identifier;
    var args = ArgList.init(tokenReader.allocator);
    _ = args;
    if (typeOfToken(tokenReader.next()) == TokenType.BracketOpen) {
        _ = tokenReader.consume(); // Open bracket
        const InvocationPhase = enum { ArgComplete, ReadyForArg };
        var currentPhase = InvocationPhase.ReadyForArg;
        while (tokenReader.consume()) |token| {
            if (currentPhase == InvocationPhase.ReadyForArg) {
                switch (token) {
                    TokenType.Identifier, TokenType.Address, TokenType.Number => {
                        // identifier.value;
                        // TODO: do args
                        currentPhase = InvocationPhase.ArgComplete;
                    },
                    TokenType.BracketClose => break,
                    else => {
                        std.debug.print("HADNLING IT 1\n", .{});
                        break;
                    },
                }
            } else if (currentPhase == InvocationPhase.ArgComplete) {
                switch (token) {
                    TokenType.Comma => currentPhase = InvocationPhase.ReadyForArg,
                    TokenType.BracketClose => break,
                    else => {
                        std.debug.print("HADNLING IT 2\n", .{});
                        break;
                    },
                }
            }
        }
        return Parseable(Invocation){ .valid = true };
    }
    return Parseable(Invocation){ .valid = false };
}

fn typeOfToken(token: ?TokenUnion) ?TokenType {
    if (token) |tokenPresent| {
        return tokenPresent;
    }
    return null;
}

fn handleStatementsUntil(tokenReader: *TokenReader, tokenType: TokenType) void {
    while (tokenReader.consume()) |token| {
        tokenParser.printToken(token);
        if (token == tokenType) return;

        switch (token) {
            TokenType.Dot => {
                const nextToken = tokenReader.next();
                if (nextToken == null) {
                    // TODO: ERROR EOF EARLY
                    break;
                }
                switch (nextToken.?) {
                    TokenType.Identifier => {
                        std.debug.print("PRAGMA\n", .{});
                        _ = handleDefiniteInvocation(tokenReader);
                        if (typeOfToken(tokenReader.consume()) != TokenType.Semicolon) {
                            // TODO: Error
                            std.debug.print("Expected semicolon\n", .{});
                        }
                    },
                    else => {
                        // TODO: Error
                        std.debug.print("ERROR 1\n", .{});
                    },
                }
            },
            TokenType.Identifier => |identifier| {
                const nextToken = tokenReader.next();
                if (nextToken == null) {
                    // TODO: ERROR EOF EARLY
                    break;
                }
                switch (nextToken.?) {
                    TokenType.Colon => {
                        std.debug.print("Block Start\n", .{});
                        _ = tokenReader.consume(); // Skip colon
                        _ = handleBlock(identifier, tokenReader);
                    },
                    TokenType.BracketOpen => {
                        std.debug.print("Function execution\n", .{});
                        _ = handleInvocation(identifier, tokenReader);
                        if (typeOfToken(tokenReader.consume()) != TokenType.Semicolon) {
                            // TODO: Error
                            std.debug.print("Expected semicolon\n", .{});
                        }
                    },
                    else => {
                        // TODO: Error
                        std.debug.print("ERROR 2\n", .{});
                    },
                }
            },
            else => {
                // TODO: Error
                std.debug.print("Invalid top level structure\n", .{});
            },
        }
    }
    // TODO: error
    std.debug.print("Ended before expected\n", .{});
}

//std.ArrayList(TopLevelStructure)
pub fn toStatements(allocator: std.mem.Allocator, tokens: []TokenUnion) void {
    var filteredTokens = std.ArrayList(TokenUnion).init(allocator);
    defer filteredTokens.clearAndFree();
    for (tokens) |token| {
        if (typeOfToken(token) != TokenType.Comment) {
            // TODO: Handle properly
            filteredTokens.append(token) catch {};
        }
    }
    var tokenReader = TokenReader{ .tokens = filteredTokens.items, .allocator = allocator };
    handleStatementsUntil(&tokenReader, TokenType.EOF);
}
