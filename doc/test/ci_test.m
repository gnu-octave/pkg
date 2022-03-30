########################################################################
##
## Copyright (C) 2022 The Octave Project Developers
##
## See the file COPYRIGHT.md in the top-level directory of this
## distribution or <https://octave.org/copyright/>.
##
## This file is part of Octave.
##
## Octave is free software: you can redistribute it and/or modify it
## under the terms of the GNU General Public License as published by
## the Free Software Foundation, either version 3 of the License, or
## (at your option) any later version.
##
## Octave is distributed in the hope that it will be useful, but
## WITHOUT ANY WARRANTY; without even the implied warranty of
## MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
## GNU General Public License for more details.
##
## You should have received a copy of the GNU General Public License
## along with Octave; see the file COPYING.  If not, see
## <https://www.gnu.org/licenses/>.
##
########################################################################

function ci_test ()

  c_red    = '\033[38;5;1m';
  c_green  = '\033[38;5;2m';
  c_normal = '\033[0m';
  PASSED = [c_green, "PASSED", c_normal];
  FAILED = [c_red,   "FAILED", c_normal];
  pkg_dev_url = ...
    "https://github.com/gnu-octave/pkg/archive/refs/heads/main.tar.gz";

  ## Use builtin Octave pkg-toolkit to install new pkg-toolkit.
  ## For customized pkg settings in `~/.octaverc` call after each step:
  ##   source ("~/.octaverc");
  pkg ("install", pkg_dev_url);
  pkg ("load", "pkg");

  #####################################
  ## New pkg-tool takes over command.
  #####################################

  ## Check if setting startup hook works.
  pkg_config ("-add-startup-hook");

  ## Show configuration of pkg-tool.  MUST be command form for output!
  pkg config

  ##############
  ## Run Tests
  ##############

  ## Call old pkg-tool tests
  config = pkg_config ();
  test_dir = fullfile (config.pkg_dir, "doc", "test");
  unwind_protect
    old_dir = cd (test_dir);
    tic;
    [~, ~, nfail] = test ("pkg_test_suite_old");
    t = toc ();
    if (nfail > 0)
      printf ([FAILED, "  'pkg_test_suite_old' in %.2f seconds.\n"], t);
      tic;
      test ("pkg_test_suite_old", "verbose");
      t = toc ();
      printf ([FAILED, "  'pkg_test_suite_old' in %.2f seconds.\n"], t);
      exit (-1);
    else
      printf ([PASSED, "  'pkg_test_suite_old' in %.2f seconds.\n"], t);
    endif
  unwind_protect_cleanup
    cd (old_dir);
  end_unwind_protect

  ###########################
  ## Uninstall new pkg-tool.
  ###########################
  pkg_config ("-remove-startup-hooks");
  pkg_unload ("pkg");
  
  ## Finally with the builtin pkg-tool
  ## For customized pkg settings in `~/.octaverc` call now:
  ##   source ("~/.octaverc");
  pkg ("uninstall", "pkg");

endfunction
