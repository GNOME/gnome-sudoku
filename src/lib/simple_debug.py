import optparse
import defaults

parser = optparse.OptionParser(
    version=defaults.VERSION,
    option_list=[
    optparse.make_option("-v",const=True,action="store_const",
                         dest="debug",help="Print debug information",
                         default=False),
    optparse.make_option("-p",const=True,action="store_const",
                         dest="profile",help="Profile gnome-sudoku",
                         default=False),
    optparse.make_option("-w",const=True,action="store_const",
                         dest="walk",help="Step through program",
                         default=False),
    ]
    )

options,args = parser.parse_args()

    
# Make a lovely wrapper 
if options.debug:
    def simple_debug (f):
        def _ (self, *args,**kwargs):
            print self.__class__,f.__name__,args,kwargs
            return f(self,*args,**kwargs)
        return _

elif options.walk:
    ff = []
    def simple_debug (f):
        def _ (self, *args,**kwargs):
            if (self.__class__,f.__name__) not in ff:
                print self.__class__,f.__name__,args,kwargs
                if raw_input('Hit return to step forward (hit i to ignore this function): ')=='i':
                    ff.append((self.__class__,f.__name__))
            return f(self,*args,**kwargs)
        return _


else:
    def simple_debug (f): return f
