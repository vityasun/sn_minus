-- Written for: SlashMoon. By: VIKA & Ronni

SlashMoon.Tasks = SlashMoon.Tasks or {}
SlashMoon.Tasks.Config = SlashMoon.Tasks.Config or {}

-- "fh" uses Fazbear's Hunt lifecycle. "standalone" uses SN's state machine.
SlashMoon.Tasks.Config.CompatibilityMode = SlashMoon.Tasks.Config.CompatibilityMode or "fh"
SlashMoon.Tasks.Config.Teams = SlashMoon.Tasks.Config.Teams or {
    survivor = TEAM_SURVIVOR or 2700,
    animatronic = TEAM_PILLS or 2701,
    editor = SlashMoon.TEAM_EDITOR or 2703,
    spectator = TEAM_SPECTATOR,
}

SlashMoon.Tasks.Config.Standalone = SlashMoon.Tasks.Config.Standalone or {
    prepareTime = 10,
    endTime = 10,
    minPlayers = 1,
}

if SlashMoon.Tasks.Config.CompatibilityMode == "standalone" then
    TEAM_SURVIVOR = TEAM_SURVIVOR or SlashMoon.Tasks.Config.Teams.survivor
    TEAM_PILLS = TEAM_PILLS or SlashMoon.Tasks.Config.Teams.animatronic
    SlashMoon.TEAM_EDITOR = SlashMoon.TEAM_EDITOR or SlashMoon.Tasks.Config.Teams.editor
    if not SlashMoon.Tasks.Config.Teams.spectator then
        SlashMoon.Tasks.Config.Teams.spectator = TEAM_SPECTATOR or TEAM_UNASSIGNED
    end

    team.SetUp(SlashMoon.Tasks.Config.Teams.survivor, "Survivors", Color(84, 163, 255))
    team.SetUp(SlashMoon.Tasks.Config.Teams.animatronic, "Opponents", Color(220, 70, 70))
    team.SetUp(SlashMoon.Tasks.Config.Teams.editor, "Editor", Color(120, 220, 160))
end
