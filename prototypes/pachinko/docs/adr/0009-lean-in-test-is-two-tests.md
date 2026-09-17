---
status: accepted
---

# The Lean-in Test is two tests, and a failure only condemns this presentation

A single acceptance run at design values cannot answer the question the prototype is asking, for a reason that is arithmetic rather than methodological. A 333-spin session sees SP on average 4.2 times, but the draws are independent: roughly **one session in five produces fewer than three sightings**. Run one session, see two SPs, and there is nothing to judge — and no way to tell that from a presentation that failed to hold attention.

A single run also conflates two different questions. Whether the black hole takeover is legible and tense is a property of the sequence itself. Whether the wait was worth it is a property of the interval between sequences. The first can be observed in a minute; the second only exists at design values across a whole session.

So the test splits:

- **Sequence test** — fixed seed, forced paths, SP jackpot / SP miss / normal-stop played three times each in an interleaved order. Repeatable by construction, which is what makes it the only valid way to compare one revision of the presentation against another.
- **Session test** — design values, fixed standard machine, played until the third SP appears. This is where the wait is judged, and it is the one that cannot be shortened or knob-adjusted without destroying what it measures.

Four observations, not one. The player leans in or holds their breath; they can say what was missing after a miss; the third SP still holds them the way the first did; they want to keep going after losing. Leaning in on the first sighting and not the third is a specific and useful failure, and a single-criterion test cannot see it.

The other half of this decision is what a failure is allowed to conclude. ADR 0003 removes art quality as a variable, and it is tempting to read the remaining failure as "this needs characters". It does not follow. Pacing, legibility and feedback strength are all still live variables, and all three are adjustable without drawing anything. **A failed test condemns this revision of the presentation.** Only after the seconds-level pacing table, the escalation window and the audio feedback have each been revised and the test still fails does the conclusion reach the abstract vocabulary itself.
