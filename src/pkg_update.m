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
## @deftypefn {} {} pkg_update (@var{files}, @var{handle_deps})
## Check installed Octave packages against repository and update any
## outdated items.  This requires an internet connection.
## Usage:
##
## @example
## pkg update
## @end example
##
## @noindent
## To update a single package use the @code{pkg install} command.
## @end deftypefn

function pkg_update (varargin)

  pkg_config ();

  installed_pkgs_lst = pkg_list ();

  ## Explicit list of packages to update, rather than all packages
  if (numel (files) > 0)
    update_lst = {};
    installed_names = cellfun (@(idx) idx.name, installed_pkgs_lst,
                               "UniformOutput", false);
    for i = 1:numel (files)
      idx = find (strcmp (files{i}, installed_names), 1);
      if (isempty (idx))
        warning ("pkg: package %s is not installed - skipping update",
                 files{i});
      else
        update_lst = [ update_lst, installed_pkgs_lst(idx) ];
      endif
    endfor
    installed_pkgs_lst = update_lst;
  endif

  for i = 1:numel (installed_pkgs_lst)
    installed_pkg_name = installed_pkgs_lst{i}.name;
    installed_pkg_version = installed_pkgs_lst{i}.version;
    try
      forge_pkg_version = get_forge_pkg (installed_pkg_name);  ## not necessary
    catch
      warning ("pkg: package %s not found on Octave Forge - skipping update\n",
               installed_pkg_name);
      forge_pkg_version = "0";
    end_try_catch
    if (compare_versions (forge_pkg_version, installed_pkg_version, ">"))
      feval (@pkg, "install", "-forge", installed_pkg_name);
    endif
  endfor

endfunction
