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
## @deftypefn {} {@var{list_file} =} pkg_local_list (@var{list_file})
## Get or set the file containing the list of locally installed packages.
##
## Locally installed packages are only available to the current user.
## For example getting
##
## @example
## list_file = pkg_local_list ()
## @end example
##
## and setting the file
##
## @example
## pkg_local_list ("~/.octave_packages")
## @end example
## @end deftypefn

function out_file = pkg_local_list (varargin)

  persistent local_list = tilde_expand (fullfile ("~", ".octave_packages"));

  ## Do not get removed from memory, even if "clear" is called.
  mlock ();

  params = parse_parameter ({}, varargin{:});
  if (! isempty (params.error))
    error ("pkg_local_list: %s\n\n%s\n\n", params.error, ...
      help ("pkg_local_list"));
  endif

  if (! isempty (params.flags) || (numel (params.other) > 1))
    print_usage ();
  endif

  if (numel (params.other) == 1)
    list_file = params.other{1};
    if (! ischar (list_file))
      error ("pkg: invalid local_list file");
    endif
    list_file = tilde_expand (list_file);
    if (! exist (list_file, "file"))
      try
        ## Force file to be created
        fclose (fopen (list_file, "wt"));
      catch
        error ("pkg: cannot create file %s", list_file);
      end_try_catch
    endif
    local_list = canonicalize_file_name (list_file);
  endif

  if ((nargout == 0) && isempty (params.other))
    disp (local_list);
  else
    out_file = local_list;
  endif

endfunction
