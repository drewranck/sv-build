package(default_visibility = ["//examples:__subpackages__"])

load("//tools/bzl:sv-build.bzl", "sv_library")
load("//tools/bzl:sv-build.bzl", "sv_glob_filegroup")

# This is a very lazy way to say *.v, *.sv, *.vh, *.svh:
sv_glob_filegroup(
    name = "sv-filegroup",
)

# and put it into a sh_library() for others to use as 'deps':
sv_library(
    name = "sv-library",
    srcs = [":sv-filegroup"],
    )
