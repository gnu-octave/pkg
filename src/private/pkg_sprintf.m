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

  conf = pkg_config ();
  if (conf.color)
    for i = 1:length (attributes)
      switch (attributes{i})
        case "red"
          str = ['\033[31;1m', str ,'\033[0m'];
        case "green"
          str = ['\033[32;1m', str ,'\033[0m'];
        case "yellow"
          str = ['\033[33;1m', str ,'\033[0m'];
        case "blue"
          str = ['\033[34;1m', str ,'\033[0m'];
        case "magenta"
          str = ['\033[35;1m', str ,'\033[0m'];
        case "cyan"
          str = ['\033[36;1m', str ,'\033[0m'];
      endswitch
    endfor
  endif

  str = sprintf (str, varargin{:});

endfunction
