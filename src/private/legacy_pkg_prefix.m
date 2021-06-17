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
## @deftypefn  {} {} legacy_pkg_prefix (@var{prefix}, @var{archprefix})
## @deftypefnx {} {[@var{prefix}, @var{archprefix}] =} legacy_pkg_prefix ()
## @deftypefnx {} {[@var{prefix}, @var{archprefix}] =} legacy_pkg_prefix ("-local")
## @deftypefnx {} {[@var{prefix}, @var{archprefix}] =} legacy_pkg_prefix ("-global")
## Get or set the installation prefix and archprefix directories.
##
## This is a legacy helper function to serve old pkg calls like below.
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

  params = parse_parameter ({"-global", "-local"}, varargin{:});
  if (! isempty (params.error))
    error ("pkg_prefix: %s\n\n%s\n\n", params.error, help ("pkg_prefix"));
  endif

  if ((nargin > 2) || (params.flags.("-local") && params.flags.("-global")) ...
      || ((params.flags.("-local") || params.flags.("-global"))
          && ! isempty (params.in)))
    print_usage ();
  endif

  ## Read current configuration.
  conf = pkg_config ();

  ## Set local prefix if requested.
  if (! isempty (params.in))
    if ((numel (params.in) > 2) || ! ischar (params.in{1}) ...
        || ((numel (params.in) == 2) && (! ischar (params.in{2}))))
      error ("pkg: please provide one or two directory path strings")
    endif
    conf.local.prefix = make_absolute_filename (tilde_expand (params.in{1}));
    if (numel (params.in) == 2)
      conf.local.archprefix = make_absolute_filename ( ...
        tilde_expand (params.in{2}));
    else
      conf.local.archprefix = conf.local.prefix;
    endif
    conf = pkg_config (conf);
  endif

  ## Determine the used prefix and archprefix.
  if (params.flags.("-global") ...
      || (! params.flags.("-local") && conf.has_elevated_rights))
    scope = "global";
  else
    scope = "local";
  endif
  prefix = conf.(scope).prefix;
  archprefix = conf.(scope).prefix;

  if (nargout >= 1)
    return_prefix = prefix;
    return_archprefix = archprefix;
  elseif (isempty (params.in))
    printf ("Installation prefix:             %s\n", prefix);
    printf ("Architecture dependent prefix:   %s\n", archprefix);
  endif

endfunction
