########################################################################
##
## Copyright (C) 2022 The Octave Project Developers
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
## @deftypefn {} {} pkg_startup_hook_remove ()
## Remove all pkg-tool startup hooks from '~/.octaverc'.
## @end deftypefn

function pkg_startup_hook_remove (verbose)

  pkg_tool_octaverc_hook_stub = "## line auto-generated by pkg";

  ## Read "~/.octaverc" if exists.
  octaverc_file = fullfile ("~", ".octaverc");
  delete_line_idx = [];
  if (exist (octaverc_file, "file") == 2)
    octaverc_file_contents = fileread (octaverc_file);
    octaverc_file_contents = strsplit (octaverc_file_contents, "\n");
    for i = 1:length (octaverc_file_contents)
      if (regexp (octaverc_file_contents{i}, pkg_tool_octaverc_hook_stub) > 0)
        delete_line_idx = [delete_line_idx, i];
      endif
    endfor
  endif

  if (isempty (delete_line_idx))
    return;
  endif

  octaverc_file_contents(delete_line_idx) = [];
  octaverc_file_contents = strjoin (octaverc_file_contents, "\n");

  ## (Over-)Write "~/.octaverc" file.
  fd = fopen (octaverc_file, "w");
  fprintf (fd, "%s\n", octaverc_file_contents);
  fclose (fd);

endfunction
