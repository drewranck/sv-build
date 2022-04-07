package(default_visibility = ["//examples:__subpackages__"])

load("//tools/bzl:sv-build.bzl", "sv_lint_test")
load("//tools/bzl:sv-build.bzl", "sv_library")
load("//tools/bzl:sv-build.bzl", "sv_glob_filegroup")
load("//tools/bzl:sv-build.bzl", "sv_verilator_test")

load("//tools/verilator:verilator.bzl", "sim_main_cpp_generator")

# Simple rule to make all our svh + sv + v source in a single dependency.
sv_glob_filegroup(
    name = "sv-filegroup",
)

sv_library(
    name = "sv-library",
    srcs = [":sv-filegroup"],
    deps = [
        "//examples/rtl/defines:sv-library",
    ],
    )

## lint tests:
sv_lint_test(
    name = "pipeline-lint",
    top = "pipeline.sv",
    deps = [":sv-library"],
    )

## tests:

# The sim_main_cpp_generator, because it takes a list of srcs to generate a list of targets,
# the targets are implicit name + "-" svmodule
# So in this case, sim-main-cpp-gen-pipeline_test_verilator
# Using the default for arg template="//tools/verilator:sim_main.cpp.template"
# You could skip this rule if you wanted to BYO .cpp file for driving Verilator.
sim_main_cpp_generator(
    name = "sim-main-cpp-gen",
    srcs = [":pipeline_test_verilator.sv"],
    )

# If your test dependencies had other things (asserts, info, uvm, etc) you
# could add them to this rule:
sv_library(
    name = "pipeline_test_verilator-library",
    deps = [":sv-library"],
    )

# This rule will run the entire verilator test (build + test)
sv_verilator_test(
    name = "pipeline_test_verilator-test",
    top = ":pipeline_test_verilator.sv",
    cpp = ":sim-main-cpp-gen-pipeline_test_verilator",
    deps = [":pipeline_test_verilator-library"],
    )

## pipeline_test_verilator regression:
depths = [0, 1, 2, 3]
[sv_verilator_test(
    name = "pipeline_test_verilator-test-depth{}".format(d),
    tags = ["parameter_regression"],
    top = ":pipeline_test_verilator.sv",
    cpp = ":sim-main-cpp-gen-pipeline_test_verilator",
    deps = [":pipeline_test_verilator-library"],
    defines = ["DEPTH={}".format(d)],
    ) for d in depths]
