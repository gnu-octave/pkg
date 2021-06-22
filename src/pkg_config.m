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
    printf ("\n");
    printf ("  pkg configuration:\n");
    printf ("  ------------------\n");
    
    [local_pkg_list, global_pkg_list] = pkg_list ();
    num_pkgs.("local") = numel (local_pkg_list);
    num_pkgs.("global") = numel (global_pkg_list);

    for scope = {"local", "global"}
      list = config.(scope{1}).list;
      prefix = config.(scope{1}).prefix;
      archprefix = config.(scope{1}).archprefix;
      printf ("\n    pkg install -%s  ", scope{1});
      pkg_printf ({"blue"}, "[%d package(s)]\n", num_pkgs.(scope{1}));
      printf ("\n      config.%s.list       = \"%s\" ", scope{1}, list);
      if (exist (config.(scope{1}).list, "file") != 2)
        pkg_printf ({"red"}, "(Index file does not exist)");
      endif
      printf ("\n      config.%s.prefix     = \"%s\" ", scope{1}, prefix);
      if (exist (config.(scope{1}).prefix, "dir") != 7)
        pkg_printf ({"red"}, "(Directory does not exist)");
      endif
      printf ("\n      config.%s.archprefix = \"%s\" ", scope{1}, archprefix);
      if (exist (config.(scope{1}).archprefix, "dir") != 7)
        pkg_printf ({"red"}, "(Directory does not exist)");
      endif
      printf ("\n");
    endfor

    printf ("\n\n");

    printf ("  System information:\n");
    printf ("  -------------------\n\n");
    printf ("    config.arch                = \"%s\"\n", config.arch);
    printf ("    config.color               = %d\n", config.color);
    printf ("    config.has_elevated_rights = %d\n", ...
      config.has_elevated_rights);
    printf ("\n\n  Restore the default configuration with:");
    pkg_printf ({"blue"}, "  pkg config -reset\n\n");
  endif

endfunction


function config = validate_new_config (config, new_config)
  config_field_names = {"local"; "global"; "arch"; "color"; ...
    "has_elevated_rights"};
  scope_field_names = {"archprefix"; "list"; "prefix"};
  if (! isstruct (new_config)
      || ! isequal (sort (fieldnames (new_config)), sort (config_field_names)))
    error (["pkg_config: input 'config' must be a struct like:", ...
      "  'config = pkg_config ()'"]);
  endif

  for i = 1:2
    if (! isequal (sort (fieldnames (new_config.(config_field_names{i}))), ...
                   scope_field_names))
      error (["pkg_config: input 'config' must be a struct like:", ...
        "  'config = pkg_config ()'"]);
    endif
    for j = 1:3
      fval = new_config.(config_field_names{i}).(scope_field_names{j});
      if (! ischar (fval) && ! isempty (fval))
        error ("pkg_config: 'config.%s.%s' must be a string or empty", ...
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
  config.local.list   = tilde_expand (fullfile ("~", ".octave_packages"));
  config.local.prefix = tilde_expand (fullfile ("~", "octave"));
  config.local.archprefix = config.local.prefix;
  config.global.list   = fullfile ( ...
    OCTAVE_HOME (), "share", "octave", "octave_packages");
  config.global.prefix = fullfile ( ...
    OCTAVE_HOME (), "share", "octave", "packages");
  config.global.archprefix = fullfile ( ...
    __octave_config_info__ ("libdir"), "octave", "packages");

  ## Get architecture information.
  config.arch = [__octave_config_info__("canonical_host_type"), "-", ...
                 __octave_config_info__("api_version")];

  ## Experimental colored output.
  config.color = true;

  ## If user is superuser (posix) or the process has elevated rights (Windows),
  ## set global_install to true.
  if (ispc () && ! isunix ())
    config.has_elevated_rights = __is_elevated_process__ ();
  else
    config.has_elevated_rights = (geteuid () == 0);
  endif
endfunction
