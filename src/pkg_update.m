########################################################################
##
## Copyright (C) 2005-2022 The Octave Project Developers
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

## -*- texinfo -*-
## @deftypefn {} {} pkg_update (@var{package})
## Update a given or all installed packages to the latest available version.
##
## With arguments given, this function is identical to @code{pkg_install}.
## @see{pkg_install}
## @end deftypefn

function pkg_update (varargin)
  ## Most of the work is done by pkg_install.

  ## No input or only flags: update all installed packages.
  if (! nargin || all (cellfun (@(s) (s(1) == "-"), varargin)))
    pkg_names = cellfun (@(p) p.name, pkg_list (), "UniformOutput", false);
    pkg_install (varargin{:}, pkg_names{:});
  else
    pkg_install (varargin{:});
  endif

endfunction
