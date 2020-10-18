-- Terminology:

-- journalId:
--   The id of an encounter that is selected in the encounter journal.
--   This is passed as input to EJ_GetEncounterInfo().

-- encounterId:
--   The id passed to ENCOUNTER_START.
--   This is the 7th value returned by EJ_GetEncounterInfo().

-- example:
--   local _, _, _, _, _, _, encounterId = EJ_GetEncounterInfo(journalId);

local Debug = false;

local Memantine = LibStub("AceAddon-3.0"):NewAddon("Memantine", "AceConsole-3.0", "AceEvent-3.0", "AceHook-3.0");
local AceGui = LibStub("AceGUI-3.0");

function Memantine:OnInitialize()
  self:Debug("OnInitialize");

  self.gui = nil;
  self.encounterIdToJournalId = self:CreateEncounterIdToJournalIdMap();

  self.db = LibStub("AceDB-3.0"):New("Memantine");

  self:RegisterEvent("ADDON_LOADED");
  self:RegisterEvent("ENCOUNTER_START");

  self:RegisterChatCommand("memantine", "ChatCommand");
end

function Memantine:CreateEncounterIdToJournalIdMap()
  self:Debug("CreateEncounterIdToJournalIdMap");

  local encounterIdToJournalId = {};
  for journalId = 1, 3000 do
    local _, _, _, _, _, _, encounterId = EJ_GetEncounterInfo(journalId);
    if (encounterId) then
      encounterIdToJournalId[encounterId] = journalId;
    end
  end
  return encounterIdToJournalId;
end

-- For debug: /memantine 2124 1
function Memantine:ChatCommand(command)
  self:Debug("ChatCommand", command);

  local parts = {}
  for part in string.gmatch(command, "%S+") do
    parts[#parts + 1] = part;
  end

  self:ENCOUNTER_START("ENCOUNTER_START", tonumber(parts[1]), "TEST", tonumber(parts[2]), nil);
end

function Memantine:ADDON_LOADED(eventName, addonName)
  self:Debug("ADDON_LOADED", eventName, addonName);

  if addonName == "Blizzard_EncounterJournal" then
    self:CreateGui();
  end
end

function Memantine:GetLootSpecializations()
  self:Debug("GetLootSpecializations");

  local specializations = {};
  specializations[-1] = "Do not change";
  specializations[0] = "Current Specialization";
  for i = 1, GetNumSpecializations() do
    local id, name = GetSpecializationInfo(i);
    specializations[id] = name;
  end
  return specializations;
end

function Memantine:GetSpecializationIndex(lootSpecializationId)
  self:Debug("GetSpecializationIndex", lootSpecializationId);

  for i = 1, GetNumSpecializations() do
    local id, name = GetSpecializationInfo(i);
    if id == lootSpecializationId then
      return i;
    end
  end
  return nil;
end

function Memantine:CreateGui()
  self:Debug("CreateGui");

  self.gui = AceGui:Create("Frame");
  self.gui:SetTitle("Memantine");
  self.gui:SetPoint("TOPLEFT", EncounterJournal, "TOPRIGHT", 32, 0);
  self.gui:SetWidth(200);
  self.gui:SetHeight(355);
  self.gui:SetParent(EncounterJournal);
  self.gui:SetLayout("List");

  -- Hide status bar
  self.gui.statustext:Hide();
  self.gui.statustext:GetParent():Hide();

  -- Hide close button
  local children = { self.gui.frame:GetChildren() };
  children[1]:Hide();

  self:Debug("HookGui");

  -- Handle clicking home in the navbar
  self:SecureHook("EJSuggestFrame_OpenFrame", function()
    self:Debug("EJSuggestFrame_OpenFrame");
    self:UpdateVisibility();
  end);

  self:SecureHook("EncounterJournal_ListInstances", function()
    self:Debug("EncounterJournal_ListInstances");
    self:UpdateVisibility();
  end);

  -- Handle tab switching
  self:SecureHook("EncounterJournal_SetTab", function(tabType)
    self:Debug("EncounterJournal_SetTab");
    self:UpdateVisibility();
  end);

  -- Handle open/close of adventure guide
  self:SecureHook(EncounterJournal, "Hide", function()
    self:Debug("EncounterJournal", "Hide");
    self:UpdateVisibility();
  end);

  self:SecureHook(EncounterJournal, "Show", function()
    self:Debug("EncounterJournal", "Show");
    self:UpdateVisibility();
  end);

  -- Handle boss/dungeon/etc changes
  self:SecureHook("EncounterJournal_LootUpdate", function()
    self:Debug("EncounterJournal_LootUpdate");
    self:GuiUpdateDifficulties();
    self:UpdateVisibility();
  end)

  -- Handle encounter changes
  self:SecureHook("EncounterJournal_DisplayEncounter", function()
    self:Debug("EncounterJournal_DisplayEncounter");
    self:UpdateVisibility();
  end);
end

function Memantine:GetJournalId()
  self:Debug("GetJournalId");

  return self:IsEncounterJournalLootTabShown()
    and EncounterJournal.encounterID
    or nil;
end

function Memantine:IsEncounterJournalLootTabShown()
  self:Debug("IsLootTab");

  return EncounterJournal
    and EncounterJournal:IsShown()
    and EncounterJournal.encounter
    and EncounterJournal.encounter:IsShown()
    and EncounterJournal.encounter.info
    and EncounterJournal.encounter.info.tab == 2
    or false;
end

function Memantine:UpdateVisibility()
  self:Debug("UpdateVisibility");

  local journalId = self:GetJournalId();
  local show = self:IsEncounterJournalLootTabShown() and journalId;

  if (show) then
    local encounterName = EJ_GetEncounterInfo(journalId);
    self.gui:SetTitle(encounterName);
    self.gui:Show();
  else
    self.gui:Hide();
  end

end

function Memantine:GuiUpdateDifficulties()
  self:Debug("GuiUpdateDifficulties");

  local journalId = self:GetJournalId();
  if not journalId then
    return;
  end

  self.gui:SetWidth(200);
  self.gui:SetHeight(355);
  self.gui:ReleaseChildren();

  local lootSpecializations = self:GetLootSpecializations();

  -- Create difficulty dropdowns
  local difficultyDropdowns = {};
  for difficultyId = 1, 34 do
    if EJ_IsValidInstanceDifficulty(difficultyId) then
      local difficultyName = GetDifficultyInfo(difficultyId);
      local difficultyDropdown = AceGui:Create("Dropdown");
      difficultyDropdown.journalId = journalId;
      difficultyDropdown.difficultyId = difficultyId;
      difficultyDropdown:SetRelativeWidth(1);
      difficultyDropdown:SetLabel(difficultyName);
      difficultyDropdown:SetList(lootSpecializations);
      local lootSpecializationId = self:LoadLootSpecializationId(difficultyDropdown.journalId, difficultyDropdown.difficultyId);
      difficultyDropdown:SetValue(lootSpecializationId);
      difficultyDropdown:SetCallback("OnValueChanged", function(info, name, key)
        self:SaveLootSpecializationId(difficultyDropdown.journalId, difficultyDropdown.difficultyId, key);
      end)
      table.insert(difficultyDropdowns, difficultyDropdown);
    end
  end

  -- Create set all dropdown
  local difficultyDropdown = AceGui:Create("Dropdown");
  difficultyDropdown:SetRelativeWidth(1);
  difficultyDropdown:SetLabel("All");
  difficultyDropdown:SetList(lootSpecializations);
  difficultyDropdown:SetCallback("OnValueChanged", function(info, name, key)
    if key ~= nil then
      for i = 1, #difficultyDropdowns do
        difficultyDropdowns[i]:SetValue(key);
        self:SaveLootSpecializationId(difficultyDropdowns[i].journalId, difficultyDropdowns[i].difficultyId, key);
      end
      difficultyDropdown:SetValue(nil);
    end
  end)

  self.gui:AddChild(difficultyDropdown);
  for i = 1, #difficultyDropdowns do
    self.gui:AddChild(difficultyDropdowns[i]);
  end
end

function Memantine:SaveLootSpecializationId(journalId, difficultyId, lootSpecializationId)
  self:Debug("SaveLootSpecializationId", journalId, difficultyId, lootSpecializationId);

  self.db.char[journalId] = self.db.char[journalId] or {};
  self.db.char[journalId][difficultyId] = lootSpecializationId;
end

function Memantine:LoadLootSpecializationId(journalId, difficultyId)
  self:Debug("LoadLootSpecializationId", journalId, difficultyId);

  return self.db.char[journalId] and self.db.char[journalId][difficultyId] or -1;
end

function Memantine:ENCOUNTER_START(eventName, encounterId, encounterName, difficultyId, groupSize)
  self:Debug("ENCOUNTER_START", eventName, encounterId, encounterName, difficultyId, groupSize);

  local journalId = self.encounterIdToJournalId[encounterId];
  self:Debug("journalId", journalId);

  local journalEncounterName = EJ_GetEncounterInfo(journalId);
  self:Debug("journalEncounterName", journalEncounterName);

  local lootSpecializationId = self:LoadLootSpecializationId(journalId, difficultyId);
  self:Debug("lootSpecializationId", lootSpecializationId);

  local specializationIndex = self:GetSpecializationIndex(lootSpecializationId);
  self:Debug("specializationIndex", specializationIndex);

  local difficultyName = GetDifficultyInfo(difficultyId);
  self:Debug("difficultyName", difficultyName);

  if (lootSpecializationId == -1) then
    self:Print("Encounter "..journalEncounterName.." "..difficultyName.." started. Not changing loot specialization.");
  elseif (lootSpecializationId == 0) then
    local _, lootSpecializationName = GetSpecializationInfo(GetSpecialization());
    self:Print("Encounter "..journalEncounterName.." "..difficultyName.." started. Setting loot specialization to current specialization ("..lootSpecializationName..").");
    SetLootSpecialization(0);
  else
    local _, lootSpecializationName = GetSpecializationInfo(specializationIndex);
    self:Print("Encounter "..journalEncounterName.." "..difficultyName.." started. Setting loot specialization to "..lootSpecializationName..".");
    SetLootSpecialization(lootSpecializationId);
  end
end

function Memantine:Debug(...)
  if (Debug) then
    self:Print(...);
  end
end