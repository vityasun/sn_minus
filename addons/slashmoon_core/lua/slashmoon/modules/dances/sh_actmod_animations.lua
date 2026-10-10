-- Written for: SlashMoon. By: VIKA & Ronni
local MODULE = SlashMoon.Modules.Get("dances")

-- Manual ActMod-compatible registrations.
-- Uncomment and edit entries only for animation packs installed on the server.
-- Nothing in this file is auto-discovered.

local function RegisterManualActModAnimations()
    if not SlashMoon.Dances or not SlashMoon.Dances.RegisterActModAnimation then return end

    -- Example:
    -- SlashMoon.Dances.RegisterActModAnimation("gato_nightmail", {
    --     name = "Nightmail",
    --     seq = "amod_gatopack_nightmail",
    --     free = false,
    --     duration = 7.2,
    --     movement = {
    --         type = 3,
    --         speed = 100,
    --         static = "amod_gatopack_nightmail",
    --         walk = "amod_gatopack_nightmail"
    --     },
    --     cycle = 0,
    --     repeatCycle = 0,
    --     rate = 1,
    --     loop = true,
    --     music = "music/nightmail.ogg"
    -- })

    -- Or paste an ActMod pack entry directly:
    -- SlashMoon.Dances.RegisterActModEntry("gato_nightmail", {
    --     Config = { Anim = "amod_gatopack_nightmail", Name = "Nightmail", Repeat = true },
    --     Custom = { Anim = { Time1 = 7.2, Time2 = 7.2, Cycle = 0 } },
    --     Sounds = { Start = { Sound = "music/nightmail.ogg" } }
    -- })

    local gatoAnimations = {
        ["invincible_wobble"] = {seq="amod_gatopack_invincible_wobble_animation",name="Invincible Wobble",duration=11,music="music/invincible_wobble.ogg",repeatMusic="music/invincible_wobble.ogg", movement={type=1,speed=300,static="amod_gatopack_invincible_wobble_animation",walk="amod_gatopack_invincible_wobble_animation"}},
        ["nightmail"] = {seq="amod_gatopack_nightmail",name="Nightmail",duration=7.2,music="music/nightmail.ogg",repeatMusic="music/nightmail.ogg"},
        ["walkin"] = {seq="amod_gatopack_walkin",name="Walkin'",duration=0.8,music="music/walkin.ogg",repeatMusic="music/walkin.ogg",movement={type=3,speed=100,static="amod_gatopack_walkin",walk="amod_gatopack_walkin"}},
        ["trollface_groove"] = {seq="amod_gatopack_trollface_groove",name="Trollface Groove",duration=0.7,repeatDuration=45,music="music/troll_start.ogg",repeatMusic="music/troll_loop.ogg"},
        ["stormtrooper_dance"] = {seq="amod_gatopack_stormtrooper_dance",name="Stormtrooper Dance",duration=0.416,music="music/stormtrooper.ogg",repeatMusic="music/stormtrooper.ogg"},
        ["shoo_wop"] = {seq="amod_gatopack_shoo_wop",name="Ain't no lovin' my man",duration=3.91,music="music/shoo_wop.ogg",repeatMusic="music/shoo_wop.ogg"},
        ["shimmy_ay"] = {seq="amod_gatopack_shimmy_ay",name="Shimmy Shimmy ay",duration=7.36,music="music/shimmy_ay.ogg",repeatMusic="music/shimmy_ay.ogg"},
        ["stuntin"] = {seq="amod_gatopack_stuntin",name="Stuntin'",duration=7.18,music="music/stuntin.ogg",repeatMusic="music/stuntin.ogg"},
        ["kwik_flip"] = {seq="amod_gatopack_kwik_flip",name="Kwik Flip",duration=1.58,music="music/kwik_flip.ogg",repeatMusic="music/kwik_flip.ogg"},
        ["kwik_flip_censored"] = {seq="amod_gatopack_kwik_flip",name="Kwik Flip (No swear words)",duration=1.58,music="music/kwik_flip_censored.ogg",repeatMusic="music/kwik_flip_censored.ogg"},
        ["bang_bang"] = {seq="amod_gatopack_bang_bang",name="Bang Bang",duration=0.9,music="music/bang_bang.ogg",repeatMusic="music/bang_bang.ogg"},
        ["superstar_l"] = {seq="amod_gatopack_superstar_l",name="Superstar L",duration=1.76,cycle=0.33,music="music/superstar_start.ogg",repeatMusic="music/superstar_loop.ogg"},
        ["superstar_m"] = {seq="amod_gatopack_superstar_m",name="Superstar M",duration=1.76,cycle=0.33,music="music/superstar_start.ogg",repeatMusic="music/superstar_loop.ogg"},
        ["mourning"] = {seq="amod_gatopack_mourning",name="Mourning",duration=5.2,music="music/mourning.ogg",repeatMusic="music/mourning.ogg"},
        ["pump_it_up"] = {seq="amod_gatopack_pump_it_up",name="Pump it up",duration=5.98,music="music/pump_it_up.ogg",repeatMusic="music/pump_it_up.ogg"},
        ["lost_media_1"] = {seq="amod_gatopack_lost_media_1",name="You found lost media! 1",duration=7.73,music="music/lost_media.ogg",repeatMusic="music/lost_media.ogg"},
        ["lost_media_2"] = {seq="amod_gatopack_lost_media_2",name="You found lost media! 2",duration=7.73,music="music/lost_media.ogg",repeatMusic="music/lost_media.ogg"},
        ["lost_media_3"] = {seq="amod_gatopack_lost_media_3",name="You found lost media! 3",duration=7.73,music="music/lost_media.ogg",repeatMusic="music/lost_media.ogg"},
        ["reddit_phonk"] = {seq="amod_gatopack_reddit_phonk",name="Reddit Phonk",duration=8.16,music="music/reddit_phonk.ogg",repeatMusic="music/reddit_phonk.ogg"},
        ["street_dance"] = {seq="amod_gatopack_street_dance",name="Street dance",duration=12,music="music/street_dance.ogg",repeatMusic="music/street_dance.ogg"},
        ["naoya_party"] = {seq="amod_gatopack_naoya_party",name="Naoya party",duration=0.73,repeatDuration=27.1,music="music/naoya_party_start.ogg",repeatMusic="music/naoya_party_loop.ogg"},
        ["dante_trigger"] = {seq="amod_gatopack_dante_trigger",name="Dante trigger",duration=0.76,music="music/devil_trigger.ogg",repeatMusic="music/devil_trigger.ogg"},
        ["nero_trigger"] = {seq="amod_gatopack_nero_trigger",name="Nero trigger",duration=0.76,music="music/devil_trigger.ogg",repeatMusic="music/devil_trigger.ogg"},
        ["lonely"] = {seq="amod_gatopack_lonely",name="Lonely",duration=3.7,music="music/lonely.ogg",repeatMusic="music/lonely.ogg"},
        ["stuck_in_my_head"] = {seq="amod_gatopack_stuck_in_my_head",name="Stuck in my head",duration=29.5,music="music/stuck_in_my_head.ogg",repeatMusic="music/stuck_in_my_head.ogg"},
        ["moonwalk"] = {seq="amod_gatopack_moonwalk",name="Moonwalk",duration=2.73,cycle=0.33,music="music/moonwalk.ogg",repeatMusic="music/moonwalk.ogg",movement={type=1,speed=-75}},
        ["grounded"] = {seq="amod_gatopack_goanimate",name="You're Grounded!",duration=0.93,repeatDuration=191,music="music/grounded_start.ogg",repeatMusic="music/grounded_loop.ogg"},
        ["danxfnaf_celebration"] = {seq="amod_gatopack_danxfnaf",name="DanXFnaf's Celebration",duration=0.8,music="music/danxfnaf_celebration.ogg",repeatMusic="music/danxfnaf_celebration.ogg",movement={type=3,speed=50,static="amod_gatopack_danxfnaf",walk="amod_gatopack_danxfnaf"}},
        ["peanut_butter_jelly_time"] = {seq="amod_gatopack_peanut_butter_jelly_time",name="Peanut Butter Jelly Time",duration=0.8,repeatDuration=68.6,music="music/peanut_butter_jelly_time_start.ogg",repeatMusic="music/peanut_butter_jelly_time_loop.ogg"},
        ["mii_maker"] = {seq="amod_gatopack_mii_maker",name="Mii Maker",duration=0.8,music="music/mii_maker.ogg",repeatMusic="music/mii_maker.ogg"},
        ["creepy_run_shaggy"] = {seq="amod_gatopack_creepy_run_shaggy_idle",name="Creepy Run Shaggy",duration=0.4,music="music/creepy_run.ogg",repeatMusic="music/creepy_run.ogg",movement={type=3,speed=250,static="amod_gatopack_creepy_run_shaggy_idle",walk="amod_gatopack_creepy_run_shaggy"}},
        ["creepy_run_skeleton"] = {seq="amod_gatopack_creepy_run_skeleton_idle",name="Creepy Run Skeleton",duration=0.48,music="music/creepy_run.ogg",repeatMusic="music/creepy_run.ogg",movement={type=3,speed=250,static="amod_gatopack_creepy_run_skeleton_idle",walk="amod_gatopack_creepy_run_skeleton"}},
        ["last_tour_1"] = {seq="amod_gatopack_last_tour_1",name="Last tour 1",duration=15,music="music/last_tour.ogg",repeatMusic="music/last_tour.ogg"},
        ["last_tour_2"] = {seq="amod_gatopack_last_tour_2",name="Last tour 2",duration=15,music="music/last_tour.ogg",repeatMusic="music/last_tour.ogg"},
        ["gang_dance"] = {seq="amod_gatopack_gang_dance",name="Gangstar torture dance",duration=17.9,repeatDuration=8.9,cycle=0.5,music="music/gangstar_torture_dance_start.ogg",repeatMusic="music/gangstar_torture_dance_loop.ogg"},
        ["aura_monster"] = {seq="amod_gatopack_aura_monster",name="Aura Monster",duration=2.13,cycle=0.33,music="music/aura_monster_quote.ogg",repeatMusic="music/aura_monster.ogg",movement={type=1,speed=75}},
        ["competent"] = {seq="amod_gatopack_competent",name="Competent",duration=7.23,repeatDuration=3.46,cycle=0.61,music="music/competent_intro.ogg",repeatMusic="music/competent_loop.ogg"},
        ["mj_lean"] = {seq="amod_gatopack_michael_jackson_lean",name="MJ's Lean",loop=false,music="music/mj_lean.ogg",repeatMusic="music/mj_lean.ogg"},
        ["dj_jig"] = {seq="amod_gatopack_dj_jig",name="DJ Jig",duration=3.4,music="music/dj_jig.ogg",repeatMusic="music/dj_jig.ogg"},
        ["the_prank"] = {seq="amod_gatopack_the_prank",name="The Prank",duration=3.8,music="music/the_prank.ogg",repeatMusic="music/the_prank.ogg"},
        ["hai_yorokonde"] = {seq="amod_gatopack_hai_yorokonde",name="Hai Yorokonde",duration=13.1,music="music/hai_yorokonde.ogg",repeatMusic="music/hai_yorokonde.ogg"},
        ["my_time"] = {seq="amod_gatopack_my_time",name="My Time",duration=3.6,music="music/my_time.ogg",repeatMusic="music/my_time.ogg"},
        ["giga_shake"] = {seq="amod_gatopack_giga_shake",name="Attack of the Giga Shake",duration=25.5,music="music/giga_shake.ogg",repeatMusic="music/giga_shake.ogg"},
        ["virtual_insanity"] = {seq="amod_gatopack_virtual_insanity",name="Virtual Insanity",duration=12,repeatDuration=3.76,cycle=0.68,music="music/virtual_insanity.ogg",repeatMusic="music/virtual_insanity.ogg",movement={type=3,speed=25}},
        ["chicken_dance"] = {seq="amod_gatopack_chicken_dance",name="Chicken Dance",duration=6.88,music="music/chicken_dance.ogg",repeatMusic="music/chicken_dance.ogg"},
        ["chronoshift"] = {seq="amod_gatopack_chronoshift",name="Chronoshift",duration=14.75,music="music/chronoshift.ogg",repeatMusic="music/chronoshift.ogg"},
        ["chronoshift_remix"] = {seq="amod_gatopack_chronoshift",name="Chronoshift Remix",duration=14.75,music="music/chronoshift_remix.ogg",repeatMusic="music/chronoshift_remix.ogg"},
        ["animals_of_the_farm"] = {seq="amod_gatopack_animals_of_the_farm",name="?",duration=24.58,music="music/animals_of_the_farm.ogg",repeatMusic="music/animals_of_the_farm.ogg"},
        ["looping_the_rooms"] = {seq="amod_gatopack_looping_the_rooms",name="Looping the rooms",duration=23.73,music="music/looping_the_rooms.ogg",repeatMusic="music/looping_the_rooms.ogg"},
        ["birdy_bunnie"] = {seq="amod_gatopack_birdy_bunnie",name="Birdy Bunnie",duration=2.33,music="music/birdy_bunnie.ogg",repeatMusic="music/birdy_bunnie.ogg",movement={type=3,speed=25}},
        ["side_step"] = {seq="amod_gatopack_side_step",name="Side Step",duration=1.66,music="music/side_step_start.ogg",repeatMusic="music/side_step_loop.ogg"},
        ["dai_dai_dai_kirai"] = {seq="amod_gatopack_dai_dai_dai_kirai",name="Dai dai dai kirai",duration=15.06,repeatDuration=13.84,cycle=0.0774,music="music/dai_dai_dai_kirai_intro.ogg",repeatMusic="music/dai_dai_dai_kirai_loop.ogg"},
        ["tetra"] = {seq="amod_gatopack_tetra",name="You're just like pop music",duration=1,music="music/tetra_dance_intro.ogg",repeatMusic="music/tetra_dance_loop.ogg"},
        ["mailbox_1"] = {seq="amod_gatopack_mailbox_1",name="Mailbox (Sonic)",duration=0.73,music="music/mailbox_intro.ogg",repeatMusic="music/mailbox_loop.ogg"},
        ["mailbox_2"] = {seq="amod_gatopack_mailbox_2",name="Mailbox (Tails)",duration=0.73,music="music/mailbox_intro.ogg",repeatMusic="music/mailbox_loop.ogg"},
        ["gang_flex"] = {seq="amod_gatopack_gang_flex",name="Gang flex",duration=0.5,music="music/gang_flex_intro.ogg",repeatMusic="music/gang_flex_loop.ogg"},
        ["muffin_time"] = {seq="amod_gatopack_muffin_time",name="Muffin time",duration=17.86,repeatDuration=17.21,cycle=0.033,music="music/muffin_time_intro.ogg",repeatMusic="music/muffin_time_loop.ogg"}
    }

    for id, data in pairs(gatoAnimations) do
        SlashMoon.Dances.RegisterActModAnimation(id, data)
    end
end

MODULE:Hook("InitPostEntity", "SN_ActModManualRegistrations", RegisterManualActModAnimations)
RegisterManualActModAnimations()

-- Gato pack examples:
-- amod_gatopack_invincible_wobble_animation, duration = 11
-- amod_gatopack_walkin, duration = 0.8
-- amod_gatopack_trollface_groove, duration = 0.7
-- amod_gatopack_stormtrooper_dance, duration = 0.416
-- amod_gatopack_superstar_l, duration = 1.76, cycle = 0.33
-- amod_gatopack_superstar_m, duration = 1.76, cycle = 0.33
