const std = @import("std");
const posix = std.posix;
const process = @import("../process.zig");
const allocator = std.heap.page_allocator;
const c = @import("c.zig");

pub fn getProcesses() !std.ArrayList(process.ProcessInformation) {
    var result = std.ArrayList(process.ProcessInformation).init(allocator);

    const pidBytesLen: usize = @intCast(c.proc_listpids(1, 0, null, 0));
    const pidDataLen = pidBytesLen / @sizeOf(c_int);
    const pidData = try allocator.alloc(c_int, pidDataLen);
    defer allocator.free(pidData);

    const pidsReceived: usize = @intCast(c.proc_listpids(1, 0, @ptrCast(pidData), @intCast(pidBytesLen)));
    if (pidsReceived == 0) {
        return error.FailedToListPids;
    }

    const pidsTotal = pidsReceived / @sizeOf(c_int);
    var i: u32 = 0;

    while (i < pidsTotal) : (i += 1) {
        const pid = pidData[i];
        if (pid == 0) {
            continue;
        }

        var buffer: [1024]u8 = undefined;
        const bufferLen: c_int = c.proc_pidpath(@intCast(pid), &buffer, buffer.len);
        if (bufferLen == 0) {
            continue;
        }

        const name = buffer[0..@intCast(bufferLen)];

        try result.append(process.ProcessInformation{
            .pid = @intCast(pid),
            .name = try allocator.dupe(u8, name),
        });
    }

    return result;
}
