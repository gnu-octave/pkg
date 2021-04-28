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
## @deftypefn  {} {} pkg_prefix (@var{prefix}, @var{archprefix})
## @deftypefnx {} {[@var{prefix}, @var{archprefix}] =} pkg_prefix ()
## @deftypefnx {} {[@var{prefix}, @var{archprefix}] =} pkg_prefix ("-local")
## @deftypefnx {} {[@var{prefix}, @var{archprefix}] =} pkg_prefix ("-global")
## Get or set the installation prefix and archprefix directories.
##
## Without any input and output argument, the directories for the next package
## installation will be print on the Octave command window.  This is one
## directory for architecture independent and dependent files, prefix and
## archprefix, respectively, which may be equal.  The default local and
## global prefixes can be queried using the respective flags.
##
## @example
## [prefix, archprefix] = pkg_prefix ()
## @end example
##
## Given one or two input arguments, prefix and archprefix can be changed.
## For example,
##
## @example
## pkg_prefix ("~/my_octave_packages")
## @end example
##
## @noindent
## sets prefix and archprefix to @file{~/my_octave_packages}.
## Packages will be installed in this directory.
##
## The location in which to install the architecture dependent files 
## (archprefix) can be independently specified with an addition argument.
## For example:
##
## @example
## pkg_prefix ("~/my_octave_packages", "~/my_arch_dep_pkgs")
## @end example
## @end deftypefn

function [return_prefix, return_archprefix] = legacy_pkg_prefix (varargin)

  ## Default paths.
  persistent local_prefix = tilde_expand (fullfile ("~", "octave"));

  persistent global_prefix = fullfile ( ...
    OCTAVE_HOME (), "share", "octave", "packages");
  persistent global_archprefix = fullfile ( ...
    __octave_config_info__ ("libdir"), "octave", "packages");

  persistent user_prefix = "";
  persistent user_archprefix = "";

  ## Do not get removed from memory, even if "clear" is called.
  mlock ();

  params = parse_parameter ({"-global", "-local"}, varargin{:});
  if (! isempty (params.error))
    error ("pkg_prefix: %s\n\n%s\n\n", params.error, help ("pkg_prefix"));
  endif

  if ((nargin > 2) || (params.flags.("-local") && params.flags.("-global")) ...
      || ((params.flags.("-local") || params.flags.("-global"))
          && ! isempty (params.in)))
    print_usage ();
  endif

  ## Set user prefix if requested.
  if (! isempty (params.in))
    if ((numel (params.in) > 2) || ! ischar (params.in{1}) ...
        || ((numel (params.in) == 2) && (! ischar (params.in{2}))))
      error ("pkg: please provide one or two directory path strings")
    endif
    user_prefix = make_absolute_filename (tilde_expand (params.in{1}));
    if (numel (params.in) == 2)
      user_archprefix = make_absolute_filename (tilde_expand (params.in{2}));
    endif
  endif

  opts = get_system_information ();

  ## Determine the used prefix and archprefix.
  if (! params.flags.("-global") && ! params.flags.("-local") ...
      && ! isempty (user_prefix))
    prefix = archprefix = user_prefix;
    if (! isempty (user_archprefix))
      archprefix = user_archprefix;
    endif
  elseif (params.flags.("-global") ...
          || (! params.flags.("-local") && opts.has_elevated_rights))
    prefix = global_prefix;
    archprefix = global_archprefix;
  else
    prefix = archprefix = local_prefix;
  endif

  if (nargout >= 1)
    return_prefix = prefix;
    return_archprefix = archprefix;
  elseif (isempty (params.in))
    printf ("Installation prefix:             %s\n", prefix);
    printf ("Architecture dependent prefix:   %s\n", archprefix);
  endif

endfunction
