const std = @import("std");

pub fn build(b: *std.Build) void {
	const target = b.standardTargetOptions(.{});
	const optimize = b.standardOptimizeOption(.{});

	const qlist = b.dependency("qlist", .{
		.target = target,
		.optimize = optimize,
	}).module("qlist");

	const sub = b.addExecutable(.{
		.name = "shc-sub",
		.root_module = b.createModule(.{
			.root_source_file = b.path("src/subprocess_main.zig"),
			.target = target,
			.link_libc = true,
		}),
	});

	const exe = b.addExecutable(.{
		.name = "steam-hour-counter",
		.root_module = b.createModule(.{
			.root_source_file = b.path("src/main.zig"),
			.target = target,
		}),
	});
	exe.root_module.addImport("qlist", qlist);

	b.installArtifact(sub);
	b.installArtifact(exe);
}
