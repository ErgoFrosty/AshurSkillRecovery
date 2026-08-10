import json
import re
import struct
from pathlib import Path

from luaparser import ast


ROOT = Path(__file__).resolve().parents[1]
MOD = ROOT / "AshurSkillRecovery"


def main() -> None:
    required = [
        MOD / "42" / "mod.info",
        MOD / "common" / "media" / "sandbox-options.txt",
        MOD / "common" / "media" / "scripts" / "ASR_Items.txt",
        MOD / "common" / "media" / "textures" / "Item_ASRRecoveryJournal.png",
    ]
    required.extend((MOD / "common" / "media" / "lua" / "shared" / "Translate").rglob("*.json"))
    for path in required:
        assert path.is_file(), f"missing: {path.relative_to(ROOT)}"
        if path.suffix == ".json":
            with path.open("r", encoding="utf-8") as handle:
                value = json.load(handle)
            assert isinstance(value, dict) and value, f"empty translation: {path}"

    mod_info = (MOD / "42" / "mod.info").read_text(encoding="utf-8")
    assert "id=AshurSkillRecovery" in mod_info
    assert "versionMin=42.20" in mod_info
    assert "require=" not in mod_info

    scripts = (MOD / "common" / "media" / "scripts" / "ASR_Items.txt").read_text(encoding="utf-8")
    assert "Notebook/Journal" not in scripts
    assert "AshurSkillRecovery.RecoveryJournal" in scripts
    assert "timedAction = Making" in scripts
    assert "OnCreate = AshurSkillRecovery.onCreateRecoveryJournal" in scripts
    assert "Icon = ASRRecoveryJournal" in scripts

    icon = MOD / "common" / "media" / "textures" / "Item_ASRRecoveryJournal.png"
    icon_data = icon.read_bytes()
    assert icon_data[:8] == b"\x89PNG\r\n\x1a\n", "journal icon is not a PNG"
    width, height, bit_depth, color_type = struct.unpack(">IIBB", icon_data[16:26])
    assert (width, height) == (32, 32), "journal item icon must be 32x32"
    assert bit_depth == 8 and color_type in (4, 6), "journal item icon must have alpha"

    core = (MOD / "common" / "media" / "lua" / "shared" / "AshurSkillRecovery" / "Core.lua").read_text(encoding="utf-8")
    allowlist = core.split("ASR.VANILLA_PERK_IDS = {", 1)[1].split("}", 1)[0]
    perk_ids = set(re.findall(r"\b([A-Z][A-Za-z]+)\s*=\s*true", allowlist))
    configurable_perks = perk_ids
    sandbox = (MOD / "common" / "media" / "sandbox-options.txt").read_text(encoding="utf-8")
    translations = []
    for language in ("EN", "RU"):
        path = MOD / "common" / "media" / "lua" / "shared" / "Translate" / language / "Sandbox.json"
        translations.append(json.loads(path.read_text(encoding="utf-8")))
    for perk_id in configurable_perks:
        for direction in ("Record", "Recover"):
            option = f"{direction}{perk_id}"
            assert f"option AshurSkillRecovery.{option}" in sandbox, f"missing sandbox option: {option}"
            for translation in translations:
                assert f"Sandbox_{option}" in translation, f"missing sandbox translation: {option}"
    for obsolete_id in ("Carpentry", "FirstAid", "Foraging", "PassiveSkills"):
        assert f"Record{obsolete_id}" not in sandbox and f"Recover{obsolete_id}" not in sandbox

    context = (MOD / "common" / "media" / "lua" / "client" / "AshurSkillRecovery" / "Context.lua").read_text(encoding="utf-8")
    assert "local function promptRename(item, playerObj)" in context
    assert "local function renameJournal(_, button, playerObj, item)" in context
    assert "playerObj:getPlayerNum()," in context

    journal = (MOD / "common" / "media" / "lua" / "shared" / "AshurSkillRecovery" / "Journal.lua").read_text(encoding="utf-8")
    assert "item:setCustomName(true)" in journal
    assert "item:syncItemFields()" in journal
    assert "ASR.addXpNoMultiplier or addXpNoMultiplier" in journal

    server = (MOD / "common" / "media" / "lua" / "server" / "AshurSkillRecovery" / "Server.lua").read_text(encoding="utf-8")
    assert "onCreateRecoveryJournal(craftRecipeData, playerObj)" in server
    assert "craftRecipeData:getFirstCreatedItem()" in server

    action = (MOD / "common" / "media" / "lua" / "shared" / "AshurSkillRecovery" / "RecoveryAction.lua").read_text(encoding="utf-8")
    assert "math.max(1," in action

    lua_files = sorted((MOD / "common" / "media" / "lua").rglob("*.lua"))
    assert lua_files, "no Lua source files found"
    for path in lua_files:
        ast.parse(path.read_text(encoding="utf-8"))

    print(f"project structure, translations, and {len(lua_files)} Lua files: all checks passed")


if __name__ == "__main__":
    main()
