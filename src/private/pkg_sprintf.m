########################################################################
##
## Copyright (C) 2016-2021 The Octave Project Developers
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
## @deftypefn {} {str = } pkg_sprintf (@var{attributes}, @var{str}, @var{varargin})
## Minimalistic implementation for better looking output.
## @end deftypefn

function str = pkg_sprintf (attributes, str, varargin)

  if (nargin < 1)
    print_usage ();
  endif

  if ((nargin < 2) || isempty (str))
    str = "";
  endif

  conf = pkg_config ();
  for i = 1:length (attributes)
    switch (attributes{i})
      case "check"
        if (conf.emoji_output)
          str = "✅";
        else
          str = "[ ok]";
          attributes{i} = "green";
        endif
      case "cross"
        if (conf.emoji_output)
          str = "❌";
        else
          str = "[err]";
          attributes{i} = "red";
        endif
      case "bool"
        if (conf.emoji_output)
          if (logical (str))
            str = "✅";
          else
            str = "❌";
          endif
        else
          str = num2str (str);
        endif
    endswitch
  endfor

  if (conf.color_output)
    ## https://en.wikipedia.org/wiki/ANSI_escape_code#8-bit
    for i = 1:length (attributes)
      switch (attributes{i})
        case "black"
          str = ['\033[38;5;0m', str,'\033[0m'];
        case "red"
          str = ['\033[38;5;1m', str,'\033[0m'];
        case "green"
          str = ['\033[38;5;2m', str,'\033[0m'];
        case "yellow"
          str = ['\033[38;5;3m', str,'\033[0m'];
        case "blue"
          str = ['\033[38;5;4m', str,'\033[0m'];
        case "magenta"
          str = ['\033[38;5;5m', str,'\033[0m'];
        case "cyan"
          str = ['\033[38;5;6m', str,'\033[0m'];
      endswitch
    endfor
  endif

  str = sprintf (str, varargin{:});

endfunction
