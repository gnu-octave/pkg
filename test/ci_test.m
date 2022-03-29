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

  ## Configure pkg-tool
  pkg_config

  ## Call old pkg-tool tests
  [~, ~, nfail] = test ("pkg_test_suite_old");
  if (nfail > 0)
    printf ([c_red, "FAILED: pkg_test_suite_old", c_normal]);
    test ("pkg_test_suite_old", "verbose");
    printf ([c_red, "FAILED: pkg_test_suite_old", c_normal]);
    exit (-1);
  else
    printf ([green, "PASSED: pkg_test_suite_old", c_normal])
  endif

endfunction
