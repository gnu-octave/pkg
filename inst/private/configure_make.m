########################################################################
##
## Copyright (C) 2005-2022 The Octave Project Developers
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
## @deftypefn {} {} configure_make (@var{desc}, @var{packdir}, @var{verbose})
## Perform ./configure, make, make install in package "src" directory.
## @end deftypefn

function configure_make (desc, packdir, verbose)

  if (compat_isfolder (fullfile (packdir, "src")))
    src = fullfile (packdir, "src");
    octave_bindir = __octave_config_info__ ("bindir");
    ver = version ();
    ext = __octave_config_info__ ("EXEEXT");
    mkoctfile_program = fullfile (octave_bindir, ...
                                  sprintf ("mkoctfile-%s%s", ver, ext));
    octave_config_program = fullfile (octave_bindir, ...
                                      sprintf ("octave-config-%s%s", ver, ext));
    if (ispc () && ! isunix ())
      octave_binary = fullfile (octave_bindir, sprintf ("octave-%s.bat", ver));
    else
      octave_binary = fullfile (octave_bindir, sprintf ("octave-%s%s", ver, ext));
    endif

    if (! exist (mkoctfile_program, "file"))
      __gripe_missing_component__ ("pkg", "mkoctfile");
    endif
    if (! exist (octave_config_program, "file"))
      __gripe_missing_component__ ("pkg", "octave-config");
    endif
    if (! exist (octave_binary, "file"))
      __gripe_missing_component__ ("pkg", "octave");
    endif

    if (verbose)
      mkoctfile_program = [mkoctfile_program " --verbose"];
    endif

    cenv = {"MKOCTFILE"; mkoctfile_program;
            "OCTAVE_CONFIG"; octave_config_program;
            "OCTAVE"; octave_binary};
    scenv = sprintf ("%s='%s' ", cenv{:});

    if (verbose)
      ## Add standard V=1 make argument for verbose build rules
      scenv = [scenv, "V=1"];
    endif

    ## Configure.
    if (exist (fullfile (src, "configure"), "file"))
      flags = "";
      if (isempty (getenv ("CC")))
        flags = [flags ' CC="' mkoctfile("-p", "CC") '"'];
      endif
      if (isempty (getenv ("CXX")))
        flags = [flags ' CXX="' mkoctfile("-p", "CXX") '"'];
      endif
      if (isempty (getenv ("AR")))
        flags = [flags ' AR="' mkoctfile("-p", "AR") '"'];
      endif
      if (isempty (getenv ("RANLIB")))
        flags = [flags ' RANLIB="' mkoctfile("-p", "RANLIB") '"'];
      endif
      cmd = ["cd '" src "'; " scenv " ./configure " flags];
      [status, output] = shell (cmd, verbose);
      if (status != 0)
        sts = rmdir (desc.dir, "s");
        disp (output);
        error ("pkg: error running the configure script for %s", desc.name);
      endif
    endif

    ## Make.
    if (ispc ())
      jobs = 1;
    else
      jobs = nproc ("overridable");
    endif

    if (exist (fullfile (src, "Makefile"), "file"))
      [status, output] = shell (sprintf ("%s make --jobs %i --directory '%s'",
                                         scenv, jobs, src), verbose);
      if (status != 0)
        sts = rmdir (desc.dir, "s");
        disp (output);
        error ("pkg: error running 'make' for the %s package", desc.name);
      endif
    endif

    ## Extract tests from source files which will not to be installed
    tst_files_src = [];
    for suffix = {"*.cc", "*.c", "*.C", "*.cpp", "*.cxx"}
      tst_files_src = [tst_files_src; ...
                       nthargout(1, 1, @dir, fullfile (src, suffix{1}))];
    endfor
    if (! isempty (tst_files_src))
      for tst_file_src = {tst_files_src.name}
        full_tst_file_src = fullfile (src, tst_file_src{1});
        tst_code = __extract_test_code__ (full_tst_file_src);
        if (isempty (tst_code))
          continue;
        endif
        full_tst_file = strcat (full_tst_file_src, "-tst");
        if (exist (full_tst_file))
          continue;
        endif
        tst_code = ...
          ["## DO NOT EDIT!\n", ...
           "## Generated automatically from ", tst_file_src{1}, "\n", ...
           "## by ", mfilename(), ".m during package installation.\n\n", ...
           tst_code];
        [fid, output] = fopen (full_tst_file, "w");
        if (fid == -1)
          error ("Octave:pkg:extract-tests", ...
                 "pkg: error writing extracted tests to 'src': %s", output);
        endif
        fputs (fid, tst_code);
        fclose (fid);
      endfor
    endif

  endif

endfunction


function [status, output] = shell (cmd, verbose)
  ## Execute a shell command.
  ## In the end it calls system(), but in the case of MS Windows it will first
  ## check if sh.exe works.
  ##
  ## If VERBOSE is true, it will prints the output to STDOUT in real time and
  ## the second output argument will be an empty string.  Otherwise, it will
  ## contain the output of the execeuted command.

  persistent have_sh;

  cmd = strrep (cmd, '\', '/');
  if (ispc () && ! isunix ())
    if (isempty (have_sh))
      if (system ('sh.exe -c "exit"'))
        have_sh = false;
      else
        have_sh = true;
      endif
    endif
    if (have_sh)
      cmd = ['sh.exe -c "' cmd '"'];
    else
      error ("pkg: unable to find the command shell");
    endif
  endif
  ## if verbose, we want to display the output in real time.  To do this, we
  ## must call system with 1 output argument.  But then the variable 'output'
  ## won't exist.  So we initialize it empty.  If an error does occur, and we
  ## are verbose we will return an empty string but it's all fine since
  ## the error message has already been displayed.
  output = "";
  if (verbose)
    [status] = system (cmd);
  else
    [status, output] = system (cmd);
  endif

endfunction

function body = __extract_test_code__ (nm)
  ## Collect all BIST lines starting %! from the file named nm
  ## and return them as a single \n-delimited string.
  fid = fopen (nm, "rt");
  body = "";
  if (fid >= 0)
    while (ischar (ln = fgets (fid)))
      if (strncmp (ln, "%!", 2))
        body = [body, ln];
      endif
    endwhile
    fclose (fid);
  endif
endfunction
