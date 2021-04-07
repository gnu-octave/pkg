# pkg - The GNU Octave package management tool

Since Octave is Free Software users are encouraged to share their
programs with others.
To aid this sharing Octave supports the installation of extra packages.
At the time of writing a collection of packages can be found online at
- the 'Octave Packages' page <https://gnu-octave.github.io/packages/>
- the 'Octave Forge' project <https://octave.sourceforge.io>
Since the Internet is an ever-changing place
this may not be true at the time of reading.
Therefore it is recommended to see the Octave website <https://octave.org>
for an updated reference.


## Installing and Removing Packages

Assuming a package is available in the file `image-1.0.0.tar.gz`
it can be installed from the Octave prompt with the command
```
pkg install image-1.0.0.tar.gz
```
If the package is installed successfully nothing will be printed on the prompt,
but if an error occurred during installation it will be reported.
It is possible to install several packages at once
by writing several package files after the `pkg install` command.
If a different version of the package is already installed
it will be removed prior to installing the new package.
This makes it easy to upgrade and downgrade the version of a package,
but makes it impossible to have several versions of the same package
installed at once.

To see which packages are installed type
```
>> pkg list

Package Name  | Version | Installation directory
--------------+---------+-----------------------
       image *|   1.0.0 | /home/jwe/octave/image-1.0.0
```
In this case only version 1.0.0 of the "image"-package is installed.
The `'*'` character next to the package name shows
that the image package is loaded and ready for use.

It is possible to remove a package from the system using the command
```
pkg uninstall image
```
If the package is removed successfully nothing will be printed in the prompt,
but if an error occurred it will be reported.
It should be noted that the package installation is not needed for removal.
Only the package name as reported by `pkg list` should be used
when removing a package.
It is possible to remove several packages at once
by writing several package names after the `pkg uninstall` command.

To minimize the amount of code duplication between packages
it is possible that one package depends on another one.
If a package depends on another,
it will check if that package is installed during installation.
If it is not,
an error will be reported and the package will not be installed.
This behavior can be disabled by passing the `-nodeps` flag
to the `pkg install` command
```
pkg install -nodeps my_package_with_dependencies.tar.gz
```
Since the installed package expects its dependencies to be installed
it may not function correctly.
Because of this it is not recommended to disable dependency checking.

For more information,
see
```
doc pkg
```


## Using Packages

By default the functions provided by an installed package,
for example the "image"-package",
are not available from the Octave prompt,
i.e. the package functions are not added to the Octave load path.
Packages need to be loaded first using the commands
```
pkg load image
```
In much the same way a package can be removed from the Octave path by
```
pkg unload image
```


## Administrating Packages

It is possible to make both per-user (local) and system-wide (global)
installations of packages.
Global package installations require administrator privileges (`root` user).

The local and global package installations consists of an index file,
get- and settable by `pkg local_list` and `pkg global_list`,
respectively,
and a designated package installation directory,
get- and settable by `pkg prefix -local` and `pkg prefix -global`,
respectively.

An example output for the global installations
```
>> pkg global_list
                                 /usr/share/octave/octave_packages

>> pkg prefix -global
Installation prefix:             /usr/share/octave/packages
Architecture dependent prefix:   /usr/lib/octave/packages
```
and for local installations
```
>> pkg local_list
                                 /home/username/.octave_packages

>> pkg prefix -local
Installation prefix:             /home/username/octave
Architecture dependent prefix:   /home/username/octave
```

The local installation prefix can be changed by calling
```
pkg prefix /new/prefix/dir
```
with a further input argument `new_dir` but no output arguments.
With two further input arguments
```
pkg prefix /new/prefix/dir /new/arch/prefix/dir
```
the architecture dependent prefix directory can be altered separately.
Note that prefix changes are only valid within a single Octave session.
Add a call to `pkg prefix` in an Octave startup file
to make those changes persistent.


## Creating Packages

Internally a package is simply a compressed file
that contains a top level directory of any given name.
This directory will in the following be referred to as "package"
and may contain the following files:

- `package/COPYING` (mandatory)
  License of the package.
  If the package contains (compiled) functions,
  dynamically linked to Octave libraries,
  the license must be compatible with the GNU General Public License.

- `package/DESCRIPTION` (mandatory)
  Information about the package.
  See [DESCRIPTION File](#the-description-file) for details on this file.

- `package/INDEX` (semi-mandatory)
  Listing the functions provided by the package.
  If this file is not given,
  it will be created automatically from the functions in the package
  and the `Categories` keyword in the `package/DESCRIPTION` file.
  See [INDEX File](#the-index-file) for details on this file.

- `package/CITATION` (optional)
  Instructions on how to cite the package for publication.
  Content is displayed verbatim with
  ```
  citation package_name
  ```

- `package/ChangeLog` (optional)
  Development info describing changes made to the package source files.

- `package/NEWS` (optional)
  Describing user-visible changes worth mentioning.

- `package/PKG_ADD` (optional)
  `package/PKG_DEL` (optional)
  File that includes commands that are run when the package is added
  to the Octave load path.
  Note that regular Octave `PKG_ADD` / `PKG_DEL` directives
  in the package source code will additionally be added to this file
  by the Octave package manager.
  Further note that symbolic links are to be avoided in packages.
  Symbolic links do not exist on some file systems, and so a typical use for this file is the replacement of the symbolic link

- `package/pre_install.m` (optional)
  Function that is run prior to the installation of a package.

- `package/post_install.m` (optional)
  Function that is run after the installation of a package.

- `package/on_uninstall.m` (optional)
  Function that is run prior to the removal of a package.

The three `...install.m` functions are each called with a single argument,
a struct with fields names after the data
in the [DESCRIPTION File](#the-description-file),
and the paths where the package functions will be installed.

Besides the above mentioned files,
a package can also contain one or more of the following directories:

- `package/src` (optional)
  Directory the package source code files.

  The Octave package manager will execute in this directory
  - `./configure` if this script exists
  - `make` if a `Makefile` exists (`make install` will not be called)
  to eventually compile source code files.

  In these scripts it is safer to use the provided environment variables
  `MKOCTFILE`, `OCTAVE_CONFIG`, and `OCTAVE`,
  rather than calling the programs `mkoctfile`, `octave-config`, and `octave`,
  directly.

  If the file `package/src/FILES` exists,
  all files listed in that file are copied to the final `inst` directory.
  By default all `package/src/*.m`, `package/src/*.mex`,
  and `package/src/*.oct` are copied to the final package installation
  `package/inst` directory.

- `package/inst` (optional)
  Directory containing any files that can be directly installed (copied)
  to the final package installation directory.
  Typically this will include Octave m-files.

- `package/doc` (optional)
  Directory containing documentation for the package,
  that are directly installed (copied) to the final package installation
  directory.

- `package/bin` (optional)
  Directory containing files that will be added to the Octave `EXEC_PATH`
  when the package is loaded.
  This might contain external scripts, etc.,
  called by functions within the package.


### The DESCRIPTION File

The `package/DESCRIPTION` file contains the package information
in a YAML-like format:
- Lines starting with `#` are comments.
- Lines starting with a blank character continue the previous line.
- Everything else is of the form `key: value`.

The following is a simple example of a `package/DESCRIPTION` file,
only containing mandatory fields:
```
name: package_name
version: 1.0.0
date: 2021-02-28
author: First Author <first.author@email.com>,
 Second Author <second.author@email.com>
maintainer: First Maintainer <first.maintainer@email.com>,
 Second Maintainer <second.maintainer@email.com>
title: The title of the package
description: A short description of the package.
 If this description gets too long for one line it can continue
 on the next by adding a space to the beginning of the following lines.
```

The following keywords are mandatory:
- `name`: Name of the package.
- `version`: Version of the package.
  A package version is typically digits separated by dots but may also contain
  `+`, `-`, `~`, and alphanumeric characters (in the "C" locale).
  For example, `"2.1.0+"` could indicate a development version of a package.
  Versions are compared using the Octave function `compare_versions()`.
- `date`: Date of last update.
- `author`: Original author of the package.
- `maintainer`: Maintainer of the package.
- `title`: A one line description of the package.
- `description`: A one paragraph description of the package.

The following keywords are optional:
- `depends`: A list of other Octave packages that this package depends on.
  This can include dependencies on particular versions
  with the following format:
  ```
  depends: package (>= 1.0.0)
  ```
  Possible operators are `<`, `<=`, `==`, `>=`, or `>`.
  If the part of the dependency in brackets `()` is missing,
  any version of the dependency is acceptable.
  Multiple dependencies can be defined as a comma separated list.
  This can be used to define a range of versions of a particular dependency:
  ```
  depends: package (>= 1.0.0), package (< 1.5.0)
  ```
  It is also possible to depend on particular Octave versions
  ```
  depends: octave (>= 6.1.0)
  ```
- `categories`: Describing the package.
  If no `package/INDEX` file is given this keyword is mandatory.

The following keywords are deprecated,
it is strongly recommended to **not** to use them:
- `problems`: Optional list of known problems.
- `url`: Optional list of homepages related to the package.
- `license`: Package license, the `package/COPYING` file is mandatory.
- `SystemRequirements`: External runtime dependencies of the package.
- `BuildRequires`: External build dependencies of the package.


### The INDEX File

The optional `package/INDEX` file provides a categorical view
of the functions in the package.
This file has a very simple format:
- Lines beginning with `#` are comments.
- The first non-comment line should look like this
  ```
  toolbox >> Toolbox name
  ```
- Lines beginning with an alphabetical character indicate a new category of
  functions.
- Lines starting with a white space character indicate
  that the function names on the line belong to the last mentioned category.

The format can be summarized with the following example:
```
# A comment
toolbox >> Toolbox name
Category Name 1
 function1 function2 function3
 function4
Category Name 2
 function2 function5
```


### PKG_ADD and PKG_DEL Directives

If the package contains files called `PKG_ADD` or `PKG_DEL`,
the commands in these files will be executed
when the package is added or removed from the Octave load path.
In some situations such files are a bit cumbersome to maintain,
so the package manager supports automatic creation of such files.
If a source file in the package contains a `PKG_ADD` or `PKG_DEL` directive,
they will be extracted and added to either `PKG_ADD` or `PKG_DEL`,
respectively.

In m-files a `PKG_ADD` directive looks like this
```
## PKG_ADD: some_octave_command
```
and in C++ files like this
```
// PKG_ADD: some_octave_command
```
In both cases `some_octave_command` should be replaced by the Octave command
that should be added to the `PKG_ADD` file.
In general,
`PKG_ADD` directives should be added before the `function` keyword
of an Octave function.
`PKG_DEL` directives work analogously.


### Missing Components

If a package dependency is not present,
such as another Octave package,
it may be useful to install a function,
which informs users what to do if that particular dependency is missing.

For more information on how to register such a function,
see
```
doc missing_component_hook
```
