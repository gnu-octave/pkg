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
## @deftypefn {} {} pkg_test (@var{files}, @var{handle_deps})
## Perform the built-in self tests contained in all functions provided by
## the named packages.  For example:
##
## @example
## pkg test image
## @end example
## @end deftypefn

function pkg_test (varargin)

  params = parse_parameter ({}, varargin{:});
  if (! isempty (params.error))
    error ("pkg_test: %s\n\n%s\n\n", params.error, help ("pkg_test"));
  endif

  if (isempty (params.in))
    error ("pkg_test: at least one package name is required");
  endif

  orig_path = path ();
  ## Test packages one by one
  unwind_protect
    for i = 1:numel (params.in)
      installed_pkgs_lst = pkg_list (params.in{i});
      if (isempty (installed_pkgs_lst))
        error ("pkg_test: package '%s' is not installed", params.in{i});
      endif
      printf ("Testing functions in package '%s':\n", params.in{i});
      pkg_load (params.in{i});
      installed_pkgs_dirs = {installed_pkgs_lst{1}.dir, ...
                             installed_pkgs_lst{1}.archprefix};
      installed_pkgs_dirs = ...
        installed_pkgs_dirs (! cellfun (@isempty, installed_pkgs_dirs));
      ## For local installs installed_pkgs_dirs contains the same subdirs
      installed_pkgs_dirs = unique (installed_pkgs_dirs);
      if (! isempty (installed_pkgs_dirs))
        ## FIXME invoke another test routine once that is available.
        ## Until then __run_test_suite__.m will do the job fine enough
        __run_test_suite__ ({installed_pkgs_dirs{:}}, {});
      endif
      pkg_unload (params.in{i});
    endfor
  unwind_protect_cleanup
    ## Restore load path back to its original value before loading packages
    path (orig_path);
  end_unwind_protect

endfunction
