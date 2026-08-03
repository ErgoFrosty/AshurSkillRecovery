import json
from pathlib import Path

from luaparser import ast


ROOT = Path(__file__).resolve().parents[1]
MOD = ROOT / "AshurSkillRecovery"


def main() -> None:
    required = [
        MOD / "42" / "mod.info",
        MOD / "common" / "media" / "sandbox-options.txt",
        MOD / "common" / "media" / "scripts" / "ASR_Items.txt",
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

    context = (MOD / "common" / "media" / "lua" / "client" / "AshurSkillRecovery" / "Context.lua").read_text(encoding="utf-8")
    assert "local function promptRename(item, playerObj)" in context
    assert "text, playerObj, renameJournal, item)" in context

    journal = (MOD / "common" / "media" / "lua" / "shared" / "AshurSkillRecovery" / "Journal.lua").read_text(encoding="utf-8")
    assert "item:setCustomName(true)" in journal

    lua_files = sorted((MOD / "common" / "media" / "lua").rglob("*.lua"))
    assert lua_files, "no Lua source files found"
    for path in lua_files:
        ast.parse(path.read_text(encoding="utf-8"))

    print(f"project structure, translations, and {len(lua_files)} Lua files: all checks passed")


if __name__ == "__main__":
    main()
