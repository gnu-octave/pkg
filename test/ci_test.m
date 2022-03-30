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
  
  ## Use builtin Octave pkg-toolkit to install new pkg-toolkit
  pkg ("install", pkg_dev_url);
  pkg load pkg

  ## Show configuration of pkg-tool.  MUST be command form for output!
  pkg config
  cd (old_dir);

  ## Call old pkg-tool tests
  tic;
  [~, ~, nfail] = test ("pkg_test_suite_old");
  t = toc ();
  if (nfail > 0)
    pkg_printf ([FAILED, "  pkg_test_suite_old in %.2f seconds.\n"], t);
    tic;
    test ("pkg_test_suite_old", "verbose");
    t = toc ();
    pkg_printf ([FAILED, "  pkg_test_suite_old in %.2f seconds.\n"], t);
    exit (-1);
  else
    pkg_printf ([PASSED, "  pkg_test_suite_old in %.2f seconds.\n"], t);
  endif

endfunction
