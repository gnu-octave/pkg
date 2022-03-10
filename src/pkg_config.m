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

  ## Initialize the pkg-tool.
  pkg_startup_hook ();

  ## Initialize the configuration.
  if (isempty (config))
    config = get_default_config ();
  endif

  ## Process sub-commands.
  if (nargin == 1)
    switch (new_config)
      case "-add-startup-hook"
        pkg_startup_hook (true);
        return;
      case "-remove-startup-hooks"
        pkg_startup_hook_remove (true);
        return;
      case "-reset"
        config = get_default_config ();
      otherwise
        config = validate_new_config (config, new_config);
    endswitch
  endif

  if (nargout || (length ([dbstack]) > 1))
    return_config = config;
  else
    printf ("\n");
    printf ("  pkg configuration:\n");
    printf ("  ------------------\n");

    [local_pkg_list, global_pkg_list] = pkg_list ();
    num_pkgs.("local") = numel (local_pkg_list);
    num_pkgs.("global") = numel (global_pkg_list);

    for scope = {"local", "global"}
      printf ("\n    pkg install -%s  ", scope{1});
      pkg_printf ({"blue"}, "[%d package(s)]\n", num_pkgs.(scope{1}));
      printf ("\n      config.%s.list       = ", scope{1});
      printf_file_exist (config.(scope{1}).list);
      printf ("\n      config.%s.prefix     = ", scope{1});
      printf_path_exist (config.(scope{1}).prefix);
      printf ("\n      config.%s.archprefix = ", scope{1});
      printf_path_exist (archprefix = config.(scope{1}).archprefix);
      printf ("\n");
    endfor

    printf ("\n    Cache  ");
    ## Compute items in cache.
    if (exist (config.cache_dir, "dir") == 7)
      item_count = readdir (config.cache_dir);
      item_count(strcmp (item_count, ".") | strcmp (item_count, "..")) = [];
      item_count = numel (item_count);
    else
      item_count = 0;
    endif
    pkg_printf ({"blue"}, "[%d item(s)]\n", item_count);
    printf ("\n      config.cache_dir = ");
    printf_path_exist (config.cache_dir);

    printf ("\n\n");

    printf ("  System information:\n");
    printf ("  -------------------\n\n");
    printf ("    config.arch                = \"%s\"\n", config.arch);
    printf ("    config.color_output        = %s\n", ...
      pkg_sprintf ({"bool"}, config.color_output));
    printf ("    config.emoji_output        = %s\n", ...
      pkg_sprintf ({"bool"}, config.emoji_output));
    printf ("    config.has_elevated_rights = %s\n", ...
      pkg_sprintf ({"bool"}, config.has_elevated_rights));
    printf ("    config.pkg_dir             = ");
    printf_path_exist (config.pkg_dir);
    printf ("    config.pkg_dir_builtin     = ");
    printf_path_exist (config.pkg_dir_builtin);
    printf ("\n\n  Restore the default configuration with:");
    pkg_printf ({"blue"}, "  pkg config -reset\n");
    printf ("\n");
  endif

endfunction


function printf_file_exist (f)
  if (exist (f, "file") != 2)
    pkg_printf ({"cross"});
    printf (" ");
    pkg_printf ({"red"}, "\"%s\"", f);
  else
    pkg_printf ({"check"});
    printf (" ");
    printf ("\"%s\"", f);
  endif
  printf ("\n");
endfunction


function printf_path_exist (p)
  if (exist (p, "dir") != 7)
    pkg_printf ({"cross"});
    printf (" ");
    pkg_printf ({"red"}, "\"%s\"", p);
  else
    pkg_printf ({"check"});
    printf (" ");
    printf ("\"%s\"", p);
  endif
  printf ("\n");
endfunction


function config = validate_new_config (config, new_config)
  config_field_names = {"local"; "global"; "arch"; "cache_dir"; ...
    "color_output"; "emoji_output"; "has_elevated_rights"; "pkg_dir"; ...
    "pkg_dir_builtin"};
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

  ## Check local list files, global most likely not writable.
  list_file = new_config.local.list;
  if (! isempty (list_file) && ! exist (list_file, "file"))
    try
      ## Force file to be created
      fclose (fopen (list_file, "wt"));
    catch
      error ("pkg_config: cannot create local list file '%s'", list_file);
    end_try_catch
    new_config.local.list = canonicalize_file_name (tilde_expand (list_file));
  endif

  config = new_config;

endfunction


function config = get_default_config ()

  ## Since Octave 5.1.0 mandatory.
  if (exist ("__octave_config_info__", "builtin") == 5)
    oci = @__octave_config_info__;
  else
    oci = @octave_config_info;
  endif

  ## Default (arch)prefix and list paths.
  config.local.list   = tilde_expand (fullfile ("~", ".octave_packages"));
  config.local.prefix = tilde_expand (fullfile ("~", "octave"));
  config.local.archprefix = config.local.prefix;
  config.global.list   = fullfile ( ...
    OCTAVE_HOME (), "share", "octave", "octave_packages");
  config.global.prefix = fullfile ( ...
    OCTAVE_HOME (), "share", "octave", "packages");
  config.global.archprefix = fullfile (oci ("libdir"), "octave", "packages");

  config.pkg_dir = fileparts (mfilename ("fullpath"));
  config.pkg_dir_builtin = fullfile (oci ("fcnfiledir"), "pkg");

  ## Cache directory
  config.cache_dir = fullfile (config.local.prefix, ".cache");

  ## Get architecture information.
  config.arch = [oci("canonical_host_type"), "-", oci("api_version")];

  ## Experimental colored output.

  if (compare_versions (OCTAVE_VERSION, "5.1.0", ">="))
    config.color_output = true;
    config.emoji_output = true;
  else
    config.color_output = false;
    config.emoji_output = false;
  endif

  ## If user is superuser (posix) or the process has elevated rights (Windows),
  ## set global_install to true.
  if (ispc () && ! isunix ())
    config.has_elevated_rights = __is_elevated_process__ ();
  else
    config.has_elevated_rights = (geteuid () == 0);
  endif
endfunction
