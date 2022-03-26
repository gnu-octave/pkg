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
## @deftypefn {} {} pkg_install (@var{files})
## Install named packages.  For example,
##
## @example
## pkg install image-1.0.0.tar.gz
## @end example
##
## @noindent
## installs the package found in the file @file{image-1.0.0.tar.gz}.  The
## file containing the package can be a URL, e.g.,
##
## @example
## pkg install 'http://somewebsite.org/image-1.0.0.tar.gz'
## @end example
##
## @noindent
## installs the package found in the given URL@.  This
## requires an internet connection and the cURL library.
##
## @noindent
## @emph{Security risk}: no verification of the package is performed
## before the installation.  It has the same security issues as manually
## downloading the package from the given URL and installing it.
##
## @noindent
## @emph{No support}: the GNU Octave community is not responsible for
## packages installed from foreign sites.  For support or for
## reporting bugs you need to contact the maintainers of the installed
## package directly (see the @file{DESCRIPTION} file of the package)
##
## The @var{option} variable can contain options that affect the manner
## in which a package is installed.  These options can be one or more of
##
## @table @code
## @item -nodeps
## The package manager will disable dependency checking.  With this option it
## is possible to install a package even when it depends on another package
## which is not installed on the system.  @strong{Use this option with care.}
##
## @item -local
## A local installation (package available only to current user) is forced,
## even if the user has system privileges.
##
## @item -global
## A global installation (package available to all users) is forced, even if
## the user doesn't normally have system privileges.
##
## @item -forge
## Install a package directly from the Octave Forge repository.  This
## requires an internet connection and the cURL library.
##
## @emph{Security risk}: no verification of the package is performed
## before the installation.  There are no signature for packages, or
## checksums to confirm the correct file was downloaded.  It has the
## same security issues as manually downloading the package from the
## Octave Forge repository and installing it.
##
## @item -verbose
## The package manager will print the output of all commands as
## they are performed.
## @end table
## @end deftypefn

function pkg_install (varargin)

  config = pkg_config ();

  params = parse_parameter ({"-force", "-forge", "-global", "-local", ...
    "-nocache", "-nodeps", "-resolve-only", "-verbose"}, ...
    varargin{:});
  if (! isempty (params.error))
    error ("pkg_install: %s\n\n%s\n\n", params.error, help ("pkg_install"));
  endif

  if (isempty (params.in))
    error ("pkg_install: at least one package name is required");
  endif
  files = params.in;

  ## Helper function
  sha256sum = @(x) hash ("sha256", fileread (x));
  if (ispc ())
    oct_glob = @__wglob__;
  else
    oct_glob = @glob;
  endif

  ## Determine download directory.
  if (isempty (config.cache_dir) || params.flags.("-nocache"))
    download_dir = tempname ();
  else
    download_dir = config.cache_dir;
  endif

  ## Create download directory if it does not exist.
  if (isempty (oct_glob (download_dir)))
    [status, msg] = mkdir (download_dir);
    if (status != 1)
      error ("pkg_install: cannot create download directory '%s': %s\n", ...
        download_dir, msg);
    endif
  endif


  ##################################
  ## 1. Classify and resolve input
  ##################################

  ## A package can be perfectly identified given three properties:
  ##
  ##   1. url: where it was downloaded from
  ##   2. id:  name@version tuple
  ##   3. checksum: sha256 sum of the package tarball
  ##
  ## With reservations it is possible to deduce all from one property,
  ## with the help of Octave packages and less effective with Octave Forge.

  items = struct ("url", repmat({""}, 1, numel (files)), ...
                  "id", "", ...
                  "checksum", "", ...
                  "needed_by", cell(1, numel (files)));

  for i = 1:numel (files)
    if (! isempty (oct_glob (files{i})));               # Is local file?
      items(i).url      = make_absolute_filename (files{i});
      items(i).checksum = sha256sum (items(i).url);
    elseif (length (regexp (files{i}, '^\w+://')) > 0)  # Looks like URL?
      items(i).url = files{i};
    else
      items(i).id = files{i};  # Otherwise ID to resolve.
    endif
  endfor

  ## Resolve (complete) data from package databases.
  if (params.flags.("-forge"))
    resolver = "Octave Forge";
    forge_hint = ["Tip: avoid the '-forge' flag to search in the larger ", ...
      "Octave Packages database."];
    tic ();
    items = db_forge_resolve (items);
    resolver_time = toc ();
    pkg_list = db_forge_list_packages ();
  else
    resolver = "Octave Packages";
    forge_hint = "";
    tic ();
    items = db_packages_resolve (items, params);
    resolver_time = toc ();
    [pkg_list, checksums] = db_packages_list_packages ();
  endif

  ## Resolver sanity check
  for i = 1:numel (items)
    ## If ID was not resolved to URL, probably the package does not exist:
    ## suggest an existing one.
    if (isempty (items(i).url))
      [name, ver] = strtok (items(i).id, "@");
      ## If package name correct, but only version wrong: Suggest available versions.
      if (exist ("checksums", "var") && (sum (strcmp (name, pkg_list)) == 1))
        similar = {checksums{:,3}};
        similar = similar(strncmp (similar, [name, "@"], length (name) + 1));
      else
        similar = suggest (items(i).id, pkg_list);
      endif
      if (isempty (similar))
        error (["pkg_install: no package named '%s' or similar was found.", ...
          "%s\n"], items(i).id, ["\n\n", forge_hint]);
      else
        error (["pkg_install: no package named '%s' was found.\n", ...
          "Similar package names are:\n\n\t%s\n\n"], items(i).id, ...
          strjoin (similar, ", "));
      endif
    endif
  endfor

  ## Resolver summary
  if (params.flags.("-verbose"))
    printf ("\n  Resolver summary (%s, %.2f seconds)", resolver, resolver_time);
    printf ("\n  ================\n\n");
  endif
  if (isempty (items))
    pkg_printf (["\n  <check> Packages are already installed.", ...
      "\n\n  See installed packages with '<blue>pkg list</blue>' or ", ...
      "force package installation with '<blue>pkg install -force</blue>'.", ...
      "\n\n"]);
  endif
  for i = 1:numel (items)
    if (! isempty (items(i).id))
      id = items(i).id;
    elseif (! isempty (items(i).url))
      [~, id, ext] = fileparts (items(i).url);
      id = [id, ext];
    else
      id = "???";
    endif
    if (! isempty (items(i).url))
      from = fileparts (items(i).url);
    else
      from = "???";
    endif
    if (! isempty (items(i).checksum))
      checksum = items(i).checksum;
    else
      checksum = "none";
    endif
    if (isempty (items(i).needed_by))
      needed_by = "none";
    else
      needed_by = strjoin (items(i).needed_by, ", ");
    endif
    if (params.flags.("-verbose"))
      printf ("  Install ");
    elseif (i == 1)
      printf ("\n  Installing:  ");
    endif
    pkg_printf ("<blue>%s</blue>  ", id);
    if (params.flags.("-verbose"))
      printf ("\n      from:      %s", from);
      printf ("\n      checksum:  %s", checksum);
      printf ("\n      needed by: %s\n", needed_by);
    elseif (i == numel (items))
      printf ("\n\n");
    endif
  endfor

  if (params.flags.("-resolve-only"))
    return;
  endif


  ###########################################
  ## 2. Perform installation in given order
  ###########################################

  for i = 1:numel (items)
    if (isempty (items(i).id))
      [~, id, ext] = fileparts (items(i).url);
      id = [id, ext];
    else
      id = items(i).id;
    endif
    pkg_printf ("  Install <blue>%s</blue> \n", id);

    ## Lookup URL: existing local file, file in cache, otherwise download.
    cache_files = oct_glob (fullfile (download_dir, [items(i).checksum, ".*"]));
    if (length (oct_glob (items(i).url)) == 1)
      pkg_printf ("      <check> local file\n");
    elseif (length (cache_files) == 1)
      items(i).url = cache_files{1};
      pkg_printf ("      <check> file in cache\n");
    else  # Download file.
      pkg_printf ("      <wait> downloading ... ");
      new_file = tempname (download_dir);
      [~, success, msg] = urlwrite (items(i).url, new_file);
      if (success != 1)
        error ("pkg_install: failed downloading '%s': %s", items(i).url, msg);
      endif
      ## Try to get suffix from URL
      suffix = regexp (items(i).url, '(?:\.tar)?\.[A-Za-z0-9]+$', "match");
      if (isempty (suffix))
        suffix = "";
      else
        suffix = suffix{1};
      endif
      items(i).url = fullfile (download_dir, [sha256sum(new_file), suffix]);
      movefile (new_file, items(i).url);
      pkg_printf ("\r      <check> downloaded                    \n");
    endif

    ## Test checksum if available.
    if (! isempty (items(i).checksum))
      if (strcmp (sha256sum (items(i).url), items(i).checksum))
        pkg_printf ("      <check> checksum ok\n");
      else
        pkg_printf (["      <cross> <red>invalid checksum of '%s'.", ...
          "\n\tactual:   '%s'\n", ...
          "\n\texpected: '%s'</red>\n"],
          items(i).url, sha256sum (items(i).url), items(i).checksum);
      endif
    else
      pkg_printf ("      <warn> no checksum available\n");
    endif

    ## Try to download the file to cache or temporary directory.
    pkg_printf ("      <wait> installing ... ");
    pkg_install_internal (items(i).url, params);
    pkg_printf ("\r      <check> installed                    \n");
  endfor

endfunction


function pkg_install_internal (pkg_archive, params)

  conf = pkg_config ();
  global_install = params.flags.("-global");
  if (global_install)
    prefix = conf.global.prefix;
    archprefix = conf.global.archprefix;
  else
    prefix = conf.local.prefix;
    archprefix = conf.local.archprefix;
  endif

  ## Check that the directory in prefix exist.  If it doesn't: create it!
  if (! isfolder (prefix))
    warning ("creating installation directory %s", prefix);
    [status, msg] = mkdir (prefix);
    if (status != 1)
      error ("could not create installation directory: %s", msg);
    endif
  endif

  ## In case of error directories are removed.
  confirm_recursive_rmdir (false, "local");

  ## Uncompress the packages and read the DESCRIPTION files.
  try
    ## Create a temporary directory.
    tmpdir = tempname ();
    if (params.flags.("-verbose"))
      printf ("mkdir (%s)\n", tmpdir);
    endif
    [status, msg] = mkdir (tmpdir);
    if (status != 1)
      error ("couldn't create temporary directory: %s", msg);
    endif

    ## Uncompress the package.
    [~, ~, ext] = fileparts (pkg_archive);
    if (strcmpi (ext, ".zip"))
      func_uncompress = @unzip;
    else
      func_uncompress = @untar;
    endif
    if (params.flags.("-verbose"))
      printf ("%s (%s, %s)\n", func2str (func_uncompress), pkg_archive, tmpdir);
    endif
    func_uncompress (pkg_archive, tmpdir);

    ## Get the name of the directories produced by tar.
    [dirlist, err, msg] = readdir (tmpdir);
    if (err)
      error ("pkg_install: couldn't read directory produced by tar: %s", msg);
    endif
    if (length (dirlist) > 3)
      error ("pkg_install: bundles of packages are not allowed");
    endif

    ## The filename pointed to an uncompressed package to begin with.
    if (isfolder (pkg_archive))
      dirlist = {".", "..", pkg_archive};
    endif

    if (exist (pkg_archive, "file") || isfolder (pkg_archive))
      ## The two first entries of dirlist are "." and "..".
      if (exist (pkg_archive, "file"))
        packdir = fullfile (tmpdir, dirlist{3});
      else
        packdir = fullfile (pwd (), dirlist{3});
      endif

      ## Make sure the package contains necessary files.
      verify_directory (packdir);

      ## Read the DESCRIPTION file.
      desc = get_description (fullfile (packdir, "DESCRIPTION"));

      ## Set default installation directory.
      desc.dir = fullfile (prefix, [desc.name "@" desc.version]);

      ## Set default architectire dependent installation directory.
      desc.archprefix = fullfile (archprefix, [desc.name "@" desc.version]);
      desc.archdir    = fullfile (desc.archprefix, conf.arch);
    endif
  catch
    ## Something went wrong, delete tmpdir.
    [~] = rmdir (tmpdir, "s");
    rethrow (lasterror ());
  end_try_catch

  ## Get the list of installed packages.
  [local_packages, global_packages] = pkg_list ();

  ## Check dependencies.
  if (! params.flags.("-nodeps"))
    ok = true;
    error_text = "";
    bad_deps = get_unsatisfied_deps (desc, [local_packages, global_packages]);
    ## Are there any unsatisfied dependencies?
    if (! isempty (bad_deps))
      ok = false;
      for i = 1:length (bad_deps)
        dep = bad_deps{i};
        error_text = [error_text " " desc.name " needs " ...
                      dep.package " " dep.operator " " dep.version "\n"];
      endfor
    endif

    ## Did we find any unsatisfied dependencies?
    if (! ok)
      error ("pkg_install: the following dependencies were unsatisfied:\n  %s", error_text);
    endif
  endif

  ## Perform package installation.
  try
    prepare_installation (desc, packdir);
    configure_make (desc, packdir, params.flags.("-verbose"));
    copy_built_files (desc, packdir, params.flags.("-verbose"));
    copy_files (desc, packdir, global_install);
    create_pkgadddel (desc, packdir, "PKG_ADD", global_install);
    create_pkgadddel (desc, packdir, "PKG_DEL", global_install);
    finish_installation (desc, packdir);
    ##TODO: generate_lookfor_cache (desc);
  catch
    ## Something went wrong, delete tmpdir.
    [~] = rmdir (tmpdir, "s");
    [~] = rmdir (desc.dir, "s");
    [~] = rmdir (desc.archdir, "s");
    rethrow (lasterror ());
  end_try_catch

  ## Check if the installed directory is empty.  If it is remove it
  ## from the list.
  if (dirempty (desc.dir, {"packinfo", "doc"}) && dirempty (desc.archdir))
    [~] = rmdir (desc.dir, "s");
    [~] = rmdir (desc.archdir, "s");
    error ("pkg_install: package '%s' is empty\n", desc.name);
  endif

  ## Add the packages to the package list.
  try
    if (global_install)
      global_packages = save_order ({global_packages, desc});
      if (ispc)
        ## On Windows ensure LFN paths are saved rather than 8.3 style paths
        global_packages = standardize_paths (global_packages);
      endif
      global_packages = make_rel_paths (global_packages);
      save (conf.global.list, "global_packages");
    else
      local_packages = save_order ([local_packages, desc]);
      if (ispc)
        local_packages = standardize_paths (local_packages);
      endif
      save (conf.local.list, "local_packages");
    endif
  catch
    ## Something went wrong, delete tmpdir.
    [~] = rmdir (tmpdir, "s");
    [~] = rmdir (desc.dir, "s");
    [~] = rmdir (desc.archdir, "s");
    if (global_install)
      printf ("error: couldn't append to '%s'.\n", conf.global.list);
    else
      printf ("error: couldn't append to '%s'.\n", conf.local.list);
    endif
    rethrow (lasterror ());
  end_try_catch

  ## All is well, let's clean up.
  [status, msg] = rmdir (tmpdir, "s");
  if ((status != 1) && isfolder (tmpdir))
    warning ("couldn't clean up after my self: %s\n", msg);
  endif

endfunction


function pkg = extract_pkg (nm, pat)

  mfile_encoding = __mfile_encoding__ ();
  if (strcmp (mfile_encoding, "system"))
    mfile_encoding = __locale_charset__ ();
  endif
  fid = fopen (nm, "rt", "n", mfile_encoding);
  pkg = "";
  if (fid >= 0)
    while (! feof (fid))
      ln = __u8_validate__ (fgetl (fid));
      if (ln > 0)
        t = regexp (ln, pat, "tokens");
        if (! isempty (t))
          pkg = [pkg "\n" t{1}{1}];
        endif
      endif
    endwhile
    if (! isempty (pkg))
      pkg = [pkg "\n"];
    endif
    fclose (fid);
  endif

endfunction


## Make sure the package contains the essential files.
function verify_directory (dir)

  needed_files = {"COPYING", "DESCRIPTION"};
  for f = needed_files
    if (! exist (fullfile (dir, f{1}), "file"))
      error ("package is missing file: %s", f{1});
    endif
  endfor

endfunction


function prepare_installation (desc, packdir)

  ## Is there a pre_install to call?
  if (exist (fullfile (packdir, "pre_install.m"), "file"))
    wd = pwd ();
    try
      cd (packdir);
      pre_install (desc);
      cd (wd);
    catch
      cd (wd);
      rethrow (lasterror ());
    end_try_catch
  endif

  ## If the directory "inst" doesn't exist, we create it.
  inst_dir = fullfile (packdir, "inst");
  if (! isfolder (inst_dir))
    [status, msg] = mkdir (inst_dir);
    if (status != 1)
      sts = rmdir (desc.dir, "s");
      error ("the 'inst' directory did not exist and could not be created: %s",
             msg);
    endif
  endif

endfunction


function copy_built_files (desc, packdir, verbose)

  src = fullfile (packdir, "src");
  if (! isfolder (src))
    return;
  endif

  ## Copy files to "inst" and "inst/arch" (this is instead of 'make install').
  files = fullfile (src, "FILES");
  instdir = fullfile (packdir, "inst");
  archdir = fullfile (packdir, "inst", [pkg_config()].arch);

  ## Get filenames.
  if (exist (files, "file"))
    [fid, msg] = fopen (files, "r");
    if (fid < 0)
      error ("couldn't open %s: %s", files, msg);
    endif
    filenames = char (fread (fid))';
    fclose (fid);
    if (filenames(end) == "\n")
      filenames(end) = [];
    endif
    filenames = strtrim (ostrsplit (filenames, "\n"));
    delete_idx = [];
    for i = 1:length (filenames)
      if (! all (isspace (filenames{i})))
        filenames{i} = fullfile (src, filenames{i});
      else
        delete_idx(end+1) = i;
      endif
    endfor
    filenames(delete_idx) = [];
  else
    m = dir (fullfile (src, "*.m"));
    oct = dir (fullfile (src, "*.oct"));
    mex = dir (fullfile (src, "*.mex"));
    tst = dir (fullfile (src, "*tst"));

    filenames = cellfun (@(x) fullfile (src, x),
                         {m.name, oct.name, mex.name, tst.name},
                         "uniformoutput", false);
  endif

  ## Split into architecture dependent and independent files.
  if (isempty (filenames))
    idx = [];
  else
    idx = cellfun ("is_architecture_dependent", filenames);
  endif
  archdependent = filenames(idx);
  archindependent = filenames(! idx);

  ## Copy the files.
  if (! all (isspace ([filenames{:}])))
      if (! isfolder (instdir))
        mkdir (instdir);
      endif
      if (! all (isspace ([archindependent{:}])))
        if (verbose)
          printf ("copyfile");
          printf (" %s", archindependent{:});
          printf ("%s\n", instdir);
        endif
        [status, output] = copyfile (archindependent, instdir);
        if (status != 1)
          sts = rmdir (desc.dir, "s");
          error ("Couldn't copy files from 'src' to 'inst': %s", output);
        endif
      endif
      if (! all (isspace ([archdependent{:}])))
        if (verbose)
          printf ("copyfile");
          printf (" %s", archdependent{:});
          printf (" %s\n", archdir);
        endif
        if (! isfolder (archdir))
          mkdir (archdir);
        endif
        [status, output] = copyfile (archdependent, archdir);
        if (status != 1)
          sts = rmdir (desc.dir, "s");
          error ("Couldn't copy files from 'src' to 'inst': %s", output);
        endif
      endif
  endif

endfunction


function dep = is_architecture_dependent (nm)

  persistent archdepsuffix = {".oct", ".mex", ".a", ".lib", ".so", ...
                              "tst", ".so.*", ".dll", "dylib"};

  dep = false;
  for i = 1 : length (archdepsuffix)
    ext = archdepsuffix{i};
    if (ext(end) == "*")
      isglob = true;
      ext(end) = [];
    else
      isglob = false;
    endif
    pos = strfind (nm, ext);
    if (pos)
      if (! isglob && (length (nm) - pos(end) != length (ext) - 1))
        continue;
      endif
      dep = true;
      break;
    endif
  endfor

endfunction


function copy_files (desc, packdir, global_install)

  ## Create the installation directory.
  if (! isfolder (desc.dir))
    [status, output] = mkdir (desc.dir);
    if (status != 1)
      error ("couldn't create installation directory %s : %s",
             desc.dir, output);
    endif
  endif

  octfiledir = desc.archdir;

  ## Copy the files from "inst" to installdir.
  instdir = fullfile (packdir, "inst");
  if (! dirempty (instdir))
    [status, output] = copyfile (fullfile (instdir, "*"), desc.dir);
    if (status != 1)
      sts = rmdir (desc.dir, "s");
      error ("couldn't copy files to the installation directory");
    endif
    target_dir = fullfile (desc.dir, [pkg_config()].arch);
    if (isfolder (target_dir) && ! is_same_file (target_dir, octfiledir))
      if (! isfolder (octfiledir))
        ## Can be required to create up to three levels of dirs.
        octm1 = fileparts (octfiledir);
        if (! isfolder (octm1))
          octm2 = fileparts (octm1);
          if (! isfolder (octm2))
            octm3 = fileparts (octm2);
            if (! isfolder (octm3))
              [status, output] = mkdir (octm3);
              if (status != 1)
                sts = rmdir (desc.dir, "s");
                error ("couldn't create installation directory %s : %s",
                       octm3, output);
              endif
            endif
            [status, output] = mkdir (octm2);
            if (status != 1)
              sts = rmdir (desc.dir, "s");
              error ("couldn't create installation directory %s : %s",
                     octm2, output);
            endif
          endif
          [status, output] = mkdir (octm1);
          if (status != 1)
            sts = rmdir (desc.dir, "s");
            error ("couldn't create installation directory %s : %s",
                   octm1, output);
          endif
        endif
        [status, output] = mkdir (octfiledir);
        if (status != 1)
          sts = rmdir (desc.dir, "s");
          error ("couldn't create installation directory %s : %s",
                 octfiledir, output);
        endif
      endif
      [status, output] = movefile (fullfile (target_dir, "*"), octfiledir);
      sts = rmdir (target_dir, "s");

      if (status != 1)
        sts = rmdir (desc.dir, "s");
        sts = rmdir (octfiledir, "s");
        error ("couldn't copy files to the installation directory");
      endif
    endif

  endif

  ## Create the "packinfo" directory.
  packinfo = fullfile (desc.dir, "packinfo");
  [status, msg] = mkdir (packinfo);
  if (status != 1)
    sts = rmdir (desc.dir, "s");
    sts = rmdir (octfiledir, "s");
    error ("couldn't create packinfo directory: %s", msg);
  endif

  packinfo_copy_file ("DESCRIPTION", "required", packdir, packinfo, desc, octfiledir);
  packinfo_copy_file ("COPYING", "required", packdir, packinfo, desc, octfiledir);
  packinfo_copy_file ("CITATION", "optional", packdir, packinfo, desc, octfiledir);
  packinfo_copy_file ("NEWS", "optional", packdir, packinfo, desc, octfiledir);
  packinfo_copy_file ("ONEWS", "optional", packdir, packinfo, desc, octfiledir);
  packinfo_copy_file ("ChangeLog", "optional", packdir, packinfo, desc, octfiledir);

  ## Is there an INDEX file to copy or should we generate one?
  index_file = fullfile (packdir, "INDEX");
  if (exist (index_file, "file"))
    packinfo_copy_file ("INDEX", "required", packdir, packinfo, desc, octfiledir);
  else
    try
      write_index (desc, fullfile (packdir, "inst"),
                   fullfile (packinfo, "INDEX"), global_install);
    catch
      sts = rmdir (desc.dir, "s");
      sts = rmdir (octfiledir, "s");
      rethrow (lasterror ());
    end_try_catch
  endif

  ## Is there an 'on_uninstall.m' to install?
  packinfo_copy_file ("on_uninstall.m", "optional", packdir, packinfo, desc, octfiledir);

  ## Is there a doc/ directory that needs to be installed?
  docdir = fullfile (packdir, "doc");
  if (isfolder (docdir) && ! dirempty (docdir))
    [status, output] = copyfile (docdir, desc.dir);
  endif

  ## Is there a bin/ directory that needs to be installed?
  ## FIXME: Need to treat architecture dependent files in bin/
  bindir = fullfile (packdir, "bin");
  if (isfolder (bindir) && ! dirempty (bindir))
    [status, output] = copyfile (bindir, desc.dir);
  endif

endfunction


function packinfo_copy_file (filename, requirement, packdir, packinfo, desc, octfiledir)

  filepath = fullfile (packdir, filename);
  if (! exist (filepath, "file") && strcmpi (requirement, "optional"))
    ## do nothing, it's still OK
  else
    [status, output] = copyfile (filepath, packinfo);
    if (status != 1)
      sts = rmdir (desc.dir, "s");
      sts = rmdir (octfiledir, "s");
      error ("Couldn't copy %s file: %s", filename, output);
    endif
  endif

endfunction


## Create an INDEX file for a package that doesn't provide one.
##   'desc'  describes the package.
##   'dir'   is the 'inst' directory in temporary directory.
##   'index_file' is the name (including path) of resulting INDEX file.
function write_index (desc, dir, index_file, global_install)

  ## Get names of functions in dir
  [files, err, msg] = readdir (dir);
  if (err)
    error ("couldn't read directory %s: %s", dir, msg);
  endif

  ## Get classes in dir
  class_idx = find (strncmp (files, '@', 1));
  for k = 1:length (class_idx)
    class_name = files {class_idx(k)};
    class_dir = fullfile (dir, class_name);
    if (isfolder (class_dir))
      [files2, err, msg] = readdir (class_dir);
      if (err)
        error ("couldn't read directory %s: %s", class_dir, msg);
      endif
      files2 = strcat (class_name, filesep (), files2);
      files = [files; files2];
    endif
  endfor

  ## Check for architecture dependent files.
  tmpdir = desc.archdir;
  if (isfolder (tmpdir))
    [files2, err, msg] = readdir (tmpdir);
    if (err)
      error ("couldn't read directory %s: %s", tmpdir, msg);
    endif
    files = [files; files2];
  endif

  functions = {};
  for i = 1:length (files)
    file = files{i};
    lf = length (file);
    if (lf > 2 && strcmp (file(end-1:end), ".m"))
      functions{end+1} = file(1:end-2);
    elseif (lf > 4 && strcmp (file(end-3:end), ".oct"))
      functions{end+1} = file(1:end-4);
    endif
  endfor

  ## Does desc have a categories field?
  if (! isfield (desc, "categories"))
    error ("the DESCRIPTION file must have a Categories field, when no INDEX file is given");
  endif
  categories = strtrim (strsplit (desc.categories, ","));
  if (length (categories) < 1)
    error ("the Category field is empty");
  endif

  ## Write INDEX.
  fid = fopen (index_file, "w");
  if (fid == -1)
    error ("couldn't open %s for writing", index_file);
  endif
  fprintf (fid, "%s >> %s\n", desc.name, desc.title);
  fprintf (fid, "%s\n", categories{1});
  fprintf (fid, "  %s\n", functions{:});
  fclose (fid);

endfunction


function create_pkgadddel (desc, packdir, nm, global_install)

  instpkg = fullfile (desc.dir, nm);
  instfid = fopen (instpkg, "at"); # append to support PKG_ADD at inst/
  ## If it is exists, most of the PKG_* file should go into the
  ## architecture dependent directory so that the autoload/mfilename
  ## commands work as expected.  The only part that doesn't is the
  ## part in the main directory.
  archdir = fullfile (getarchprefix (desc, global_install),
                      [desc.name "-" desc.version], [pkg_config()].arch);
  if (isfolder (desc.archdir))
    archpkg = fullfile (desc.archdir, nm);
    archfid = fopen (archpkg, "at");
  else
    archpkg = instpkg;
    archfid = instfid;
  endif

  if (archfid >= 0 && instfid >= 0)
    if (ispc ())
      oct_glob = @__wglob__;
    else
      oct_glob = @glob;
    endif

    ## Search all dot-m files for PKG commands.
    lst = oct_glob (fullfile (packdir, "inst", "*.m"));
    for i = 1:length (lst)
      nam = lst{i};
      fwrite (instfid, extract_pkg (nam, ['^[#%][#%]* *' nm ': *(.*)$']));
    endfor

    ## Search all C++ source files for PKG commands.
    cc_lst = oct_glob (fullfile (packdir, "src", "*.cc"));
    cpp_lst = oct_glob (fullfile (packdir, "src", "*.cpp"));
    cxx_lst = oct_glob (fullfile (packdir, "src", "*.cxx"));
    lst = [cc_lst; cpp_lst; cxx_lst];
    for i = 1:length (lst)
      nam = lst{i};
      fwrite (archfid, extract_pkg (nam, ['^//* *' nm ': *(.*)$']));
      fwrite (archfid, extract_pkg (nam, ['^/\** *' nm ': *(.*) *\*/$']));
    endfor

    ## Add developer included PKG commands.
    packdirnm = fullfile (packdir, nm);
    if (exist (packdirnm, "file"))
      fid = fopen (packdirnm, "rt");
      if (fid >= 0)
        while (! feof (fid))
          ln = fgets (fid);
          if (ln > 0)
            fwrite (archfid, ln);
          endif
        endwhile
        fclose (fid);
      endif
    endif

    ## If the files is empty remove it.
    fclose (instfid);
    t = dir (instpkg);
    if (t.bytes <= 0)
      unlink (instpkg);
    endif

    if (instfid != archfid)
      fclose (archfid);
      t = dir (archpkg);
      if (t.bytes <= 0)
        unlink (archpkg);
      endif
    endif
  endif

endfunction


function archprefix = getarchprefix (desc, global_install)

  if (global_install)
    [~, archprefix] = default_prefix (global_install);
    archprefix = fullfile (archprefix, [desc.name "-" desc.version]);
  else
    archprefix = desc.dir;
  endif

endfunction


function finish_installation (desc, packdir)

  ## Is there a post-install to call?
  if (exist (fullfile (packdir, "post_install.m"), "file"))
    wd = pwd ();
    try
      cd (packdir);
      post_install (desc);
      cd (wd);
    catch
      cd (wd);
      sts = rmdir (desc.dir, "s");
      sts = rmdir (desc.archdir, "s");
      rethrow (lasterror ());
    end_try_catch
  endif

endfunction


function generate_lookfor_cache (desc)

  dirs = strtrim (ostrsplit (genpath (desc.dir), pathsep ()));
  if (ispc)
    dirs = cellfun (@canonicalize_file_name, dirs, "uniformoutput", false);
  endif
  for i = 1 : length (dirs)
    doc_cache_create (fullfile (dirs{i}, "doc-cache"), dirs{i});
  endfor

endfunction
