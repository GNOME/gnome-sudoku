You are welcome to contribute code that you think would improve the project in any way. If you're looking for a place to start take a look at the [project's issues](https://gitlab.gnome.org/GNOME/gnome-sudoku/-/issues), you can also always open an issue first before you get started. If you are new to the project, start small, and if you'd like to change how GNOME Sudoku works you will need to make a compelling argument. To submit a merge request to the repository take a look at the [development handbook](https://handbook.gnome.org/development/change-submission.html).

If you are new to GNOME take a look at the following links:  
- [Vala Main Tutorial](https://docs.vala.dev/tutorials/programming-language/main.html)
- [Getting started with GTK4](https://docs.gtk.org/gtk4/getting_started.html)
- [Meson Beginner's Guide](https://mesonbuild.com/SimpleStart.html)

## AI Contributions

No.

## Code Overview

/lib contains the Board and Game's logic. It's the lowest level of the code that handles the structures which we reuse everywhere else.  

In /src you'll find the bulk of the codebase that interacts with GTK, including creating the window and all its widgets, handling events and more.  

Finally in /data you'll find all the assets that we use and other miscellaneous files.
