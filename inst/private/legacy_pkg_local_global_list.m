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
## @deftypefn {} {@var{list_file} =} legacy_pkg_local_global_list (@var{scope}, @var{list_file})
## Get or set the file containing the list of (locally/globally) packages.
##
## This is a legacy helper function to serve old pkg calls like below.
## The information "local_list" or "global_list" is given by the @var{scope}
## argument, one of "local" or "global".
##
## Getting the list file:
##
## @example
## @group
## list_file = pkg ("local_list")
## list_file = pkg ("global_list")
## @end group
## @end example
##
## and setting the list file:
##
## @example
## @group
## pkg local_list  "~/.octave_packages"
## pkg global_list "~/.octave_packages"
## @end group
## @end example
## @end deftypefn

function out_file = legacy_pkg_local_global_list (scope, list_file)

  if ((nargin < 1) || (nargin > 2) ...
      || ! any (strcmp (scope, {"local", "global"})))
    print_usage ();
  endif

  conf = pkg_config ();

  ## If setting of the list file is requested.
  if (nargin == 2)
    if (! ischar (list_file))
      error ("pkg: invalid list file");
    endif
    conf.(scope).list = list_file;
    conf = pkg_config (conf);
  endif

  if (nargout == 0)
    if (nargin == 1)
      disp (conf.(scope).list);
    endif
  else
    out_file = conf.(scope).list;
  endif

endfunction
