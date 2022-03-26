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
## @deftypefn {} {} pkg_unload (@var{files}, @var{handle_deps})
## Remove a packages from the Octave load path.
##
## After unloading a package it is no longer possible to use any functions
## provided by the package.  Trying to unload a package that other loaded
## packages still depend on will result in an error; no packages will be
## unloaded in this case.
##
## A package can be forcibly unloaded with the @option{-nodeps} flag.
## However, the functionality of dependent packages will likely be affected.
## @end deftypefn

function pkg_unload (varargin)

  pkg_config ();

  params = parse_parameter ({"-nodeps"}, varargin{:});
  if (! isempty (params.error))
    error ("pkg_unload: %s\n\n%s\n\n", params.error, help ("pkg_unload"));
  endif

  if (isempty (params.in))
    error ("pkg_unload: at least one package name is required");
  endif

  installed_pkgs_lst = pkg_list ();
  num_packages = numel (installed_pkgs_lst);

  ## Read package names and installdirs into a more convenient format.
  pnames = cellfun (@(x) x.name, installed_pkgs_lst, "UniformOutput", false);
  pvers = cellfun (@(x) x.version, installed_pkgs_lst, "UniformOutput", false);
  pids = strcat (pnames, "@", pvers);
  pdirs = cellfun (@(x) x.dir, installed_pkgs_lst, "UniformOutput", false);

  ## Get the current octave path.
  p = strtrim (ostrsplit (path (), pathsep ()));

  ## Unload package_name1 ...
  dirs = {};
  desc = {};
  idx = [];
  for i = 1:length (params.in)
    if (any (params.in{i} == "@"))
      idx2 = find (strcmp (pids, params.in{i}));
    else
      ## If only name given "pkg unload io", take newest version.
      idx2 = find (strcmp (pnames, params.in{i}), 1, "last");
    endif
    if (! any (idx2))
      error ("package %s is not installed", params.in{i});
    endif
    idx(end + 1) = idx2;
  endfor
  dirs = pdirs(idx);
  desc = installed_pkgs_lst(idx);

  if (! params.flags.("-nodeps"))
    ## Check for loaded inverse dependencies of packages to be unloaded.
    ## First create a list of loaded packages.
    jdx = find (cellfun (@(x) x.loaded, installed_pkgs_lst));
    
    ## Add inverse dependencies to field "invdeps" of installed_pkgs_lst
    installed_pkgs_lst = get_inverse_dependencies (installed_pkgs_lst);

    ## Exclude packages requested to be unloaded
    jdx = setdiff (jdx, idx);
    loaded_pkgs = installed_pkgs_lst(jdx);
    lpnames = pnames(jdx);
    p2unload = pnames(idx);
    linvdeps = {};
    for i = 1:numel (desc)
      ## Which inverse dependencies depend on this package-to-be-unloaded?
      linvdeps = [linvdeps, get_inv_deps(desc{i}, loaded_pkgs, lpnames){:}];
    endfor
    if (! isempty (linvdeps))
      linvdeps = unique (linvdeps);
      txt = strjoin (linvdeps, "\n\t - ");
      error (["pkg: the following loaded package(s):\n", ...
              "\t - %s\n", ...
              "depend on the one(s) you want to unload.\n", ...
              "Either unload any depender package(s), or use the '-nodeps' flag.\n", ...
              "Note: the '-nodeps' flag may affect functionality of these packages.\n"],
             txt);
    endif
  endif

  ## Check for architecture dependent directories.
  archdirs = {};
  for i = 1:numel (dirs)
    archdir = fullfile (desc{i}.archprefix, [pkg_config()].arch);
    if (isfolder (archdir))
      archdirs{end+1} = dirs{i};
      archdirs{end+1} = archdir;
    else
      archdirs{end+1} = dirs{i};
    endif
  endfor

  ## Unload the packages.
  for i = 1:numel (archdirs)
    d = archdirs{i};
    idx = strcmp (p, d);
    if (any (idx))
      rmpath (d);
      ## FIXME: We should also check if we need to remove items from EXEC_PATH.
      ##if (isguirunning)
      ##  __event_manager_update_gui_lexer__;  Octave 7
      ##endif
    endif
  endfor

endfunction


function linvdeps = get_inv_deps (desc, loaded_pkgs, lpnames)

  ## Which nested loaded inverse dependencies depend on the package in desc?
  linvdeps = intersect (desc.invdeps, lpnames);
  for i = 1:numel (linvdeps)
    kdx = find (ismember (lpnames, linvdeps{i}));
    linvdeps = [ linvdeps (get_inv_deps (loaded_pkgs{kdx}, ...
                                         loaded_pkgs, lpnames)){:} ];
  endfor

endfunction
