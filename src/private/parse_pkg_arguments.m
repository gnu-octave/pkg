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
## @deftypefn {} {@var{opts} =} parse_pkg_arguments (action, varargin)
## 
## @end deftypefn

function opts = parse_pkg_arguments (action, varargin)

  persistent persistent_opts = struct ();

  ## Do not get removed from memory, even if "clear" is called.
  mlock ();

  ## Populate structure with persistent information.
  if (isempty (fieldnames (persistent_opts)))
    persistent_opts = get_persistent_opts ()
  endif
  
  ## From now on populate options structure with non-persistent information.
  opts = persistent_opts;
  
  ## valid actions in alphabetical order
  available_actions = {"build", "describe", "global_list",  "install", ...
                       "list", "load", "local_list", "prefix", "rebuild", ...
                       "test", "uninstall", "unload", "update"};

  ## Parse input arguments
  if (isempty (varargin) || ! iscellstr (varargin))
    print_usage ();
  endif
  opts.files = {};
  opts.deps = true;
  opts.verbose = false;
  opts.octave_forge = false;
  for i = 1:numel (varargin)
    switch (varargin{i})
      case "-nodeps"
        opts.deps = false;
      ## TODO completely remove these warnings after some releases.
      case "-noauto"
        warning ("Octave:deprecated-option",
                 ["pkg: autoload is no longer supported.  The -noauto "...
                  "option is no longer required."]);
      case "-auto"
        warning ("Octave:deprecated-option",
                 ["pkg: autoload is no longer supported.  Add a "...
                  "'pkg load ...' command to octaverc instead."]);
      case "-verbose"
        opts.verbose = true;
      case "-forge"
        if (! __octave_config_info__ ("CURL_LIBS"))
          error ("pkg: can't download from Octave Forge without the cURL library");
        endif
        opts.octave_forge = true;
      case "-local"
        opts.global_install = false;
        if (! user_prefix)
          [prefix, archprefix] = default_prefix (global_install);
        endif
      case "-global"
        global_install = true;
        if (! user_prefix)
          [prefix, archprefix] = default_prefix (global_install);
        endif
      case available_actions
        if (! strcmp (action, "none"))
          error ("pkg: more than one action specified");
        endif
        action = varargin{i};
      otherwise
        files{end+1} = varargin{i};
    endswitch
  endfor

  opts.arch = [__octave_config_info__("canonical_host_type"), "-", ...
               __octave_config_info__("api_version")];
endfunction


function opts = get_persistent_opts ()

  ## If user is superuser (posix) or the process has elevated rights (Windows),
  ## set global_install to true.
  if (ispc () && ! isunix ())
    opts.global_install = __is_elevated_process__ ();
  else
    opts.global_install = (geteuid () == 0);
  endif

  ## Default paths.
  oct_share_dir = fullfile (OCTAVE_HOME (), "share", "octave");
  oct_lib_dir   = fullfile (__octave_config_info__ ("libdir"), "octave");
  opts.local_list    = tilde_expand (fullfile ("~", ".octave_packages"));
  opts.local_prefix  = tilde_expand (fullfile ("~", "octave"));
  opts.global_list   = fullfile (oct_share_dir, "octave_packages");
  opts.global_prefix = fullfile (oct_share_dir, "packages");
  opts.global_archprefix = fullfile (oct_lib_dir, "packages");

endfunction