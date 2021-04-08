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
## @deftypefn {} {@var{opts} =} parse_pkg_arguments (varargin)
## Split arguments into action, flags, and remaining arguments.
## @end deftypefn

function opts = get_system_information ()

  persistent persistent_opts = struct ();

  ## Do not get removed from memory, even if "clear" is called.
  mlock ();

  ## Populate structure with persistent information.
  if (isempty (fieldnames (persistent_opts)))
    persistent_opts = get_persistent_opts ();
  endif

  opts = persistent_opts;

endfunction


function opts = get_persistent_opts ()

  ## If user is superuser (posix) or the process has elevated rights (Windows),
  ## set global_install to true.
  if (ispc () && ! isunix ())
    opts.has_elevated_rights = __is_elevated_process__ ();
  else
    opts.has_elevated_rights = (geteuid () == 0);
  endif
  
  opts.arch = [__octave_config_info__("canonical_host_type"), "-", ...
               __octave_config_info__("api_version")];

endfunction
