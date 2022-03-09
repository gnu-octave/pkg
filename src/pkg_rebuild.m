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
## @deftypefn {} {@var{descriptions} =} pkg_rebuild (@var{prefix}, @var{archprefix}, @var{files}, @var{verbose})
## Rebuild the package database from the installed directories.  This can
## be used in cases where the package database has been corrupted.
## @end deftypefn

function pkg_rebuild (varargin)

  pkg_startup_hook ();

  if (global_install)
    global_packages = pkg_rebuild_internal (prefix, archprefix, files, verbose);
    global_packages = save_order (global_packages);
    if (ispc)
      ## On Windows ensure LFN paths are saved rather than 8.3 style paths
      global_packages = standardize_paths (global_packages);
    endif
    global_packages = make_rel_paths (global_packages);
    save (global_list, "global_packages");
    if (nargout)
      local_packages = global_packages;
    endif
  else
    local_packages = pkg_rebuild_internal (prefix, archprefix, files, verbose);
    local_packages = save_order (local_packages);
    if (ispc)
      local_packages = standardize_paths (local_packages);
    endif
    save (local_list, "local_packages");
    if (! nargout)
      clear ("local_packages");
    endif
  endif

endfunction


function descriptions = pkg_rebuild_internal (prefix, archprefix, files, verbose)

  if (isempty (files))
    if (! exist (prefix, "dir"))
      dirlist = [];
    else
      [dirlist, err, msg] = readdir (prefix);
      if (err)
        error ("couldn't read directory %s: %s", prefix, msg);
      endif
      ## the two first entries of dirlist are "." and ".."
      dirlist([1,2]) = [];
    endif
  else
    old_descriptions = pkg_list ();
    wd = pwd ();
    unwind_protect
      cd (prefix);
      if (ispc ())
        dirlist = __wglob__ (strcat (files, '-*'));
      else
        dirlist = glob (strcat (files, '-*'));
      endif
    unwind_protect_cleanup
      cd (wd);
    end_unwind_protect
  endif

  descriptions = {};
  for k = 1:length (dirlist)
    descfile = fullfile (prefix, dirlist{k}, "packinfo", "DESCRIPTION");
    if (verbose)
      printf ("recreating package description from %s\n", dirlist{k});
    endif
    if (exist (descfile, "file"))
      desc = get_description (descfile);
      desc.dir = fullfile (prefix, dirlist{k});
      desc.archprefix = fullfile (archprefix, [desc.name "-" desc.version]);
      descriptions{end + 1} = desc;
    elseif (verbose)
      warning ("directory %s is not a valid package", dirlist{k});
    endif
  endfor

  if (! isempty (files))
    ## We are rebuilding for a particular package(s) so we should take
    ## care to keep the other untouched packages in the descriptions
    descriptions = {descriptions{:}, old_descriptions{:}};

    dup = [];
    for i = 1:length (descriptions)
      if (any (dup == i))
        continue;
      endif
      for j = (i+1):length (descriptions)
        if (any (dup == j))
          continue;
        endif
        if (strcmp (descriptions{i}.name, descriptions{j}.name))
          dup = [dup, j];
        endif
      endfor
    endfor
    if (! isempty (dup))
      descriptions(dup) = [];
    endif
  endif

endfunction
