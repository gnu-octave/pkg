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
## @deftypefn {}  {@var{descriptions} =} pkg_rebuild (@var{files})
## @deftypefnx {} {} pkg_rebuild (@option{-verbose})
## @deftypefnx {} {} pkg_rebuild (@option{-global})
## Rebuild the package list from the (arch)prefix directories.
##
## This can be used in cases where the package list has been corrupted
## and installed packages cannot be found by the pkg-tool.
##
## Use @option{-verbose} to get more verbose output.
##
## Use @option{-global} to rebuild the global package list.  This might
## require elevated (system administrator) rights.
## @end deftypefn

function packages = pkg_rebuild (varargin)

  config = pkg_config ();

  params = parse_parameter ({"-verbose", "-global"}, varargin{:});
  if (! isempty (params.error))
    error ("pkg_rebuild: %s\n\n%s\n\n", params.error, help ("pkg_rebuild"));
  endif
  files = params.in;

  if (params.flags.("-global"))
    if (! config.has_elevated_rights)
      warning (["pkg_rebuild: '-global' was used without having elevated ", ...
        "(system administrator) rights.  The following operation is ", ...
        "likely to fail.\n"]);
    endif
    scope = "global";
  else
    scope = "local";
  endif

  if (ispc ())
    oct_glob = @__wglob__;
  else
    oct_glob = @glob;
  endif

  if (isempty (files))
    dirlist = oct_glob (fullfile (config.(scope).prefix, "*"));
  else
    dirlist = oct_glob (fullfile (config.(scope).prefix, strcat (files, '*')));
  endif

  if (isempty (dirlist))
    error ("pkg_rebuild: could not read directory '%s'\n", ...
      config.(scope).prefix);
  endif

  descriptions = {};
  if (params.flags.("-verbose"))
    printf ("Recreating package list from directories:\n\n");
  endif
  for k = 1:length (dirlist)
    descfile = fullfile (dirlist{k}, "packinfo", "DESCRIPTION");
    if (params.flags.("-verbose"))
      pkg_printf ("  <blue>'%s'</blue>\n", dirlist{k});
    endif
    if (exist (descfile, "file"))
      ## Read the DESCRIPTION file.
      desc = get_description (descfile);

      ## Use found installation directory.
      desc.dir = dirlist{k};

      ## Set default architecture dependent installation directory.
      desc.archprefix = fullfile (config.(scope).archprefix, [desc.name "@" desc.version]);
      desc.archdir    = fullfile (desc.archprefix, config.arch);

      descriptions{end + 1} = desc;
    elseif (params.flags.("-verbose"))
      warning ("    Directory '%s' does not contain a valid package", ...
        dirlist{k});
    endif
  endfor
  disp (" ");

  if (! isempty (files))
    ## We are rebuilding for a particular package(s) so we should take
    ## care to keep the other untouched packages in the descriptions
    old_descriptions = pkg_list ();
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


  descriptions = sort_dependencies_first (descriptions);
  descriptions = standardize_paths (descriptions);

  if (params.flags.("-global"))
    global_packages = descriptions;
    save (config.global.list, "global_packages");
  else
    local_packages = descriptions;
    save (config.local.list, "local_packages");
  endif

  if (nargout)
    packages = descriptions;
  endif

endfunction
