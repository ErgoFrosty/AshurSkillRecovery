from pathlib import Path

from lupa import LuaRuntime


ROOT = Path(__file__).resolve().parents[1]


def main() -> None:
    shared_path = ROOT / "AshurSkillRecovery" / "common" / "media" / "lua" / "shared" / "?.lua"
    server_path = ROOT / "AshurSkillRecovery" / "common" / "media" / "lua" / "server" / "?.lua"
    for test_name in ("test_math.lua", "test_journal.lua"):
        runtime = LuaRuntime(unpack_returned_tuples=True)
        runtime.execute(
            f'package.path = [[{shared_path.as_posix()}]] .. ";" .. '
            f'[[{server_path.as_posix()}]] .. ";" .. package.path'
        )
        runtime.execute((ROOT / "tests" / test_name).read_text(encoding="utf-8"))


if __name__ == "__main__":
    main()
