-- Hyprland configuration entrypoint.
-- Keep module order explicit because some settings depend on earlier definitions.
require("modules.monitors")
require("modules.env")
require("modules.autostart")
require("modules.appearance")
require("modules.animations")
require("modules.layouts")
require("modules.input")
require("modules.misc")
require("modules.binds")
require("modules.rules")
