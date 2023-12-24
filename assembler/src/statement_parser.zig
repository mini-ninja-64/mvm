const std = @import("std");
const MvmaSource = @import("./mvma.zig").MvmaSource;
const TokenParser = @import("./token_parser.zig");
const TokenType = TokenParser.TokenType;
const TokenUnion = TokenParser.TokenUnion;

const Number = u32;
const Identifier = []const u8;
const Address = []const u8;

const ArgType = enum { Identifier, Number, Address };
const Arg = union(ArgType) {
    Identifier: Identifier,
    Number: Number,
    Address: Address,

    fn dealloc(self: *Arg) void {
        switch (self.*) {
            ArgType.Identifier => {},
            ArgType.Number => {},
            ArgType.Address => {},
        }
    }
};
const ArgList = std.ArrayList(Arg);

const Invocation = struct {
    identifier: Identifier,
    args: ArgList,
    fn dealloc(self: *Invocation) void {
        for (self.args.items) |*arg| {
            arg.dealloc();
        }
        self.args.clearAndFree();
    }
};
const Pragma = Invocation;
const InvokingStatementType = enum { Pragma, Function };
const InvokingStatement = union(InvokingStatementType) {
    Pragma: Pragma,
    Function: Invocation,

    fn dealloc(self: *InvokingStatement) void {
        switch (self.*) {
            InvokingStatementType.Pragma => |*pragma| pragma.dealloc(),
            InvokingStatementType.Function => |*invokingStatement| invokingStatement.dealloc(),
        }
    }
};
const Block = struct {
    identifier: Identifier,
    statements: std.ArrayList(Statement),

    fn dealloc(self: *Block) void {
        for (self.statements.items) |*statement| {
            statement.dealloc();
        }
        self.statements.clearAndFree();
    }
};

const StatementType = enum { Block, InvokingStatement };
const Statement = union(StatementType) {
    Block: Block,
    InvokingStatement: InvokingStatement,

    fn dealloc(self: *Statement) void {
        switch (self.*) {
            StatementType.Block => |*block| block.dealloc(),
            StatementType.InvokingStatement => |*invokingStatement| invokingStatement.dealloc(),
        }
    }
};

const ParserError = struct {
    token: ?TokenUnion = null,
    errorMessage: []const u8,
};
const ParseResult = struct {
    parsed: std.ArrayList(Statement),
    errors: std.ArrayList(ParserError),

    pub fn successful(self: *ParseResult) bool {
        return self.errors.items.len == 0;
    }

    pub fn clearAndFree(self: *ParseResult) void {
        self.errors.clearAndFree();
        for (self.parsed.items) |*statement| {
            statement.dealloc();
        }
        self.parsed.clearAndFree();
    }
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
        return Block{ .identifier = identifier.value.items, .statements = blockStatements };
    } else {
        try errors.append(ParserError{
            .token = token,
            .errorMessage = "Expected '{'",
        });
        return null;
    }
}

fn handleDefiniteInvocation(tokenReader: *TokenReader, errors: *std.ArrayList(ParserError)) AllocatorError!?Invocation {
    if (typeOfToken(tokenReader.next()) != TokenType.Identifier) {
        try errors.append(ParserError{
            .token = tokenReader.next(),
            .errorMessage = "Expected identifier",
        });
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
                        try errors.append(ParserError{
                            .token = token,
                            .errorMessage = "Invalid token in argument list, expected an argument or ')'",
                        });
                        break;
                    },
                }
            } else if (currentPhase == InvocationPhase.ArgComplete) {
                switch (token) {
                    TokenType.Comma => currentPhase = InvocationPhase.ReadyForArg,
                    TokenType.BracketClose => break,
                    else => {
                        try errors.append(ParserError{
                            .token = token,
                            .errorMessage = "Invalid token in argument list, expected ',' or ')'",
                        });
                        break;
                    },
                }
            }
        }
        return Invocation{ .identifier = identifier.value.items, .args = args };
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
        if (typeOfToken(token) == finalToken)
            return statements;

        if (tokenReader.next()) |nextToken| {
            switch (token) {
                TokenType.Dot => {
                    switch (nextToken) {
                        TokenType.Identifier => {
                            if (try handleDefiniteInvocation(tokenReader, errors)) |invocation| {
                                try statements.append(Statement{
                                    .InvokingStatement = InvokingStatement{ .Pragma = invocation },
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
                            try errors.append(ParserError{
                                .token = nextToken,
                                .errorMessage = "Invalid token following '.'",
                            });
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
                            if (try handleInvocation(identifier, tokenReader, errors)) |function| {
                                try statements.append(Statement{
                                    .InvokingStatement = InvokingStatement{ .Function = function },
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
                            try errors.append(ParserError{
                                .token = nextToken,
                                .errorMessage = "Invalid token following identifier",
                            });
                        },
                    }
                },
                else => {
                    try errors.append(ParserError{
                        .token = token,
                        .errorMessage = "Invalid top level structure",
                    });
                },
            }
        } else {
            try errors.append(ParserError{
                .errorMessage = "Unexpected EOF",
            });
        }
    }
    if (finalToken != null) {
        try errors.append(ParserError{
            .errorMessage = "Unexpected EOF",
        });
    }
    return statements;
}

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
