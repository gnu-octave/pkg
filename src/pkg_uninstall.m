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
## @deftypefn {} {} pkg_uninstall (@var{params.in})
## Uninstall a package.
##
## Example
##
## @example
## @group
## pkg uninstall image
## pkg uninstall image@atchar{}2.14.0
## @end group
## @end example
##
## @noindent
## removes the @code{image} package from the system.  If another installed
## package depends on the @code{image} package an error will be issued.
## The package can be uninstalled by force using the @option{-nodeps} option.
## @end deftypefn

function pkg_uninstall (varargin)

  conf = pkg_config ();

  params = parse_parameter ({"-global", "-nodeps"}, varargin{:});
  if (! isempty (params.error))
    error ("pkg_uninstall: %s\n\n%s\n\n", params.error, help ("pkg_uninstall"));
  endif

  if (isempty (params.in))
    error ("pkg_uninstall: at least one package name is required");
  endif

  ## Get the list of installed packages.
  [local_packages, global_packages] = pkg_list ();
  if (params.flags.("-global"))
    installed_pkgs_lst = global_packages;
  else
    installed_pkgs_lst = local_packages;
  endif

  ## Read package names and installdirs into a more convenient format.
  pnames = cellfun (@(x) x.name, installed_pkgs_lst, "UniformOutput", false);
  pvers = cellfun (@(x) x.version, installed_pkgs_lst, "UniformOutput", false);
  pids = strcat (pnames, "@", pvers);
  pdirs = cellfun (@(x) x.dir, installed_pkgs_lst, "UniformOutput", false);

  delete_idx = [];
  for i = 1:length (params.in)
    if (any (params.in{i} == "@"))
      idx2 = find (strcmp (pids, params.in{i}));
    else
      ## If only name given "pkg uninstall io", take oldest version.
      idx2 = find (strcmp (pnames, params.in{i}), 1, "first");
    endif
    if (! any (idx2))
      error (pkg_sprintf (["package <blue>'%s'</blue> is not installed.", ...
        "\n\nRun <blue>'pkg_list'</blue> to see all installed packages ", ...
        "and versions.\n"], params.in{i}));
    endif
    delete_idx(end + 1) = idx2;
  endfor

  ## Compute the packages that will remain installed.
  idx = setdiff (1:length (installed_pkgs_lst), delete_idx);
  remaining_packages = {installed_pkgs_lst{idx}};
  to_delete_packages = {installed_pkgs_lst{delete_idx}};

  ## Check dependencies.
  if (! params.flags.("-nodeps"))
    error_text = "";
    for i = 1:length (remaining_packages)
      desc = remaining_packages{i};
      bad_deps = get_unsatisfied_deps (desc, to_delete_packages, true);

      ## Will the uninstallation break any dependencies?
      if (! isempty (bad_deps))
        for i = 1:length (bad_deps)
          dep = bad_deps{i};
          error_text = [error_text " " desc.name " needs " ...
                        dep.package " " dep.operator " " dep.version "\n"];
        endfor
      endif
    endfor

    if (! isempty (error_text))
      error ("the following dependencies where unsatisfied:\n  %s", error_text);
    endif
  endif

  ## Delete the directories containing the packages.
  confirm_recursive_rmdir (false, "local");
  for i = delete_idx
    desc = installed_pkgs_lst{i};
    desc.archdir = fullfile (desc.archprefix, conf.arch);
    ## If an 'on_uninstall.m' exist, call it!
    if (exist (fullfile (desc.dir, "packinfo", "on_uninstall.m"), "file"))
      wd = pwd ();
      cd (fullfile (desc.dir, "packinfo"));
      on_uninstall (desc);
      cd (wd);
    endif
    ## Do the actual deletion.
    if (desc.loaded)
      rmpath (desc.dir);
      if (isfolder (desc.archdir))
        rmpath (desc.archdir);
      endif
    endif
    if (isfolder (desc.dir))
      ## FIXME: If first call to rmdir fails, then error() will
      ##        stop further processing of desc.archdir & desc.archprefix.
      ##        If this is, in fact, correct, then calls should
      ##        just be shortened to rmdir (...) and let rmdir()
      ##        report failure and reason for failure.
      [status, msg] = rmdir (desc.dir, "s");
      if (status != 1 && isfolder (desc.dir))
        error ("couldn't delete directory %s: %s", desc.dir, msg);
      endif
      [status, msg] = rmdir (desc.archdir, "s");
      if (status != 1 && isfolder (desc.archdir))
        error ("couldn't delete directory %s: %s", desc.archdir, msg);
      endif
      if (dirempty (desc.archprefix))
        sts = rmdir (desc.archprefix, "s");
      endif
    else
      warning ("directory %s previously lost", desc.dir);
    endif
  endfor

  ## Write a new ~/.octave_packages.
  if (params.flags.("-global"))
    if (numel (remaining_packages) == 0)
      [~] = unlink (conf.global.list);
    else
      global_packages = sort_dependencies_first (remaining_packages);
      lobal_packages = standardize_paths (global_packages);
      save (conf.global.list, "global_packages");
    endif
  else
    if (numel (remaining_packages) == 0)
      [~] = unlink (conf.local.list);
    else
      local_packages = sort_dependencies_first (remaining_packages);
      local_packages = standardize_paths (local_packages);
      save (conf.local.list, "local_packages");
    endif
  endif

endfunction
