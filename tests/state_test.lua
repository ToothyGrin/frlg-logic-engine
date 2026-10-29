local State = require("logic.state")

local function test_capability_requirements()
    local moves = {
        {badge = "state_has_cascade_badge", hm = "state_has_hm01_cut", capability = "state_can_cut"},
        {badge = "state_has_soul_badge", hm = "state_has_hm03_surf", capability = "state_can_surf"},
    }

    for _, move in ipairs(moves) do
        for _, has_badge in ipairs({false, true}) do
            for _, has_hm in ipairs({false, true}) do
                local player = {}
                player[move.badge] = has_badge
                player[move.hm] = has_hm
                local state = State.evaluate(player)
                assert(
                    state[move.capability] == (has_badge and has_hm),
                    move.capability .. " must require both its badge and HM"
                )
            end
        end
    end
end

local function test_missing_and_invalid_flags()
    local missing = State.evaluate({})
    assert(missing.state_can_cut == false, "Missing Cut facts should mean unavailable")
    assert(missing.state_can_surf == false, "Missing Surf facts should mean unavailable")
    assert(missing.state_event_brock_defeated == false, "Missing story facts should be false")

    for _, value in ipairs({"true", 1, 0, {}}) do
        local state = State.evaluate({
            state_has_cascade_badge = value,
            state_has_hm01_cut = true,
            state_has_soul_badge = true,
            state_has_hm03_surf = value,
            state_event_brock_defeated = value,
        })
        assert(state.state_can_cut == false, "Nonboolean badge values must not enable Cut")
        assert(state.state_can_surf == false, "Nonboolean HM values must not enable Surf")
        assert(state.state_event_brock_defeated == false, "Story flags must also require true")
    end
end

local function test_capabilities_cannot_be_overridden()
    local forced = State.evaluate({state_can_cut = true, state_can_surf = true})
    assert(forced.state_can_cut == false, "A supplied Cut capability must not bypass its facts")
    assert(forced.state_can_surf == false, "A supplied Surf capability must not bypass its facts")

    local inventory = State.evaluate({
        state_has_cascade_badge = true,
        state_has_soul_badge = true,
        state_has_hm01_cut = true,
        state_has_hm03_surf = true,
    })
    assert(inventory.state_can_cut, "HM01 and Cascade Badge must enable Cut without party facts")
    assert(inventory.state_can_surf, "HM03 and Soul Badge must enable Surf without party facts")

    local moves = State.evaluate({
        state_has_cascade_badge = true,
        state_has_soul_badge = true,
        state_has_hm01_cut = true,
        state_has_hm03_surf = true,
        state_can_cut = false,
        state_can_surf = false,
    })
    assert(moves.state_can_cut, "A supplied false capability must not override valid facts")
    assert(moves.state_can_surf, "A supplied false capability must not override valid facts")
end

local function test_independent_capabilities_and_events()
    local state = State.evaluate({
        state_has_cascade_badge = true,
        state_has_hm03_surf = true,
        state_delivered_oaks_parcel = true,
        state_event_brock_defeated = true,
    })
    assert(state.state_can_cut == false, "HM03 must not satisfy the HM01 requirement")
    assert(state.state_can_surf == false, "The Cascade Badge must not satisfy Surf's badge requirement")
    assert(state.state_delivered_oaks_parcel, "Parcel delivery must pass through")
    assert(state.state_event_brock_defeated, "Brock's event must pass through")

    local badge_only = State.evaluate({state_has_boulder_badge = true})
    assert(badge_only.state_event_brock_defeated == false, "A badge must not imply the separate Brock event")
end

local function test_recalculation_and_input_preservation()
    local player = {
        state_has_cascade_badge = true,
        state_has_soul_badge = true,
        state_has_hm01_cut = true,
        state_has_hm03_surf = true,
    }
    local before = State.evaluate(player)
    assert(player.state_can_cut == nil, "Evaluation must not add derived flags to its input")
    assert(player.state_has_cascade_badge == true, "Evaluation must preserve authoritative facts")

    player.state_has_hm01_cut = false
    player.state_has_soul_badge = false
    local after = State.evaluate(player)
    assert(after.state_can_cut == false, "Removing an HM must remove its capability")
    assert(after.state_can_surf == false, "Removing a badge must remove its capability")
    assert(before.state_can_cut and before.state_can_surf, "Earlier results must remain unchanged")

    after.state_has_cascade_badge = false
    assert(player.state_has_cascade_badge, "Changing evaluated facts must not alter the player input")
end

local function test_party_facts_are_irrelevant()
    local with_inventory = State.evaluate({
        state_has_cascade_badge = true,
        state_has_soul_badge = true,
        state_has_hm01_cut = true,
        state_has_hm03_surf = true,
        state_party_knows_cut = false,
        state_party_knows_surf = false,
    })
    assert(with_inventory.state_can_cut, "Party knowledge must not block Cut when HM and badge are acquired")
    assert(with_inventory.state_can_surf, "Party knowledge must not block Surf when HM and badge are acquired")

    local without_inventory = State.evaluate({
        state_has_cascade_badge = true,
        state_has_soul_badge = true,
        state_party_knows_cut = true,
        state_party_knows_surf = true,
    })
    assert(without_inventory.state_can_cut == false, "Party knowledge must not replace HM01")
    assert(without_inventory.state_can_surf == false, "Party knowledge must not replace HM03")
end

local function test_invalid_player_state()
    local ok, message = pcall(State.evaluate, "invalid")
    assert(not ok, "Player state must be a table")
    assert(type(message) == "string", "Invalid input must produce a string error")
    assert(string.find(message, "Player state must be a table", 1, true), "Unexpected error: " .. message)
end

test_capability_requirements()
test_missing_and_invalid_flags()
test_capabilities_cannot_be_overridden()
test_independent_capabilities_and_events()
test_recalculation_and_input_preservation()
test_party_facts_are_irrelevant()
test_invalid_player_state()

print("Player state evaluation tests passed.")
