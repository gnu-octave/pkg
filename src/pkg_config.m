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
## @deftypefn  {} {@var{config} =} pkg_config ()
## @deftypefnx {} {} pkg_config (@var{new_config})
## @deftypefnx {} {} pkg_config (@option{-reset})
## @deftypefnx {} {} pkg_config (@option{-add-startup-hook})
## @deftypefnx {} {} pkg_config (@option{-remove-startup-hooks})
## Get or set the pkg-tool configuration.
##
## 1. Read the pkg-tool configuration:
##
## @example
## config = pkg_config ()
## @end example
##
## 2. Modify the pkg-tool configuration:
##
## @example
## @group
## config = pkg_config ();
## config.local.prefix = "/some/path";  # Modify the structure
## config = pkg_config (config)
## @end group
## @end example
##
## 3. Reset the pkg-tool configuration:
##
## @example
## pkg_config -reset
## @end example
##
## 4. Add or remove startup hook in @file{octaverc}-file:
##
## @example
## @group
## pkg_config -add-startup-hook
## pkg_config -remove-startup-hooks
## @end group
## @end example
##
## By default, Octave is equipped with a builtin pkg-toolkit.  To override
## the builtin pkg-toolkit and the builtin @code{pkg}-command, in the
## @file{octaverc}-file a line of code is added to ensure precedence
## at each start of an Octave session.  See the documentation about Octave
## startup files for more information.
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

  if (nargout ...
      || ((length ([dbstack]) > 1) && (! strcmp ([dbstack](2).name, "pkg"))))
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
      pkg_printf ("<blue>[%d package(s)]</blue>\n\n", num_pkgs.(scope{1}));
      printf ("      config.%s.list       = ", scope{1});
      printf_file_exist (config.(scope{1}).list);
      printf ("      config.%s.prefix     = ", scope{1});
      printf_path_exist (config.(scope{1}).prefix);
      printf ("      config.%s.archprefix = ", scope{1});
      printf_path_exist (archprefix = config.(scope{1}).archprefix);
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
    pkg_printf ("<blue>[%d item(s)]</blue>\n", item_count);
    printf ("\n      config.cache_dir = ");
    printf_path_exist (config.cache_dir);

    printf ("\n\n");

    printf ("  System information:\n");
    printf ("  -------------------\n\n");
    printf ("    config.arch                = \"%s\"\n", config.arch);
    printf ("    config.color_output        = %s\n", ...
      sprintf_bool (config.color_output));
    printf ("    config.emoji_output        = %s\n", ...
      sprintf_bool (config.emoji_output));
    printf ("    config.has_elevated_rights = %s\n", ...
      sprintf_bool (config.has_elevated_rights));
    printf ("    config.pkg_dir             = ");
    printf_path_exist (config.pkg_dir);
    printf ("    config.pkg_dir_builtin     = ");
    printf_path_exist (config.pkg_dir_builtin);
    printf ("\n\n  Restore the default configuration with:");
    pkg_printf ("  <blue>pkg config -reset</blue>\n");
    printf ("\n");
  endif

endfunction


function printf_file_exist (f)
  if (exist (f, "file") != 2)
    pkg_printf ("<cross> <red>\"%s\"</red>\n", f);
  else
    pkg_printf ("<check> \"%s\"\n", f);
  endif
endfunction


function printf_path_exist (p)
  if (exist (p, "dir") != 7)
    pkg_printf ("<cross> <red>\"%s\"</red>\n", p);
  else
    pkg_printf ("<check> \"%s\"\n", p);
  endif
endfunction


function str = sprintf_bool (bool)
  if (bool)
    str = pkg_sprintf ("<yes>");
  else
    str = pkg_sprintf ("<no>");
  endif
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
  endif

  ## Ensure proper paths
  new_config.local.list        = fix_path (new_config.local.list);
  new_config.local.prefix      = fix_path (new_config.local.prefix);
  new_config.local.archprefix  = fix_path (new_config.local.archprefix);
  new_config.global.list       = fix_path (new_config.global.list);
  new_config.global.prefix     = fix_path (new_config.global.prefix);
  new_config.global.archprefix = fix_path (new_config.global.archprefix);
  new_config.cache_dir         = fix_path (new_config.cache_dir);

  config = new_config;

endfunction


function p = fix_path (p)
  p = tilde_expand (p);
  pp = canonicalize_file_name (p);
  if (! isempty (pp))
    p = pp;
  endif
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
