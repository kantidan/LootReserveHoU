LootReserveHoU = LootReserveHoU or { };
LootReserveHoU.Constants = { };

LootReserveHoU.Constants.MAX_RESERVES          = 99;
LootReserveHoU.Constants.MAX_MULTIRESERVES     = 99;
LootReserveHoU.Constants.MAX_RESERVES_PER_ITEM = 99;
LootReserveHoU.Constants.MAX_CHAT_STORAGE      = 25;

LootReserveHoU.Constants.ReserveResult = {
    OK                       = 0,
    NotInRaid                = 1,
    NoSession                = 2,
    NotAccepting             = 3,
    NotMember                = 4,
    ItemNotReservable        = 5,
    AlreadyReserved          = 6,
    NoReservesLeft           = 7,
    FailedConditions         = 8,
    Locked                   = 9,
    NotEnoughReservesLeft    = 10,
    MultireserveLimit        = 11,
    MultireserveLimitPartial = 12,
    FailedClass              = 13,
    FailedFaction            = 14,
    FailedLimit              = 15,
    FailedLimitPartial       = 16,
    FailedUsable             = 17,
};
LootReserveHoU.Constants.CancelReserveResult = {
    OK                = 0,
    NotInRaid         = 1,
    NoSession         = 2,
    NotAccepting      = 3,
    NotMember         = 4,
    ItemNotReservable = 5,
    NotReserved       = 6,
    Forced            = 7,
    Locked            = 8,
    InternalError     = 9,
    NotEnoughReserves = 10,
};
LootReserveHoU.Constants.OptResult = {
    OK                = 0,
    NotInRaid         = 1,
    NoSession         = 2,
    NotMember         = 4,
};
LootReserveHoU.Constants.ReserveDeltaResult = {
    NoSession         = 2,
    NotMember         = 4,
};
LootReserveHoU.Constants.ReservesSorting = {
    ByTime   = 0,
    ByName   = 1,
    BySource = 2,
    ByLooter = 3,
};
LootReserveHoU.Constants.WinnerReservesRemoval = {
    None      = 0,
    Single    = 1,
    Smart     = 2,
    All       = 3,
    Duplicate = 4,
};
LootReserveHoU.Constants.ChatReservesListLimit = {
    None = -1,
};
LootReserveHoU.Constants.ChatAnnouncement = {
    SessionStart        = 1,
    SessionResume       = 2,
    SessionStop         = 3,
    RollStartReserved   = 4,
    RollStartCustom     = 5,
    RollWinner          = 6,
    RollTie             = 7,
    SessionInstructions = 8,
    RollCountdown       = 9,
    SessionBlindToggle  = 10,
    SessionReserves     = 11,
};
LootReserveHoU.Constants.DefaultPhases = {
    "Main Spec",
    "Off Spec",
    "Collection",
    "Vendor",
};
LootReserveHoU.Constants.WonRollPhase = {
    Reserve  = 1,
    RaidRoll = 2,
};
LootReserveHoU.Constants.RollType = {
    NotRolled = 0,
    Passed    = -1,
    Deleted   = -2,
};
LootReserveHoU.Constants.LoadState = {
    NotStarted  = 0,
    Started     = 1,
    SessionDone = 2,
    Pending     = 3,
    AllDone     = 4,
};
LootReserveHoU.Constants.ClassFilenameToClassID   = { };
LootReserveHoU.Constants.ClassLocalizedToFilename = { };
LootReserveHoU.Constants.ItemQuality = {
    [-1] = "All",
    [0]  = "Junk",
    [1]  = "Common",
    [2]  = "Uncommon",
    [3]  = "Rare",
    [4]  = "Epic",
    [5]  = "Legendary",
    [6]  = "Artifact",
    [7]  = "Heirloom",
    [99] = "None",
};
LootReserveHoU.Constants.RedundantSubTypes = {
    ["Polearms"]  = "Polearm",
    ["Staves"]    = "Staff",
    ["Bows"]      = "Bow",
    ["Crossbows"] = "Crossbow",
    ["Guns"]      = "Gun",
    ["Thrown"]    = "Thrown Weapon",
    ["Wands"]     = "Wand",
    ["Relic"]     = "Relic",
    
    ["Shields"]   = "Shield",
    ["Idols"]     = "Idol",
    ["Librams"]   = "Libram",
    ["Totems"]    = "Totem",
    ["Sigils"]    = "Sigil",
};
LootReserveHoU.Constants.WeaponTypeNames = {
    ["Two-Handed Axes"]   = "Axe",
    ["One-Handed Axes"]   = "Axe",
    ["Two-Handed Swords"] = "Sword",
    ["One-Handed Swords"] = "Sword",
    ["Two-Handed Maces"]  = "Mace",
    ["One-Handed Maces"]  = "Mace",
    ["Polearms"]          = "Polearm",
    ["Staves"]            = "Staff",
    ["Daggers"]           = "Dagger",
    ["Fist Weapons"]      = "Fist Weapon",
    ["Bows"]              = "Bow",
    ["Crossbows"]         = "Crossbow",
    ["Guns"]              = "Gun",
    ["Thrown"]            = "Thrown Weapon",
    ["Wands"]             = "Wand",
};
LootReserveHoU.Constants.Genders = {
    Male   = 2,
    Female = 3,
};
LootReserveHoU.Constants.Races = {
    Human    = 1,
    Dwarf    = 3,
    Gnome    = 7,
    NightElf = 4,
    Orc      = 2,
    Troll    = 8,
    Tauren   = 6,
    Scourge  = 5,
    Draenei  = 11,
    BloodElf = 10,
    Worgen   = 22,
    Goblin   = 9,
};
LootReserveHoU.Constants.Sounds = {
    LevelUp = 1440,
    Cheer = {
        [LootReserveHoU.Constants.Races.Human]    = {[LootReserveHoU.Constants.Genders.Male] = 2677, [LootReserveHoU.Constants.Genders.Female] = 2689},
        [LootReserveHoU.Constants.Races.Dwarf]    = {[LootReserveHoU.Constants.Genders.Male] = 2725, [LootReserveHoU.Constants.Genders.Female] = 2737},
        [LootReserveHoU.Constants.Races.Gnome]    = {[LootReserveHoU.Constants.Genders.Male] = 2835, [LootReserveHoU.Constants.Genders.Female] = 2847},
        [LootReserveHoU.Constants.Races.NightElf] = {[LootReserveHoU.Constants.Genders.Male] = 2749, [LootReserveHoU.Constants.Genders.Female] = 2761},
        [LootReserveHoU.Constants.Races.Orc]      = {[LootReserveHoU.Constants.Genders.Male] = 2701, [LootReserveHoU.Constants.Genders.Female] = 2713},
        [LootReserveHoU.Constants.Races.Troll]    = {[LootReserveHoU.Constants.Genders.Male] = 2859, [LootReserveHoU.Constants.Genders.Female] = 2871},
        [LootReserveHoU.Constants.Races.Tauren]   = {[LootReserveHoU.Constants.Genders.Male] = 2797, [LootReserveHoU.Constants.Genders.Female] = 2810},
        [LootReserveHoU.Constants.Races.Scourge]  = {[LootReserveHoU.Constants.Genders.Male] = 2773, [LootReserveHoU.Constants.Genders.Female] = 2785},
        [LootReserveHoU.Constants.Races.Draenei]  = {[LootReserveHoU.Constants.Genders.Male] = 9706, [LootReserveHoU.Constants.Genders.Female] = 9681},
        [LootReserveHoU.Constants.Races.BloodElf] = {[LootReserveHoU.Constants.Genders.Male] = 9656, [LootReserveHoU.Constants.Genders.Female] = 9632},
    },
    Congratulate = {
        [LootReserveHoU.Constants.Races.Human]    = {[LootReserveHoU.Constants.Genders.Male] = 6168, [LootReserveHoU.Constants.Genders.Female] = 6141},
        [LootReserveHoU.Constants.Races.Dwarf]    = {[LootReserveHoU.Constants.Genders.Male] = 6113, [LootReserveHoU.Constants.Genders.Female] = 6104},
        [LootReserveHoU.Constants.Races.Gnome]    = {[LootReserveHoU.Constants.Genders.Male] = 6131, [LootReserveHoU.Constants.Genders.Female] = 6122},
        [LootReserveHoU.Constants.Races.NightElf] = {[LootReserveHoU.Constants.Genders.Male] = 6186, [LootReserveHoU.Constants.Genders.Female] = 6177},
        [LootReserveHoU.Constants.Races.Orc]      = {[LootReserveHoU.Constants.Genders.Male] = 6366, [LootReserveHoU.Constants.Genders.Female] = 6357},
        [LootReserveHoU.Constants.Races.Troll]    = {[LootReserveHoU.Constants.Genders.Male] = 6402, [LootReserveHoU.Constants.Genders.Female] = 6393},
        [LootReserveHoU.Constants.Races.Tauren]   = {[LootReserveHoU.Constants.Genders.Male] = 6384, [LootReserveHoU.Constants.Genders.Female] = 6375},
        [LootReserveHoU.Constants.Races.Scourge]  = {[LootReserveHoU.Constants.Genders.Male] = 6420, [LootReserveHoU.Constants.Genders.Female] = 6411},
        [LootReserveHoU.Constants.Races.Draenei]  = {[LootReserveHoU.Constants.Genders.Male] = 9707, [LootReserveHoU.Constants.Genders.Female] = 9682},
        [LootReserveHoU.Constants.Races.BloodElf] = {[LootReserveHoU.Constants.Genders.Male] = 9657, [LootReserveHoU.Constants.Genders.Female] = 9641},
    },
    Cry = {
        [LootReserveHoU.Constants.Races.Human]    = {[LootReserveHoU.Constants.Genders.Male] = 6921, [LootReserveHoU.Constants.Genders.Female] = 6916},
        [LootReserveHoU.Constants.Races.Dwarf]    = {[LootReserveHoU.Constants.Genders.Male] = 6901, [LootReserveHoU.Constants.Genders.Female] = 6895},
        [LootReserveHoU.Constants.Races.Gnome]    = {[LootReserveHoU.Constants.Genders.Male] = 6911, [LootReserveHoU.Constants.Genders.Female] = 6906},
        [LootReserveHoU.Constants.Races.NightElf] = {[LootReserveHoU.Constants.Genders.Male] = 6931, [LootReserveHoU.Constants.Genders.Female] = 6926},
        [LootReserveHoU.Constants.Races.Orc]      = {[LootReserveHoU.Constants.Genders.Male] = 6941, [LootReserveHoU.Constants.Genders.Female] = 6936},
        [LootReserveHoU.Constants.Races.Troll]    = {[LootReserveHoU.Constants.Genders.Male] = 6961, [LootReserveHoU.Constants.Genders.Female] = 6956},
        [LootReserveHoU.Constants.Races.Tauren]   = {[LootReserveHoU.Constants.Genders.Male] = 6951, [LootReserveHoU.Constants.Genders.Female] = 6946},
        [LootReserveHoU.Constants.Races.Scourge]  = {[LootReserveHoU.Constants.Genders.Male] = 6972, [LootReserveHoU.Constants.Genders.Female] = 6967},
        [LootReserveHoU.Constants.Races.Draenei]  = {[LootReserveHoU.Constants.Genders.Male] = 9701, [LootReserveHoU.Constants.Genders.Female] = 9676},
        [LootReserveHoU.Constants.Races.BloodElf] = {[LootReserveHoU.Constants.Genders.Male] = 9651, [LootReserveHoU.Constants.Genders.Female] = 9647},
    },
};
LootReserveHoU.Constants.LocomotionPhrases = {
    "Advance",
    "Amble",
    "Apparate",
    "Aviate",
    -- "Backpack",
    "Bike",
    "Bolt",
    -- "Bounce",
    -- "Bound",
    -- "Bowl",
    "Briskly Jog",
    "Canter",
    -- "Carom",
    "Carpool",
    "Cartwheel",
    "Catapult",
    -- "Cavort",
    "Charge",
    -- "Clamber",
    -- "Climb",
    -- "Clump",
    -- "Coast",
    "Commute",
    "Corporealize",
    "Crawl",
    -- "Creep",
    "Cycle",
    "Breakdance",
    "Dart",
    "Dash",
    "Dig",
    -- "Dodder",
    "Drift",
    "Drive",
    "Embark",
    "Engage Warp",
    -- "File",
    -- "Flit",
    -- "Float",
    "Fly",
    -- "Frolic",
    -- "FTL Warp",
    "Gallop",
    -- "Gambol",
    "Glide",
    "Go Fast",
    "Goosestep",
    "Hang Glide",
    "Hasten",
    "Hike",
    "Hobble",
    "Hop",
    "Hurry",
    "Hurtle",
    -- "Inch",
    "Jog",
    "Journey",
    "Jump",
    "Leap",
    "Limp",
    "Locomote",
    "Lollop",
    "Lope",
    -- "Lumber",
    "Lurch",
    "March",
    "Materialize",
    "Meander",
    -- "Mince",
    "Moonwalk",
    "Mosey",
    -- "Nip",
    -- "Pad",
    "Paddle",
    -- "Parade",
    "Perambulate", "Perambulate", "Perambulate", "Perambulate", "Perambulate", "Perambulate", "Perambulate", "Perambulate", "Perambulate", "Perambulate",
    "Plod",
    "Prance",
    -- "Promenade",
    "Prowl",
    "Race",
    -- "Ramble",
    "Reverse",
    -- "Roam",
    "Roll",
    -- "Romp",
    "Rove",
    "Row",
    "Run",
    "Rush",
    "Sail",
    "Sashay",
    "Saunter",
    "Scamper",
    "Scoot",
    "Scram",
    "Scramble",
    -- "Scud",
    "Scurry",
    -- "Scutter",
    "Scuttle",
    "Shamble",
    -- "Shuffle",
    "Sidle",
    "Skedaddle",
    "Ski",
    -- "Skip",
    "Skitter",
    "Skulk",
    "Sleepwalk",
    "Slide",
    "Slink",
    "Slippy Slide",
    "Slither",
    -- "Slog",
    -- "Slouch",
    "Sneak",
    "Somersault",
    -- "Speed",
    "Speedwalk",
    -- "Stagger",
    -- "Stomp",
    -- "Stray",
    "Streak",
    "Stride",
    "Stroll",
    "Strut",
    -- "Stumble",
    -- "Stump",
    -- "Swagger",
    -- "Sweep",
    "Swim",
    -- "Tack",
    "Taxi",
    -- "Tear",
    "Teleport",
    "Tiptoe",
    "Toddle",
    "Totter",
    "Traipse",
    -- "Tramp",
    "Travel",
    "Trek",
    -- "Troop",
    "Trot",
    -- "Trudge",
    -- "Trundle",
    "Tunnel",
    -- "Vault",
    "Velocitize",
    "Vibrate",
    "Waddle",
    "Wade",
    "Walk",
    "Wander",
    -- "Warp",
    "Water Ski",
    "Water Walk",
    -- "Whiz",
    "Zigzag",
    "Zoom",
};

local result = LootReserveHoU.Constants.ReserveResult;
LootReserveHoU.Constants.ReserveResultText =
{
    [result.OK]                       = "",
    [result.NotInRaid]                = "You are not in the raid",
    [result.NoSession]                = "Loot reserves aren't active",
    [result.NotAccepting]             = "Loot reserves are not currently being accepted",
    [result.NotMember]                = "You are not participating in loot reserves",
    [result.ItemNotReservable]        = "That item is not reservable",
    [result.AlreadyReserved]          = "You are already reserving that item",
    [result.NoReservesLeft]           = "You are at your reserve limit",
    [result.FailedConditions]         = "You cannot reserve that item",
    [result.Locked]                   = "Your reserves are locked in and cannot be changed",
    [result.NotEnoughReservesLeft]    = "You don't have enough reserves to do that",
    [result.MultireserveLimit]        = "You cannot reserve that item more times",
    [result.MultireserveLimitPartial] = "Not all of your reserves were accepted because you reached the limit of how many times you are allowed to reserve a single item",
    [result.FailedClass]              = "Your class cannot reserve that item",
    [result.FailedFaction]            = "Your faction cannot reserve that item",
    [result.FailedLimit]              = "That item has reached the limit of reserves",
    [result.FailedLimitPartial]       = "Not all of your reserves were accepted because the item reached the limit of reserves",
    [result.FailedUsable]             = "You may not reserve unusable items",
};

local result = LootReserveHoU.Constants.CancelReserveResult;
LootReserveHoU.Constants.CancelReserveResultText =
{
    [result.OK]                = "",
    [result.NotInRaid]         = "You are not in the raid",
    [result.NoSession]         = "Loot reserves aren't active",
    [result.NotAccepting]      = "Loot reserves are not currently being accepted",
    [result.NotMember]         = "You are not participating in loot reserves",
    [result.ItemNotReservable] = "That item is not reservable",
    [result.NotReserved]       = "You did not reserve that item",
    [result.Forced]            = "",
    [result.Locked]            = "Your reserves are locked in and cannot be changed",
    [result.InternalError]     = "Internal error",
    [result.NotEnoughReserves] = "You don't have that many reserves on that item",
};

local result = LootReserveHoU.Constants.OptResult;
LootReserveHoU.Constants.OptResultText =
{
    [result.OK]                       = "",
    [result.NotInRaid]                = "You are not in the raid",
    [result.NoSession]                = "Loot reserves aren't active",
    [result.NotMember]                = "You are not participating in loot reserves",
};

local result = LootReserveHoU.Constants.ReserveDeltaResult;
LootReserveHoU.Constants.ReserveDeltaResultText =
{
    [result.NoSession]         = "Loot reserves aren't active",
    [result.NotMember]         = "You are not participating in loot reserves",
};

local enum = LootReserveHoU.Constants.ReservesSorting;
LootReserveHoU.Constants.ReservesSortingText =
{
    [enum.ByTime]   = "By Time",
    [enum.ByName]   = "By Item Name",
    [enum.BySource] = "By Boss",
    [enum.ByLooter] = "By Looter",
};

local enum = LootReserveHoU.Constants.WinnerReservesRemoval;
LootReserveHoU.Constants.WinnerReservesRemovalText =
{
    [enum.None]      = "None",
    [enum.Single]    = "Just one",
    [enum.Duplicate] = "Duplicate",
    [enum.All]       = "All",
    [enum.Smart]     = "Smart",
};

local enum = LootReserveHoU.Constants.ChatReservesListLimit;
LootReserveHoU.Constants.ChatReservesListLimitText =
{
    [enum.None] = "None",
};

local enum = LootReserveHoU.Constants.WonRollPhase;
LootReserveHoU.Constants.WonRollPhaseText =
{
    [enum.Reserve]  = "Reserve",
    [enum.RaidRoll] = "Raid-Roll",
};

for i = 1, LootReserveHoU:GetNumClasses() do
    local name, file, id = LootReserveHoU:GetClassInfo(i);
    if file and id then
        LootReserveHoU.Constants.ClassFilenameToClassID[file] = id;
    end
end
for filename, localized in pairs(LOCALIZED_CLASS_NAMES_MALE) do
    LootReserveHoU.Constants.ClassLocalizedToFilename[localized] = filename;
end
for filename, localized in pairs(LOCALIZED_CLASS_NAMES_FEMALE) do
    LootReserveHoU.Constants.ClassLocalizedToFilename[localized] = filename;
end
for localized, filename in pairs(LootReserveHoU.Constants.ClassLocalizedToFilename) do
    LootReserveHoU.Constants.ClassLocalizedToFilename[localized:lower()] = filename;
end
