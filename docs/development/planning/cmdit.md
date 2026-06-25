# cmdit — the Sovereign CLI / Argument-Parsing Library

> Record of the 2026-06-25 ecosystem CLI review + the design and adoption plan for
> **cmdit**, the standalone CLI/arg-parsing distlib. Mined by a fan-out survey
> (4 readers over ~34 repos) → synthesis → adversarial verification.

| Field | Value |
|-------|-------|
| Status | **Scaffolded + built — v0.1.0** (`/home/macro/Repos/cmdit`, the extraction cut). Binary smoke + 26/26 tests green; `dist/cmdit.cyr` generated. Not committed/tagged (user does git). |
| Repo | [cmdit](https://github.com/MacCracken/cmdit) — `[lib]` distlib, `dist/cmdit.cyr`. English "command" wordplay lane (with `cmdrs`/`bnrmr`). |
| Created | 2026-06-25 |

---

## The premise correction (what the review actually found)

The original question was "do we have a CLI lib? if not, name it cmdit." The honest
answer: **no standalone CLI *library* existed, but a stdlib *parser* did** —
`cyrius/lib/flags.cyr` (407 lines, getopt-long: typed bool/int/str, `--name`/
`--name=value`/`--name value`/`-x`/`--`/lone-`-`, a FlagErr taxonomy, allocate-once
ctx, table-generated help), already consumed by ~9 repos (kii, anuenue,
bannermanor, agnova, yo). kii — suspected to *be* the parser — is only a 91-line
*wrapper* around it.

So cmdit is **not greenfield**: it is **`flags.cyr` productized as a standalone
distlib + extended**. This matters because (a) `flags.cyr` lives in the toolchain,
so it can't grow `enum`/`repeat`/verb features without a cyrius release (and cyrius
is hands-off), and (b) ~31 of the ~40 CLI binaries never adopted it and still
hand-roll. A standalone distlib that forks the proven core and adds the missing
surface is the right shape — the verdict confirmed enum/repeat **require new
branches inside the parse loop** (impossible by mere wrapping), so a fork is
necessary, not duplication for its own sake.

**Scale of the hand-rolling:** ~40 repos hand-roll `argc()/argv()`; ~29 hand-write
`--help`/`--version`/usage; every structured consumer re-copies the argc/argv →
`cstr*` materialize bridge.

---

## The universal surface (by prevalence)

**Ubiquitous** (nearly every CLI): `args_init` + raw `argc/argv`; `--help`/`-h`;
some `--version`; positionals in argv order; bool flags; short+long alias pairs;
`--key value`; the `0`/`1`/`2` exit convention; `<prog>: <reason>` stderr errors;
pre-seeded defaults.
**Common:** int + string/path value flags; `--key=value` attached form; the
argc/argv→`cstr*` materialize bridge; subcommand/verb dispatch (streq if-chains,
no table-driven dispatch anywhere today); **enum/choice flags** (hand-validated in
attn11/owl/agnova/cyim/phylax — the #1 missing primitive); `--` terminator + lone
`-`; generated help (exists, minority-adopted — the biggest value-add); missing-
value guards; cross-flag validation; per-verb flag subsets.
**Occasional:** required flags; env-var fallback; numeric range checks; nested
sub-verbs; pure-function parse (testable); global-flags-before-or-after-verb;
result-enum/registry consumer pattern; action/immediate-dispatch flags; repeatable
flags; `--no-foo` negation; busybox multiplexer (argv[0]); typed/optional trailing
positionals.
**Rare:** bundled shorts `-abc` (only darshini) — deliberately deferred.

---

## cmdit 0.1.0 — the extraction cut (built)

Forked `flags.cyr`'s core → `cmdit_*` (byte-compatible `CMDIT_BOOL/INT/STR` + error
codes), PLUS the three universal additions:
- **`cmdit_argv`** — the materialize bridge (argc/argv → contiguous NULL-terminated
  `cstr*`, `args_init` once, cached). The single most-duplicated boilerplate.
- **Auto `--help`/`-h` + `--version`/`-V`** — `cmdit_new` registers them;
  `cmdit_parse*` short-circuit to `CMDIT_HELP`/`CMDIT_VERSION`. Generated
  `cmdit_help`, centralized `cmdit_version`, standard `cmdit_print_error`.
- **`CMDIT_EXIT_OK/RUN/USAGE`** — the exit convention as named constants.
- `FLAGS_MAX` 32→64 (attn11 has ~35 flags); `cmdit_raw_argv` escape hatch; pure
  testable `cmdit_parse_argv`.

Idiom notes honored: untyped i64 params (cstr is a pointer, not a declared type);
heap `alloc((argc+1)*8)` for the bridge (not a fixed stack cap); error-codes (not
`guard()`-abort) for parse failures; bare-call `_entry()` + `sys_exit` documented
for the agnos init-rsp-capture caveat.

**Deferred:** 0.2.0 = `cmdit_enum`/`cmdit_repeat`/`cmdit_required`/`cmdit_range`/
`cmdit_env`; 0.3.0 = verb dispatch (`cmdit_verb`/`cmdit_dispatch`, nested sub-verbs,
before-or-after globals, multiplexer doc). Out of scope: bundled shorts, attached
`-xvalue`, count `-vvv`, float flags, REPL/telnet DSLs.

---

## Adoption tiers (post-0.1.0)

- **Tier 0 — non-adopters** (zero-flag tools): iam, tarka, nous. cmdit is opt-in;
  these stay as-is.
- **Tier 1 — drop-in** (flag + positional, single command): **kii** (the re-fold
  seed), anuenue, bannermanor, klug, shakti, yo, whirl. Low effort: swap to
  `cmdit_new`, delete the hand-rolled materialize, get auto help/version free.
- **Tier 2 — subcommand tools** (need 0.3.0 verbs): hadara, hoosh, takumi, hapi,
  ark, sit, phylax, agnova, cyim.
- **Tier 3 — rich/edge**: attn11 (~35 flags + enums), owl (5 enums + `=value`),
  chakshu, agora, agnoshi, dig (raw-argv escape), darshini (bundled shorts — punted).

**Re-fold first:** kii drops its in-repo flag-set wrapper for `[deps.cmdit]` — the
seed becoming the first consumer (the akshara/taar pattern); its output must stay
byte-identical, the cleanest proof the extraction is faithful.

---

## Cross-references

- cmdit repo: `README.md`, `docs/development/roadmap.md` (the 0.1→0.2→0.3 arc).
- [`shared-crates.md`](shared-crates.md) + [`roadmap.md`](../roadmap.md) Future
  Shared Crates row.
