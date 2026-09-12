load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "QwengramHistoryStorage",
    module_name = "QwengramHistoryStorage",
    srcs = glob(["*.swift"]),
    copts = ["-warnings-as-errors"],
    deps = ["//submodules/Postbox:Postbox"],
    visibility = ["//visibility:public"],
)
