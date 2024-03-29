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
## @deftypefn {} {@var{bad_deps} =} get_unsatisfied_deps (@var{desc}, @var{installed_pkgs_lst})
## Get a list of unsatistied dependencies for a package.
## @end deftypefn

function bad_deps = get_unsatisfied_deps (desc, installed_pkgs_lst)

  bad_deps = {};

  ## For each dependency.
  for i = 1:length (desc.depends)
    dep = desc.depends{i};

    ## Is the current dependency Octave?
    if (strcmp (dep.package, "octave"))
      if (! compare_versions (OCTAVE_VERSION, dep.version, dep.operator))
        bad_deps{end+1} = dep;
      endif
    else
      ok = false;
      for i = 1:length (installed_pkgs_lst)
        if (strcmp (dep.package, installed_pkgs_lst{i}.name) ...
            && compare_versions (installed_pkgs_lst{i}.version, ...
                                 dep.version, dep.operator))
          ok = true;
          break;
        endif
      endfor
      if (! ok)
        bad_deps{end+1} = dep;
      endif
    endif
  endfor

endfunction
