const std = @import("std");

pub const MvmaSource = struct {
    allocator: std.mem.Allocator,
    reader: std.fs.File.Reader,
    position: usize = 0,
    column: usize = 0,
    line: usize = 0,
    nextByte: ?u8 = null,

    pub const FilePosition = struct { line: usize, column: usize };

    pub fn peekNext(self: *MvmaSource) ?u8 {
        if (self.nextByte) |nextByte| return nextByte;

        const nextByte = self.reader.readByte() catch return null;
        self.nextByte = nextByte;
        return nextByte;
    }

    fn incrementPosition(self: *MvmaSource, newChar: u8) void {
        if (newChar == '\n') {
            self.line += 1;
            self.column = 0;
        } else {
            self.column += 1;
        }
        self.position += 1;
    }

    pub fn consumeNext(self: *MvmaSource) ?u8 {
        if (self.nextByte) |nextByte| {
            self.incrementPosition(nextByte);
            self.nextByte = null;
            return nextByte;
        }
        const nextByte = self.reader.readByte() catch return null;
        self.incrementPosition(nextByte);
        return nextByte;
    }

    pub fn consumeUntil(self: *MvmaSource, delimiters: []const u8) std.ArrayList(u8) {
        var string = std.ArrayList(u8).init(self.allocator);
        while (self.peekNext()) |char| {
            for (delimiters) |delimiter| {
                if (char == delimiter) return string;
            }
            string.append(self.consumeNext().?) catch {};
        }
        self.nextByte = null;
        return string;
    }

    pub fn currentPosition(self: *MvmaSource) FilePosition {
        return FilePosition{ .column = self.column + 1, .line = self.line + 1 };
    }
};
