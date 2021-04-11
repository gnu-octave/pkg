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
## Parse and split parameters into flags and other parameter.
##
## After running this function, @code{params.error} must be checked to be
## empty.  If @code{params.error} is not empty, an error has occured and
## the error message string is the content.
##
## @example
## @group
## >> params = parse_parameter ({"-nodeps"}, "install", "-nodeps", "image")
## params =
## 
##   scalar structure containing the fields:
##
##     flags =
##
##       scalar structure containing the fields:
##
##         -nodeps = 1
##
##     other =
##     {
##       [1,1] = image
##     }
##
##     error =
## @end group
## @end example
## @end deftypefn

function params = parse_parameter (accepted_flags, varargin)

  if (! iscell (accepted_flags))
    error (["pkg > parse_parameter: 'accepted_flags' must be a cell array " ...
      "of strings."]);
  endif

  params.flags = [];
  for i = 1:length (accepted_flags)
    params.flags.(accepted_flags{i}) = false;
  endfor
  params.other = {};
  params.error = "";

  for i = 1:numel (varargin)
    switch (varargin{i})
      case accepted_flags
        if (params.flags.(varargin{i}))
          params.error = ["multiple occurence of flag '", varargin{i}, "'"];
          return;
        endif
        params.flags.(varargin{i}) = true;
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
        if (! ischar (varargin{i}))
          params.error = "input must be strings";
          return;
        endif
        if (varargin{i}(1) == '-')
          params.error = ["flag '", varargin{i}, "' not supported"];
          return;
        else
          params.other{end+1} = varargin{i};
        endif
    endswitch
  endfor

endfunction
