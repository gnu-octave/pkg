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
## @deftypefn {} {[@var{items}] =} db_forge_resolve (@var{items})
## Resolve package items with Octave Forge.
##
## Example: Resolve "io" and "image" package.
##
## @example
## @group
## items(1).id = "io";
## items(2).id = "image";
## items = db_forge_resolve (items)
## # items.id = {"io@2.6.4", "image@2.14.0"}
## # items.url = {"https://io-url", "https://image-url"}
## @end group
## @end example
## @end deftypefn

function items = db_forge_resolve (items)

  ## Octave Forge can only resolve package IDs without version.
  ## Most of the data is clear, only the most recent package version can
  ## be determined.

  for i = 1:numel (items)

    if (isempty (items(i).id))
      continue;
    endif

    ## Verify that name is valid.
    name = tolower (items(i).id);

    if (any (name == "@"));
      error (pkg_sprintf (["pkg>db_forge_resolve: the <blue>'-forge'", ...
      "</blue> package repository cannot resolve package versions.\n", ...
      "Try without <blue>'@1.2.3'</blue> suffix.\n"]));
    endif
    if (! any (strcmp (name, db_forge_list_packages ())));
      continue;
    endif

    ## Try to download package's index page.
    url = sprintf ("https://octave.sourceforge.io/%s/index.html", name);
    [html, succ] = urlread (url);
    if (! succ)
      error ("pkg>db_forge_resolve: could not read URL '%s'.", url);
    endif

    ## Remove blanks for simpler matching.
    html(isspace (html)) = [];
    ## Try to grep for the package version.
    pat = "<tdclass=""package_table"">PackageVersion:</td><td>([\\d.]*)</td>";
    ver = regexp (html, pat, "tokens");
    if (isempty (ver) || isempty (ver{1}))
      error (["pkg>db_forge_resolve: could not find latest version of ", ...
        "package '%s'."], name);
    endif

    items(i).id = sprintf ("%s@%s", name, ver{1}{1});
    items(i).url = sprintf ( ...
      "https://downloads.sourceforge.net/project/octave/Octave%%20Forge%%20Packages/Individual%%20Package%%20Releases/%s-%s.tar.gz",
      name, ver{1}{1});
  endfor

endfunction
