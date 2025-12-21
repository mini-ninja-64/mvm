const std = @import("std");
const StatementParser = @import("./statement_parser.zig");
const BytecodeFunctions = @import("./bytecode_operations.zig").BytecodeFunctions;

const Metadata = struct { startAddress: u16 };
const Binary = struct {
    metadata: Metadata,
    bytecode: std.ArrayList(u8),

    pub fn clearAndFree(self: *Binary) void {
        self.bytecode.clearAndFree();
    }
};

const Operation = struct {
    const Value = struct {
        value: u16,
        size: u4,
    };
    const LazyValue = struct {
        address: []const u8,
        size: u4,
    };
    const ArgType = enum { Value, LazyValue };
    const Arg = union(ArgType) {
        Value: Value,
        LazyValue: LazyValue,

        pub fn getValue(self: *const Arg, addressHandler: *AddressHandler) ?Value {
            switch (self.*) {
                Operation.ArgType.Value => |value| return value,
                Operation.ArgType.LazyValue => |lazyValue| {
                    if (addressHandler.get(lazyValue.address)) |address| {
                        return Operation.Value{
                            .value = @truncate(address),
                            .size = lazyValue.size,
                        };
                    } else {
                        return null;
                    }
                },
            }
        }
    };
    opcode: u16,
    opcodeSize: u4,
    args: std.ArrayList(Operation.Arg),

    pub fn clearAndFree(self: *Operation) void {
        self.args.clearAndFree();
    }
};

const BinaryStream = struct {
    metadata: Metadata,
    operations: std.ArrayList(Operation),
    addressHandler: AddressHandler,
    allocator: std.mem.Allocator,

    fn handlePragma(self: *BinaryStream, invocation: StatementParser.Invocation, blockName: []const u8) !void {
        _ = self;
        _ = invocation;
        _ = blockName;
    }

    fn handleFunction(self: *BinaryStream, invocation: StatementParser.Invocation, blockName: []const u8) !void {
        if (BytecodeFunctions.get(invocation.identifier)) |functionDefinition| {
            const argHandlers = functionDefinition.argHandlers;
            if (argHandlers.len == invocation.args.items.len) {
                var args = std.ArrayList(Operation.Arg).init(self.allocator);
                for (argHandlers, invocation.args.items) |argHandler, arg| {
                    if (!argHandler.validator(arg)) {
                        std.debug.print("invalid arg\n", .{});
                    } else {
                        const opArg: Operation.Arg = switch (arg) {
                            StatementParser.ArgType.Register => |register| Operation.Arg{ .Value = Operation.Value{
                                .size = argHandler.size,
                                .value = register.index,
                            } },
                            StatementParser.ArgType.Number => |number| Operation.Arg{ .Value = Operation.Value{
                                .size = argHandler.size,
                                .value = @truncate(number),
                            } },
                            StatementParser.ArgType.Address => |address| operation: {
                                const currentBlock = if (address.scoped) blockName else "";

                                break :operation Operation.Arg{ .LazyValue = Operation.LazyValue{
                                    .size = argHandler.size,
                                    .address = try self.addressHandler.registerAddressReference(
                                        currentBlock,
                                        address.elements.items,
                                    ),
                                } };
                            },
                        };
                        try args.append(opArg);
                    }
                }
                try self.operations.append(Operation{
                    .opcode = functionDefinition.opcode,
                    .opcodeSize = functionDefinition.opcodeSize,
                    .args = args,
                });
            } else {
                std.debug.print("Too few args: {s}\n", .{invocation.identifier});
            }
        }
    }

    pub fn handleBytecode(self: *BinaryStream, statements: []StatementParser.Statement, blockName: []const u8) !void {
        for (statements) |statement| {
            switch (statement) {
                StatementParser.StatementType.InvokingStatement => |invokingStatement| {
                    switch (invokingStatement) {
                        StatementParser.InvokingStatementType.Function => |invocation| try self.handleFunction(invocation, blockName),
                        StatementParser.InvokingStatementType.Pragma => |invocation| try self.handlePragma(invocation, blockName),
                    }
                },
                StatementParser.StatementType.Block => |block| {
                    const newBlockName = try self.addressHandler.add(blockName, block.identifier, self.operations.items.len * 2);
                    try self.handleBytecode(block.statements.items, newBlockName);
                },
            }
        }
    }

    pub fn toBinary(self: *BinaryStream) !std.ArrayList(u8) {
        var bytecode = std.ArrayList(u8).init(self.allocator);
        for (self.operations.items) |operation| {
            const binaryShift: u16 = @as(u16, 16 - @as(u16, operation.opcodeSize));
            var opBinary = operation.opcode << @truncate(binaryShift);
            var argsBinary: u16 = 0;
            var argPosition: u8 = operation.opcodeSize;
            for (operation.args.items) |arg| {
                const argValue = arg.getValue(&self.addressHandler);
                var argBinaryValue: u16 = argValue.?.value;
                argPosition += argValue.?.size;
                const shiftValue = @as(u16, 16 - argPosition);
                argBinaryValue <<= @truncate(shiftValue);
                argsBinary |= argBinaryValue;
            }
            opBinary |= argsBinary;

            try bytecode.append(@truncate((opBinary & 0xFF00) >> 8));
            try bytecode.append(@truncate(opBinary & 0x00FF));
        }
        return bytecode;
    }

    fn clearAndFree(self: *BinaryStream) void {
        self.addressHandler.clearAndFree();
        for (self.operations.items) |*operation| {
            operation.clearAndFree();
        }
        self.operations.clearAndFree();
    }
};

const ByteValueType = enum { LazyLookup, Byte };
const ByteValue = union(ByteValueType) {
    LazyLookup: []const u8,
    Byte: u8,
};

pub fn buildAddressHandler(allocator: std.mem.Allocator) AddressHandler {
    return AddressHandler{
        .addresses = std.StringHashMap(std.ArrayList(u8)).init(allocator),
        .addressLookup = std.StringHashMap(usize).init(allocator),
        .allocator = allocator,
    };
}

const AddressHandler = struct {
    addresses: std.StringHashMap(std.ArrayList(u8)),
    addressLookup: std.StringHashMap(usize),
    allocator: std.mem.Allocator,

    pub fn registerAddressReference(self: *AddressHandler, prefix: []const u8, nameStack: []const []const u8) ![]const u8 {
        var addressName = std.ArrayList(u8).init(self.allocator);
        try addressName.appendSlice(prefix);
        for (nameStack) |name| {
            try addressName.append('.');
            try addressName.appendSlice(name);
        }

        if (self.addresses.get(addressName.items)) |address| {
            addressName.clearAndFree();
            return address.items;
        } else {
            try self.addresses.put(addressName.items, addressName);
            return addressName.items;
        }
    }

    pub fn add(self: *AddressHandler, prefix: []const u8, name: []const u8, address: usize) ![]const u8 {
        var addressName = try self.registerAddressReference(prefix, &[_][]const u8{name});

        try self.addressLookup.put(addressName, address);
        return addressName;
    }

    pub fn get(self: *AddressHandler, address: []const u8) ?usize {
        return self.addressLookup.get(address);
    }

    pub fn clearAndFree(self: *AddressHandler) void {
        self.addressLookup.clearAndFree();
        var addresses = self.addresses.valueIterator();
        while (addresses.next()) |*address| {
            address.*.clearAndFree();
        }
        self.addresses.clearAndFree();
    }
};

pub fn generateBytecode(allocator: std.mem.Allocator, statements: []StatementParser.Statement) !Binary {
    var bs = BinaryStream{
        .addressHandler = buildAddressHandler(allocator),
        .operations = std.ArrayList(Operation).init(allocator),
        .metadata = Metadata{ .startAddress = 0 },
        .allocator = allocator,
    };
    defer bs.clearAndFree();
    try bs.handleBytecode(statements, "");
    var bytes = try bs.toBinary();
    return Binary{
        .metadata = bs.metadata,
        .bytecode = bytes,
    };
}
