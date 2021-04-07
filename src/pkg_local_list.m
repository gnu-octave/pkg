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
## Undocumented internal function.
## @end deftypefn

function list_file = pkg_local_list (list_file)

  persistent local_list = tilde_expand (fullfile ("~", ".octave_packages"));

  ## Do not get removed from memory, even if "clear" is called.
  mlock ();
 
  if (! nargin && ! nargout)
    disp (local_list);
  elseif (! nargin && nargout)
    list_file = local_list;
  elseif (nargin && ! nargout && ischar (list_file))
    local_list = tilde_expand (list_file);
    if (! exist (local_list, "file"))
      try
        ## Force file to be created
        fclose (fopen (local_list, "wt"));
      catch
        error ("pkg: cannot create file %s", local_list);
      end_try_catch
    endif
    local_list = canonicalize_file_name (local_list);
  else
    error ("pkg: specify a local_list file, or request an output argument");
  endif

endfunction
