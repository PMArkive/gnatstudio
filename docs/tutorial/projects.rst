********
Projects
********


Project Wizard
==============

Go to the menu `File->New Project...`: this opens up the GNAT Studio project
creation wizard.

The first page of the wizard allows you to select a pre-defined project
template in the left-hand pane. These project templates are organized
according to the technology they use (e.g: `AWS`) or the platform that
is targeted (e.g: `STM32F4 compatible`). The description of the currently
selected project is displayed on the right-hand side pane.

Select a project template and click on `Next`: a page asking you the name and
the location of your project will appear. This page may also list project
template-specific options.

Once completed, click on `Apply` to actually create the project. Note that you
can still customize your newly created project after is creation by directly
modifying the project file: GNAT Studio provides completion, tooltips, outline
and other common IDE features for project files through LSP and the
`Ada Language Server <https://github.com/AdaCore/ada_language_server>`_, helping you
to customize your project more easily.

.. _Variable_editor:

Variable editor
===============

Select the window titled "Scenario".  If not available, you can open it
using the menu `View->Scenario`.
This window contains a `Build` label.

This is a configuration variable. With GNAT Studio and the GNAT
project facility, you can define as many configuration variables as you want,
and modify any project settings (e.g. switches, sources, ...) based on the
values of configuration variables. These variables can also take any
number of different values.

The `BUILD` variable demonstrates a typical `Debug/Production`
configuration where we've set different switches for the two modes.

Back to our project, let's now examine the dependencies between sources.

.. _Source_dependencies:

Source dependencies
===================

Select :file:`sdc.adb` in the `Project View` and then the contextual menu item
`Browsers/Show dependencies for sdc.adb`: this will open a new graph showing
the dependencies between sources of the project.

Click on the right arrow of :file:`tokens.ads` to display the files that
:file:`tokens.ads` depends on. Similarly, click on the right arrow of
:file:`stack.ads`.

.. _Project_dependencies:

Project dependencies
====================

Open the :file:`sdc.gpr` GPR project file and add a dependency on the
:file:`prj1.gpr` located under the :file:`projects` directory by adding
the following line at the top of the project file::

    with "./projects/prj1.gpr";

Save the project file and click on the :guilabel:`Reload Project` button
(refresh icon) of the :guilabel:`Project View` to take into account the
modifications.

You can see the new dependency added in the project view, as a list (or tree,
if :guilabel:`Show flat view` is enabled in local configuration menu) of
projects. In particular, project dependencies are duplicated when tree view is
used: if you open the `prj1` icon by clicking on the triangle, and then
similarly open the `prj2` icon, you will notice that the project `prj4` is
displayed twice: once as a dependency of `prj2`, and once as a dependency of
`prj1`.

GNAT Studio can also display the graph of dependencies between projects: on
*Sdc* project, use the contextual menu `Browsers/Show projects imported by
Sdc`: this will open a project hierarchy browser.

On the *Sdc* project, select the contextual menu `Browsers/Show projects
imported by Sdc (recursively)`.

In the browser, you can move the project items, and select them to highlight
the dependencies.
