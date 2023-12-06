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
const StatementType = enum { pragma, invocation };
const Statement = union(StatementType) {
    pragma: Pragma,
    invocation: Invocation,
};
const Block = struct {
    identifier: Identifier,
    statements: std.ArrayList(Statement),
};

pub fn parseStatement(tokens: []TokenUnion) !Statement {
    _ = tokens;
}

const TokenReader = struct {
    tokens: []TokenUnion,
    position: usize = 0,

    pub fn next(self: *TokenReader) ?TokenUnion {
        if (self.position >= self.tokens.len - 1) return null;
        return self.tokens[self.position];
    }

    pub fn previous(self: *TokenReader) ?TokenUnion {
        if (self.position == 0) return null;
        return self.tokens[self.position - 1];
    }

    pub fn consume(self: *TokenReader) ?TokenUnion {
        if (self.position >= self.tokens.len - 1) return null;
        self.position += 1;
        return self.tokens[self.position];
    }

    // TODO: should be able to return null
    pub fn current(self: *TokenReader) TokenUnion {
        return self.tokens[self.position];
    }
};

fn handleArgList(tokenReader: *TokenReader) void {
    if (tokenReader.next() == TokenType.BracketOpen) {
        tokenReader.consume();
        while (tokenReader.next() == TokenType.Address or tokenReader.next() == TokenType.Number or tokenReader.next() == TokenType.Identifier) {
            const nextToken = tokenReader.consume();
            if (nextToken == TokenType.BracketClose or nextToken == TokenType.Comma) {} else {}
        }
    } else {}
}

fn handleBlock(tokenReader: *TokenReader) void {
    if (tokenReader.current() != TokenUnion.BlockOpen) {
        std.debug.print("ERROR: INVALID BLOCK", .{});
    }
    while (tokenReader.consume()) |token| {
        switch (token) {
            TokenType.Dot, TokenType.Identifier, TokenType.Comment => {
                handleTopLevel(tokenReader);
            },
            TokenType.BlockClose => {},
            else => {},
        }
    }
    // while (tokenReader.consume()) |token| {
    //     switch (token) {
    //         TokenType.Dot, TokenType.Identifier => {
    //             if (token == TokenType.Dot) _ = tokenReader.consume();
    //             const invocationId = tokenReader.current();
    //             handleArgList(tokenReader);
    //             const invocation = Invocation{ .identifier = invocationId.Identifier.value };
    //             _ = invocation;
    //         },
    //         TokenType.Comment => {},
    //         else => {},
    //     }
    // }
}

fn handleInvocation(tokenReader: *TokenReader) void {
    const nextToken = tokenReader.next();
    if (nextToken != null and nextToken.? == TokenType.Identifier) {
        _ = tokenReader.consume();
        if (tokenReader.next() != null and tokenReader.next().? == TokenType.BracketOpen) {
            _ = tokenReader.consume();
            while (tokenReader.current() != TokenType.BlockClose) {
                const token = tokenReader.consume();
                switch (token) {
                    TokenType.Identifier => {},
                    TokenType.Comma => {},
                    else => {
                        std.debug.print("HADNLING IT", .{});
                    },
                }
            }
        }
    } else {}
}

fn handleTopLevel(tokenReader: *TokenReader) void {
    while (tokenReader.consume()) |token| {
        switch (token) {
            TokenType.Dot => {
                // Pragma
                const nextToken = tokenReader.next();
                if (nextToken != null and nextToken.? == TokenType.Identifier) {
                    handleInvocation(tokenReader);
                } else {}
            },
            TokenType.Identifier => {
                // std.debug.print("IDENT\n", .{});
                const nextToken = tokenReader.next();
                if (nextToken != null and nextToken.? == TokenType.Colon) {
                    _ = tokenReader.consume();
                } else {}
            },
            TokenType.Comment => {},
            else => {},
        }
    }
}

pub fn toStatements(tokens: []TokenUnion) void {
    var tokenReader = TokenReader{ .tokens = tokens };
    handleTopLevel(&tokenReader);
}
