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
## @deftypefn {} {} pkg_startup_hook (verbose)
## Perform startup tasks for pkg tool once per Octave session.
## If verbose is true, all tasks are run again and more verbose information
## is printed.
## @end deftypefn

function pkg_startup_hook (verbose)

  persistent pkg_tool_initialized = false;

  if (nargin < 1)
    verbose = false;
  endif

  ## Run pkg tool initialization only once per Octave session.
  if (pkg_tool_initialized && ! verbose)
    return;
  endif
  pkg_tool_initialized = true;

  ##################################
  ## Perform run once startup tasks.
  ##################################

  if (verbose)
    disp (" ")
    disp ("  Small 'pkg' self-test");
    disp ("  =====================")
    disp (" ")
  endif

  verbose_output (verbose, "Check if 'pkg' command can be used.", ...
    check_pkg_tool_on_load_path ());

  verbose_output (verbose, ...
    "Check if '~/.octaverc' contains pkg-tool startup hook.", ...
    check_pkg_tool_octaverc_hook_exists ());

  verbose_output (verbose, ...
    "Check if 'suggest.oct' is compiled.", ...
    check_suggest_oct_exists ());

  if (verbose)
    pkg_printf ("\n  <check> <blue>All self-tests done.</blue>\n\n");
  endif

endfunction


function verbose_output (verbose, description, msg)
  if (! verbose)
    return;
  endif

  if (! isempty (msg))
    pkg_printf ("  <cross> <red>%s</red>\n", description);
    disp (msg);
  else
    pkg_printf ("  <check> %s\n", description);
  endif
endfunction


function msg = check_pkg_tool_on_load_path ()
  msg = "";

  ## Double call of fileparts to strip "/private" sub-directory.
  pkg_path = fileparts (fileparts (mfilename ('fullpath')));
  paths = strsplit (path, pathsep);
  if (! any (strcmp (pkg_path, paths)))
    warning ("off", "Octave:shadowed-function", "local");
    addpath (pkg_path);
    ## See https://savannah.gnu.org/bugs/?48925
    if (compare_versions (OCTAVE_VERSION, "6.1.0", "<="))
      addpath (fullfile (pkg_path, "private"));
    endif
  endif

  ## Check if the right pkg tool is used.
  pkg_tool = which ("pkg");
  pkg_tool_expected = fullfile (pkg_path, "pkg.m");
  if (! strcmp (pkg_tool, pkg_tool_expected))
    msg = sprintf (["\tThe currently used pkg-tool is\n\n\t'%s'\n\n\t", ...
      "but should be \n\n\t'%s'\n\n\tPlease check your load path ", ...
      "and '.octaverc' carefully."], pkg_tool, pkg_tool_expected);
  endif
endfunction


function msg = check_pkg_tool_octaverc_hook_exists ();
  msg = "";

  pkg_tool_octaverc_hook_stub = "## line auto-generated by pkg";
  pkg_tool_octaverc_hook_code = mfilename ("fullpath");
  ## Following line is equivalent to "../pkg_config".
  pkg_tool_octaverc_hook_code = fullfile (fileparts (fileparts ( ...
    pkg_tool_octaverc_hook_code)), "pkg_config");
  pkg_tool_octaverc_hook_code = sprintf ("run (\"%s\");  %s", ...
    pkg_tool_octaverc_hook_code);

  pkg_tool_octaverc_hook = [pkg_tool_octaverc_hook_code, ...
                            pkg_tool_octaverc_hook_stub];

  ## Read "~/.octaverc" if exists.
  octaverc_file = fullfile ("~", ".octaverc");
  octaverc_hook_exists = false;
  octaverc_hook_same   = false;
  if (exist (octaverc_file, "file") == 2)
    octaverc_file_contents = file2cellstr (octaverc_file);
    if (length (regexp (strjoin (octaverc_file_contents, "\n"), ...
                        pkg_tool_octaverc_hook_stub)) > 0)
      octaverc_hook_exists = true;
    endif
    for i = 1:length (octaverc_file_contents)
      if (strcmp (strtrim (octaverc_file_contents{i}), pkg_tool_octaverc_hook))
        octaverc_hook_same = true;
        break;
      endif
    endfor
  else
    octaverc_file_contents = {};
  endif

  if (! octaverc_hook_exists)
    octaverc_file_contents = [{pkg_tool_octaverc_hook}, octaverc_file_contents];
    octaverc_file_contents = strjoin (octaverc_file_contents, "\n");

    ## (Over-)Write "~/.octaverc" file.
    fd = fopen (octaverc_file, "w");
    fprintf (fd, "%s\n", octaverc_file_contents);
    fclose (fd);

    octaverc_hook_same = true;
  endif

  ## Final sanity check.
  octaverc_file_contents = fileread (octaverc_file);
  if (length (regexp (octaverc_file_contents, pkg_tool_octaverc_hook_stub)) > 1)
    msg = sprintf (["\tThe '%s' seems to be corrupt.  ", ...
      "Do you have multiple pkg-tool versions installed?\n\t", ...
      "Please remove all entries with the comment '%s' manually."], ...
      octaverc_file, pkg_tool_octaverc_hook_stub);
    return;
  endif

  if (! octaverc_hook_same)
    msg = sprintf (["\tIn '%s' another pkg-tool version is currently ", ...
      "default.\n\tTo make this pkg-tool version version default, ", ...
      "run the following two commands:\n", ...
      "\n\tpkg_config (\"-remove-startup-hooks\");", ...
      "\n\tpkg_config (\"-add-startup-hook\");\n"], octaverc_file);
  endif
endfunction


function msg = check_suggest_oct_exists ()
  msg = "";

  ## Check if 'suggest.oct' is compiled.
  if (exist ("suggest", "file") != 3)
    old_dir = cd ([pkg_config()].pkg_dir);
    unwind_protect
      mkoctfile suggest.cc
    unwind_protect_cleanup
      cd (old_dir);
    end_unwind_protect
  endif
endfunction
