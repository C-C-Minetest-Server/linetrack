-- linetracks/src/common.lua
-- Common functions
-- Copyright (C) ?  (c) orwell96 and contributors
-- Copyright (C) 2025  1F616EMO
-- SPDX-License-Identifier: LGPL-2.1-or-later

for _, mod in ipairs({
    "luaautomation",
    "line_automation",
    "interlocking",
}) do
    linetrack["use_" .. mod] = false

    if core.settings:get_bool("linetracks_use_" .. mod, true) then
        if core.get_modpath("advtrains_" .. mod) then
            linetrack["use_" .. mod] = true
        else
            core.log("warning",
                "[linetracks] " .. mod .. " support requestsed but advtrains_" .. mod " is not enabled.")
        end
    end
end

linetrack.register_wagon = advtrains.register_wagon
if core.global_exists("advtrains_attachment_offset_patch") then
    linetrack.register_wagon = function(name, wagon, ...)
        advtrains_attachment_offset_patch.setup_advtrains_wagon(wagon)
        for _, seat in pairs(wagon.seats) do
            seat.view_offset = nil
        end
        return advtrains.register_wagon(name, wagon, ...)
    end
end
