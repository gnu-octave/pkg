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
## @deftypefn {} {} pkg_test (@var{files}, @var{handle_deps})
## Perform the built-in self tests contained in package functions.
##
## Example
##
## @example
## @group
## pkg test image
## pkg test image@atchar{}2.14.0
## @end group
## @end example
## @end deftypefn

function pkg_test (varargin)

  pkg_config ();

  params = parse_parameter ({}, varargin{:});
  if (! isempty (params.error))
    error ("pkg_test: %s\n\n%s\n\n", params.error, help ("pkg_test"));
  endif

  if (isempty (params.in))
    error ("pkg_test: at least one package name to test is required\n");
  endif

  orig_path = path ();
  ## Test packages one by one
  unwind_protect
    for i = 1:numel (params.in)
      installed_pkgs_lst = pkg_list (params.in{i});
      if (isempty (installed_pkgs_lst))
        error (pkg_sprintf (["package <blue>'%s'</blue> is not installed.", ...
          "\n\nRun <blue>'pkg list'</blue> to see all installed packages ", ...
          "and versions.\n"], params.in{i}));
      elseif (length (installed_pkgs_lst) > 1)
        matches = cell (1, length (installed_pkgs_lst));
        for j = 1:length (installed_pkgs_lst)
          matches{j} = [installed_pkgs_lst{j}.name, "@", ...
                        installed_pkgs_lst{j}.version];
        endfor
        error (pkg_sprintf (["packages <blue>'%s'</blue> have the name ", ...
          "<blue>'%s'</blue>.\n\nPlease select the package to test.\n"], ...
          strjoin (matches, ", "), params.in{i}));
      endif
      pkg_load (params.in{i});
      pkg_printf ("Testing functions in package <blue>'%s'</blue>:\n", ...
        [installed_pkgs_lst{1}.name, "@", installed_pkgs_lst{1}.version]);
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
