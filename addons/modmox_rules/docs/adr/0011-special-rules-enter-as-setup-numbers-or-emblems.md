# Boss rules and character statuses enter only as setup numbers or Emblems

The engine has no special-case flags for particular encounters or character statuses. The game side turns them into one of two things before the encounter starts. Starting conditions (life totals, opening hand size, free mulligans, who goes first) are resolved into final numbers in the Encounter Setup, so a "Forgetful" Hero simply has an opening hand size of 6. Anything that bends the rules during play becomes an Emblem built from the ordinary card primitives, so it passes through the same layers, triggers and replacement effects as cards and cannot behave unpredictably. The engine never knows that statuses or bosses exist.

Who starts is part of the setup too. By default a coin flip (Game RNG) picks which player chooses to play or draw, as in CR 103.1. The setup can instead name the chooser, or force the Hero or Villain to start, which is how a Status or Villain ability that "always plays first" is expressed.
