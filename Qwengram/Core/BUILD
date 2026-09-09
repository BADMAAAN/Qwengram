load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "QwengramCore",
    module_name = "QwengramCore",
    srcs = glob([
        "**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    visibility = [
        "//visibility:public",
    ],
)
