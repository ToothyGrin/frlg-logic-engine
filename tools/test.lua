-- Run from the project root: lua tools/test.lua
require("tests.world_test")
require("tests.warp_links_test")
require("tests.state_test")
require("tests.traversal_test")
require("tests.reachability_test")
require("tests.world_data_test")
require("tests.cerulean_gates_test")
require("tests.phase2_snapshots_test")
require("tests.encounters_test")
require("tests.acquisitions_test")
require("tests.choices_test")

print("All Lua tests passed.")
