---
name: thermo-nuclear-review
description: Run an extremely strict maintainability review for abstraction quality, giant files, and spaghetti-condition growth.
---

# Thermo-Nuclear Code Quality Review

Brutally strict review of implementation quality, maintainability, and abstraction. Be **ambitious**: don't just spot local cleanups, hunt for "code judo" — behavior-preserving restructurings that make the implementation dramatically simpler, smaller, more direct. Prefer deleting complexity over rearranging it. Prefer the version that feels inevitable in hindsight.

## Core Prompt

> Deep code quality audit of the current branch's changes. Rethink how the changes are structured to meaningfully improve quality without changing behavior — better abstractions and modularity, less spaghetti, more succinct and legible. Be ambitious: if restructuring some of the codebase clearly improves the implementation, go for it. Be thorough and rigorous. Measure twice, cut once.

## Standards

Start with anything in the repo that documents how code should be written (`CODING_STANDARDS.md`, `CONTRIBUTING.md`, local agent instructions, etc.). Repo standards override the baseline below: if documented project guidance endorses something a smell would normally flag, suppress the smell. Treat smells as labelled heuristics, not hard violations (`possible Feature Envy`), and skip anything tooling already enforces.

Treat each as a presumptive blocker unless the author justifies it clearly:

1. **Code judo first.** For every meaningful change, ask if a reframing makes whole branches / helpers / modes / layers disappear. Don't settle for "a bit cleaner," or for a cleaner version of the same messy idea when a simpler idea is plausible.
2. **1k-line ceiling.** A PR pushing a file from under 1000 lines to over is a strong smell — decompose first unless there's a compelling reason and the result stays clearly organized.
3. **No spaghetti growth.** New ad-hoc conditionals, scattered special cases, one-off branches bolted onto unrelated flows are design problems, not nits. Push logic into a dedicated helper / state machine / policy / module.
4. **Clean the design, don't rubber-stamp "it works."** If behavior stays the same while structure gets meaningfully cleaner, demand it. Remove moving pieces, don't spread complexity.
5. **Boring over magic.** Flag brittle/ad-hoc/"magic" behavior, generic mechanisms hiding simple data shapes, and thin wrappers / identity abstractions / pass-throughs that add indirection without clarity.
6. **Type & boundary cleanliness.** Question needless optionality, `any`, `unknown`, cast-heavy code, and silent fallbacks papering over unclear invariants. Prefer explicit typed models and shared contracts.
7. **Canonical layer.** Keep feature logic out of shared paths and implementation details out of APIs. Reuse existing canonical helpers; put logic in the package/module that owns the concept instead of normalizing drift.
8. **Atomic & parallel.** Flag work serialized for no reason (parallelize when it also simplifies) and updates that can leave state half-applied (push toward atomic). Don't chase micro-optimizations.

### Smell Baseline

When repo guidance is silent, keep Fowler's core smells in the review vocabulary. Match them against the diff as `what it is → how to fix`:

- **Mysterious Name** — a function, variable, or type whose name doesn't reveal what it does or holds. → Rename it; if no honest name comes, the design is murky.
- **Duplicated Code** — the same logic shape appears in more than one hunk or file. → Extract the shared shape and call it from both sites.
- **Feature Envy** — a method reaches into another object's data more than its own. → Move the method onto the data it envies.
- **Data Clumps** — the same fields or params keep travelling together. → Bundle them into one type and pass that.
- **Primitive Obsession** — a primitive or string stands in for a domain concept. → Give the concept its own small type.
- **Repeated Switches** — the same switch / if-cascade on the same type recurs. → Replace it with polymorphism, or one shared map / dispatcher.
- **Shotgun Surgery** — one logical change forces scattered edits across many files. → Gather what changes together into one module.
- **Divergent Change** — one file or module is edited for unrelated reasons. → Split so each module changes for one reason.
- **Speculative Generality** — abstractions, parameters, or hooks serve needs the spec doesn't have. → Delete them; inline back until a real need shows up.
- **Message Chains** — long `a.b().c().d()` navigation exposes structure the caller shouldn't know. → Hide the walk behind one method on the first object.
- **Middle Man** — a class or function mostly delegates onward. → Cut it and call the real target directly.
- **Refused Bequest** — a subclass or implementer ignores or overrides most inherited behavior. → Drop inheritance and use composition.

## Preferred Remedies

Delete a layer of indirection rather than polish it · reframe the state model so conditionals vanish · move the ownership boundary so the feature extends an existing abstraction · turn special cases into a simpler default · extract a pure helper · split a large file · replace condition chains with a typed model or dispatcher · separate orchestration from business logic · collapse duplicate branches · drop wrappers that don't clarify the API · reuse the canonical helper · make type boundaries explicit so control flow simplifies · parallelize / make atomic when it simplifies.

## Tone

Direct, serious, demanding — not rude. Don't soften major maintainability issues into mild suggestions. If the code makes the codebase messier, or missed a dramatic simplification, say so plainly. Useful phrasings:

- `this pushes the file past 1k lines. can we decompose first?`
- `another special-case branch in an already busy flow — move it behind its own abstraction?`
- `works, but makes the surrounding code more spaghetti. keep the behavior, restructure the implementation.`
- `feature logic leaking into a shared path. can we isolate it?`
- `this abstraction seems unnecessary — keep the direct flow?`
- `why a cast / optional here? make the boundary explicit instead?`
- `bespoke helper for something we already have. reuse the canonical one?`
- `i think there's a code-judo move here that makes these branches disappear.`
- `this refactor moves complexity around but doesn't delete it. can the model itself get simpler?`

## Output

Prioritize: (1) structural regressions, (2) missed code-judo simplifications, (3) spaghetti/branching growth, (4) boundary/abstraction/type problems, (5) file-size/decomposition, (6) modularity, (7) legibility. Few high-conviction comments, not a flood of cosmetic nits.

## Approval Bar

Correct behavior alone is not enough. Don't approve with any of: visible code-judo move left on the table, unjustified 1k-line crossing, new spaghetti branching, feature checks scattered across shared code, unnecessary wrapper/cast/optionality churn, or canonical-helper duplication / wrong-layer logic. Otherwise leave explicit, actionable feedback pushing for a cleaner decomposition.
