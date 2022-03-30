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
## @deftypefn  {} {} pkg_load (@var{package})
## @deftypefnx {} {} pkg_load (@option{-nodeps}, @dots{})
## Add a package to the Octave load path.
##
## After loading a package it is possible to use the functions provided by
## the package.  For example,
##
## @example
## @group
## pkg load image
## pkg load image@atchar{}2.14.0
## @end group
## @end example
##
## adds the "image"-package to the path.
##
## Note: When loading a package, @code{pkg} will automatically try to load
## any unloaded dependencies as well, unless the @option{-nodeps} flag has
## been specified.
##
## Be aware that the functionality of package(s) loaded will probably be
## impacted by use of the @option{-nodeps} flag.  Even if necessary
## dependencies are loaded later, the functionality of top-level packages
## can still be affected because the optimal loading order may not have been
##followed.
## @end deftypefn

function pkg_load (varargin)

  pkg_config ();

  params = parse_parameter ({"-nodeps"}, varargin{:});
  if (! isempty (params.error))
    error ("pkg_load: %s\n\n%s\n\n", params.error, help ("pkg_load"));
  endif

  if (isempty (params.in))
    print_usage ();
  endif

  installed_pkgs_lst = pkg_list ();
  num_packages = length (installed_pkgs_lst);

  ## Read package names and installdirs into a more convenient format.
  pnames = cellfun (@(x) x.name, installed_pkgs_lst, "UniformOutput", false);
  pvers = cellfun (@(x) x.version, installed_pkgs_lst, "UniformOutput", false);
  pids = strcat (pnames, "@", pvers);
  pdirs = cellfun (@(x) x.dir, installed_pkgs_lst, "UniformOutput", false);

  idx = [];
  for i = 1:length (params.in)
    if (any (params.in{i} == "@"))
      idx2 = find (strcmp (pids, params.in{i}));
    else
      ## If only name given "pkg load io", take newest version.
      idx2 = find (strcmp (pnames, params.in{i}), 1, "last");
    endif
    if (! any (idx2))
      error (pkg_sprintf (["package <blue>'%s'</blue> is not installed.", ...
        "\n\nRun <blue>'pkg list'</blue> to see all installed packages ", ...
        "and versions.\n"], params.in{i}));
    endif
    idx(end + 1) = idx2;
  endfor

  ## Ensure ordering of dependencies before their dependers.
  idx = determine_load_order (idx, [], ! params.flags.("-nodeps"), ...
                              installed_pkgs_lst);

  dirs = {};
  execpath = EXEC_PATH ();
  for i = idx
    desc = installed_pkgs_lst{i};
    desc.archdir = fullfile (desc.archprefix, [pkg_config()].arch);
    ndir = desc.dir;
    dirs{end+1} = ndir;
    if (compat_isfolder (fullfile (dirs{end}, "bin")))
      execpath = [execpath pathsep() fullfile(dirs{end}, "bin")];
    endif
    if (compat_isfolder (desc.archdir))
      dirs{end + 1} = desc.archdir;
      if (compat_isfolder (fullfile (dirs{end}, "bin")))
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

  ## FIXME: Octave 7?
  ## Update lexer for autocompletion if necessary
  #if (isguirunning && (length (idx) > 0))
  #  __event_manager_update_gui_lexer__;
  #endif

endfunction


function idx = determine_load_order (lidx, idx, handle_deps, installed_pkgs_lst)

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
          idx = determine_load_order (tmplidx, idx, handle_deps,
                                      installed_pkgs_lst);
        endif
      endif
    endif
  endfor

endfunction
