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
## @deftypefn  {} {@var{config} =} pkg_config (@var{new_config})
## @deftypefnx {} {@var{config} =} pkg_config ("-reset")
## Get or set the pkg-tool configuration.
##
## Read the pkg-tool configuration
##
## @example
## config = pkg_config ()
## @end example
##
## Modify the pkg-tool configuration
##
## @example
## @group
## config = pkg_config ();
## config.user.prefix = "/some/path";  # Modify the structure
## config = pkg_config (config)
## @end group
## @end example
##
## Reset the pkg-tool configuration
##
## @example
## pkg_config -reset
## @end example
## @end deftypefn

function return_config = pkg_config (new_config)

  persistent config = [];

  ## Do not get removed from memory, even if "clear" is called.
  mlock ();

  if (nargin > 1)
    print_usage ();
  endif

  if (isempty (config) || ((nargin == 1) && (strcmp (new_config, "-reset"))))
    config = get_default_config ();
  elseif (nargin == 1)
    config = validate_new_config (config, new_config);
  endif

  if (nargout)
    return_config = config;
  else
    if (! isempty (config.user.prefix))
      scope = "user";
    elseif (config.has_elevated_rights)
      scope = "global";
    else
      scope = "local";
    endif
    prefix = config.(scope).prefix;
    archprefix = config.(scope).archprefix;
    printf ("\n");
    printf ("  pkg configuration:\n");
    printf ("  ------------------\n");
    printf ("\n    Packages are installed by default to:\n\n");
    printf ("      config.%s.prefix     = \"%s\"\n", scope, prefix);
    printf ("      config.%s.archprefix = \"%s\"\n", scope, archprefix);
    printf ("\n    Package index file(s):\n\n");
    if ((exist (config.global.list, "file") == 2) || config.has_elevated_rights)
      printf ("      config.global.list = \"%s\"\n", config.global.list);
    endif
    if ((exist (config.local.list, "file") == 2) ...
        || (! config.has_elevated_rights && isempty (config.user.list)))
      printf ("      config.local.list  = \"%s\"\n", config.local.list);
    endif
    if (! isempty (config.user.list) && (exist (config.user.list, "file") == 2))
      printf ("      config.user.list   = \"%s\"\n", config.user.list);
    endif
    printf ("\n\n");
    printf ("  System information:\n");
    printf ("  -------------------\n\n");
    printf ("    config.has_elevated_rights = %d\n", ...
      config.has_elevated_rights);
    printf ("    config.arch                = \"%s\"\n", config.arch);
    printf ("\n\n  Restore the default configuration with:");
    printf ("  pkg config -reset\n\n");
  endif

endfunction


function config = validate_new_config (new_config)
  config_field_names = {"user"; "local"; "global"; "arch"; ...
                        "has_elevated_rights"};
  scope_field_names = {"archprefix"; "list"; "prefix"};
  if (! isstruct (new_config)
      || ! isequal (sort (fieldnames (new_config)), sort (config_field_names)))
    error (["pkg_config: input 'config' must be a struct like:", ...
      "  'config = pkg_config ()'"]);
  endif

  for i = 1:3
    if (! isequal (sort (fieldnames (new_config.(config_field_names{i}))), ...
                   scope_field_names))
      error (["pkg_config: input 'config' must be a struct like:", ...
        "  'config = pkg_config ()'"]);
    endif
    for j = 1:3
      if (! ischar (new_config.(config_field_names{i}).(scope_field_names{j})))
        error ("pkg_config: 'config.%s.%s' must be a string", ...
          config_field_names{i}, scope_field_names{j});
      endif
    endfor
  endfor

  config = new_config;

##  if (! exist (list_file, "file"))
##    try
##      ## Force file to be created
##      fclose (fopen (list_file, "wt"));
##    catch
##      error ("pkg: cannot create file %s", list_file);
##    end_try_catch
##  endif
endfunction


function config = get_default_config ()
  ## Default (arch)prefix and list paths.
  config.user.list   = [];
  config.user.prefix = [];
  config.user.archprefix = [];
  config.local.list   = tilde_expand (fullfile ("~", ".octave_packages"));
  config.local.prefix = tilde_expand (fullfile ("~", "octave"));
  config.local.archprefix = config.local.prefix;
  config.global.list   = fullfile ( ...
    OCTAVE_HOME (), "share", "octave", "octave_packages");
  config.global.prefix = fullfile ( ...
    OCTAVE_HOME (), "share", "octave", "packages");
  config.global.archprefix = fullfile ( ...
    __octave_config_info__ ("libdir"), "octave", "packages");

  ## If user is superuser (posix) or the process has elevated rights (Windows),
  ## set global_install to true.
  if (ispc () && ! isunix ())
    config.has_elevated_rights = __is_elevated_process__ ();
  else
    config.has_elevated_rights = (geteuid () == 0);
  endif

  ## Get architecture information.
  config.arch = [__octave_config_info__("canonical_host_type"), "-", ...
                 __octave_config_info__("api_version")];
endfunction
