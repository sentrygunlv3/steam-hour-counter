const std = @import("std");

pub fn build(b: *std.Build) void {
	const sub = b.addExecutable(.{
		.name = "shc-sub",
		.root_module = b.createModule(.{
			.root_source_file = b.path("src/subprocess/main.zig"),
			.target = b.graph.host,
			.link_libc = true,
		}),
	});

	const exe = b.addExecutable(.{
		.name = "steam-hour-counter",
		.root_module = b.createModule(.{
			.root_source_file = b.path("src/main.zig"),
			.target = b.graph.host,
		}),
	});

	b.installArtifact(sub);
	b.installArtifact(exe);
}
