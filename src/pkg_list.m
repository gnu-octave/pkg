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
## @deftypefn {} {[@var{local_packages}, @var{global_packages}] =} pkg_list (@var{package_name})
##
## Show a list of currently installed packages.
##
## @example
## pkg_list ()
## @end example
##
## @noindent
## produces a short report with the package name, version, and installation
## directory for each installed package.
##
## Supply a package name to limit reporting to a particular package:
##
## @example
## pkg_list ("image")
## @end example
##
## If a single return argument is requested then @code{pkg_list} returns a
## cell array where each element is a structure with information on a single
## package.
##
## @example
## all_packages = pkg_list ()
## @end example
##
## If two output arguments are requested @code{pkg} splits the list of
## installed packages into locally and globally installed packages.
##
## @example
## [local_packages, global_packages] = pkg_list ()
## @end example
## @end deftypefn

function varargout = pkg_list (varargin)

  pkg_config ();

  params = parse_parameter ({"-forge"}, varargin{:});
  if (! isempty (params.error))
    error ("pkg_list: %s\n\n%s\n\n", params.error, help ("pkg_list"));
  endif

  conf = pkg_config ();

  ## FIXME: Legacy Octave Forge support.
  if (params.flags.("-forge"))
    if (nargout)
      varargout{1} = list_forge_packages ();
    else
      list_forge_packages ();
    endif
    return;
  endif

  ## Get the list of installed packages.
  try
    local_packages = load (conf.local.list).local_packages;
  catch
    local_packages = {};
  end_try_catch
  try
    global_packages = load (conf.global.list).global_packages;
    global_packages = expand_rel_paths (global_packages);
    if (ispc)
      ## On Windows ensure 8.3 style paths are turned into LFN paths
      global_packages = standardize_paths (global_packages);
    endif
  catch
    global_packages = {};
  end_try_catch

  ## Filter lists, if info on a particular packages was requested.
  if (! isempty (params.in))
    local_names = cellfun (@(x) x.name, local_packages, ...
                           "UniformOutput", false);
    global_names = cellfun (@(x) x.name, global_packages, ...
                            "UniformOutput", false);
    local_idx = false (size (local_names));
    global_idx = false (size (global_names));
    for i = 1:numel (params.in)
      local_idx |= strcmp (params.in{i}, local_names);
      global_idx |= strcmp (params.in{i}, global_names);
    endfor
    local_packages = local_packages(local_idx);
    global_packages = global_packages(global_idx);
    if (isempty (local_packages))
      local_packages = {};
    endif
    if (isempty (global_packages))
      global_packages = {};
    endif
  endif

  ## Now check if the package is loaded.
  tmppath = path ();
  for i = 1:numel (local_packages)
    local_packages{i}.loaded = (! isempty (strfind (tmppath, ...
                                                    local_packages{i}.dir)));
  endfor
  for i = 1:numel (global_packages)
    global_packages{i}.loaded = (! isempty (strfind (tmppath, ...
                                                     global_packages{i}.dir)));
  endfor

  ## Finished if two lists are requested.
  if (nargout > 1)
    varargout = {local_packages, global_packages};
    return;
  endif

  ## Create unified list without duplicates, local_packages take precedence.
  installed_pkgs_lst = {local_packages{:}, global_packages{:}};
  installed_names = cellfun (@(x) x.name, installed_pkgs_lst,
                             "UniformOutput", false);
  [~, idx] = unique (installed_names, "first");
  installed_names = installed_names(idx);
  installed_pkgs_lst = installed_pkgs_lst(idx);

  ## Finished if unified list is requested.
  if (nargout == 1)
    varargout = {installed_pkgs_lst};
    return;
  endif

  ## Nothing requested, print list.
  num_packages = numel (installed_pkgs_lst);
  if (num_packages == 0)
    if (isempty (params.in))
      pkg_printf ({"red"}, "no packages installed.\n");
    else
      pkg_printf ({"red"}, "package '%s' is not installed.\n", params.in{1});
    endif
    return;
  endif

  ## Create table output.
  installed_versions = cellfun (@(x) x.version, installed_pkgs_lst,
                                "UniformOutput", false);
  installed_dirs = cellfun (@(x) x.dir, installed_pkgs_lst,
                            "UniformOutput", false);
  installed_loaded = cellfun (@(x) ifelse (x.loaded, "loaded", "") , ...
                              installed_pkgs_lst, "UniformOutput", false);
  columns = [{"Package Name", installed_names{:}}', ...
             {"Version", installed_versions{:}}', ...
             {"Status", installed_loaded{:}}', ...
             {"Installation directory", installed_dirs{:}}'];
  disp (pkg_table (columns, "rrrl"));

endfunction


function pkg_list = expand_rel_paths (pkg_list)

  ## Prepend location of OCTAVE_HOME to install directories.
  loc = OCTAVE_HOME ();
  for i = 1:numel (pkg_list)
    ## Be sure to only prepend OCTAVE_HOME to pertinent package paths.
    if (strncmpi (pkg_list{i}.dir, "__OH__", 6))
      pkg_list{i}.dir = [ loc pkg_list{i}.dir(7:end) ];
      pkg_list{i}.archprefix = [ loc pkg_list{i}.archprefix(7:end) ];
    endif
  endfor

endfunction


function list = list_forge_packages ()

  [list, succ] = urlread ("https://packages.octave.org/list_packages.php");
  if (! succ)
    error ("pkg: could not read URL, please verify internet connection");
  endif

  list = ostrsplit (list, " \n\t", true);

  if (nargout == 0)
    ## FIXME: This is a convoluted way to get the latest version number
    ##        for each package in less than 56 seconds (bug #39479).

    ## Get the list of all packages ever published
    [html, succ] = urlread ('https://sourceforge.net/projects/octave/files/Octave%20Forge%20Packages/Individual%20Package%20Releases');

    if (! succ)
      error ("pkg: failed to fetch list of packages from sourceforge.net");
    endif

    ## Scrape the HTML
    ptn = '<tr\s+title="(.*?gz)"\s+class="file';
    [succ, tok] = regexp (html, ptn, "start", "tokens");
    if (isempty (succ))
      error ("pkg: failed to parse list of packages from sourceforge.net");
    endif

    ## Remove version numbers and produce unique list of packages
    files = cellstr (tok);
    pkg_names = cellstr (regexp (files, '^.*?(?=-\d)', "match"));
    [~, idx] = unique (pkg_names, "first");
    files = files(idx);

    printf ("Octave Forge (legacy) provides these packages:\n\n");
    printf ("  %-20s | Version\n", "Package Name");
    printf ("  ---------------------+--------\n");
    for i = 1:length (list)
      pkg_nm = list{i};
      idx = regexp (files, sprintf ('^%s(?=-\\d)', pkg_nm));
      idx = ! cellfun (@isempty, idx);
      if (any (idx))
        ver = regexp (files{idx}, '\d+\.\d+\.\d+', "match"){1};
      else
        ver = "unknown";
      endif
      printf ("  %-20s | %s\n", pkg_nm, ver);
    endfor
  endif

endfunction
