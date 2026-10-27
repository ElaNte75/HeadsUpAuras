# Project checks

- The installed addon files live under `HeadsUpAuras/` in this repository. The in-game addon directory itself is not necessarily a Git checkout.
- On this Windows environment, `py` provides Python with `lupa` available. Lua syntax can be checked without executing WoW APIs:
  `py -c "from pathlib import Path; from lupa import LuaRuntime; lua = LuaRuntime(); [lua.execute('assert(load(...))', p.read_text(encoding='utf-8-sig')) for p in Path('HeadsUpAuras').glob('*.lua')]"`
- Run `git diff --check` before committing.
- Full UI and combat verification requires World of Warcraft. Reload with `/reload`, open `/hua`, and test the changed trigger on appropriate targets.
