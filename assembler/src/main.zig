const std = @import("std");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    const asmFilePath = args[1];
    const asmFile = try std.fs.cwd().openFile(asmFilePath, std.fs.File.OpenFlags{});
    defer asmFile.close();

    var buf_reader = std.io.bufferedReader(asmFile.reader());
    var in_stream = buf_reader.reader();

    while (try in_stream.readByte()) |char| {
        switch (char) {
            ' ' => {},
            ' ' => {},
            else => {},
        }
    }
}
