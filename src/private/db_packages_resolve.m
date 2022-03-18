########################################################################
##
## Copyright (C) 2022 The Octave Project Developers
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
## @deftypefn {} {[@var{urls}, @var{ids}, @var{checksums}] =} db_packages_resolve (@var{names})
## Resolve packages by name from Octave Packages.
##
## Example: Resolve "io" package.
##
## @example
## @group
## [urls, ids, checksums] = db_packages_resolve ({"io"})
## urls = {"https://downloads.sourceforge.net/project/octave/Octave%20Forge%20Packages/Individual%20Package%20Releases/io-2.6.3.tar.gz"}
## ids = {"io@2.6.3"}
## checksums = {}
## @end group
## @end example
## @end deftypefn

function items = db_packages_resolve (items, params)

  ## available_packages: Nx1 cell array of strings
  ## checksums:          Nx3 cell array of strings of the format
  ##                     {checksum, url, id (name@version)}
  ## index:              Raw Octave packages index structure from
  ##                     https://gnu-octave.github.io/packages/packages/
  [available_packages, checksums, index] = db_packages_list_packages ();

  ## Round 1: Improve user input.
  for i = 1:numel (items)

    ## Complete ID to first version, e.g. "io" to "io@1.2.3".
    items(i).id = tolower (items(i).id);
    if (! any (items(i).id == "@") ...
        && any (strcmp (items(i).id, available_packages)))
      versions = getfield (getfield (index, items(i).id), "versions");
      items(i).id = [items(i).id, "@", versions(1).id];
    endif

    ## Find item in Octave Packages index.
    idx_match = false (size (checksums(:,1)));
    if (! isempty (items(i).checksum))
      idx_match |= strcmp (items(i).checksum, checksums(:,1));
    endif
    if (! isempty (items(i).url))
      idx_match |= strcmp (items(i).url, checksums(:,2));
    endif
    if (! isempty (items(i).id))
      idx_match |= strcmp (items(i).id, checksums(:,3));
    endif

    ## We don't know the package: nothing we can do.
    if (! any (idx_match));
      continue;
    endif

    ## Input has multiple matches.  Stop ask user to be more precise.
    if (sum (idx_match) > 1);
      printf ("pkg_install>db_packages_resolve: multiple matches for input:\n");
      printf (["\t%s:\n\t\tchecksum: '%s'", ...
                    "\n\t\turl:      '%s'\n"], checksums'{[1,3,2],:});
      error ("pkg_install>db_packages_resolve: multiple matches for input.");
    endif

    ## Improve and validate user input.
    if (isempty (items(i).checksum))
      items(i).checksum = checksums{idx_match, 1};
    else
      if (! strcmp (items(i).checksum, checksums{idx_match, 1}))
        printf ("      ");
        pkg_printf ({"warn"});
        printf (" ");
        printf (["invalid checksum of '%s'.", ...
          "\n\tactual:   '%s'\n", ...
          "\n\texpected: '%s'\n"],
          items(i).id, items(i).checksum, checksums{idx_match, 1});
      endif
    endif
    if (isempty (items(i).url))
      items(i).url = checksums{idx_match, 2};
    endif
    if (isempty (items(i).id))
      items(i).id = checksums{idx_match, 3};
    else
      if (! strcmp (items(i).id, checksums{idx_match, 3}))
        printf ("      ");
        pkg_printf ({"warn"});
        printf (" ");
        printf (["invalid package name and version.\n", ...
          "Expected '%s', but found '%s'.\n"], ...
          checksums{idx_match, 3}, items(i).id);
      endif
    endif
  endfor

endfunction
