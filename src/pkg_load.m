########################################################################
##
## Copyright (C) 2005-2021 The Octave Project Developers
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
## @deftypefn {} {} pkg_load (@var{files}, @var{handle_deps})
## Undocumented internal function.
## @end deftypefn

function pkg_load (files, handle_deps)

  if (isempty (files))
    error ("pkg: load action requires at least one package name");
  endif

  installed_pkgs_lst = pkg_list ();
  num_packages = length (installed_pkgs_lst);

  ## Read package names and installdirs into a more convenient format.
  pnames = pdirs = cell (1, num_packages);
  for i = 1:num_packages
    pnames{i} = installed_pkgs_lst{i}.name;
    pdirs{i} = installed_pkgs_lst{i}.dir;
  endfor

  idx = [];
  for i = 1:length (files)
    idx2 = find (strcmp (pnames, files{i}));
    if (! any (idx2))
      error ("package %s is not installed", files{i});
    endif
    idx(end + 1) = idx2;
  endfor

  ## Load the packages, but take care of the ordering of dependencies.
  load_packages_and_dependencies (idx, handle_deps, installed_pkgs_lst, true);

endfunction


function load_packages_and_dependencies (idx, handle_deps, installed_pkgs_lst,
                                         global_install)

  idx = load_package_dirs (idx, [], handle_deps, installed_pkgs_lst);
  dirs = {};
  execpath = EXEC_PATH ();
  for i = idx
    desc = installed_pkgs_lst{i};
    desc.archdir = fullfile (desc.archprefix, getarch ());
    ndir = desc.dir;
    dirs{end+1} = ndir;
    if (isfolder (fullfile (dirs{end}, "bin")))
      execpath = [execpath pathsep() fullfile(dirs{end}, "bin")];
    endif
    if (isfolder (desc.archdir))
      dirs{end + 1} = desc.archdir;
      if (isfolder (fullfile (dirs{end}, "bin")))
        execpath = [execpath pathsep() fullfile(dirs{end}, "bin")];
      endif
    endif
  endfor

  ## Dependencies are sorted before their dependers in "dirs". Add them
  ## consecutively in a for loop to the path to make sure dependencies are
  ## added before their dependers (bug #57403).
  for ii = 1:numel (dirs)
    addpath (dirs{ii});
  endfor

  ## Add the binaries to exec_path.
  if (! strcmp (EXEC_PATH, execpath))
    EXEC_PATH (execpath);
  endif

  ## Update lexer for autocompletion if necessary
  if (isguirunning && (length (idx) > 0))
    __event_manager_update_gui_lexer__;
  endif

endfunction


function idx = load_package_dirs (lidx, idx, handle_deps, installed_pkgs_lst)

  for i = lidx
    if (isfield (installed_pkgs_lst{i}, "loaded")
        && installed_pkgs_lst{i}.loaded)
      continue;
    else
      ## Insert this package at the front before recursing over dependencies.
      if (! any (idx == i))
        idx = [i, idx];
      endif

      if (handle_deps)
        deps = installed_pkgs_lst{i}.depends;
        if ((length (deps) > 1)
            || (length (deps) == 1 && ! strcmp (deps{1}.package, "octave")))
          tmplidx = [];
          for k = 1 : length (deps)
            for j = 1 : length (installed_pkgs_lst)
              if (strcmp (installed_pkgs_lst{j}.name, deps{k}.package))
                if (! any (idx == j))
                  tmplidx(end + 1) = j;
                  break;
                endif
              endif
            endfor
          endfor
          idx = load_package_dirs (tmplidx, idx, handle_deps,
                                 installed_pkgs_lst);
        endif
      endif
    endif
  endfor

endfunction
