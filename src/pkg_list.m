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

function [out1, out2] = pkg_list (varargin)

  params = parse_parameter ({"-forge"}, varargin{:});
  if (! isempty (params.error))
    error ("pkg_list: %s\n\n%s\n\n", params.error, help ("pkg_list"));
  endif

  conf = pkg_config ();

  ## FIXME: Legacy Octave Forge support.
  if (params.flags.("-forge"))
    if (nargout)
      out1 = list_forge_packages ();
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
  installed_pkgs_lst = {local_packages{:}, global_packages{:}};

  ## Eliminate duplicates in the installed package list.
  ## Locally installed packages take precedence.
  installed_names = cellfun (@(x) x.name, installed_pkgs_lst,
                             "uniformoutput", false);
  [~, idx] = unique (installed_names, "first");
  installed_names = installed_names(idx);
  installed_pkgs_lst = installed_pkgs_lst(idx);

  ## Check whether info on a particular package was requested
  if (! isempty (params.in))
    idx = [];
    for i = 1 : numel (params.in)
      idx = [idx, find(strcmp (params.in{i}, installed_names))];
    endfor
    if (isempty (idx))
      installed_names = {};
      installed_pkgs_lst = {};
    else
      installed_names = installed_names(idx);
      installed_pkgs_lst = installed_pkgs_lst(idx);
    endif
  endif

  ## Now check if the package is loaded.
  ## FIXME: Couldn't dir_in_loadpath() be used here?
  tmppath = path ();
  for i = 1:numel (installed_pkgs_lst)
    if (strfind (tmppath, installed_pkgs_lst{i}.dir))
      installed_pkgs_lst{i}.loaded = true;
    else
      installed_pkgs_lst{i}.loaded = false;
    endif
  endfor
  for i = 1:numel (local_packages)
    if (strfind (tmppath, local_packages{i}.dir))
      local_packages{i}.loaded = true;
    else
      local_packages{i}.loaded = false;
    endif
  endfor
  for i = 1:numel (global_packages)
    if (strfind (tmppath, global_packages{i}.dir))
      global_packages{i}.loaded = true;
    else
      global_packages{i}.loaded = false;
    endif
  endfor

  ## Should we return something?
  if (nargout == 1)
    out1 = installed_pkgs_lst;
  elseif (nargout > 1)
    out1 = local_packages;
    out2 = global_packages;
  else
    ## Don't return anything, instead we'll print something.
    num_packages = numel (installed_pkgs_lst);
    if (num_packages == 0)
      if (isempty (params.in))
        printf ("no packages installed.\n");
      else
        printf ("package %s is not installed.\n", params.in{1});
      endif
      return;
    endif

    ## Compute the maximal lengths of name, version, and dir.
    h1 = "Package Name";
    h2 = "Version";
    h3 = "Installation directory";
    max_name_length = max ([length(h1), cellfun(@length, installed_names)]);
    version_lengths = cellfun (@(x) length (x.version), installed_pkgs_lst);
    max_version_length = max ([length(h2), version_lengths]);
    ncols = terminal_size ()(2);
    max_dir_length = ncols - max_name_length - max_version_length - 7;
    if (max_dir_length < 20)
      max_dir_length = Inf;
    endif

    h1 = postpad (h1, max_name_length + 1, " ");
    h2 = postpad (h2, max_version_length, " ");;

    ## Print a header.
    header = sprintf ("%s | %s | %s\n", h1, h2, h3);
    printf (header);
    tmp = sprintf (repmat ("-", 1, length (header) - 1));
    tmp(length (h1)+2) = "+";
    tmp(length (h1)+length (h2)+5) = "+";
    printf ("%s\n", tmp);

    ## Print the packages.
    format = sprintf ("%%%ds %%1s| %%%ds | %%s\n",
                      max_name_length, max_version_length);
    for i = 1:num_packages
      cur_name = installed_pkgs_lst{i}.name;
      cur_version = installed_pkgs_lst{i}.version;
      cur_dir = installed_pkgs_lst{i}.dir;
      if (length (cur_dir) > max_dir_length)
        first_char = length (cur_dir) - max_dir_length + 4;
        first_filesep = strfind (cur_dir(first_char:end), filesep ());
        if (! isempty (first_filesep))
          cur_dir = ["..." cur_dir((first_char + first_filesep(1) - 1):end)];
        else
          cur_dir = ["..." cur_dir(first_char:end)];
        endif
      endif
      if (installed_pkgs_lst{i}.loaded)
        cur_loaded = "*";
      else
        cur_loaded = " ";
      endif
      printf (format, cur_name, cur_loaded, cur_version, cur_dir);
    endfor
  endif

endfunction


function pkg_list = expand_rel_paths (pkg_list)

  ## Prepend location of OCTAVE_HOME to install directories
  loc = OCTAVE_HOME ();
  for i = 1:numel (pkg_list)
    ## Be sure to only prepend OCTAVE_HOME to pertinent package paths
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
