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
    statements: std.ArrayList(Statement),
};

const StatementType = enum { Block, InvokingStatement };
const Statement = union(StatementType) {
    Block: Block,
    InvokingStatement: InvokingStatement,
};

const ParserError = struct { token: ?TokenUnion = null, errorMessage: []const u8 };
const ParseResult = struct {
    parsed: std.ArrayList(Statement),
    errors: std.ArrayList(ParserError),
};

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
const AllocatorError = std.mem.Allocator.Error;

fn handleBlock(identifier: IdentifierToken, tokenReader: *TokenReader, errors: *std.ArrayList(ParserError)) AllocatorError!?Block {
    const token = tokenReader.consume();
    if (typeOfToken(token) == TokenType.BlockOpen) {
        const blockStatements = try handleStatementsUntil(tokenReader, errors, TokenType.BlockClose);
        return Block{ .identifier = identifier.value, .statements = blockStatements };
    } else {
        try errors.append(ParserError{ .token = token, .errorMessage = "Expected '{'" });
        return null;
    }
}

fn handleDefiniteInvocation(tokenReader: *TokenReader, errors: *std.ArrayList(ParserError)) AllocatorError!?Invocation {
    if (typeOfToken(tokenReader.next()) != TokenType.Identifier) {
        try errors.append(ParserError{ .token = tokenReader.next(), .errorMessage = "Expected identifier" });
        return null;
    }

    return handleInvocation(tokenReader.consume().?.Identifier, tokenReader, errors);
}

fn handleInvocation(identifier: IdentifierToken, tokenReader: *TokenReader, errors: *std.ArrayList(ParserError)) AllocatorError!?Invocation {
    var args = ArgList.init(tokenReader.allocator);
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
                        try errors.append(ParserError{ .token = token, .errorMessage = "Invalid token in argument list, expected an argument or ')'" });
                        break;
                    },
                }
            } else if (currentPhase == InvocationPhase.ArgComplete) {
                switch (token) {
                    TokenType.Comma => currentPhase = InvocationPhase.ReadyForArg,
                    TokenType.BracketClose => break,
                    else => {
                        try errors.append(ParserError{ .token = token, .errorMessage = "Invalid token in argument list, expected ',' or ')'" });
                        break;
                    },
                }
            }
        }
        return Invocation{ .identifier = identifier.value, .args = args };
    }
    return null;
}

fn typeOfToken(token: ?TokenUnion) ?TokenType {
    if (token) |tokenPresent| {
        return tokenPresent;
    }
    return null;
}

fn handleStatementsUntil(
    tokenReader: *TokenReader,
    errors: *std.ArrayList(ParserError),
    finalToken: ?TokenType,
) AllocatorError!std.ArrayList(Statement) {
    var statements = std.ArrayList(Statement).init(tokenReader.allocator);
    while (tokenReader.consume()) |token| {
        // tokenParser.printToken(token);
        if (typeOfToken(token) == finalToken)
            return statements;

        if (tokenReader.next()) |nextToken| {
            switch (token) {
                TokenType.Dot => {
                    switch (nextToken) {
                        TokenType.Identifier => {
                            if (try handleDefiniteInvocation(tokenReader, errors)) |invocation| {
                                try statements.append(Statement{
                                    .InvokingStatement = InvokingStatement{ .pragma = invocation },
                                });
                            }
                            const expectedSemicolon = tokenReader.consume();
                            if (typeOfToken(expectedSemicolon) != TokenType.Semicolon) {
                                try errors.append(ParserError{
                                    .token = expectedSemicolon,
                                    .errorMessage = "Expected semicolon",
                                });
                            }
                        },
                        else => {
                            try errors.append(ParserError{ .token = nextToken, .errorMessage = "Invalid token following '.'" });
                        },
                    }
                },
                TokenType.Identifier => |identifier| {
                    switch (nextToken) {
                        TokenType.Colon => {
                            _ = tokenReader.consume(); // Skip colon
                            if (try handleBlock(identifier, tokenReader, errors)) |block| {
                                try statements.append(Statement{
                                    .Block = block,
                                });
                            }
                        },
                        TokenType.BracketOpen => {
                            if (try handleInvocation(identifier, tokenReader, errors)) |invocation| {
                                try statements.append(Statement{
                                    .InvokingStatement = InvokingStatement{ .invocation = invocation },
                                });
                            }

                            const expectedSemicolon = tokenReader.consume();
                            if (typeOfToken(expectedSemicolon) != TokenType.Semicolon) {
                                try errors.append(ParserError{
                                    .token = expectedSemicolon,
                                    .errorMessage = "Expected semicolon",
                                });
                            }
                        },
                        else => {
                            try errors.append(ParserError{ .token = nextToken, .errorMessage = "Invalid token following identifier" });
                        },
                    }
                },
                else => {
                    try errors.append(ParserError{ .token = token, .errorMessage = "Invalid top level structure" });
                },
            }
        } else {
            try errors.append(ParserError{
                .errorMessage = "Unexpected EOF",
            });
        }
    }
    if (finalToken != null) {
        try errors.append(ParserError{ .token = null, .errorMessage = "Unexpected EOF" });
    }
    return statements;
}

//std.ArrayList(TopLevelStructure)
//
pub fn toStatements(allocator: std.mem.Allocator, tokens: []TokenUnion) !ParseResult {
    var filteredTokens = std.ArrayList(TokenUnion).init(allocator);
    defer filteredTokens.clearAndFree();

    var errors = std.ArrayList(ParserError).init(allocator);

    for (tokens) |token| {
        if (typeOfToken(token) != TokenType.Comment) {
            try filteredTokens.append(token);
        }
    }
    var tokenReader = TokenReader{ .tokens = filteredTokens.items, .allocator = allocator };
    const statements = try handleStatementsUntil(&tokenReader, &errors, null);
    return ParseResult{
        .parsed = statements,
        .errors = errors,
    };
}
