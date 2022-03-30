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
## @deftypefn {} {[@var{available_packages}, @var{checksums}, @var{pkg_idx}] =} db_packages_list_packages ()
## List available packages from Octave Packages.
##
## @var{available_packages} is a cell array of strings only with package names.
##
## @var{checksums} is a cell array of strings where each row
## @code{@var{checksums}(i,:)} contains three strings for quick lookup
##
## @code{@{ "sha256", "url", "name@atchar{}version" @}}.
##
## @var{pkg_idx} is the raw Octave Packages index, which is only queried
## once per Octave session due to persistent variables.
## @end deftypefn

function [available_packages, checksums, pkg_idx] = db_packages_list_packages ()

  persistent index = {};
  persistent checksum_cache = {};

  ## Do not get removed from memory, even if "clear" is called.
  mlock ();

  if (! isempty (index))
    available_packages = fieldnames (index);
    checksums = checksum_cache;
    pkg_idx = index;
    return;
  endif

  ## Try once per Octave session to get the list of all packages.
  index = package_index_resolve ();

  available_packages = fieldnames (index);

  ## Build checksum cache
  for i = 1:numel (available_packages)
    versions = getfield (getfield (index, available_packages{i}), "versions");
    versions = [{versions.sha256}; {versions.url}; ...
                strcat([available_packages{i}, "@"], {versions.id})]';
    checksum_cache = [checksum_cache; versions];
  endfor

  ## Check for checksum sanity.
  chksums = checksum_cache(:,1);
  chksums(cellfun (@isempty, chksums)) = [];

  if (length (chksums) != length (unique (chksums)))
    error (["pkg>db_packages_list_packages: checksums corrupt.\nPlease ", ...
      "report a bug at <https://github.com/gnu-octave/packages/issues>."]);
  endif

  checksums = checksum_cache;
  pkg_idx = index;

endfunction


function __pkg__ = package_index_resolve ()

  cache_dir = [pkg_config()].cache_dir;
  cache_file = fullfile (cache_dir, "octave_package_index.mat");

  try
    data = urlread ("https://gnu-octave.github.io/packages/packages/")(6:end);
  catch
    if (exist (cache_file, "file") == 2)
      load (cache_file, "__pkg__", "timestamp");
      ## Warn if package information is older than a day.
      age_in_days = (time () - timestamp) / 60;
      if (age_in_days > 1)
        warning (["pkg>db_packages_list_packages: could not retrieve ", ...
          "package information from the internet.\n  The cached package ", ...
          "information is %.0f day(s) old.\n"], age_in_days);
      endif
      return
    else
      error (["pkg>db_packages_list_packages: checksums corrupt.\nPlease ", ...
        "report a bug at <https://github.com/gnu-octave/packages/issues>."]);
    endif
  end_try_catch
  data = strrep (data, "&gt;",  ">");
  data = strrep (data, "&lt;",  "<");
  data = strrep (data, "&amp;", "&");
  data = strrep (data, "&#39;", "'");
  eval (data);
  if (exist (cache_dir, "dir") == 7)
    timestamp = time ();
    save (cache_file, "__pkg__", "timestamp");
  endif
endfunction
