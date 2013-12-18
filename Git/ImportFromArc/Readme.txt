Purpose:
  Just for fun

Abstract:
  Thought, it would be nice to have full ConEmu's development
  history in one local GIT repository...
  Well, I have all source archives and can create history
  step-by-step unpacking them and creating commits...
  But archives are containing not only sources, but some
  debug stuff, sometimes experiment cpp files, or other rubbish.

How to:
  run_all.cmd is main entry point. It takes archives one-by-one:
  C:\Projects\ConEmu-Deploy\Pack\imp_src\*.7z
  Unpack them to the folder:
  C:\Projects\Test\mrg3\
  And with git & powershell script looks what was changed.
  Ask user confirmation about ADDING new items with choices:
    add/skip/rescan/quit  (it also beeps to attract attention)
    I can easily remove rubbish in the other ConEmu tab.
  Also, sometimes there was two files per release, script takes
  care about that (e.g. ConEmu.090324b.7z, ConEmu.090324b.src.7z).

Interesting:
  I also want to get "real" dates of commits (2009 year, yes?),
  but I can't find a way to do that with GIT options...
  No problem, there is ConEmuFakeDT env.var, look at go.cmd.

Result:
  Wow, clean commit tree from old archives.
  Import history from googlecode SVN... next step.
