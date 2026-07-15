SMODS.Atlas {
    key = "ioigtec", -- code key
    path = --[[ <mod root>/assets/{1x,2x}/ ]] "ioigtec.png", -- atlas name
    px = 71, -- sprite width in 1x size
    py = 95  -- height
}

local function most_played_hand()
    local hand, tally = nil, -1

    if not G.GAME or not G.GAME.hands or not G.handlist then
        return hand, tally
    end

    for _, hand_name in ipairs(G.handlist) do
        local hand_data = G.GAME.hands[hand_name]

        if hand_data and hand_data.visible and hand_data.played > tally then
            hand = hand_name
            tally = hand_data.played
        end
    end

    return hand, tally
end

SMODS.Joker {
    key = "avalanche", -- joker name in code
    loc_txt = {
        name = "Avalanche", -- Joker name
        text = {
            "Gains {C:mult}+#1#{} Mult",
            "when {C:attention}Blind{} is completed",
            "{C:inactive}(Currently {C:mult}+#2#{C:inactive} Mult)"
            -- https://github.com/Steamodded/examples/blob/master/Mods/JokerExamples/ModdedVanilla.lua
        }
    },
    config = { -- Store card variables
        extra = {
            mult = 3,
            accumulated = 3
        }
    },
    loc_vars = function(self, info_queue, card)
        return { vars = { card.ability.extra.mult, card.ability.extra.accumulated } } -- vars #1 fills in #1#, #2 = #2# etc
    end,
    rarity = 3, -- common, uncommon, rare, legendary
    atlas = "ioigtec",
    pos = { x = 1, y = 0 }, -- atlas position
    cost = 7,
    calculate = function(self, card, context)
        card.ability.extra.accumulated = card.ability.extra.accumulated or 0

        if context.joker_main then
            return {
                mult = card.ability.extra.accumulated
            }
        end

        if context.end_of_round and context.cardarea == G.jokers and not context.blueprint then
            card.ability.extra.accumulated = card.ability.extra.accumulated + card.ability.extra.mult

            return {
                message = localize('k_upgrade_ex'),
                colour = G.C.MULT
            }
        end
    end
}

SMODS.Consumable {
    key = "divinity",
    set = "Spectral",
    hidden = true,
    soul_rate = 0.004,
    soul_set = "Spectral",
    loc_txt = {
        name = "Divinity",
        text = {
            "For every time your",
            "most played {C:attention}poker hand{}",
            "has been played, roll a",
            "{C:green}#1# in #2#{} chance to level it up"
        }
    },
    config = {
        extra = {
            odds = 3
        }
    },
    loc_vars = function(self, info_queue, card)
        local odds = card and card.ability and card.ability.extra and card.ability.extra.odds or self.config.extra.odds

        return {
            vars = {
                G.GAME and G.GAME.probabilities and G.GAME.probabilities.normal or 1,
                odds
            }
        }
    end,
    atlas = "ioigtec",
    pos = { x = 2, y = 0 },
    can_use = function(self, card)
        local hand, played = most_played_hand()
        return hand and played > 0
    end,
    use = function(self, card, area, copier)
        local used_consumable = copier or card
        local hand, played = most_played_hand()
        local odds = card.ability.extra and card.ability.extra.odds or self.config.extra.odds

        if not hand or played <= 0 then
            return
        end

        local levels = 0

        for i = 1, played do
            if SMODS.pseudorandom_probability(used_consumable, "divinity" .. i, 1, odds, "Divinity") then
                levels = levels + 1
            end
        end

        card_eval_status_text(used_consumable, "extra", nil, nil, nil, {
            message = levels .. "/" .. played,
            colour = levels > 0 and G.C.SECONDARY_SET.Spectral or G.C.RED
        })

        if levels > 0 then
            update_hand_text({ sound = "button", volume = 0.7, pitch = 0.8, delay = 0.3 }, {
                handname = localize(hand, "poker_hands"),
                chips = G.GAME.hands[hand].chips,
                mult = G.GAME.hands[hand].mult,
                level = G.GAME.hands[hand].level,
            })
            level_up_hand(used_consumable, hand, false, levels)
            update_hand_text(
                { sound = "button", volume = 0.7, pitch = 1.1, delay = 0 },
                { mult = 0, chips = 0, handname = "", level = "" }
            )
        else
            card_eval_status_text(used_consumable, "extra", nil, nil, nil, {
                message = localize("k_nope_ex"),
                colour = G.C.SECONDARY_SET.Spectral
            })
        end
    end
}

SMODS.Joker {
    key = "hoarder",
    loc_txt = {
        name = "Hoarder",
        text = {
            "Each {C:attention}Enhanced{} card",
            "held in hand gives",
            "{C:mult}+#1#{} Mult"
        }
    },
    config = {
        extra = {
            mult = 5
        }
    },
    loc_vars = function(self, info_queue, card)
        return {
            vars = {
                card.ability.extra.mult
            }
        }
    end,
    rarity = 3,
    atlas = "ioigtec",
    pos = { x = 0, y = 0 },
    cost = 6,
    calculate = function(self, card, context)
        if context.individual and context.cardarea == G.hand and context.other_card and
            not context.repetition and not context.end_of_round and not context.retrigger_joker_check then
            if not next(SMODS.get_enhancements(context.other_card)) then
                return
            end

            if context.other_card.debuff then
                return {
                    message = localize('k_debuffed'),
                    colour = G.C.RED,
                    card = card
                }
            end

            return {
                mult = card.ability.extra.mult,
                card = card
            }
        end
    end
}

SMODS.Joker {
    key = "robin_hood",
    loc_txt = {
        name = "Robin Hood",
        text = {
            "Each scored {C:attention}face card{}",
            "adds {X:mult,C:white}X#2#{} Mult",
            "to this Joker, then is",
            "{C:attention}destroyed{} after scoring",
            "{C:inactive}(Currently {X:mult,C:white}X#1#{C:inactive} Mult)"
        }
    },
    config = {
        extra = {
            destroyed = 1,
            gain = 1.75
        }
    },
    loc_vars = function(self, info_queue, card)
        return {
            vars = {
                card.ability.extra.destroyed,
                card.ability.extra.gain
            }
        }
    end,
    rarity = 4,
    atlas = "ioigtec",
    pos = { x = 3, y = 0 },
    soul_pos = { x = 4, y = 0 },
    cost = 20,
    calculate = function(self, card, context)
        card.ability.extra.destroyed = card.ability.extra.destroyed or 1

        if context.before and context.scoring_hand and not context.blueprint then
            local destroyed = 0

            for _, scoring_card in ipairs(context.scoring_hand) do
                if scoring_card:is_face() then
                    destroyed = destroyed + 1
                end
            end

            if destroyed > 0 then
                card.ability.extra.destroyed = card.ability.extra.destroyed + destroyed * card.ability.extra.gain

                return {
                    message = localize('k_upgrade_ex'),
                    colour = G.C.MULT
                }
            end
        end

        if context.destroying_card and context.cardarea == G.play and not context.blueprint then
            if context.destroying_card:is_face() then
                return {
                    remove = true
                }
            end
        end

        if context.joker_main and card.ability.extra.destroyed > 0 then
            return {
                x_mult = card.ability.extra.destroyed
            }
        end
    end
}

SMODS.Joker {
    key = "retransmit",
    loc_txt = {
        name = "Retransmit",
        text = {
            "Each scored card has a",
            "{C:green}#1# in #2#+n{} chance to",
            "{C:attention}retrigger{}, increasing {C:attention}n{}",
            "by {C:attention}1{} until a roll fails",
            "{C:inactive}(n starts at 0)"
        }
    },
    config = {
        extra = {
            odds = 2
        }
    },
    loc_vars = function(self, info_queue, card)
        return {
            vars = {
                G.GAME and G.GAME.probabilities and G.GAME.probabilities.normal or 1,
                card.ability.extra.odds
            }
        }
    end,
    rarity = 2,
    atlas = "ioigtec",
    pos = { x = 5, y = 0 },
    cost = 8,
    calculate = function(self, card, context)
        if context.repetition and context.cardarea == G.play and context.other_card then
            local repetitions = 0
            local odds = card.ability.extra.odds
            local seed = "retransmit" .. (context.other_card.sort_id or 0) .. "_"

            while SMODS.pseudorandom_probability(card, seed .. odds, 1, odds, "Retransmit") do
                repetitions = repetitions + 1
                odds = odds + 1
            end

            if repetitions > 0 then
                return {
                    message = localize("k_again_ex"),
                    repetitions = repetitions,
                    card = card
                }
            end
        end
    end
}
