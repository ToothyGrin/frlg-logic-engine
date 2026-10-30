local Choices = require("logic.choices")
local State = {}

-- Only supported authoritative facts are copied; capabilities are always derived.
local input_ids = {
    "state_has_cascade_badge",
    "state_has_soul_badge",
    "state_has_hm01_cut",
    "state_has_hm03_surf",
    "state_has_old_rod",
    "state_has_good_rod",
    "state_has_super_rod",
    "state_has_coin_case",
    "state_event_oak_ready_for_starter",
    "state_event_mt_moon_miguel_defeated",
    "state_event_oaks_parcel_delivered",
    "state_event_brock_defeated",
    "state_event_ss_ticket_acquired",
    "state_event_cerulean_cave_guard_cleared",
}

function State.evaluate(player, world)
    assert(type(player) == "table", "Player state must be a table")

    local state = {}

    for _, id in ipairs(input_ids) do
        state[id] = player[id] == true
    end

    -- D031: tracker policy uses HM ownership and the matching badge, without party checks.
    state.state_can_cut = state.state_has_cascade_badge
        and state.state_has_hm01_cut

    state.state_can_surf = state.state_has_soul_badge
        and state.state_has_hm03_surf

    state.choices = Choices.normalize(world, player.choices)
    state.starter_choice = Choices.starter_identity(state.choices)
    return state
end

return State
