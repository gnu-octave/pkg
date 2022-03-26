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
        pkg_printf (["      <warn> invalid checksum of '%s'.", ...
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
        pkg_printf (["      <warn> invalid package name and version.\n", ...
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

  ## Maybe nothing to do?
  if (isempty (items))
    return;
  endif

  ## Forcing treats resolver errors as warnings
  if (params.flags.("-force"))
    reserr = @warning;
  else
    reserr = @error;
  endif

  ## Add dependencies to resolve, e.g. {"octave", ">=", "4.2.0"}
  for i = 1:numel (items)
    items(i).deps = get_dependencies (items(i), index);
  endfor

  ## Iterative resolving.
  max_iter = 100;
  for j = 1:max_iter

    [stack_package_names, stack_package_versions] = splitid ({items.id});

    for i = 1:numel (items)
      deps = items(i).deps;
      done = false (size(deps, 1), 1);
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
              continue;
            endif
          else
            done(k) = true;
            continue;
          endif
        endif

        ## Satisfied by another package that will be installed?
        idx = strcmp (dep_name, stack_package_names);
        if (any (idx))
          if (! isempty (dep_op) && ! isempty (dep_ver))
            match = find(idx, 1);
            if (compare_versions (stack_package_versions{match}, ...
              dep_ver, dep_op))
              items(match).needed_by{end+1} = items(i).id;
              done(k) = true;
              continue;
            endif
          else
            items(match).needed_by{end+1} = items(i).id;
            done(k) = true;
            continue;
          endif
        endif

      endfor
      items(i).deps(done,:) = [];
    endfor

    ## Detect circular dependencies.
    for i = 1:numel (items)
      if (exist_circular_dependency (items, i, i))
        reserr (["pkg_install>db_packages_resolve: Circular dependency ", ...
          "detected for '%s'."], items(i).id);
        return;
      endif
    endfor

    ## Reorder dependencies to the left (installed first).
    ## Takes at worst `numel(items)` rounds.
    for i = 1:numel (items)
      do_swap = false;
      swap = 1:numel (items);
      for k = 1:numel (items)
        if (isempty (items(k).needed_by))
          continue;
        endif
        id = min (cellfun (@(x) find (strcmp (x, {items.id}), 1), ...
                           items(k).needed_by));
        if (id < k)  # Dependency is on the right.
          do_swap = true;
          swap(swap == k) = [];
          swap = [swap(1:id-1), k, swap(id:end)];
        endif
      endfor
      if (do_swap)
        items = items(swap);
      else
        break;
      endif
    endfor

    ## All dependencies are resolved?  Then done =)
    if (all (cellfun (@isempty, {items.deps})))
      rmfield (items, "deps");
      return;
    endif

    ## Try to find packages, that satisfies remaining dependencies.
    if (! params.flags.("-nodeps"))
      ## Analyze of same package dependencies, e.g. io >= and <=.
      pkg_to_find.name = "";
      pkg_to_find.versions = {};
      pkg_to_find.v = [];

      for i = 1:numel (items)
        ## Nothing to do?
        if (isempty (items(i).deps))
          continue;
        endif

        ## If no dependency is looked for yet.
        if (isempty (pkg_to_find.name))
          pkg_to_find.name = items(i).deps{1,1};
          if (! isfield (index, pkg_to_find.name))
            break;  ## Dependency cannot be resolved.
          endif
          pkg_to_find.versions = getfield (getfield ( ...
            index, pkg_to_find.name), "versions");
          pkg_to_find.versions = {pkg_to_find.versions.id};
          pkg_to_find.feasible = true (size (pkg_to_find.versions));
        endif

        ## Narrow down feasible version of pkg_to_find.
        for k = find (strcmp (pkg_to_find.name, {items(i).deps{:,1}}))
          pkg_to_find.feasible = pkg_to_find.feasible & ...
            cellfun (@(x) compare_versions (x, items(i).deps{k,3}, ...
              items(i).deps{k,2}), pkg_to_find.versions);
        endfor
      endfor

      ## Finally, the newest feasible version is chosen.
      idx = find (pkg_to_find.feasible, 1);
      if (isempty (idx))
        continue;
      endif
      new_item_data = getfield (getfield ( ...
            index, pkg_to_find.name), "versions")(idx);
      new_item.url = new_item_data.url;
      new_item.id = [pkg_to_find.name, "@", pkg_to_find.versions{idx}];
      new_item.checksum = new_item_data.sha256;
      new_item.needed_by = {};
      new_item.deps = get_dependencies (new_item, index);
      items = [new_item, items];
    endif
  endfor

  ## Verbose resolver problem description.
  pkg_printf (["<red>The following package dependencies could not be ", ...
    "resolved:</red>\n\n"]);
  for i = 1:numel (items)
    if (isempty (items(i).deps))
      continue;
    endif
    pkg_printf ("  <blue>%s</blue> needs:\n", items(i).id);
    for j = 1:size(deps, 1)
      printf ("    %s %s %s\n", items(i).deps{j,:});
    endfor
  endfor
  printf ("\n");
  rmfield (items, "deps");
  reserr (pkg_sprintf ("<red>Could not resolve all dependencies.</red>\n"));

endfunction


function [name, ver] = splitid (id)
  [name, ver] = strtok (id, "@");
  if (iscellstr (ver))
    ver = cellfun (@(x) x(2:end), ver, "UniformOutput", false);
  else
    ver = ver(2:end);
  endif
endfunction


function dependencies = get_dependencies (item, index)
  dependencies = cell (0, 3);
  [name, version] = splitid (item.id);
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
    dependencies(end+1,:) = {dep_name, dep_op, dep_ver};
  endfor
endfunction


function bool = exist_circular_dependency (items, i, stack)
  if (isempty (items(i).needed_by))
    bool = false;
    return;
  endif
  for j = 1:length(items(i).needed_by)
    id = find (strcmp (items(i).needed_by{j}, {items.id}), 1);
    if (any (stack == id))
      bool = true;  ## Circular dependency found!
      return;
    endif
    bool = exist_circular_dependency (items, id, [stack, id]);
  endfor
endfunction
