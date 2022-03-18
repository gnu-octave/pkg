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

  #################################
  ## Round 1: Improve user input.
  #################################

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

  ## Give up if something could not fully be resolved.
  if (any (cellfun (@isempty, {items.url})))
    return;
  endif


  ###################################
  ## Round 2: resolve dependencies.
  ###################################

  ## Remove duplicates
  [~, idx] = unique ({items.id}, "stable");
  items = items(idx);

  ## Get list of packages and treat Octave as such.
  installed_packages = pkg_list ();
  installed_package_names    = ["octave", ...
                                cellfun(@(x) x.name,    installed_packages, ...
                                       "UniformOutput", false)];
  installed_package_versions = [OCTAVE_VERSION, ...
                                cellfun(@(x) x.version, installed_packages, ...
                                        "UniformOutput", false)];

  ## If not forced installation, unlist already installed packages.
  if (! params.flags.("-force"))
    for i = 1:numel (installed_package_names)
      other_id = [installed_package_names{i}, "@", ...
                  installed_package_versions{i}];
      items(strcmp ({items.id}, other_id)) = [];
    endfor
  endif

  ## Forcing treats resolver errors as warnings
  if (params.flags.("-force"))
    reserr = @warning;
  else
    reserr = @error;
  endif

  ## Add dependencies to resolve, e.g. "octave (>= 4.2.0)"
  for i = 1:numel (items)
    items(i).deps = cell (0, 3);  ## {"octave", ">=", "4.2.0"}

    [name, version] = splitid (items(i).id);
    versions = getfield (getfield (index, name), "versions");
    deps = {versions(strcmp ({versions.id}, version)).depends.name};

    ## FIXME: ignore dependency "pkg" for now.
    deps(strcmp (deps, "pkg")) = [];

    for j = 1:numel(deps)
      [dep_name, dep_op] = strtok (deps{j});
      dep_op = strtrim (dep_op);
      if (! isempty (dep_op) && length (dep_op) > 2)
        dep_op = dep_op(2:end-1);  # remove braces, e.g. "(>= 4.2.0)"
        [dep_op, dep_ver] = strtok (dep_op);
        dep_ver = strtrim (dep_ver);
      else
        dep_op = "";
        dep_ver = "";
      endif
      items(i).deps(end+1,:) = {dep_name, dep_op, dep_ver};
    endfor
  endfor

  ## Iterative resolving.
  ## FIXME: add new dependencies, regard "-nodeps"
  ## FIXME: circular dependency detection.
  max_iter = 100;
  for j = 1:max_iter

    [stack_package_names, stack_package_versions] = splitid ({items.id});

    for i = 1:numel (items)
      deps = items(i).deps;
      done = false (size(deps, 1), 1);
      do_swap = false;
      swap = 1:numel (items);
      for k = 1:size(deps, 1)
        dep_name = deps{k,1};
        dep_op = deps{k,2};
        dep_ver = deps{k,3};

        ## Satisfied by already installed package?
        idx = strcmp (dep_name, installed_package_names);
        if (any (idx))
          if (! isempty (dep_op) && ! isempty (dep_ver))
            if (compare_versions (installed_package_versions{find(idx, 1)}, ...
              dep_ver, dep_op))
              done(k) = true;
            endif
          else
            done(k) = true;
          endif
        endif

        ## Satisfied by another package that will be installed?
        idx = strcmp (dep_name, stack_package_names);
        if (any (idx))
          if (! isempty (dep_op) && ! isempty (dep_ver))
            match = find(idx, 1);
            if (compare_versions (stack_package_versions{match}, ...
              dep_ver, dep_op))
              done(k) = true;
              ## dependency should be left of item
              if (match > i)
                do_swap = true;
                swap(match) = [];
                swap = [swap(1:i-1), match, swap(i:end)];
                break;
              endif
            endif
          else
            done(k) = true;
            ## dependency should be left of item
            if (match > i)
              do_swap = true;
              swap(match) = [];
              swap = [swap(1:i-1), match, swap(i:end)];
              break;
            endif
          endif
        endif

      endfor
      items(i).deps(done,:) = [];
      if (do_swap)
        items = items(swap);
        break;
      endif
    endfor

    ## All dependencies are resolved =)
    if (isempty ({items.deps}))
      return;
    endif

  endfor

  {items.deps}
  reserr ("Could not resolve all dependencies");

endfunction


function [name, ver] = splitid (id)
  [name, ver] = strtok (id, "@");
  if (iscellstr (ver))
    ver = cellfun (@(x) x(2:end), ver, "UniformOutput", false);
  else
    ver = ver(2:end);
  endif
endfunction
