import gtk, gtk.glade, gobject
import sudoku
from gtk_goodies import gconf_wrapper
from defaults import *
from gettext import gettext as _
from gettext import ngettext
import threading

class GameGenerator (gconf_wrapper.GConfWrapper):

    glade_file = os.path.join(GLADE_DIR,'puzzle_generator.glade')

    initial_prefs = {'generate_target_easy':1,
                     'generate_target_medium':0,
                     'generate_target_hard':1,
                     'generate_target_veryHard':1,
                     'generate_endlessly':1,
                     'generate_for_target':0,
                     'number_of_sudokus_to_generate':10,
                     }

    def __init__ (self, UI, gconf):
        self.ui = UI
        self.sudoku_maker = self.ui.sudoku_maker
        # Don't work in background...
        self.ui.stop_worker_thread()
        gconf_wrapper.GConfWrapper.__init__(self,gconf)
        self.glade = gtk.glade.XML(self.glade_file)
        self.generate_for_target_widgets = []
        self.cat_to_label = {}
        for d in ['easy',
                  'medium',
                  'hard',
                  'veryHard']:
            widget_name = '%sCheckButton'%d
            widget = self.glade.get_widget(widget_name)
            label_widget_name = '%sLabel'%d
            setattr(self,label_widget_name,self.glade.get_widget(label_widget_name))
            setattr(self,widget_name,widget)
            gconf_setting = 'generate_target_%s'%d
            self.gconf_wrap_toggle(gconf_setting,widget)
            self.generate_for_target_widgets.append(widget)
            self.cat_to_label[d] = getattr(self,label_widget_name)
        self.cat_to_label['very hard'] = self.cat_to_label['veryHard']
        self.generateEndlesslyRadio = self.glade.get_widget('generateEndlesslyRadio')
        self.generateForTargetRadio = self.glade.get_widget('generateForTargetRadio')
        self.gconf_wrap_toggle('generate_endlessly',self.generateEndlesslyRadio)
        self.gconf_wrap_toggle('generate_for_target',self.generateForTargetRadio)
        self.generateEndlesslyRadio.connect('toggled',self.generate_method_changed_cb)
        self.newSudokusSpinButton = self.glade.get_widget('newSudokusSpinButton')
        self.gconf_wrap_adjustment('number_of_sudokus_to_generate',
                                   self.newSudokusSpinButton.get_adjustment()
                                   )
        self.generate_for_target_widgets.append(self.newSudokusSpinButton)
        self.generateButton = self.glade.get_widget('generateButton')
        self.generateButton.connect('clicked',self.generate_cb)
        self.closeButton = self.glade.get_widget('closeButton')
        self.closeButton.connect('clicked',self.close_cb)
        self.pauseButton = self.glade.get_widget('pauseButton')
        self.pauseButton.connect('clicked',self.pause_cb)
        self.stopButton = self.glade.get_widget('stopButton')
        self.stopButton.connect('clicked',self.stop_cb)
        self.pauseButton.set_sensitive(False)
        self.stopButton.set_sensitive(False)
        self.prog = self.glade.get_widget('progressbar1')
        self.prog.set_text('0 %')
        self.working = False
        self.easyCheckButton.connect('clicked',self.criteria_cb)
        self.mediumCheckButton.connect('clicked',self.criteria_cb)
        self.hardCheckButton.connect('clicked',self.criteria_cb)
        self.veryHardCheckButton.connect('clicked',self.criteria_cb)
        self.generate_method_changed_cb()
        self.dialog = self.glade.get_widget('PuzzleGenerator')
        self.dialog.show_all()
        self.dialog.set_transient_for(self.ui.w)
        self.dialog.present()
        self.setup_base_status()

    def generate_method_changed_cb (self, *args):
        if not self.generateForTargetRadio.get_active():
            for w in self.generate_for_target_widgets:
                w.set_sensitive(False)
            if not self.working:
                self.generateButton.set_sensitive(True)
        else:
            for w in self.generate_for_target_widgets:
                w.set_sensitive(True)
                self.criteria_cb()

    def criteria_cb (self, *args):
        if (self.easyCheckButton.get_active()
            or self.mediumCheckButton.get_active()
            or self.hardCheckButton.get_active()
            or self.veryHardCheckButton.get_active()):
            self.generateButton.set_sensitive(True)
        else:
            self.generateButton.set_sensitive(False)

    def generate_cb (self, *args):
        self.ngenerated = 0
        self.generated_by_cat = {}
        self.toward_target = 0
        self.pauseButton.set_sensitive(True)
        self.stopButton.set_sensitive(True)
        self.generateButton.set_sensitive(False)
        self.generateForTargetRadio.set_sensitive(False)
        self.generateEndlesslyRadio.set_sensitive(False)
        for w in self.generate_for_target_widgets:
            w.set_sensitive(False)
        self.working = True
        self.paused = False
        self.prog.set_text(_('Working...'))
        gobject.timeout_add(100,self.update_status)
        self.worker = threading.Thread(target=lambda *args: self.sudoku_maker.work(limit=None,diff_min=self.get_diff_min(),diff_max=self.get_diff_max()))
        self.worker.start()

    def pause_cb (self, widg):
        if widg.get_active():
            self.sudoku_maker.pause()
            self.paused = True
        else:
            self.sudoku_maker.resume()
            self.prog.set_text(_('Working...'))
            self.paused = False

    def stop_cb (self, *args):
        self.sudoku_maker.stop()
        self.stopButton.set_sensitive(False)
        self.pauseButton.set_sensitive(False)
        self.pauseButton.set_active(False)
        self.generateButton.set_sensitive(True)
        self.generateForTargetRadio.set_sensitive(True)
        self.generateEndlesslyRadio.set_sensitive(True)
        if self.generateForTargetRadio.get_active():
            for w in self.generate_for_target_widgets:
                w.set_sensitive(True)
        self.working = False

    def close_cb (self, widg):
        if self.working:
            self.stop_cb()
        self.dialog.hide()
        self.dialog.destroy()

    def setup_base_status (self):
        """Setup basic status.
        """
        for diff,lab in [('easy',self.easyLabel),
                         ('medium',self.mediumLabel),
                         ('hard',self.hardLabel),
                         ('very hard',self.veryHardLabel)]:
            num = self.sudoku_maker.n_puzzles(diff)
            self.increment_label(lab,num)

    def increment_label (self, lab, val=0):
        curtext = lab.get_text()
        if (not curtext):
	    lab.pcount = val
        else:
	    lab.pcount += 1
        newtext = ngettext("%(n)s puzzle","%(n)s puzzles",lab.pcount)%{'n':lab.pcount}
        lab.set_text(newtext)

    def update_status (self, *args):
        """Update status of our progress bar and puzzle table.
        """
        #print 'update_status!'
        npuzzles = sum(self.sudoku_maker.new_puzzles.values())
        #print 'npuzzles=',npuzzles,'ngenerated=',self.ngenerated
        if npuzzles > self.ngenerated:
            # updating gui...
            self.ngenerated=self.toward_target=npuzzles
            for cat in self.sudoku_maker.new_puzzles:
                to_add = self.sudoku_maker.new_puzzles[cat] - self.generated_by_cat.get(cat,0)
                self.increment_label(self.cat_to_label[cat],to_add)
                self.generated_by_cat[cat] = self.sudoku_maker.new_puzzles[cat]
        self.update_progress_bar()
        if (self.generateForTargetRadio.get_active()
            and
            self.toward_target>=int(self.newSudokusSpinButton.get_value())
            ):
            print 'Done!'
            self.stop_cb()
            return False
        if self.paused: self.prog.set_text(_('Paused'))
        elif self.generateEndlesslyRadio.get_active():
            self.prog.pulse()
        if not self.working: return False
        if hasattr(self.sudoku_maker,'new_generator') and self.sudoku_maker.new_generator.terminated:
            self.prog.set_text(_('Stopped'))
            self.stopButton.set_sensitive(False)
            self.pauseButton.set_sensitive(False)
            self.pauseButton.set_active(False)
            self.generateButton.set_sensitive(True)
            return False
        return True

    def update_progress_bar (self):
        if self.generateForTargetRadio.get_active():
            tot = int(self.newSudokusSpinButton.get_value())
            self.prog.set_fraction(
                float(self.toward_target)/tot
                )
            try:
                txt = ngettext('Generated %(n)s out of %(total)s puzzle',
                               'Generated %(n)s out of %(total)s puzzles',
                               tot)%{'n':self.toward_target,'total':tot}
            except TypeError:
                # Allow for fuzzy translation badness caused by a
                # previous version having this done the wrong way
                # (i.e. the previous version didn't use the dictionary
                # method for the format string, which meant
                # translators couldn't change the word order here.
                try:
                    txt = ngettext('Generated %(n)s out of %(total)s puzzle',
                                   'Generated %(n)s out of %(total)s puzzles',
                                   tot)%(self.toward_target,tot)
                except:
                    # Fallback to English
                    txt = 'Generated %s out of %s puzzles'%(self.toward_target,tot)
        else:
            self.prog.pulse()
            txt = ngettext('Generated %(n)s puzzle','Generated %(n)s puzzles',self.toward_target)%{'n':self.toward_target}
        if self.paused: txt = txt + ' (' + _('Paused') + ')'
        self.prog.set_text(txt)

    def get_diff_min (self):
        if self.generateEndlesslyRadio.get_active(): return None
        if self.easyCheckButton.get_active(): return None
        if self.mediumCheckButton.get_active(): return sudoku.DifficultyRating.medium_range[0]
        if self.hardCheckButton.get_active(): return sudoku.DifficultyRating.hard_range[0]
        if self.veryHardCheckButton.get_active(): return sudoku.DifficultyRating.very_hard_range[0]

    def get_diff_max (self):
        if self.generateEndlesslyRadio.get_active(): return None
        if self.veryHardCheckButton.get_active(): return None
        if self.hardCheckButton.get_active(): return sudoku.DifficultyRating.hard_range[1]
        if self.mediumCheckButton.get_active(): return sudoku.DifficultyRating.medium_range[1]
        if self.easyCheckButton.get_active(): return sudoku.DifficultyRating.easy_range[1]
