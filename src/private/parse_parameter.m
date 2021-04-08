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
## @deftypefn {} {@var{params} =} parse_parameter (varargin)
## Parse and split parameters into action, flags, and other parameter.
## @end deftypefn

function params = parse_parameter (varargin)

  ## valid actions in alphabetical order
  available_actions = {"build", "describe", "global_list", "install", ...
                       "list", "load", "local_list", "prefix", "rebuild", ...
                       "test", "uninstall", "unload", "update"};

  params.action = "";
  params.flags = {};
  params.flag.nodeps = false;
  params.flag.verbose = false;
  params.flag.local = false;
  params.flag.global = false;
  params.flag.octave_forge = false;
  params.other = {};

  for i = 1:numel (varargin)
    switch (varargin{i})
      case available_actions
        if (! isempty (params.action))
          error ("pkg: more than one action specified");
        endif
        params.action = varargin{i};
      otherwise
        if (! ischar (varargin{i}))
          error ("pkg: input must be strings");
        endif
        if (varargin{i}(1) == '-')
          params.flags{end+1} = varargin{i};
        else
          params.other{end+1} = varargin{i};
        endif
    endswitch
  endfor
  
  if (numel (params.flags) > numel (unique (params.flags)))
    error ("pkg: duplicate option found");
  endif
  
  for i = 1:numel (params.flags)
    switch (params.flags{i})
      case "-nodeps"
        params.flag.nodeps = true;
      case "-verbose"
        params.flag.verbose = true;
      case "-local"
        if (params.flag.global)
          error ("pkg: contradicting flags '-local' and '-global'");
        endif
        params.flag.local = true;
      case "-global"
        if (params.flag.local)
          error ("pkg: contradicting flags '-local' and '-global'");
        endif
        params.flag.global = true;
      case "-forge"
        warning ("Octave:deprecated-option", ...
                 "pkg: the '-forge' option is no longer required.");
        params.flag.octave_forge = true;
      case "-noauto"
        warning ("Octave:deprecated-option", ...
                 ["pkg: autoload is no longer supported.  The -noauto ", ...
                  "option is no longer required."]);
      case "-auto"
        warning ("Octave:deprecated-option", ...
                 ["pkg: autoload is no longer supported.  Add a ", ...
                  "'pkg load ...' command to the Octave startup file ", ...
                  "instead."]);
       otherwise
         error ("pkg: unknown flag '%s'", params.flags{i});
    endswitch
  endfor

endfunction
