import json
import os
import re
import struct
from pathlib import Path

from luaparser import ast


ROOT = Path(__file__).resolve().parents[1]
MOD = ROOT / "AshurSkillRecovery"

VANILLA_SKILL_TRANSLATION_KEYS = {
    "Aiming": "IGUI_perks_Aiming",
    "Axe": "IGUI_perks_Axe",
    "Blacksmith": "IGUI_perks_Blacksmith",
    "Blunt": "IGUI_perks_Blunt",
    "Butchering": "IGUI_perks_Butchering",
    "Carving": "IGUI_perks_Carving",
    "Cooking": "IGUI_perks_Cooking",
    "Doctor": "IGUI_perks_Doctor",
    "Electricity": "IGUI_perks_Electricity",
    "Farming": "IGUI_perks_Farming",
    "Fishing": "IGUI_perks_Fishing",
    "Fitness": "IGUI_perks_Fitness",
    "FlintKnapping": "IGUI_perks_FlintKnapping",
    "Glassmaking": "IGUI_perks_Glassmaking",
    "Husbandry": "IGUI_perks_Husbandry",
    "Lightfoot": "IGUI_perks_Lightfooted",
    "LongBlade": "IGUI_perks_LongBlade",
    "Maintenance": "IGUI_perks_Maintenance",
    "Masonry": "IGUI_perks_Masonry",
    "Mechanics": "IGUI_perks_Mechanics",
    "MetalWelding": "IGUI_perks_MetalWelding",
    "Nimble": "IGUI_perks_Nimble",
    "PlantScavenging": "IGUI_perks_Foraging",
    "Pottery": "IGUI_perks_Pottery",
    "Reloading": "IGUI_perks_Reloading",
    "SmallBlade": "IGUI_perks_SmallBlade",
    "SmallBlunt": "IGUI_perks_SmallBlunt",
    "Sneak": "IGUI_perks_Sneaking",
    "Spear": "IGUI_perks_Spear",
    "Sprinting": "IGUI_perks_Sprinting",
    "Strength": "IGUI_perks_Strength",
    "Tailoring": "IGUI_perks_Tailoring",
    "Tracking": "IGUI_perks_Tracking",
    "Trapping": "IGUI_perks_Trapping",
    "Woodwork": "IGUI_perks_Woodwork",
}


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
    assert configurable_perks == set(VANILLA_SKILL_TRANSLATION_KEYS), (
        "vanilla skill translation map does not match the recovery allow-list"
    )
    sandbox = (MOD / "common" / "media" / "sandbox-options.txt").read_text(encoding="utf-8")
    translations = []
    for language in ("EN", "RU"):
        path = MOD / "common" / "media" / "lua" / "shared" / "Translate" / language / "Sandbox.json"
        translations.append(json.loads(path.read_text(encoding="utf-8")))
    for perk_id in configurable_perks:
        option = f"Enable{perk_id}"
        assert f"option AshurSkillRecovery.{option}" in sandbox, f"missing sandbox option: {option}"
        for translation in translations:
            assert f"Sandbox_{option}" in translation, f"missing sandbox translation: {option}"
        assert f"option AshurSkillRecovery.Record{perk_id}" not in sandbox
        assert f"option AshurSkillRecovery.Recover{perk_id}" not in sandbox

    vanilla_ru_names = {
        "Aiming": "Точность", "Axe": "Топоры", "Blacksmith": "Кузнечное дело",
        "Blunt": "Длинное дробящее", "Butchering": "Мясницкое дело", "Carving": "Резьба",
        "Cooking": "Кулинария", "Doctor": "Медицина", "Electricity": "Электрика",
        "Farming": "Фермерство", "Fishing": "Рыболовство", "Fitness": "Фитнес",
        "FlintKnapping": "Камнеобработка", "Glassmaking": "Стеклоделие",
        "Husbandry": "Уход за животными", "Lightfoot": "Лёгкий шаг",
        "LongBlade": "Длинное режущее", "Maintenance": "Прочность",
        "Masonry": "Каменная кладка", "Mechanics": "Автомеханика",
        "MetalWelding": "Газосварка", "Nimble": "Проворность",
        "PlantScavenging": "Собирательство", "Pottery": "Гончарное дело",
        "Reloading": "Перезарядка", "SmallBlade": "Короткое режущее",
        "SmallBlunt": "Короткое дробящее", "Sneak": "Скрытность", "Spear": "Копья",
        "Sprinting": "Бег", "Strength": "Сила", "Tailoring": "Шитьё",
        "Tracking": "Выслеживание", "Trapping": "Звероловство", "Woodwork": "Плотничество",
    }
    ru_sandbox = translations[1]
    for perk_id, vanilla_name in vanilla_ru_names.items():
        translation_key = VANILLA_SKILL_TRANSLATION_KEYS[perk_id]
        assert ru_sandbox[f"Sandbox_Enable{perk_id}"] == vanilla_name, (
            f"RU label for {perk_id} must match {translation_key}"
        )

    vanilla_en_names = {
        "Aiming": "Aiming", "Axe": "Axe", "Blacksmith": "Blacksmithing",
        "Blunt": "Long Blunt", "Butchering": "Butchering", "Carving": "Carving",
        "Cooking": "Cooking", "Doctor": "First Aid", "Electricity": "Electrical",
        "Farming": "Agriculture", "Fishing": "Fishing", "Fitness": "Fitness",
        "FlintKnapping": "Knapping", "Glassmaking": "Glassmaking",
        "Husbandry": "Animal Care", "Lightfoot": "Lightfooted",
        "LongBlade": "Long Blade", "Maintenance": "Maintenance", "Masonry": "Masonry",
        "Mechanics": "Mechanics", "MetalWelding": "Welding", "Nimble": "Nimble",
        "PlantScavenging": "Foraging", "Pottery": "Pottery", "Reloading": "Reloading",
        "SmallBlade": "Short Blade", "SmallBlunt": "Short Blunt", "Sneak": "Sneaking",
        "Spear": "Spear", "Sprinting": "Running", "Strength": "Strength",
        "Tailoring": "Tailoring", "Tracking": "Tracking", "Trapping": "Trapping",
        "Woodwork": "Carpentry",
    }
    en_sandbox = translations[0]
    for perk_id, vanilla_name in vanilla_en_names.items():
        translation_key = VANILLA_SKILL_TRANSLATION_KEYS[perk_id]
        assert en_sandbox[f"Sandbox_Enable{perk_id}"] == vanilla_name, (
            f"EN label for {perk_id} must match {translation_key}"
        )

    game_dir_value = os.environ.get("PROJECT_ZOMBOID_DIR")
    if game_dir_value:
        game_dir = Path(game_dir_value)
        for language, sandbox_translation in (("EN", en_sandbox), ("RU", ru_sandbox)):
            vanilla_path = game_dir / "media" / "lua" / "shared" / "Translate" / language / "IG_UI.json"
            assert vanilla_path.is_file(), f"missing vanilla translation: {vanilla_path}"
            vanilla_translation = json.loads(vanilla_path.read_text(encoding="utf-8"))
            for perk_id, translation_key in VANILLA_SKILL_TRANSLATION_KEYS.items():
                assert sandbox_translation[f"Sandbox_Enable{perk_id}"] == vanilla_translation[translation_key], (
                    f"{language} label for {perk_id} differs from installed game key {translation_key}"
                )

    build_script = (ROOT / "build.ps1").read_text(encoding="utf-8")
    assert "name=Ashur Skill Recovery DEV [B42.20]" in build_script
    assert "id=AshurSkillRecoveryDev" in build_script
    assert "Failed to assign the distinct DEV mod ID." in build_script
    assert "translation.Sandbox_AshurSkillRecovery" in build_script

    context = (MOD / "common" / "media" / "lua" / "client" / "AshurSkillRecovery" / "Context.lua").read_text(encoding="utf-8")
    assert "local function promptRename(item, playerObj)" in context
    assert "local function renameJournal(_, button, playerObj, item)" in context
    assert "playerObj:getPlayerNum()," in context

    journal = (MOD / "common" / "media" / "lua" / "shared" / "AshurSkillRecovery" / "Journal.lua").read_text(encoding="utf-8")
    assert "item:setCustomName(true)" in journal
    assert "item:syncItemFields()" in journal
    assert "ASR.addXpNoMultiplier or addXpNoMultiplier" in journal
    assert "playerObj:getAlreadyReadBook()" in journal
    assert "sendSyncPlayerFields" in journal
    assert "0x00000001" in journal
    assert "0x00000004" in journal

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
