const std = @import("std");

pub fn build(b: *std.Build) void {
	const sub = b.addExecutable(.{
		.name = "shc-sub",
		.root_module = b.createModule(.{
			.root_source_file = b.path("src/subprocess/main.zig"),
			.target = b.graph.host,
		}),
	});
	sub.linkLibC();

	const exe = b.addExecutable(.{
		.name = "shc",
		.root_module = b.createModule(.{
			.root_source_file = b.path("src/main.zig"),
			.target = b.graph.host,
		}),
	});
	exe.linkLibC();

	b.installArtifact(sub);
	b.installArtifact(exe);
}
