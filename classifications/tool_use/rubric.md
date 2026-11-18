If the item is about a tool itself (a new feature, package or interface for that tool), the tool is `used`.

Judge the authors' own work, not the background, the literature they cite or future work.

When the text names a tool but does not say what was done with it, the tool is `mentioned`.

Clarifications (Niclas, 2026-10-18, after the blind check of version 2):

- A tool the authors run only to produce the reference results that their new method is compared with (simulations giving the empirical power for an analytical method, standard errors from SAEM as the reference for an approximation) is `comparator`, not `used`.
- Software the authors built around a tool, without running an analysis in it (a package that reads or plots its outputs, a toolkit for its workflow, a computing platform on which it is installed and run), counts as `used` for that tool.

Hard cases settled in the checks of versions 3 and 4 (version 5):

- A candidate counts through any member of its family that the text names (WinBUGS or JAGS for BUGS, Stan for Stan/Torsten, ADAPT 5 for S-ADAPT).
- A tool run through a wrapper or workflow tool (PsN running NONMEM, a package that writes the control files and runs them) is `used`.
- A second tool run only to check the main results is a reference run: `comparator`.
- A tool named only as something a planned framework will support, or as one of the applications a general platform can connect to, is `mentioned`, unless the authors' software is built around it.
- When a tool is both the platform of the authors' new software and the benchmark it is compared with, built around wins: `used`.
