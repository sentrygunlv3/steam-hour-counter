const std = @import("std");
const print = std.debug.print;
const Child = std.process.Child;
const Signal = std.os.linux.SIG;

var running = true;
var subprocesses: std.StringHashMap(Child) = undefined;

fn signalHandler(signo: i32) callconv(.c) void {
	switch (signo) {
		Signal.INT => {
			cleanup();
			std.process.exit(0);
		},
		Signal.TERM => {
			running = false;
		},
		Signal.HUP => {
			// update
		},
		else => {},
	}
}

pub fn main() !void {
	var sa = std.os.linux.Sigaction{
		.handler = .{.handler = signalHandler},
		.mask = std.os.linux.sigemptyset(),
		.flags = 0,
	};

	_ = std.os.linux.sigaction(Signal.INT, &sa, null);
	_ = std.os.linux.sigaction(Signal.TERM, &sa, null);
	_ = std.os.linux.sigaction(Signal.HUP, &sa, null);

	var gpa = std.heap.GeneralPurposeAllocator(.{}){};
	const allocator = gpa.allocator();

	subprocesses = std.StringHashMap(Child).init(allocator);

	var programs = std.StringHashMap([]const u8).init(allocator);
	// program name - steam id
	try programs.put("blender", "365670");
	try programs.put("godot", "404790");

	while (running) {
		std.Thread.sleep(5 * std.time.ns_per_s);

		var iterator = programs.iterator();
		while (iterator.next()) |item| {
			const proc = try Child.run(.{
				.argv = &[_][]const u8{"pgrep", "-x", item.key_ptr.*},
				.allocator = allocator,
			});
			defer allocator.free(proc.stdout);
			defer allocator.free(proc.stderr);

			var child = subprocesses.get(item.key_ptr.*);
			if (proc.stdout.len > 0 and child == null) {
				print("found {s}\n", .{item.key_ptr.*});
				var env_map = try std.process.getEnvMap(allocator);
				defer env_map.deinit();

				try env_map.put("SteamAppId", item.value_ptr.*);

				var sub = Child.init(
					&[_][]const u8{"/usr/lib/steam-hour-counter/shc-sub"},
					allocator
				);
				sub.env_map = &env_map;
				Child.spawn(&sub) catch {
					_ = try sub.kill();
				};
				subprocesses.put(item.key_ptr.*, sub) catch {
					_ = try sub.kill();
				};
				print("started subprocess for {s}\n", .{item.key_ptr.*});
			} else if (proc.stdout.len < 1 and child != null) {
				_ = try child.?.kill();
				_ = subprocesses.remove(item.key_ptr.*);
				print("killed subprocess for {s}\n", .{item.key_ptr.*});
			}
		}
	}
	cleanup();
}

fn cleanup() void {
	print("\nshutting down subprocesses for:\n", .{});
	var iterator = subprocesses.iterator();
	while (iterator.next()) |item| {
		print("- {s}\n", .{item.key_ptr.*});
		_ = item.value_ptr.kill() catch {};
	}
}
