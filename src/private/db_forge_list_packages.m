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
## @deftypefn {} {[@var{url}, @var{id}] =} db_forge_resolve (@var{name})
## Resolve a package from Octave Forge.
##
## Example: Resolve "io" package.
##
## @example
## @group
## [url, id] = db_forge_resolve ("io")
## url = "https://downloads.sourceforge.net/project/octave/Octave%20Forge%20Packages/Individual%20Package%20Releases/io-2.6.3.tar.gz"
## id = "io-2.6.3.tar.gz"
## @end group
## @end example
## @end deftypefn

function available_packages = db_forge_list_packages ()

  persistent packages = {};

  ## Do not get removed from memory, even if "clear" is called.
  mlock ();

  if (! isempty (packages))
    available_packages = packages;
    return;
  endif

  ## Try once per Octave session to get the list of all packages.
  [html, succ] = urlread ("https://octave.sourceforge.io/list_packages.php");
  if (! succ)
    error (["pkg > db_forge_list_packages: could not read URL, ", ...
      "please verify internet connection"]);
  endif
  packages = strsplit (html);

  available_packages = packages;

endfunction
