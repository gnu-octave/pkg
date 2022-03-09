########################################################################
##
## Copyright (C) 2016-2022 The Octave Project Developers
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
## @deftypefn {} {} pkg_table (@var{data}, @var{column_align})
## Minimalistic implementation for better looking table output.
##
## @var{data} is an @var{m} by @var{n} cell array of strings.
##
## @var{column_align} is a string with the length of the number of columns of
## @var{data}.  @code{"r"} means the data will be right aligned, @code{"l"}
## left aligned, respectively.
## @end deftypefn

function str = pkg_table (data, column_align)

  if (nargin < 2)
    print_usage ();
  endif

  if (! iscellstr (data) || (ndims (data) != 2))
    error ("pkg_table: data must be a two dimensional cell array of strings");
  endif
  [m, n] = size (data);

  if (! char (column_align) || ! all ([1, n] == size (column_align)))
    error ("pkg_table: data must be a two dimensional cell array of strings");
  endif
  column_align = cellfun (@(x) ifelse (x == 'r', '', '-'), ...
    num2cell (column_align), "UniformOutput", false);

  for i = 1:n
    max_width = max (cellfun (@(x) length(x), data(:,i)));
    data{1,i} = sprintf([" %-" num2str(max_width) "s "], data{1,i});
    data(3:end,i) = cellfun (...
      @(x) sprintf([" %", column_align{i}, num2str(max_width), "s "], x), ...
      data(3:end,i), "UniformOutput", false);
    data(:,i) = [data(1,i); repmat("-", 1, max_width + 2); ...
                    data(3:end,i)];
  endfor

  str = cell (m, 1);
  for i = 1:m
    if (i == 2)
      str{i} = strjoin (data(i,:), "+");
    else
      str{i} = strjoin (data(i,:), "|");
    endif
  endfor
  str = strjoin (str, "\n");

endfunction
