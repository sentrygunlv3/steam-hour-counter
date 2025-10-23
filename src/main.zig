const std = @import("std");
const print = std.debug.print;
const Child = std.process.Child;
const fs = std.fs;

var running = true;
var subprocesses: std.StringHashMap(Child) = undefined;

fn signalHandler(signo: i32) callconv(.c) void {
	if (signo == std.os.linux.SIG.INT) {
		std.debug.print("SIGINT signal\n", .{});
		cleanup();
		std.process.exit(0);
	}
}

pub fn main() !void {
	var sa = std.os.linux.Sigaction{
		.handler = .{ .handler = signalHandler },
		.mask = std.os.linux.sigemptyset(),
		.flags = 0,
	};

	_ = std.os.linux.sigaction(std.os.linux.SIG.INT, &sa, null);

	var gpa = std.heap.GeneralPurposeAllocator(.{}){};
	const allocator = gpa.allocator();

	const exe_path = try std.fs.selfExePathAlloc(allocator);
	defer allocator.free(exe_path);
	const subprocess_path = try std.fmt.allocPrint(allocator, "{s}-sub", .{exe_path});

	subprocesses = std.StringHashMap(Child).init(allocator);

	const name = "blender";

	while (running) {
		std.Thread.sleep(5 * std.time.ns_per_s);
		const proc = try Child.run(.{
			.argv = &[_][]const u8{"pgrep", "-x", name},
			.allocator = allocator,
		});
		defer allocator.free(proc.stdout);
		defer allocator.free(proc.stderr);

		if (proc.stdout.len > 0 and subprocesses.get(name) == null) {
			print("found {s}\n", .{name});
			var env_map = try std.process.getEnvMap(allocator);
			defer env_map.deinit();

			try env_map.put("SteamAppId", "440");

			var sub = Child.init(
				&[_][]const u8{subprocess_path},
				allocator
			);
			sub.env_map = &env_map;
			Child.spawn(&sub) catch {
				_ = try sub.kill();
			};
			subprocesses.put(name, sub) catch {
				_ = try sub.kill();
			};
			print("started sub\n", .{});
		} else if (proc.stdout.len < 1 and subprocesses.get(name) != null) {
			var child = subprocesses.get(name).?;
			_ = try child.kill();
			_ = subprocesses.remove(name);
			print("killed sub\n", .{});
		}
	}
	cleanup();
}

fn cleanup() void {
	var iterator = subprocesses.iterator();
	while (iterator.next()) |item| {
		print("{s} = {d}\n", .{ item.key_ptr.*, item.value_ptr.*.id });
		_ = item.value_ptr.kill() catch {};
	}
}
