const std = @import("std");
const StatementParser = @import("./statement_parser.zig");

const ArgValidator = *const fn (StatementParser.Arg) bool;

pub const ArgHandler = struct {
    size: u4,
    validator: ArgValidator,
};

pub const BytecodeOperation = struct {
    opcode: u16,
    opcodeSize: u4,
    argHandlers: []const ArgHandler,
};

fn registerValidator(arg: StatementParser.Arg) bool {
    _ = arg;
    return true;
}

fn constantValidator(arg: StatementParser.Arg) bool {
    _ = arg;
    return true;
}

fn branchConfigValidator(arg: StatementParser.Arg) bool {
    _ = arg;
    return true;
}

const REGISTER_ARG_HANDLER = ArgHandler{
    .size = 4,
    .validator = &registerValidator,
};

const CONSTANT_ARG_HANDLER = ArgHandler{
    .size = 8,
    .validator = &constantValidator,
};

const BRANCH_CONFIG_ARG_HANDLER = ArgHandler{
    .size = 2,
    .validator = &branchConfigValidator,
};

pub const BytecodeFunctions = std.ComptimeStringMap(BytecodeOperation, .{
    .{ "AddConstant", BytecodeOperation{
        .opcode = 0b0000,
        .opcodeSize = 4,
        .argHandlers = &[_]ArgHandler{
            REGISTER_ARG_HANDLER,
            CONSTANT_ARG_HANDLER,
        },
    } },
    .{ "Add", BytecodeOperation{
        .opcode = 0b0001,
        .opcodeSize = 4,
        .argHandlers = &[_]ArgHandler{
            REGISTER_ARG_HANDLER,
            REGISTER_ARG_HANDLER,
            REGISTER_ARG_HANDLER,
        },
    } },
    .{ "SubtractConstant", BytecodeOperation{
        .opcode = 0b0010,
        .opcodeSize = 4,
        .argHandlers = &[_]ArgHandler{
            REGISTER_ARG_HANDLER,
            CONSTANT_ARG_HANDLER,
        },
    } },
    .{ "Subtract", BytecodeOperation{
        .opcode = 0b0011,
        .opcodeSize = 4,
        .argHandlers = &[_]ArgHandler{
            REGISTER_ARG_HANDLER,
            REGISTER_ARG_HANDLER,
            REGISTER_ARG_HANDLER,
        },
    } },

    .{ "WriteConstant", BytecodeOperation{
        .opcode = 0b0100,
        .opcodeSize = 4,
        .argHandlers = &[_]ArgHandler{
            REGISTER_ARG_HANDLER,
            CONSTANT_ARG_HANDLER,
        },
    } },

    .{ "ShiftLeft", BytecodeOperation{
        .opcode = 0b0101,
        .opcodeSize = 4,
        .argHandlers = &[_]ArgHandler{
            REGISTER_ARG_HANDLER,
            REGISTER_ARG_HANDLER,
            REGISTER_ARG_HANDLER,
        },
    } },
    .{ "ShiftRight", BytecodeOperation{
        .opcode = 0b0110,
        .opcodeSize = 4,
        .argHandlers = &[_]ArgHandler{
            REGISTER_ARG_HANDLER,
            REGISTER_ARG_HANDLER,
            REGISTER_ARG_HANDLER,
        },
    } },
    .{ "Or", BytecodeOperation{
        .opcode = 0b0111,
        .opcodeSize = 4,
        .argHandlers = &[_]ArgHandler{
            REGISTER_ARG_HANDLER,
            REGISTER_ARG_HANDLER,
            REGISTER_ARG_HANDLER,
        },
    } },
    .{ "And", BytecodeOperation{
        .opcode = 0b1000,
        .opcodeSize = 4,
        .argHandlers = &[_]ArgHandler{
            REGISTER_ARG_HANDLER,
            REGISTER_ARG_HANDLER,
            REGISTER_ARG_HANDLER,
        },
    } },
    .{ "Flip", BytecodeOperation{
        .opcode = 0b1001,
        .opcodeSize = 4,
        .argHandlers = &[_]ArgHandler{
            REGISTER_ARG_HANDLER,
            REGISTER_ARG_HANDLER,
        },
    } },
    .{ "Xor", BytecodeOperation{
        .opcode = 0b1010,
        .opcodeSize = 4,
        .argHandlers = &[_]ArgHandler{
            REGISTER_ARG_HANDLER,
            REGISTER_ARG_HANDLER,
            REGISTER_ARG_HANDLER,
        },
    } },

    .{ "CopyRegister", BytecodeOperation{
        .opcode = 0b1110_0000,
        .opcodeSize = 8,
        .argHandlers = &[_]ArgHandler{
            REGISTER_ARG_HANDLER,
            REGISTER_ARG_HANDLER,
        },
    } },
    .{ "CopyFromAddress", BytecodeOperation{
        .opcode = 0b1110_0001,
        .opcodeSize = 8,
        .argHandlers = &[_]ArgHandler{
            REGISTER_ARG_HANDLER,
            REGISTER_ARG_HANDLER,
        },
    } },
    .{ "CopyToAddress", BytecodeOperation{
        .opcode = 0b1110_0010,
        .opcodeSize = 8,
        .argHandlers = &[_]ArgHandler{
            REGISTER_ARG_HANDLER,
            REGISTER_ARG_HANDLER,
        },
    } },
    .{ "CopyHalfWordFromAddress", BytecodeOperation{
        .opcode = 0b1110_0011,
        .opcodeSize = 8,
        .argHandlers = &[_]ArgHandler{
            REGISTER_ARG_HANDLER,
            REGISTER_ARG_HANDLER,
        },
    } },
    .{ "CopyHalfWordToAddress", BytecodeOperation{
        .opcode = 0b1110_0100,
        .opcodeSize = 8,
        .argHandlers = &[_]ArgHandler{
            REGISTER_ARG_HANDLER,
            REGISTER_ARG_HANDLER,
        },
    } },
    .{ "CopyByteFromAddress", BytecodeOperation{
        .opcode = 0b1110_0101,
        .opcodeSize = 8,
        .argHandlers = &[_]ArgHandler{
            REGISTER_ARG_HANDLER,
            REGISTER_ARG_HANDLER,
        },
    } },
    .{ "CopyByteToAddress", BytecodeOperation{
        .opcode = 0b1110_0110,
        .opcodeSize = 8,
        .argHandlers = &[_]ArgHandler{
            REGISTER_ARG_HANDLER,
            REGISTER_ARG_HANDLER,
        },
    } },

    .{ "Compare", BytecodeOperation{
        .opcode = 0b1110_0111,
        .opcodeSize = 8,
        .argHandlers = &[_]ArgHandler{
            REGISTER_ARG_HANDLER,
            REGISTER_ARG_HANDLER,
        },
    } },

    .{ "BranchAlways", BytecodeOperation{
        .opcode = 0b1111_00_0000,
        .opcodeSize = 10,
        .argHandlers = &[_]ArgHandler{
            BRANCH_CONFIG_ARG_HANDLER,
            REGISTER_ARG_HANDLER,
        },
    } },
    .{ "BranchEqual", BytecodeOperation{
        .opcode = 0b1111_00_0001,
        .opcodeSize = 10,
        .argHandlers = &[_]ArgHandler{
            BRANCH_CONFIG_ARG_HANDLER,
            REGISTER_ARG_HANDLER,
        },
    } },
    .{ "BranchNotEqual", BytecodeOperation{
        .opcode = 0b1111_00_0010,
        .opcodeSize = 10,
        .argHandlers = &[_]ArgHandler{
            BRANCH_CONFIG_ARG_HANDLER,
            REGISTER_ARG_HANDLER,
        },
    } },
    .{ "BranchGreaterThan", BytecodeOperation{
        .opcode = 0b1111_00_0011,
        .opcodeSize = 10,
        .argHandlers = &[_]ArgHandler{
            BRANCH_CONFIG_ARG_HANDLER,
            REGISTER_ARG_HANDLER,
        },
    } },
    .{ "BranchGreaterThanEqual", BytecodeOperation{
        .opcode = 0b1111_00_0100,
        .opcodeSize = 10,
        .argHandlers = &[_]ArgHandler{
            BRANCH_CONFIG_ARG_HANDLER,
            REGISTER_ARG_HANDLER,
        },
    } },
    .{ "BranchLessThan", BytecodeOperation{
        .opcode = 0b1111_00_0101,
        .opcodeSize = 10,
        .argHandlers = &[_]ArgHandler{
            BRANCH_CONFIG_ARG_HANDLER,
            REGISTER_ARG_HANDLER,
        },
    } },
    .{ "BranchLessThanEqual", BytecodeOperation{
        .opcode = 0b1111_00_0110,
        .opcodeSize = 10,
        .argHandlers = &[_]ArgHandler{
            BRANCH_CONFIG_ARG_HANDLER,
            REGISTER_ARG_HANDLER,
        },
    } },
});
