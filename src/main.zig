const std = @import("std");
const print = std.debug.print;
const Child = std.process.Child;
const Signal = std.os.linux.SIG;

const qlist = @import("qlist");

var running = true;
var update = true;

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
			update = true;
		},
		else => {},
	}
}

pub fn main() !void {
	var gpa = std.heap.GeneralPurposeAllocator(.{}){};
	const allocator = gpa.allocator();

	subprocesses = std.StringHashMap(Child).init(allocator);
	var programs = qlist.QList.init(allocator);

	var env_map = try std.process.getEnvMap(allocator);
	defer env_map.deinit();

	const home_dir = env_map.get("HOME") orelse {
		print("cant get home dir", .{});
		return;
	};

	var sa = std.os.linux.Sigaction{
		.handler = .{.handler = signalHandler},
		.mask = std.os.linux.sigemptyset(),
		.flags = 0,
	};

	_ = std.os.linux.sigaction(Signal.INT, &sa, null);
	_ = std.os.linux.sigaction(Signal.TERM, &sa, null);
	_ = std.os.linux.sigaction(Signal.HUP, &sa, null);

	while (running) {
		if (update) {
			update = false;
			print("reading config\n", .{});

			const conf_path = try std.fs.path.join(allocator, &[_][]const u8{
				home_dir, ".config", "steam-hour-counter"
			});
	
			qlist.read(&programs, conf_path) catch |e| {
				print("{}\n", .{e});
			};
		}

		var iterator = programs.hm.iterator();
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
				
				try env_map.put("SteamAppId", item.value_ptr.*.string);

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
		std.Thread.sleep(15 * std.time.ns_per_s);
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
