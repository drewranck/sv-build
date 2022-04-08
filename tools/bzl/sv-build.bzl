load("@sv_build//tools/verilator:verilator.bzl", "VERILATOR_FLAGS")
load("@sv_build//tools/verilator:verilator.bzl", "get_str_dotf_cmd_bash_verilator")
load("@sv_build//tools/verilator:verilator.bzl", "sim_main_cpp_generator")

load("@bazel_skylib//lib:selects.bzl", "selects")

# TODO(drewranck): wishful thinking, I only support "verilator" for now.
SV_SIMULATORS = [
    "verilator",
    "modelsim_ase",
    #"modelsim", # same as Questa
    #"questa",
    #"dsim",
]


# Some "select" shortnames for easier reading:
kDEFAULT = "//conditions:default"
kVERILATOR_DEBUG = "@sv_build//tools/bzl:cfg_verilator_debug"



def sv_glob_filegroup(name, **kwargs):
    """ Filegroup target (build): created by globbing all the .svh, .sv, .vh, .v files."""
    native.filegroup(
        name = name,
        srcs = native.glob(["*.svh"]) + native.glob(["*.sv"])
        + native.glob(["*.vh"]) + native.glob(["*.v"]),
        **kwargs
        )


def sv_library(name, srcs=None, deps=None, data=None, **kwargs):
    """ Build target - library to hold srcs, deps, data: under the 'name' Target.

    This uses sh_library, so srcs, deps, data are completely interchangable,
    so use best practices. Try to put generated files in deps and/or data.
    """
    native.sh_library(
        name = name,
        srcs = srcs,
        deps = deps,
        data = data,
        **kwargs
        )


def sv_gen_dot_f(name, srcs=[], deps=[], **kwargs):
    """ Build target - Generate a "dot f" file to be used by an SV tool.
    args:
      name -- bazel target name
      deps -- all the source dependencies.

    In Verilator land, the .f consists of some +args, followed
    by a -y some/path of everywhere to look for .v, .sv, .vh, .svh files.

    The select statement has been tested for config_settings provided by
    @sv_build//bzl:BUILD


    """

    _fname = name + ".f"

    cmd_bash_verilator = get_str_dotf_cmd_bash_verilator(_fname)

    native.genrule(
        name = name,
        srcs = srcs + deps,
        outs = [_fname],
        cmd_bash = selects.with_or({
            kDEFAULT: cmd_bash_verilator,
            kVERILATOR_DEBUG: cmd_bash_verilator,
            })

        )


def sv_lint_test(name, top, deps, lint_flags=[], size="small", defines=[], tags=[], **kwargs):
    """ Test target - runs verilator in --lint-only mode

    Keyword arguments:
    name -- bazel target name
    top  -- the systemverilog top level module name (no .sv here)
    deps -- bazel dependency list, from an sv_library(..) rule
    lint_flags -- args passed to verilator
    size -- string, bazel test size, aka "small"
    defines -- list of SystemVerilog defines, such as [CYC_TIMEOUT=1000, ...]

    """
    _sv_lint_test_impl(name = name,
                       top = top,
                       deps = deps,
                       lint_flags = lint_flags,
                       size = size,
                       defines = defines,
                       tags = tags,
                       **kwargs)


def _sv_lint_test_impl(name, top, deps, lint_flags, tags, size, defines, **kwargs):

    dot_f_target = name + "-gen-dot-f"
    sv_gen_dot_f(
        name = dot_f_target,
        deps = deps
        )

    myargs_verilator = VERILATOR_FLAGS["lint"] + lint_flags

    for d in defines + VERILATOR_FLAGS["defines"]:
        myargs_verilator += [" +define+{}".format(d)]

    myargs_verilator += [
        " -f $(location {})".format(dot_f_target),
        " $(rootpath {})".format(top)
        ]

    # Test out if we build in cfg_dbg_verilator
    # This does show up, even though we are in a test rule.
    myargs_dbg_verilator = myargs_verilator + [" +define+SvLint_CfgDbgVerilator=Yes"]

    # Note: to get configurations to work in macros,
    # I'd have to maintain doing nothing "select" wise to manipulate
    # a variable (like myargs). So a few options:
    # 1) args: maintain myargs_verilator as tool specific, vs something like
    #    myargs_modelsim_ase. That way the fully bloated versions of
    #    each are carried around before passing to the sh_test rule.
    # 1b) for defines changes, again we'd either need the bloated lists
    #     of all combinations, or use a unique .sh that already has
    #     the defines. For example, Xilinx vs. Altera.
    # 2) It's fine to select on verilator_lint.sh vs modelsim_ase_lint.sh

    mytags = ["sv", "lint_test", "verilator"]

    native.sh_test(
        name = name,
        size = size,
        tags = tags + mytags,
        args = selects.with_or({
            kDEFAULT: myargs_verilator,
            kVERILATOR_DEBUG: myargs_dbg_verilator,
            }),
        srcs = selects.with_or({
            kDEFAULT: ["@sv_build//tools/verilator:bazel_verilator_lint.sh"],
            kVERILATOR_DEBUG: ["@sv_build//tools/verilator:bazel_verilator_lint.sh"],
            }),
        deps = deps,
        data = [top, dot_f_target],
        )



def sv_verilator_test(name, deps=[],
                      size="small",
                      tags=[],
                      top="", cpp="",
                      verilator_flags=[], run_flags=[],
                      seed=1,
                      defines=[], plusargs=[],
                      expect_fail=False,
                      verilator_binary=None,
                      **kwargs):
    """ Test target - runs verilator to build an executable and runs it.

    Keyword arguments:
    name -- bazel target name
    deps -- bazel dependency list, from an sv_library(..) rule
    size -- string, bazel test size, aka "small"
    tags -- bazel tags, passed to all test rules.
    top  -- the systemverilog src top level module file, with .sv.
    cpp  -- The (usually generated) sim_main.cpp file used by Verilator.
            see rule sim_main_cpp_generator(..)
    verilator_flags -- list of args passed to verilator invocation.
    run_flags -- list of args passed to the verialted executable invocation.
    seed -- the simulation seed provided as an argument to verilated executable.
    defines -- list of SystemVerilog defines, such as [CYC_TIMEOUT=1000, ...]
               defines are used when running verilator (building the executable).
    plusargs -- list of SystemVerilog plusargs, such as [verbosity=500, ...]
                plusargs are used when running the executable for simulation.
    expect_fail -- boolean, set to True if you expect this test should fail.
    verilator_binary -- None, or a bazel target of an already verilated
                          executable from a sv_verilator_binary(..) rule.

    sv_verilator_test is sort of a 1-step from srcs + deps to running a simulation.
    It will call sv_verilator_binary(...) (assiming keyword arg verilator_binary=False)
    and then will run the test on the binary executable.

    """
    _sv_verilator_test_impl(name = name,
                            deps = deps,
                            size = size,
                            tags = tags,
                            top = top,
                            cpp = cpp,
                            verilator_flags = verilator_flags,
                            run_flags = run_flags,
                            seed = seed,
                            defines = defines,
                            plusargs = plusargs,
                            expect_fail = expect_fail,
                            verilator_binary = verilator_binary,
                            **kwargs)


def _sv_verilator_test_impl(name, deps, size, tags,
                            top, cpp,
                            verilator_flags, run_flags,
                            seed,
                            defines, plusargs,
                            expect_fail,
                            verilator_binary=None,
                            **kwargs):

    if verilator_binary == None:
        # If we didn't bring our own binary, then we have to build one. Do that here.

        new_verilator_binary = name + "-binary"

        _sv_verilator_binary_impl(name = new_verilator_binary,
                                  tags = tags,
                                  top = top,
                                  cpp = cpp,
                                  deps = deps,
                                  verilator_flags = verilator_flags,
                                  defines = defines,
                                  **kwargs)

        # Now we should have a binary:
        verilator_binary = new_verilator_binary



    # Run the binary
    _sv_verilator_run_binary_impl(name = name,
                                  tags = tags,
                                  run_flags = run_flags,
                                  size = size,
                                  seed = seed,
                                  plusargs = plusargs,
                                  expect_fail = expect_fail,
                                  verilator_binary = verilator_binary,
                                  **kwargs)


def _sv_verilator_run_binary_impl(name, verilator_binary,
                                  size="small",
                                  tags=[],
                                  run_flags=[],
                                  seed=1, plusargs=[],
                                  expect_fail=False,
                                  **kwargs):
    """ Test target - private rule to run a verilated executable.

    Keyword arguments:
    name -- bazel target name
    verilator_binary -- A bazel target of an already verilated
                        executable from a sv_verilator_binary(..) rule.
    size -- string, bazel test size, aka "small"
    tags -- bazel tags, passed to all test rules.
    run_flags -- list of args passed to the verialted executable invocation.
    seed -- the simulation seed provided as an argument to verilated executable.
    plusargs -- list of SystemVerilog plusargs, such as [verbosity=500, ...]
                plusargs are used when running the executable for simulation.
    expect_fail -- boolean, set to True if you expect this test should fail.

    Note that the seed argument has special handling:
    -- if seed is 0, blank, None, then seed="random" which is specially handled
       by verilator_run.sh to set the binary's runtime arg +verilator+seed+(value)

    """

    runargs = VERILATOR_FLAGS["plusargs"] + run_flags

    sh_to_run = ["@sv_build//tools/verilator:bazel_verilator_run.sh"]


    if seed == "" or seed == 0 or seed == None:
        seed = 1


    for p in plusargs:
        runargs += [" +{}".format(p)]

    # The args to verilator_run.sh are:
    # <bin_exe> <expect_fail> <seed> [leftover args for verilator]
    myargs_verilator = ["$(rootpath {})".format(verilator_binary),
                        "{}".format(expect_fail),
                        "{}".format(seed)] + runargs

    # Test if we can add an arg via a configuation select:
    # This does not work, b/c config_setting changes happen at
    # Build time. To pass a plusarg, you need to use
    # bazel test :target --test_arg=+drewplusarg=hello
    myargs_dbg_verilator = myargs_verilator + [" +drewplusarg=hello_dbg_verilator"]

    mytags = ["sv", "sim_test", "verilator"]
    if expect_fail:
        mytags += ["expect_fail"]

    native.sh_test(
        name = name,
        size = size,
        tags = tags + mytags,
        args = selects.with_or({
            kDEFAULT: myargs_verilator,
            kVERILATOR_DEBUG: myargs_dbg_verilator,
            }),
        srcs = sh_to_run,
        data = selects.with_or({
            kDEFAULT: [verilator_binary],
            kVERILATOR_DEBUG: [verilator_binary],
            }),
        )


def sv_verilator_binary(name, top, cpp, deps, tags=[], verilator_flags=[],
                        defines=[],
                        **kwargs):
    _sv_verilator_binary_impl(name = name, top = top, cpp = cpp, deps = deps,
                              tags = tags,
                              verilator_flags = verilator_flags,
                              defines = defines,
                              **kwargs)

def _sv_verilator_binary_impl(name, deps, top, cpp, tags=[], verilator_flags=[],
                              defines=[],
                              **kwargs):
    """ Build target - runs verilator to build an executable, does NOT run the exec.

    Keyword arguments:
    name -- bazel target name
    deps -- bazel dependency list, from an sv_library(..) rule
    top  -- the systemverilog src top level module file, with .sv.
    cpp  -- The (usually generated) sim_main.cpp file used by Verilator.
            see rule sim_main_cpp_generator(..)
    verilator_flags -- list of args passed to verilator invocation.
    defines -- list of SystemVerilog defines, such as [CYC_TIMEOUT=1000, ...]
               defines are used when running verilator (building the executable).

    sv_verilator_binary is part of a 2-step flow, this will build the verilated exec
    """

    dot_f_target = name + "-gen-dot-f"
    sv_gen_dot_f(
        name = dot_f_target,
        deps = deps
        )

    # TODO(drew.ranck): Try to generate the 'cpp' if it was left blank by the caller.
    # This does not work yet.
    if cpp == "":
        fail("missing cpp arg (cpp={})".format(cpp))

    #    cpp_name = name + "-sim-main-cpp-gen"
    #    print("missing cpp, attempting to build it myself cpp_name={} top={}".format(cpp_name, top))

    #    sim_main_cpp_generator(
    #        name = cpp_name,
    #        srcs = [top],
    #        template = "@sv_build//tools/verilator:sim_main.cpp.template",
    #        )

    #    cpp = cpp_name
    #    print("trying cpp={}".format(cpp))

    # Verilator uses V prepended the module name as the binary output exe:
    mybin = "V" + name

    # For this "build", we're going to need two sets of "args":
    # 1) the output binary, mybin
    # 2) a file with all the compile args -- all verilator args (in list myargs)

    myargs_verilator = VERILATOR_FLAGS["build"] + verilator_flags

    for d in VERILATOR_FLAGS["defines"] + defines:
        myargs_verilator += [" +define+{}".format(d)]

    # we have to use $(execpath ...) on these locations b/c that's how
    # genrule uses them (different than a sh_test.. b/c bazel reasons).
    myargs_verilator += [
        " -f $(execpath {})".format(dot_f_target),
        " $(execpath {})".format(cpp),
        " $(execpath {})".format(top),
    ]

    myargs_verilator_flat = " ".join([str(a) for a in myargs_verilator])

    # Test out if we build in cfg_dbg_verilator
    # This DOES show up in the build, which is good.
    myargs_dbg_verilator_flat = myargs_verilator_flat
    myargs_dbg_verilator_flat += " +define+VerilatorBinary_CfgDbgVerilator=Yes"
    myargs_dbg_verilator_flat += " --debug"

    verilator_sh_to_run = ["@sv_build//tools/verilator:bazel_verilator_binary.sh"]

    # Adding sv_sim_test here b/c we only gerate the binary on those.
    mytags = ["sv",
              "verilator",
              "sim_test"]

    native.genrule(
        name = name,
        tags = tags + mytags,
        outs = [mybin],
        cmd_bash = selects.with_or({
            kDEFAULT:
            "$(location @sv_build//tools/verilator:bazel_verilator_binary.sh) "
            + "$(execpath {}) {}".format(mybin,
                                         myargs_verilator_flat),

            kVERILATOR_DEBUG:
            "$(location @sv_build//tools/verilator:bazel_verilator_binary.sh) "
            + "$(execpath {}) {}".format(mybin,
                                         myargs_dbg_verilator_flat),
            }),
        srcs = selects.with_or({
            kDEFAULT: verilator_sh_to_run + deps,
            kVERILATOR_DEBUG: verilator_sh_to_run + deps,
            }),
        tools = [top, cpp, dot_f_target]
        )
