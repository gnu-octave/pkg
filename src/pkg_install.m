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

  pkg_startup_hook ();

  params = parse_parameter ( ...
    {"-forge", "-global", "-local", "-nodeps", "-verbose"}, varargin{:});
  if (! isempty (params.error))
    error ("pkg_install: %s\n\n%s\n\n", params.error, help ("pkg_install"));
  endif

  if (isempty (params.in))
    error ("pkg_install: at least one package name is required");
  endif
  files = params.in;

  ## If something goes wrong, many directories have to be removed.
  confirm_recursive_rmdir (false, "local");

  local_files = {};
  tmp_dir = tempname ();
  unwind_protect

    if (params.flags.("-forge"))
      [urls, local_files] = cellfun ("get_forge_download", files,
                                     "uniformoutput", false);
      [files, succ] = cellfun ("urlwrite", urls, local_files,
                               "uniformoutput", false);
      succ = [succ{:}];
      if (! all (succ))
        i = find (! succ, 1);
        error ("pkg: could not download file %s from URL %s",
               local_files{i}, urls{i});
      endif
    else
      ## If files do not exist, maybe they are not local files.
      ## Try to download them.
      not_local_files = cellfun (@(x) isempty (glob (x)), files);
      if (any (not_local_files))
        [success, msg] = mkdir (tmp_dir);
        if (success != 1)
          error ("pkg: failed to create temporary directory: %s", msg);
        endif

        for file = files(not_local_files)
          file = file{1};
          [~, fname, fext] = fileparts (file);
          tmp_file = fullfile (tmp_dir, [fname fext]);
          local_files{end+1} = tmp_file;
          looks_like_url = regexp (file, '^\w+://');
          if (looks_like_url)
            [~, success, msg] = urlwrite (file, local_files{end});
            if (success != 1)
              error ("pkg: failed downloading '%s': %s", file, msg);
            endif
          else
            looks_like_pkg_name = regexp (file, '^[\w-]+$');
            if (looks_like_pkg_name)
              error (["pkg: file not found: %s.\n" ...
                      "This looks like an Octave Forge package name." ...
                      "  Did you mean:\n" ...
                      "       pkg install -forge %s"], ...
                     file, file);
            else
              error ("pkg: file not found: %s", file);
            endif
          endif
          files{strcmp (files, file)} = local_files{end};

        endfor
      endif
    endif
    pkg_install_internal (files, params);

  unwind_protect_cleanup
    [~] = cellfun ("unlink", local_files);
    if (exist (tmp_dir, "file"))
      [~] = rmdir (tmp_dir, "s");
    endif
  end_unwind_protect

endfunction


function pkg_install_internal (files, params)

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

  ## Get the list of installed packages.
  [local_packages, global_packages] = pkg_list ();

  installed_pkgs_lst = {local_packages{:}, global_packages{:}};

  if (global_install)
    packages = global_packages;
  else
    packages = local_packages;
  endif

  if (ispc ())
    oct_glob = @__wglob__;
  else
    oct_glob = @glob;
  endif

  ## Uncompress the packages and read the DESCRIPTION files.
  tmpdirs = packdirs = descriptions = {};
  try
    ## Warn about non existent files.
    for i = 1:length (files)
      if (isempty (oct_glob (files{i})))
        warning ("file %s does not exist", files{i});
      endif
    endfor

    ## Unpack the package files and read the DESCRIPTION files.
    files = oct_glob (files);
    packages_to_uninstall = [];
    for i = 1:length (files)
      tgz = files{i};

      if (exist (tgz, "file"))
        ## Create a temporary directory.
        tmpdir = tempname ();
        tmpdirs{end+1} = tmpdir;
        if (params.flags.("-verbose"))
          printf ("mkdir (%s)\n", tmpdir);
        endif
        [status, msg] = mkdir (tmpdir);
        if (status != 1)
          error ("couldn't create temporary directory: %s", msg);
        endif

        ## Uncompress the package.
        [~, ~, ext] = fileparts (tgz);
        if (strcmpi (ext, ".zip"))
          func_uncompress = @unzip;
        else
          func_uncompress = @untar;
        endif
        if (params.flags.("-verbose"))
          printf ("%s (%s, %s)\n", func2str (func_uncompress), tgz, tmpdir);
        endif
        func_uncompress (tgz, tmpdir);

        ## Get the name of the directories produced by tar.
        [dirlist, err, msg] = readdir (tmpdir);
        if (err)
          error ("couldn't read directory produced by tar: %s", msg);
        endif

        if (length (dirlist) > 3)
          error ("bundles of packages are not allowed");
        endif
      endif

      ## The filename pointed to an uncompressed package to begin with.
      if (isfolder (tgz))
        dirlist = {".", "..", tgz};
      endif

      if (exist (tgz, "file") || isfolder (tgz))
        ## The two first entries of dirlist are "." and "..".
        if (exist (tgz, "file"))
          packdir = fullfile (tmpdir, dirlist{3});
        else
          packdir = fullfile (pwd (), dirlist{3});
        endif
        packdirs{end+1} = packdir;

        ## Make sure the package contains necessary files.
        verify_directory (packdir);

        ## Read the DESCRIPTION file.
        filename = fullfile (packdir, "DESCRIPTION");
        desc = get_description (filename);

        ## Set default installation directory.
        desc.dir = fullfile (prefix, [desc.name "-" desc.version]);

        ## Set default architectire dependent installation directory.
        desc.archprefix = fullfile (archprefix, [desc.name "-" desc.version]);
        desc.archdir    = fullfile (desc.archprefix, conf.arch);

        ## Save desc.
        descriptions{end+1} = desc;

        ## Are any of the new packages already installed?
        ## If so we'll remove the old version.
        for j = 1:length (packages)
          if (strcmp (packages{j}.name, desc.name))
            packages_to_uninstall(end+1) = j;
          endif
        endfor
      endif
    endfor
  catch
    ## Something went wrong, delete tmpdirs.
    for i = 1:length (tmpdirs)
      sts = rmdir (tmpdirs{i}, "s");
    endfor
    rethrow (lasterror ());
  end_try_catch

  ## Check dependencies.
  if (! params.flags.("-nodeps"))
    ok = true;
    error_text = "";
    for i = 1:length (descriptions)
      desc = descriptions{i};
      idx2 = setdiff (1:length (descriptions), i);
      if (global_install)
        ## Global installation is not allowed to have dependencies on locally
        ## installed packages.
        idx1 = setdiff (1:length (global_packages), packages_to_uninstall);
        pseudo_installed_packages = {global_packages{idx1}, ...
                                     descriptions{idx2}};
      else
        idx1 = setdiff (1:length (local_packages), packages_to_uninstall);
        pseudo_installed_packages = {local_packages{idx1}, ...
                                     global_packages{:}, ...
                                     descriptions{idx2}};
      endif
      bad_deps = get_unsatisfied_deps (desc, pseudo_installed_packages);
      ## Are there any unsatisfied dependencies?
      if (! isempty (bad_deps))
        ok = false;
        for i = 1:length (bad_deps)
          dep = bad_deps{i};
          error_text = [error_text " " desc.name " needs " ...
                        dep.package " " dep.operator " " dep.version "\n"];
        endfor
      endif
    endfor

    ## Did we find any unsatisfied dependencies?
    if (! ok)
      error ("the following dependencies were unsatisfied:\n  %s", error_text);
    endif
  endif

  ## Prepare each package for installation.
  try
    for i = 1:length (descriptions)
      desc = descriptions{i};
      pdir = packdirs{i};
      prepare_installation (desc, pdir);
      configure_make (desc, pdir, params.flags.("-verbose"));
      copy_built_files (desc, pdir, params.flags.("-verbose"));
    endfor
  catch
    ## Something went wrong, delete tmpdirs.
    for i = 1:length (tmpdirs)
      sts = rmdir (tmpdirs{i}, "s");
    endfor
    rethrow (lasterror ());
  end_try_catch

  ## Uninstall the packages that will be replaced.
  try
    for i = packages_to_uninstall
      if (global_install)
        pkg_uninstall (global_packages{i}.name, "-nodeps", "-global");
      else
        pkg_uninstall (local_packages{i}.name, "-nodeps");
      endif
    endfor
  catch
    ## Something went wrong, delete tmpdirs.
    for i = 1:length (tmpdirs)
      sts = rmdir (tmpdirs{i}, "s");
    endfor
    rethrow (lasterror ());
  end_try_catch

  ## Install each package.
  try
    for i = 1:length (descriptions)
      desc = descriptions{i};
      pdir = packdirs{i};
      copy_files (desc, pdir, global_install);
      create_pkgadddel (desc, pdir, "PKG_ADD", global_install);
      create_pkgadddel (desc, pdir, "PKG_DEL", global_install);
      finish_installation (desc, pdir);
      generate_lookfor_cache (desc);
    endfor
  catch
    ## Something went wrong, delete tmpdirs.
    for i = 1:length (tmpdirs)
      sts = rmdir (tmpdirs{i}, "s");
    endfor
    for i = 1:length (descriptions)
      sts = rmdir (descriptions{i}.dir, "s");
      sts = rmdir (descriptions{i}.archdir, "s");
    endfor
    rethrow (lasterror ());
  end_try_catch

  ## Check if the installed directory is empty.  If it is remove it
  ## from the list.
  for i = length (descriptions):-1:1
    if (dirempty (descriptions{i}.dir, {"packinfo", "doc"})
        && dirempty (descriptions{i}.archdir))
      warning ("package %s is empty\n", descriptions{i}.name);
      sts = rmdir (descriptions{i}.dir, "s");
      sts = rmdir (descriptions{i}.archdir, "s");
      descriptions(i) = [];
    endif
  endfor

  ## Add the packages to the package list.
  try
    if (global_install)
      idx = setdiff (1:length (global_packages), packages_to_uninstall);
      global_packages = save_order ({global_packages{idx}, descriptions{:}});
      if (ispc)
        ## On Windows ensure LFN paths are saved rather than 8.3 style paths
        global_packages = standardize_paths (global_packages);
      endif
      global_packages = make_rel_paths (global_packages);
      save (conf.global.list, "global_packages");
      installed_pkgs_lst = {local_packages{:}, global_packages{:}};
    else
      idx = setdiff (1:length (local_packages), packages_to_uninstall);
      local_packages = save_order ({local_packages{idx}, descriptions{:}});
      if (ispc)
        local_packages = standardize_paths (local_packages);
      endif
      if (! exist (fileparts (conf.local.list), "dir")
          && ! mkdir (fileparts (conf.local.list)))
        error ("Octave:pkg:install:local-dir", ...
               "pkg: Could not create directory for local package configuration");
      endif
      save (conf.local.list, "local_packages");
      installed_pkgs_lst = {local_packages{:}, global_packages{:}};
    endif
  catch
    ## Something went wrong, delete tmpdirs.
    for i = 1:length (tmpdirs)
      sts = rmdir (tmpdirs{i}, "s");
    endfor
    for i = 1:length (descriptions)
      sts = rmdir (descriptions{i}.dir, "s");
    endfor
    if (global_install)
      printf ("error: couldn't append to %s\n", conf.global.list);
    else
      printf ("error: couldn't append to %s\n", conf.local.list);
    endif
    rethrow (lasterror ());
  end_try_catch

  ## All is well, let's clean up.
  for i = 1:length (tmpdirs)
    [status, msg] = rmdir (tmpdirs{i}, "s");
    if (status != 1 && isfolder (tmpdirs{i}))
      warning ("couldn't clean up after my self: %s\n", msg);
    endif
  endfor

  ## If there is a NEWS file, mention it.
  ## Check if desc exists too because it's possible to get to this point
  ## without creating it such as giving an invalid filename for the package
  if (exist ("desc", "var")
      && exist (fullfile (desc.dir, "packinfo", "NEWS"), "file"))
    printf (["For information about changes from previous versions " ...
             "of the %s package, run 'news %s'.\n"],
            desc.name, desc.name);
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


function [url, local_file] = get_forge_download (name)
  [ver, url] = get_forge_pkg (name);
  local_file = tempname (tempdir (), [name "-" ver "-"]);
  local_file = [local_file ".tar.gz"];
endfunction


function [ver, url] = get_forge_pkg (name)

## Try to discover the current version of an Octave Forge package from the web,
## using a working internet connection and the urlread function.
## If two output arguments are requested, also return an address from which
## to download the file.

  ## Verify that name is valid.
  if (! (ischar (name) && rows (name) == 1 && ndims (name) == 2))
    error ("get_forge_pkg: package NAME must be a string");
  elseif (! all (isalnum (name) | name == "-" | name == "." | name == "_"))
    error ("get_forge_pkg: invalid package NAME: %s", name);
  endif

  name = tolower (name);

  ## Try to download package's index page.
  [html, succ] = urlread (sprintf ("https://packages.octave.org/%s/index.html",
                                   name));
  if (succ)
    ## Remove blanks for simpler matching.
    html(isspace (html)) = [];
    ## Good.  Let's grep for the version.
    pat = "<tdclass=""package_table"">PackageVersion:</td><td>([\\d.]*)</td>";
    t = regexp (html, pat, "tokens");
    if (isempty (t) || isempty (t{1}))
      error ("get_forge_pkg: could not read version number from package's page");
    else
      ver = t{1}{1};
      if (nargout > 1)
        ## Build download string.
        pkg_file = sprintf ("%s-%s.tar.gz", name, ver);
        url = ["https://packages.octave.org/download/" pkg_file];
        ## Verify that the package string exists on the page.
        if (isempty (strfind (html, pkg_file)))
          warning ("get_forge_pkg: download URL not verified");
        endif
      endif
    endif
  else
    ## Try get the list of all packages.
    [html, succ] = urlread ("https://packages.octave.org/list_packages.php");
    if (! succ)
      error ("get_forge_pkg: could not read URL, please verify internet connection");
    endif
    t = strsplit (html);
    if (any (strcmp (t, name)))
      error ("get_forge_pkg: package NAME exists, but index page not available");
    endif
    ## Try a simplistic method to determine similar names.
    function d = fdist (x)
      len1 = length (name);
      len2 = length (x);
      if (len1 <= len2)
        d = sum (abs (name(1:len1) - x(1:len1))) + sum (x(len1+1:end));
      else
        d = sum (abs (name(1:len2) - x(1:len2))) + sum (name(len2+1:end));
      endif
    endfunction
    dist = cellfun ("fdist", t);
    [~, i] = min (dist);
    error ("get_forge_pkg: package not found: ""%s"".  Maybe you meant ""%s?""",
           name, t{i});
  endif

endfunction
