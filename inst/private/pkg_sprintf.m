########################################################################
##
## Copyright (C) 2021-2022 The Octave Project Developers
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
## @deftypefn {} {str = } pkg_sprintf (@var{template}, @var{varargin})
## sprintf with some more features.
##
##  Extra symbols:
##    <yes>
##    <check>
##    <no>
##    <cross>
##    <warn>
##    <wait>
##
##  Colored output:
##    <black>  ...</black>
##    <red>    ...</red>
##    <green>  ...</green>
##    <yellow> ...</yellow>
##    <blue>   ...</blue>
##    <magenta>...</magenta>
##    <cyan>   ...</cyan>
## @end deftypefn

function str = pkg_sprintf (template, varargin)

  if (nargin < 1)
    print_usage ();
  endif

  conf = pkg_config ();

  if (conf.emoji_output)
    template = regexprep (template, '<yes>',   '✅');
    template = regexprep (template, '<check>', '✅');
    template = regexprep (template, '<no>',    '❌');
    template = regexprep (template, '<cross>', '❌');
    template = regexprep (template, '<warn>',  '⚠');
    template = regexprep (template, '<wait>',  '⏳');
  else
    template = regexprep (template, '<yes>',   '<green>[yes]</green>');
    template = regexprep (template, '<check>', '<green>[ ok]</green>');
    template = regexprep (template, '<no>',    '<red>[ no]</red>');
    template = regexprep (template, '<cross>', '<red>[err]</red>');
    template = regexprep (template, '<warn>',  '<yellow>[!!!]</yellow>');
    template = regexprep (template, '<wait>',  '<blue>[-->]</blue>');
  endif

  ## https://en.wikipedia.org/wiki/ANSI_escape_code#8-bit
  if (conf.color_output)
    template = regexprep (template, '<black>',    '\033[38;5;0m');
    template = regexprep (template, '<red>',      '\033[38;5;1m');
    template = regexprep (template, '<green>',    '\033[38;5;2m');
    template = regexprep (template, '<yellow>',   '\033[38;5;3m');
    template = regexprep (template, '<blue>',     '\033[38;5;4m');
    template = regexprep (template, '<magenta>',  '\033[38;5;5m');
    template = regexprep (template, '<cyan>',     '\033[38;5;6m');
    template = regexprep (template, '</black>',   '\033[0m');
    template = regexprep (template, '</red>',     '\033[0m');
    template = regexprep (template, '</green>',   '\033[0m');
    template = regexprep (template, '</yellow>',  '\033[0m');
    template = regexprep (template, '</blue>',    '\033[0m');
    template = regexprep (template, '</magenta>', '\033[0m');
    template = regexprep (template, '</cyan>',    '\033[0m');
  else
    template = regexprep (template, '<black>',    '');
    template = regexprep (template, '<red>',      '');
    template = regexprep (template, '<green>',    '');
    template = regexprep (template, '<yellow>',   '');
    template = regexprep (template, '<blue>',     '');
    template = regexprep (template, '<magenta>',  '');
    template = regexprep (template, '<cyan>',     '');
    template = regexprep (template, '</black>',   '');
    template = regexprep (template, '</red>',     '');
    template = regexprep (template, '</green>',   '');
    template = regexprep (template, '</yellow>',  '');
    template = regexprep (template, '</blue>',    '');
    template = regexprep (template, '</magenta>', '');
    template = regexprep (template, '</cyan>',    '');
  endif

  str = sprintf (template, varargin{:});

endfunction
