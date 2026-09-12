To build GNOME Sudoku you'll need: `meson blueprint-compiler cargo rust`  
And the development libraries for: `gtk4 adwaita`  

If you want a specific GNOME Sudoku version take a look at the [tags](https://gitlab.gnome.org/GNOME/gnome-sudoku/-/tags) and the [tarballs](https://download.gnome.org/sources/gnome-sudoku/).

If there are any missing or outdated dependencies you'll get warnings from [meson](https://mesonbuild.com/Quick-guide.html#compiling-a-meson-project).  
  
The instructions to get the **latest development version** are as follow:
```
git clone https://gitlab.gnome.org/GNOME/gnome-sudoku.git
cd gnome-sudoku
meson setup builddir -Dprofile=Devel 
cd builddir && meson compile
```
Run locally:
```
GSETTINGS_SCHEMA_DIR=./data ./src/gnome-sudoku
```

Install:
```
sudo meson install
```

Uninstall:
```
sudo ninja uninstall
```
if you run into issues open a ticket on [gitlab](https://gitlab.gnome.org/GNOME/gnome-sudoku/-/work_items).
