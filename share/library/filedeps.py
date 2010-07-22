"""This plug-in adds a menu for computing the dependencies between two files

When you modify some source files, it often happens that the compiler will
decide to recompile other files that depended on it. Finding out why there is
such a dependency is not always obvious, and this plug-in will help you in
that respect.

Once it has been activated, select the new menu
   /Navigate/Show File Dependency Path...
and in the dialog that appears enter the two source files you are interested
in. This will then list in the console why the first file depends on the
second (for instance "file1" depends on "file2", which depends on "file3")
"""


#############################################################################
## No user customization below this line
#############################################################################

import GPS
import os.path

def dependency_path (from_file, to_file):
 """Shows why modifying to_file implies that from_file needs to be
    recompiled. This information is computed from the cross-references
    database, and requires your application to have been compiled
    properly. This function does not attempt to compute the shortest
    dependency path, and just returns the first one it finds.
    FROM_FILE and TO_FILE must be instances of GPS.File"""

 if not isinstance (from_file, GPS.File):
   from_file = GPS.File (from_file)
 if not isinstance (to_file, GPS.File):
   to_file = GPS.File (to_file)

 if from_file == to_file:
    return "Same file"

 deps = dict()

 # List of files to analyze. This is a list of tuples, the first element of
 # which is the name of the file to analyze, and the second is the name of
 # the parent that put it in the list
 to_analyze = [(from_file, None)]

 while len (to_analyze) != 0:
   (file, because_of) = to_analyze.pop()
   imports = file.imports (include_implicit=False)

   deps[file] = because_of
   if file == to_file:
     break

   for f in imports:
     if f and not deps.has_key (f):
        to_analyze.append ((f, file))

 # Now print the results

 target = to_file
 result=""
 while target:
   result = " -> " + target.name() + "\n" + result
   if not deps.has_key (target):
      result = "No dependency between these two files"
      break
   target = deps[target]

 return result

def print_dependency_path (from_file, to_file):
 GPS.Console().write \
    ("Dependencies from " + os.path.basename (from_file.name())\
     + " to " + os.path.basename (to_file.name()) + "\n"
     + dependency_path (from_file, to_file) + "\n")

def interactive_dependency_path (menu):
   (file1, file2) = GPS.MDI.input_dialog ("Show dependency path", "From", "To")
   print_dependency_path (GPS.File (file1), GPS.File (file2))

GPS.Menu.create ("/Navigate/Show File Dependency Path...",
                 interactive_dependency_path)
