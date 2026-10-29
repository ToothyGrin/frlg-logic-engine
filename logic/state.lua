local State = {}

-- Only supported authoritative facts are copied; capabilities are always derived.
local input_ids = {
    "state_has_cascade_badge",
    "state_has_soul_badge",
    "state_has_hm01_cut",
    "state_has_hm03_surf",
    "state_delivered_oaks_parcel",
    "state_event_brock_defeated",
}

function State.evaluate(player)
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

    return state
end

return State
