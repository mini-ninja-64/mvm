const std = @import("std");
const StatementParser = @import("./statement_parser.zig");

const Metadata = struct { startAddress: u16 };
const Binary = struct { metadata: Metadata, bytecode: std.ArrayList(u8) };

const ArgValidator = fn (StatementParser.Arg, u16) bool;
const ArgValidatorPtr = *const ArgValidator;

fn registerValidator(arg: StatementParser.Arg, size: u16) bool {
    _ = size;
    _ = arg;
    return true;
}

fn constantValidator(arg: StatementParser.Arg, size: u16) bool {
    _ = size;
    _ = arg;
    return true;
}

fn branchConfigValidator(arg: StatementParser.Arg, size: u16) bool {
    _ = size;
    _ = arg;
    return true;
}

const FunctionHandler = struct {
    opcode: u16,
    opcodeSize: u4,
    argSizes: []const u16,
    validators: []const ArgValidatorPtr,
};
const FUNCTION_LUT = std.ComptimeStringMap(FunctionHandler, .{
    .{ "AddConstant", FunctionHandler{
        .opcode = 0b0000,
        .opcodeSize = 4,
        .argSizes = &[_]u16{ 4, 8 },
        .validators = &[_]ArgValidatorPtr{ &registerValidator, &constantValidator },
    } },
    .{ "Add", FunctionHandler{
        .opcode = 0b0001,
        .opcodeSize = 4,
        .argSizes = &[_]u16{ 4, 4, 4 },
        .validators = &[_]ArgValidatorPtr{ &registerValidator, &registerValidator, &registerValidator },
    } },
    .{ "SubtractConstant", FunctionHandler{
        .opcode = 0b0010,
        .opcodeSize = 4,
        .argSizes = &[_]u16{ 4, 8 },
        .validators = &[_]ArgValidatorPtr{ &registerValidator, &constantValidator },
    } },
    .{ "Subtract", FunctionHandler{
        .opcode = 0b0011,
        .opcodeSize = 4,
        .argSizes = &[_]u16{ 4, 4, 4 },
        .validators = &[_]ArgValidatorPtr{ &registerValidator, &registerValidator, &registerValidator },
    } },

    .{ "WriteConstant", FunctionHandler{
        .opcode = 0b0100,
        .opcodeSize = 4,
        .argSizes = &[_]u16{ 4, 8 },
        .validators = &[_]ArgValidatorPtr{ &registerValidator, &constantValidator },
    } },

    .{ "ShiftLeft", FunctionHandler{
        .opcode = 0b0101,
        .opcodeSize = 4,
        .argSizes = &[_]u16{ 4, 4, 4 },
        .validators = &[_]ArgValidatorPtr{ &registerValidator, &registerValidator, &registerValidator },
    } },
    .{ "ShiftRight", FunctionHandler{
        .opcode = 0b0110,
        .opcodeSize = 4,
        .argSizes = &[_]u16{ 4, 4, 4 },
        .validators = &[_]ArgValidatorPtr{ &registerValidator, &registerValidator, &registerValidator },
    } },
    .{ "Or", FunctionHandler{
        .opcode = 0b0111,
        .opcodeSize = 4,
        .argSizes = &[_]u16{ 4, 4, 4 },
        .validators = &[_]ArgValidatorPtr{ &registerValidator, &registerValidator, &registerValidator },
    } },
    .{ "And", FunctionHandler{
        .opcode = 0b1000,
        .opcodeSize = 4,
        .argSizes = &[_]u16{ 4, 4, 4 },
        .validators = &[_]ArgValidatorPtr{ &registerValidator, &registerValidator, &registerValidator },
    } },
    .{ "Flip", FunctionHandler{
        .opcode = 0b1001,
        .opcodeSize = 4,
        .argSizes = &[_]u16{ 4, 4 },
        .validators = &[_]ArgValidatorPtr{ &registerValidator, &registerValidator },
    } },
    .{ "Xor", FunctionHandler{
        .opcode = 0b1010,
        .opcodeSize = 4,
        .argSizes = &[_]u16{ 4, 4, 4 },
        .validators = &[_]ArgValidatorPtr{ &registerValidator, &registerValidator, &registerValidator },
    } },

    .{ "CopyRegister", FunctionHandler{
        .opcode = 0b1110_0000,
        .opcodeSize = 8,
        .argSizes = &[_]u16{ 4, 4 },
        .validators = &[_]ArgValidatorPtr{ &registerValidator, &registerValidator },
    } },
    .{ "CopyFromAddress", FunctionHandler{
        .opcode = 0b1110_0001,
        .opcodeSize = 8,
        .argSizes = &[_]u16{ 4, 4 },
        .validators = &[_]ArgValidatorPtr{ &registerValidator, &registerValidator },
    } },
    .{ "CopyToAddress", FunctionHandler{
        .opcode = 0b1110_0010,
        .opcodeSize = 8,
        .argSizes = &[_]u16{ 4, 4 },
        .validators = &[_]ArgValidatorPtr{ &registerValidator, &registerValidator },
    } },
    .{ "CopyHalfWordFromAddress", FunctionHandler{
        .opcode = 0b1110_0011,
        .opcodeSize = 8,
        .argSizes = &[_]u16{ 4, 4 },
        .validators = &[_]ArgValidatorPtr{ &registerValidator, &registerValidator },
    } },
    .{ "CopyHalfWordToAddress", FunctionHandler{
        .opcode = 0b1110_0100,
        .opcodeSize = 8,
        .argSizes = &[_]u16{ 4, 4 },
        .validators = &[_]ArgValidatorPtr{ &registerValidator, &registerValidator },
    } },
    .{ "CopyByteFromAddress", FunctionHandler{
        .opcode = 0b1110_0101,
        .opcodeSize = 8,
        .argSizes = &[_]u16{ 4, 4 },
        .validators = &[_]ArgValidatorPtr{ &registerValidator, &registerValidator },
    } },
    .{ "CopyByteToAddress", FunctionHandler{
        .opcode = 0b1110_0110,
        .opcodeSize = 8,
        .argSizes = &[_]u16{ 4, 4 },
        .validators = &[_]ArgValidatorPtr{ &registerValidator, &registerValidator },
    } },

    .{ "Compare", FunctionHandler{
        .opcode = 0b1110_0111,
        .opcodeSize = 8,
        .argSizes = &[_]u16{ 4, 4 },
        .validators = &[_]ArgValidatorPtr{ &registerValidator, &registerValidator },
    } },

    .{ "BranchAlways", FunctionHandler{
        .opcode = 0b1111_00_0000,
        .opcodeSize = 10,
        .argSizes = &[_]u16{ 2, 4 },
        .validators = &[_]ArgValidatorPtr{ &branchConfigValidator, &registerValidator },
    } },
    .{ "BranchEqual", FunctionHandler{
        .opcode = 0b1111_00_0001,
        .opcodeSize = 10,
        .argSizes = &[_]u16{ 2, 4 },
        .validators = &[_]ArgValidatorPtr{ &branchConfigValidator, &registerValidator },
    } },
    .{ "BranchNotEqual", FunctionHandler{
        .opcode = 0b1111_00_0010,
        .opcodeSize = 10,
        .argSizes = &[_]u16{ 2, 4 },
        .validators = &[_]ArgValidatorPtr{ &branchConfigValidator, &registerValidator },
    } },
    .{ "BranchGreaterThan", FunctionHandler{
        .opcode = 0b1111_00_0011,
        .opcodeSize = 10,
        .argSizes = &[_]u16{ 2, 4 },
        .validators = &[_]ArgValidatorPtr{ &branchConfigValidator, &registerValidator },
    } },
    .{ "BranchGreaterThanEqual", FunctionHandler{
        .opcode = 0b1111_00_0100,
        .opcodeSize = 10,
        .argSizes = &[_]u16{ 2, 4 },
        .validators = &[_]ArgValidatorPtr{ &branchConfigValidator, &registerValidator },
    } },
    .{ "BranchLessThan", FunctionHandler{
        .opcode = 0b1111_00_0101,
        .opcodeSize = 10,
        .argSizes = &[_]u16{ 2, 4 },
        .validators = &[_]ArgValidatorPtr{ &branchConfigValidator, &registerValidator },
    } },
    .{ "BranchLessThanEqual", FunctionHandler{
        .opcode = 0b1111_00_0110,
        .opcodeSize = 10,
        .argSizes = &[_]u16{ 2, 4 },
        .validators = &[_]ArgValidatorPtr{ &branchConfigValidator, &registerValidator },
    } },
});

const BinaryStream = struct {
    metadata: Metadata,
    bytes: std.ArrayList(ByteValue),
    addressHandler: AddressHandler,

    fn handlePragma(self: *BinaryStream, invocation: StatementParser.Invocation) !void {
        _ = self;
        _ = invocation;
    }

    fn handleFunction(self: *BinaryStream, invocation: StatementParser.Invocation) !void {
        _ = self;
        if (FUNCTION_LUT.get(invocation.identifier)) |functionDefinition| {
            const validators = functionDefinition.validators;
            const argSizes = functionDefinition.argSizes;
            if (validators.len == invocation.args.items.len) {
                var op: u16 = functionDefinition.opcode << (16 - functionDefinition.opcodeSize);
                _ = op;
                var args: u16 = 0;
                _ = args;
                var argPosition = functionDefinition.opcodeSize;
                _ = argPosition;
                for (validators, invocation.args.items, argSizes) |validator, arg, argSize| {
                    if (!validator(arg, argSize)) {
                        std.debug.print("invalid arg\n", .{});
                    }
                }
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
                        StatementParser.InvokingStatementType.Function => |invocation| try self.handleFunction(invocation),
                        StatementParser.InvokingStatementType.Pragma => |invocation| try self.handlePragma(invocation),
                        // StatementParser.InvokingStatementType.Pragma => |invocation| {
                        //     for (invocation.args.items) |arg| {
                        //         switch (arg) {
                        //             StatementParser.ArgType.Address => |address| {
                        //                 _ = ByteValue{ .LazyLookup = try self.addressHandler.registerAddressReference(blockName, address) };
                        //             },
                        //             StatementParser.ArgType.Number => |number| {
                        //                 _ = number;
                        //                 _ = ByteValue{ .Byte = 0 };
                        //             },
                        //             StatementParser.ArgType.Register => |register| {
                        //                 _ = ByteValue{ .Byte = register.index };
                        //             },
                        //         }
                        //     }
                        // },
                    }
                },
                StatementParser.StatementType.Block => |block| {
                    const newBlockName = try self.addressHandler.add(blockName, block.identifier, self.bytes.items.len);
                    try self.handleBytecode(block.statements.items, newBlockName);
                },
            }
        }
    }

    fn clearAndFree(self: *BinaryStream) void {
        self.addressHandler.clearAndFree();
        self.bytes.clearAndFree();
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

    pub fn registerAddressReference(self: *AddressHandler, prefix: []const u8, name: []const u8) ![]const u8 {
        var addressName = std.ArrayList(u8).init(self.allocator);
        try addressName.appendSlice(prefix);
        try addressName.append(':');
        try addressName.appendSlice(name);

        if (self.addresses.get(addressName.items)) |address| {
            addressName.clearAndFree();
            std.debug.print("using cached addr: {s}\n", .{address.items});
            return address.items;
        } else {
            std.debug.print("new addr: {s}\n", .{addressName.items});
            try self.addresses.put(addressName.items, addressName);
            return addressName.items;
        }
    }

    pub fn add(self: *AddressHandler, prefix: []const u8, name: []const u8, address: usize) ![]const u8 {
        var addressName = try self.registerAddressReference(prefix, name);

        try self.addressLookup.put(addressName, address);
        return addressName;
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

pub fn generateBytecode(allocator: std.mem.Allocator, statements: []StatementParser.Statement) !void {
    var bs = BinaryStream{
        .addressHandler = buildAddressHandler(allocator),
        .bytes = std.ArrayList(ByteValue).init(allocator),
        .metadata = Metadata{ .startAddress = 0 },
    };
    defer bs.clearAndFree();
    try bs.handleBytecode(statements, "");

    // return Binary{
    //     .metadata = metadata,
    //     .bytecode = bytes,
    // };
}
