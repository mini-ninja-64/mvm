# MVM CPU

## Registers

An MVM CPU requires a minimum of 8*32 bit standard registers
Registers 8 onwards may be available for hardware peripherals such as serial.

| Index | Description              | Read/Write | Reset Value           | Layout                                                                |
|-------|--------------------------|------------|-----------------------|-----------------------------------------------------------------------|
| 0     | General Purpose Register | RW         | 0b0000 0000 0000 0000 | N/A                                                                   |
| 1     | General Purpose Register | RW         | 0b0000 0000 0000 0000 | N/A                                                                   |
| 2     | General Purpose Register | RW         | 0b0000 0000 0000 0000 | N/A                                                                   |
| 3     | General Purpose Register | RW         | 0b0000 0000 0000 0000 | N/A                                                                   |
| 4     | Status Register          | RO         | 0b0000 0000 0000 0000 | equal[1] negative[1] carry[1] overflow[1] reserved[20] failureCode[8] |
| 5     | Stack Pointer            | RW         | 0b0000 0000 0000 0000 | todo[32]                                                              |
| 6     | Link Register            | RW         | 0b0000 0000 0000 0000 | todo[32]                                                              |
| 7     | Program Counter          | RW         | 0b0000 0000 0000 0000 | todo[32]                                                              |

## Instruction Set

| Index      | Instruction                                   | OPCODE         | Encoding                         | Pseudocode          |
|------------|-----------------------------------------------|----------------|----------------------------------|----------------     |
| 4 bit ops  |                                               |                |                                  |                     |
| 0          | AddConstant(Rx, Constant)                     | 0b0000         | OPCODE[4] Rx[4] Constant[8]      | Rx += Constant      |
| 1          | Add(Rx, Ry, Rz)                               | 0b0001         | OPCODE[4] Rx[4] Ry[4] Rz[4]      | Rx = Ry + Rz        |
| 2          | SubtractConstant(Rx, Constant)                | 0b0010         | OPCODE[4] Rx[4] Constant[8]      | Rx -= Constant      |
| 3          | Subtract(Rx, Ry, Rz)                          | 0b0011         | OPCODE[4] Rx[4] Ry[4] Rz[4]      | Rx = Ry - Rz        |
|            |                                               |                |                                  |                     |
| 4          | WriteConstant(Rx, Constant)                   | 0b0100         | OPCODE[4] Rx[4] Constant[8]      | Rx = Constant       |
|            |                                               |                |                                  |                     |
| 5          | ShiftLeft(Rx, Ry, Rz)                         | 0b0101         | OPCODE[4] Rx[4] Ry[4] Rz[4]      | Rx  = Ry << Rz      |
| 6          | ShiftRight(Rx, Ry, Rz)                        | 0b0110         | OPCODE[4] Rx[4] Ry[4] Rz[4]      | Rx  = Ry >> Rz      |
| 7          | Or(Rx, Ry, Rz)                                | 0b0111         | OPCODE[4] Rx[4] Ry[4] Rz[4]      | Rx  = Ry \| Rz      |
| 8          | And(Rx, Ry, Rz)                               | 0b1000         | OPCODE[4] Rx[4] Ry[4] Rz[4]      | Rx = Ry & Rz        |
| 9          | Flip(Rx, Ry)                                  | 0b1001         | OPCODE[4] Rx[4] Ry[4] _[4]       | Rx = ~Ry            |
| 10         | Xor(Rx, Ry, Rz)                               | 0b1010         | OPCODE[4] Rx[4] Ry[4] Rz[4]      | Rx = Ry^Rz          |
|            |                                               |                |                                  |                     |
| 8 bit ops  |                                               |                |                                  |                     |
| 11         | CopyRegister(Rx, Ry)                          | 0b1110 0000    | OPCODE[8] Rx[4] Ry[4]            | Rx = Ry             |
| 12         | CopyFromAddress(Rx, Ry)                       | 0b1110 0001    | OPCODE[8] Rx[4] Ry[4]            | Rx = *Ry            |
| 13         | CopyToAddress(Rx, Ry)                         | 0b1110 0010    | OPCODE[8] Rx[4] Ry[4]            | *Ry = Rx            |
| 14         | CopyHalfWordFromAddress(Rx, Ry)               | 0b1110 0011    | OPCODE[8] Rx[4] Ry[4]            | Rx = (*Ry & 0xFFFF) |
| 15         | CoyHalfWordToAddress(Rx, Ry)                  | 0b1110 0100    | OPCODE[8] Rx[4] Ry[4]            | *Ry = (Rx & 0xFFFF) |
| 16         | CoyByteFromAddress(Rx, Ry)                    | 0b1110 0101    | OPCODE[8] Rx[4] Ry[4]            | *Ry = (\*Rx & 0xFF) |
| 17         | CoyByteToAddress(Rx, Ry)                      | 0b1110 0110    | OPCODE[8] Rx[4] Ry[4]            | *Ry = (Rx & 0xFF)   |
|            |                                               |                |                                  |                     |
| 18         | Compare(Rx, Ry)                               | 0b1110 0111    | OPCODE[8] Rx[4] Ry[4]            | Rx - Ry             |
|            |                                               |                |                                  |                     |
| 14 bit ops |                                               |                |                                  |                     |
| 19         | BranchAlways(BranchConfig, Rx)                | 0b1111 00 0000 | OPCODE[14] BranchConfig[2] Rx[4] |                     |
| 20         | BranchEqual(BranchConfig, Rx)                 | 0b1111 00 0001 | OPCODE[14] BranchConfig[2] Rx[4] |                     |
| 21         | BranchNotEqual(BranchConfig, Rx)              | 0b1111 00 0010 | OPCODE[14] BranchConfig[2] Rx[4] |                     |
|            |                                               |                |                                  |                     |
| 22         | BranchMoreThanUnsigned(BranchConfig, Rx)      | 0b1111 00 0011 | OPCODE[14] BranchConfig[2] Rx[4] |                     |
| 23         | BranchMoreThanSigned(BranchConfig, Rx)        | 0b1111 00 0100 | OPCODE[14] BranchConfig[2] Rx[4] |                     |
| 24         | BranchMoreThanEqualUnsigned(BranchConfig, Rx) | 0b1111 00 0101 | OPCODE[14] BranchConfig[2] Rx[4] |                     |
| 25         | BranchMoreThanEqualSigned(BranchConfig, Rx)   | 0b1111 00 0110 | OPCODE[14] BranchConfig[2] Rx[4] |                     |
|            |                                               |                |                                  |                     |
| 26         | BranchLessThanUnsigned(BranchConfig, Rx)      | 0b1111 00 0111 | OPCODE[14] BranchConfig[2] Rx[4] |                     |
| 27         | BranchLessThanSigned(BranchConfig, Rx)        | 0b1111 00 1000 | OPCODE[14] BranchConfig[2] Rx[4] |                     |
| 28         | BranchLessThanEqualUnsigned(BranchConfig, Rx) | 0b1111 00 1001 | OPCODE[14] BranchConfig[2] Rx[4] |                     |
| 29         | BranchLessThanEqualSigned(BranchConfig, Rx)   | 0b1111 00 1010 | OPCODE[14] BranchConfig[2] Rx[4] |                     |
|            |                                               |                |                                  |                     |
| 30         | BranchLessThanUnsigned(BranchConfig, Rx)      | 0b1111 00 1011 | OPCODE[14] BranchConfig[2] Rx[4] |                     |
| 31         | BranchLessThanSigned(BranchConfig, Rx)        | 0b1111 00 1100 | OPCODE[14] BranchConfig[2] Rx[4] |                     |
| 32         | BranchLessThanEqualUnsigned(BranchConfig, Rx) | 0b1111 00 1101 | OPCODE[14] BranchConfig[2] Rx[4] |                     |
| 33         | BranchLessThanEqualSigned(BranchConfig, Rx)   | 0b1111 00 1110 | OPCODE[14] BranchConfig[2] Rx[4] |                     |
|            |                                               |                |                                  |                     |
| 34         | BranchLessThanUnsigned(BranchConfig, Rx)      | 0b1111 00 1111 | OPCODE[14] BranchConfig[2] Rx[4] |                     |
| 35         | BranchLessThanSigned(BranchConfig, Rx)        | 0b1111 01 0000 | OPCODE[14] BranchConfig[2] Rx[4] |                     |
| 36         | BranchLessThanEqualUnsigned(BranchConfig, Rx) | 0b1111 01 0001 | OPCODE[14] BranchConfig[2] Rx[4] |                     |
| 37         | BranchLessThanEqualSigned(BranchConfig, Rx)   | 0b1111 01 0010 | OPCODE[14] BranchConfig[2] Rx[4] |                     |

### Args

`Rx/Ry/Rz` are 4 bit unsigned integers representing the register to update.

`Constant` is an 8 bit unsigned integer value.

`BranchConfig` Layout:
| Bit     | 0        | 1                  |
|---------|----------|--------------------|
| Purpose | Reserved | UpdateLinkRegister |
