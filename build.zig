const std = @import("std");
const raySdk = @import("raylib/build.zig");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "viz",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const lib = try raySdk.compileRaylib(b, target, optimize, .{});

    lib.installHeader(b.path("raylib/src/raylib.h"), "raylib.h");
    lib.installHeader(b.path("raylib/src/rcamera.h"), "rcamera.h");
    lib.installHeader(b.path("raylib/src/raymath.h"), "raymath.h");
    lib.installHeader(b.path("raylib/src/rlgl.h"), "rlgl.h");

    exe.linkLibrary(lib);

    b.installArtifact(lib);
    b.installArtifact(exe);

    const run_exe = b.addRunArtifact(exe);
    const run_step = b.step("run", "Run app");

    run_step.dependOn(&run_exe.step);
}
