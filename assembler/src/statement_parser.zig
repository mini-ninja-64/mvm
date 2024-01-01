const std = @import("std");
const MvmaSource = @import("./mvma.zig").MvmaSource;
const TokenParser = @import("./token_parser.zig");
const TokenType = TokenParser.TokenType;
const TokenUnion = TokenParser.TokenUnion;

pub const Number = usize;
pub const Identifier = []const u8;
pub const Address = struct {
    scoped: bool,
    elements: std.ArrayList([]const u8),
};
pub const Register = struct { index: u8 };

pub const ArgType = enum { Register, Number, Address };
pub const Arg = union(ArgType) {
    Register: Register,
    Number: Number,
    Address: Address,

    fn dealloc(self: *Arg) void {
        switch (self.*) {
            ArgType.Register => {},
            ArgType.Number => {},
            ArgType.Address => |*address| {
                address.elements.clearAndFree();
            },
        }
    }
};
pub const ArgList = std.ArrayList(Arg);

pub const Invocation = struct {
    identifier: Identifier,
    args: ArgList,
    fn dealloc(self: *Invocation) void {
        for (self.args.items) |*arg| {
            arg.dealloc();
        }
        self.args.clearAndFree();
    }
};
pub const Pragma = Invocation;
pub const InvokingStatementType = enum { Pragma, Function };
pub const InvokingStatement = union(InvokingStatementType) {
    Pragma: Pragma,
    Function: Invocation,

    fn dealloc(self: *InvokingStatement) void {
        switch (self.*) {
            InvokingStatementType.Pragma => |*pragma| pragma.dealloc(),
            InvokingStatementType.Function => |*invokingStatement| invokingStatement.dealloc(),
        }
    }
};
pub const Block = struct {
    identifier: Identifier,
    statements: std.ArrayList(Statement),

    fn dealloc(self: *Block) void {
        for (self.statements.items) |*statement| {
            statement.dealloc();
        }
        self.statements.clearAndFree();
    }
};

pub const StatementType = enum { Block, InvokingStatement };
pub const Statement = union(StatementType) {
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

const REGISTER_LUT = std.ComptimeStringMap(Register, .{
    .{ "r0", Register{ .index = 0 } },
    .{ "r1", Register{ .index = 1 } },
    .{ "r2", Register{ .index = 2 } },
    .{ "r3", Register{ .index = 3 } },
    .{ "r4", Register{ .index = 4 } },
    .{ "r5", Register{ .index = 5 } },
    .{ "r6", Register{ .index = 6 } },
    .{ "r7", Register{ .index = 7 } },
    .{ "r8", Register{ .index = 8 } },
    .{ "r9", Register{ .index = 9 } },
    .{ "r10", Register{ .index = 10 } },
    .{ "r11", Register{ .index = 11 } },
    .{ "status", Register{ .index = 12 } },
    .{ "sp", Register{ .index = 13 } },
    .{ "lr", Register{ .index = 14 } },
    .{ "pc", Register{ .index = 15 } },
});

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
                        switch (token) {
                            TokenType.Identifier => |identifierToken| {
                                if (REGISTER_LUT.get(identifierToken.value.items)) |register| {
                                    try args.append(Arg{ .Register = register });
                                } else {
                                    try errors.append(ParserError{
                                        .token = token,
                                        .errorMessage = "Unrecognised type in argument list",
                                    });
                                }
                            },
                            TokenType.Address => |addressToken| {
                                var addressElements = std.ArrayList([]const u8).init(tokenReader.allocator);
                                for (addressToken.value.elements.items) |addressElement| {
                                    try addressElements.append(addressElement.items);
                                }
                                try args.append(Arg{ .Address = Address{
                                    .scoped = addressToken.value.scoped,
                                    .elements = addressElements,
                                } });
                            },
                            TokenType.Number => |numberToken| try args.append(Arg{ .Number = numberToken.value }),
                            else => unreachable,
                        }
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
                        .errorMessage = "Invalid token found",
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
