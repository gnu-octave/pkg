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
## Install a package.
##
## @item uninstall
## Uninstall a package.
##
## @item load
## Add a package to the Octave load path.
##
## @item unload
## Remove a package from the Octave load path.
##
## @item list
## List installed packages.
##
## @item describe
## Describe installed packages.
##
## @item config
## Get or set the pkg-tool configuration.
##
## @item update
## Update a given or all packages to the latest available version.
##
## @item build
## Build platform dependent binary packages from Octave source packages.
##
## @item rebuild
## Rebuild the package database from the installed directories.
##
## @item test
## Perform the built-in self tests contained in package functions.
##
## @end table
## @seealso{ver, news}
## @end deftypefn

function varargout = pkg (varargin)

  [~] = pkg_config ();  # Suppress output to command window.

  if (nargin < 1)
    varargin = {""};
  endif

  ## Valid actions in alphabetical order.
  available_actions = { ...
    "build", ...
    "config", ...
    "describe", ...
    "install", ...
    "list", ...
    "load", ...
    "rebuild", ...
    "test", ...
    "uninstall", ...
    "unload", ...
    "update"};

  ## Create help string.
  help_str = "Call 'pkg' with one of the following actions:\n\n";
  for i = 1:length (available_actions)
    help_str = [help_str, "  pkg ", available_actions{i}, "\n"];
  endfor
  help_str = [help_str, "\nFor more help type\n\n   help pkg\n"];
  help_str = [help_str, "\nFor more help about a particular action ", ...
    "type for example:\n\n  pkg help install\n"];

  ## Dispatch to specialized function.
  switch (varargin{1})
    case available_actions
      fcn = str2func (["pkg_", varargin{1}]);
      [varargout{1:nargout}] = fcn (varargin{2:end});

    case "help"
      if (nargin == 1)
        disp (help_str);
      elseif (exist (["pkg_", varargin{2}], "file") == 2)
        printf ("\n%s\n\n", help (["pkg_", varargin{2}]));
      else
        error (["unsupported action '%s'.  ", help_str, "\n"], varargin{2});
      endif

    ## Legacy actions
    case "prefix"
      [varargout{1:nargout}] = legacy_pkg_prefix (varargin{2:end});

    case "global_list"
      [varargout{1:nargout}] = legacy_pkg_local_global_list ("global",
                                                             varargin{2:end});
    case "local_list"
      [varargout{1:nargout}] = legacy_pkg_local_global_list ("local",
                                                             varargin{2:end});
    otherwise
      error (["unsupported action '%s'.  ", help_str, "\n"], varargin{1});
  endswitch

endfunction
