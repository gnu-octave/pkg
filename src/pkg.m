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
## @deftypefn  {} {} pkg @var{command} @var{pkg_name}
## @deftypefnx {} {} pkg @var{command} @var{option} @var{pkg_name}
## @deftypefnx {} {[@var{out1}, @dots{}] =} pkg (@var{command}, @dots{} )
## Manage or query packages (groups of add-on functions) for Octave.
##
## Packages can be installed globally (i.e., for all users of the system) or
## locally (i.e., for the current user only).
##
## Global packages are installed by default in a system-wide location.  This is
## usually a subdirectory of the folder where Octave itself is installed.
## Therefore, Octave needs write access to this folder to install global
## packages.  That usually means that Octave has to run with root access (or
## "Run as administrator" on Windows) to be able to install packages globally.
##
## In contrast, local packages are installed by default in the user's
## home directory (profile on Windows) and are only available to that specific
## user.  Usually, they can be installed without root access (or administrative
## privileges).
##
## For global and local packages, there are separate databases holding the
## information about the installed packages.  If some package is installed
## globally as well as locally, the local installation takes precedence over
## ("shadows") the global one.  Which package installation (global or local) is
## used can also be manipulated by using prefixes and/or using the
## @samp{local_list} input argument.  Using these mechanisms, several different
## releases of one and the same package can be installed side by side as well
## (but cannot be loaded simultaneously).
##
## Packages might depend on external software and/or other packages.  To be
## able to install such packages, these dependencies should be installed
## beforehand.  A package that depends on other package(s) can still be
## installed using the @option{-nodeps} flag.  The effects of unsatisfied
## dependencies on external software---like libraries---depends on the
## individual package.
##
## Packages must be loaded before they can be used.  When loading a package,
## Octave performs the following tasks:
## @enumerate
## @item
## If the package depends on other packages (and @code{pkg load} is called
## without the @option{-nodeps} option), the package is not loaded
## immediately.  Instead, those dependencies are loaded first (recursively if
## needed).
##
## @item
## When all dependencies are satisfied, the package's subdirectories are
## added to the search path.
## @end enumerate
##
## This load order leads to functions that are provided by dependencies being
## potentially shadowed by functions of the same name that are provided by
## top-level packages.
##
## Each time, a package is added to the search path, initialization script(s)
## for the package are automatically executed if they are provided by the
## package.
##
## Depending on the value of @var{command} and on the number of requested
## return arguments, @code{pkg} can be used to perform several tasks.
## Possible values for @var{command} are:
##
## @table @samp
##
## @item install
## Install named packages.  For example,
##
## @example
## pkg install image-1.0.0.tar.gz
## @end example
##
## @noindent
## installs the package found in the file @file{image-1.0.0.tar.gz}.  The
## file containing the package can be a URL, e.g.,
##
## @example
## pkg install 'http://somewebsite.org/image-1.0.0.tar.gz'
## @end example
##
## @noindent
## installs the package found in the given URL@.  This
## requires an internet connection and the cURL library.
##
## @noindent
## @emph{Security risk}: no verification of the package is performed
## before the installation.  It has the same security issues as manually
## downloading the package from the given URL and installing it.
##
## @noindent
## @emph{No support}: the GNU Octave community is not responsible for
## packages installed from foreign sites.  For support or for
## reporting bugs you need to contact the maintainers of the installed
## package directly (see the @file{DESCRIPTION} file of the package)
##
## The @var{option} variable can contain options that affect the manner
## in which a package is installed.  These options can be one or more of
##
## @table @code
## @item -nodeps
## The package manager will disable dependency checking.  With this option it
## is possible to install a package even when it depends on another package
## which is not installed on the system.  @strong{Use this option with care.}
##
## @item -local
## A local installation (package available only to current user) is forced,
## even if the user has system privileges.
##
## @item -global
## A global installation (package available to all users) is forced, even if
## the user doesn't normally have system privileges.
##
## @item -forge
## Install a package directly from the Octave Forge repository.  This
## requires an internet connection and the cURL library.
##
## @emph{Security risk}: no verification of the package is performed
## before the installation.  There are no signature for packages, or
## checksums to confirm the correct file was downloaded.  It has the
## same security issues as manually downloading the package from the
## Octave Forge repository and installing it.
##
## @item -verbose
## The package manager will print the output of all commands as
## they are performed.
## @end table
##
## @item update
## Check installed Octave Forge packages against repository and update any
## outdated items.  This requires an internet connection and the cURL library.
## Usage:
##
## @example
## pkg update
## @end example
##
## @noindent
## To update a single package use @code{pkg install -forge}
##
## @item uninstall
## Uninstall named packages.  For example,
##
## @example
## pkg uninstall image
## @end example
##
## @noindent
## removes the @code{image} package from the system.  If another installed
## package depends on the @code{image} package an error will be issued.
## The package can be uninstalled anyway by using the @option{-nodeps} option.
##
## @item load
## Add named packages to the Octave load path.
##
## @example
## help pkg_load
## @end example
##
## @item unload
## Remove named packages from the path.  After unloading a package it is
## no longer possible to use the functions provided by the package.  Trying
## to unload a package that other loaded packages still depend on will result
## in an error; no packages will be unloaded in this case.  A package can
## be forcibly removed with the @option{-nodeps} flag, but be aware that the
## functionality of dependent packages will likely be affected.  As when
## loading packages, reloading dependencies after having unloaded them with the
## @option{-nodeps} flag may not restore all functionality of the dependent
## packages as the required loading order may be incorrect.
##
## @item list
## List installed packages.
##
## @example
## help pkg_list
## @end example
##
## @item describe
## Show a short description of installed packages.  With the option
## @qcode{"-verbose"} also list functions provided by the package.  For
## example,
##
## @example
## pkg describe -verbose
## @end example
##
## @noindent
## will describe all installed packages and the functions they provide.
## Display can be limited to a set of packages:
##
## @example
## @group
## ## describe control and signal packages
## pkg describe control signal
## @end group
## @end example
##
## If one output is requested a cell of structure containing the
## description and list of functions of each package is returned as
## output rather than printed on screen:
##
## @example
## desc = pkg ("describe", "secs1d", "image")
## @end example
##
## @noindent
## If any of the requested packages is not installed, @code{pkg} returns an
## error, unless a second output is requested:
##
## @example
## [desc, flag] = pkg ("describe", "secs1d", "image")
## @end example
##
## @noindent
## @var{flag} will take one of the values @qcode{"Not installed"},
## @qcode{"Loaded"}, or
## @qcode{"Not loaded"} for each of the named packages.
##
## @item prefix
## Set the installation prefix directory.
##
## @example
## help pkg_prefix
## @end example
##
## @item local_list
## Get or set the file containing the list of locally installed packages.
##
## @example
## help pkg_local_list
## @end example
##
## @item global_list
## Get or set the file containing the list of globally installed packages.
##
## @example
## help pkg_global_list
## @end example
##
## @item build
## Build a binary form of a package or packages.  The binary file produced
## will itself be an Octave package that can be installed normally with
## @code{pkg}.  The form of the command to build a binary package is
##
## @example
## pkg build builddir image-1.0.0.tar.gz @dots{}
## @end example
##
## @noindent
## where @code{builddir} is the name of a directory where the temporary
## installation will be produced and the binary packages will be found.
## The options @option{-verbose} and @option{-nodeps} are respected, while
## all other options are ignored.
##
## @item rebuild
## Rebuild the package database from the installed directories.  This can
## be used in cases where the package database has been corrupted.
##
## @item test
## Perform the built-in self tests contained in all functions provided by
## the named packages.  For example:
##
## @example
## pkg test image
## @end example
##
## @end table
## @seealso{ver, news}
## @end deftypefn

function [local_packages, global_packages] = pkg (varargin)

  if (nargin < 1)
    varargin = {""};
  endif
  
  ## valid actions in alphabetical order
  available_actions = { ...
    "build", ...
    "describe", ...
    "global_list", ...
    "install", ...
    "list", ...
    "load", ...
    "local_list", ...
    "prefix", ...
    "rebuild", ...
    "test", ...
    "uninstall", ...
    "unload", ...
    "update"};
  help_str = "Call 'pkg' with one of the following actions:\n\n";
  for i = 1:length (available_actions)
    help_str = [help_str, "  pkg ", available_actions{i}, "\n"];
  endfor
  help_str = [help_str, "\nGet more help about a particular action.  ", ...
    "For example:\n\n  pkg help install\n"];

  ## Dispatch to specialized function.
  switch (varargin{1})
    case "list"
      if (nargout == 1)
        local_packages = pkg_list (varargin{2:end});
      elseif (nargout > 1)
        [local_packages, global_packages] = pkg_list (varargin{2:end});
      else
        pkg_list (varargin{2:end});
      endif

    case "install"
      if (isempty (files))
        error ("pkg: install action requires at least one filename");
      endif

      local_files = {};
      tmp_dir = tempname ();
      unwind_protect

        if (octave_forge)
          [urls, local_files] = cellfun ("get_forge_download", files,
                                         "uniformoutput", false);
          [files, succ] = cellfun ("urlwrite", urls, local_files,
                                   "uniformoutput", false);
          succ = [succ{:}];
          if (! all (succ))
            i = find (! succ, 1);
            error ("pkg: could not download file %s from URL %s",
                   local_files{i}, urls{i});
          endif
        else
          ## If files do not exist, maybe they are not local files.
          ## Try to download them.
          not_local_files = cellfun (@(x) isempty (glob (x)), files);
          if (any (not_local_files))
            [success, msg] = mkdir (tmp_dir);
            if (success != 1)
              error ("pkg: failed to create temporary directory: %s", msg);
            endif

            for file = files(not_local_files)
              file = file{1};
              [~, fname, fext] = fileparts (file);
              tmp_file = fullfile (tmp_dir, [fname fext]);
              local_files{end+1} = tmp_file;
              looks_like_url = regexp (file, '^\w+://');
              if (looks_like_url)
                [~, success, msg] = urlwrite (file, local_files{end});
                if (success != 1)
                  error ("pkg: failed downloading '%s': %s", file, msg);
                endif
              else
                looks_like_pkg_name = regexp (file, '^[\w-]+$');
                if (looks_like_pkg_name)
                  error (["pkg: file not found: %s.\n" ...
                          "This looks like an Octave Forge package name." ...
                          "  Did you mean:\n" ...
                          "       pkg install -forge %s"], ...
                         file, file);
                else
                  error ("pkg: file not found: %s", file);
                endif
              endif
              files{strcmp (files, file)} = local_files{end};

            endfor
          endif
        endif
        pkg_install (files, deps, prefix, archprefix, verbose, local_list,
                     global_list, global_install);

      unwind_protect_cleanup
        [~] = cellfun ("unlink", local_files);
        if (exist (tmp_dir, "file"))
          [~] = rmdir (tmp_dir, "s");
        endif
      end_unwind_protect

    case "uninstall"
      pkg_uninstall (files, deps, verbose, local_list, global_list, global_install);

    case "load"
      pkg_load (varargin{2:end});

    case "unload"
      pkg_unload (files, deps);

    case "prefix"
      if (nargout)
        [local_packages, global_packages] = pkg_prefix (varargin{2:end});
      else
        pkg_prefix (varargin{2:end});
      endif

    case "local_list"
      if (nargout)
        local_packages = pkg_local_list (varargin{2:end});
      else
        pkg_local_list (varargin{2:end});
      endif

    case "global_list"
      if (nargout)
        local_packages = pkg_global_list (varargin{2:end});
      else
        pkg_global_list (varargin{2:end});
      endif

    case "rebuild"
      if (global_install)
        global_packages = pkg_rebuild (prefix, archprefix, files, verbose);
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
        local_packages = pkg_rebuild (prefix, archprefix, files, verbose);
        local_packages = save_order (local_packages);
        if (ispc)
          local_packages = standardize_paths (local_packages);
        endif
        save (local_list, "local_packages");
        if (! nargout)
          clear ("local_packages");
        endif
      endif

    case "build"
      build (files, verbose);

    case "describe"
      if (nargout)
        [local_packages, global_packages] = pkg_describe (files, verbose);
      else
        pkg_describe (files, verbose);
      endif

    case "update"
      installed_pkgs_lst = pkg_list ();

      ## Explicit list of packages to update, rather than all packages
      if (numel (files) > 0)
        update_lst = {};
        installed_names = cellfun (@(idx) idx.name, installed_pkgs_lst,
                                   "UniformOutput", false);
        for i = 1:numel (files)
          idx = find (strcmp (files{i}, installed_names), 1);
          if (isempty (idx))
            warning ("pkg: package %s is not installed - skipping update",
                     files{i});
          else
            update_lst = [ update_lst, installed_pkgs_lst(idx) ];
          endif
        endfor
        installed_pkgs_lst = update_lst;
      endif

      for i = 1:numel (installed_pkgs_lst)
        installed_pkg_name = installed_pkgs_lst{i}.name;
        installed_pkg_version = installed_pkgs_lst{i}.version;
        try
          forge_pkg_version = get_forge_pkg (installed_pkg_name);
        catch
          warning ("pkg: package %s not found on Octave Forge - skipping update\n",
                   installed_pkg_name);
          forge_pkg_version = "0";
        end_try_catch
        if (compare_versions (forge_pkg_version, installed_pkg_version, ">"))
          feval (@pkg, "install", "-forge", installed_pkg_name);
        endif
      endfor

    case "test"
      if (isempty (files))
        error ("pkg: test action requires at least one package name");
      endif
      ## Make sure the requested packages are loaded
      orig_path = path ();
      pkg_load (files, deps, local_list, global_list);
      ## Test packages one by one
      installed_pkgs_lst = pkg_list (files);
      unwind_protect
        for i = 1:numel (installed_pkgs_lst)
          printf ("Testing functions in package '%s':\n", files{i});
          installed_pkgs_dirs = {installed_pkgs_lst{i}.dir, ...
                                 installed_pkgs_lst{i}.archprefix};
          installed_pkgs_dirs = ...
            installed_pkgs_dirs (! cellfun (@isempty, installed_pkgs_dirs));
          ## For local installs installed_pkgs_dirs contains the same subdirs
          installed_pkgs_dirs = unique (installed_pkgs_dirs);
          if (! isempty (installed_pkgs_dirs))
            ## FIXME invoke another test routine once that is available.
            ## Until then __run_test_suite__.m will do the job fine enough
            __run_test_suite__ ({installed_pkgs_dirs{:}}, {});
          endif
        endfor
      unwind_protect_cleanup
        ## Restore load path back to its original value before loading packages
        path (orig_path);
      end_unwind_protect
    case "help"
      if (nargin == 1)
        disp (help_str);
      else
        printf ("\n%s\n\n", help (["pkg_", varargin{2}]));
      endif
    otherwise
      error (["Wrong action.  ", help_str, "\n"]);
  endswitch

endfunction


function [url, local_file] = get_forge_download (name)
  [ver, url] = get_forge_pkg (name);
  local_file = tempname (tempdir (), [name "-" ver "-"]);
  local_file = [local_file ".tar.gz"];
endfunction


function [ver, url] = get_forge_pkg (name)

## Try to discover the current version of an Octave Forge package from the web,
## using a working internet connection and the urlread function.
## If two output arguments are requested, also return an address from which
## to download the file.

  ## Verify that name is valid.
  if (! (ischar (name) && rows (name) == 1 && ndims (name) == 2))
    error ("get_forge_pkg: package NAME must be a string");
  elseif (! all (isalnum (name) | name == "-" | name == "." | name == "_"))
    error ("get_forge_pkg: invalid package NAME: %s", name);
  endif

  name = tolower (name);

  ## Try to download package's index page.
  [html, succ] = urlread (sprintf ("https://packages.octave.org/%s/index.html",
                                   name));
  if (succ)
    ## Remove blanks for simpler matching.
    html(isspace (html)) = [];
    ## Good.  Let's grep for the version.
    pat = "<tdclass=""package_table"">PackageVersion:</td><td>([\\d.]*)</td>";
    t = regexp (html, pat, "tokens");
    if (isempty (t) || isempty (t{1}))
      error ("get_forge_pkg: could not read version number from package's page");
    else
      ver = t{1}{1};
      if (nargout > 1)
        ## Build download string.
        pkg_file = sprintf ("%s-%s.tar.gz", name, ver);
        url = ["https://packages.octave.org/download/" pkg_file];
        ## Verify that the package string exists on the page.
        if (isempty (strfind (html, pkg_file)))
          warning ("get_forge_pkg: download URL not verified");
        endif
      endif
    endif
  else
    ## Try get the list of all packages.
    [html, succ] = urlread ("https://packages.octave.org/list_packages.php");
    if (! succ)
      error ("get_forge_pkg: could not read URL, please verify internet connection");
    endif
    t = strsplit (html);
    if (any (strcmp (t, name)))
      error ("get_forge_pkg: package NAME exists, but index page not available");
    endif
    ## Try a simplistic method to determine similar names.
    function d = fdist (x)
      len1 = length (name);
      len2 = length (x);
      if (len1 <= len2)
        d = sum (abs (name(1:len1) - x(1:len1))) + sum (x(len1+1:end));
      else
        d = sum (abs (name(1:len2) - x(1:len2))) + sum (name(len2+1:end));
      endif
    endfunction
    dist = cellfun ("fdist", t);
    [~, i] = min (dist);
    error ("get_forge_pkg: package not found: ""%s"".  Maybe you meant ""%s?""",
           name, t{i});
  endif

endfunction
