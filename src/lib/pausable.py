import time

class MethodWrapper:

    def __call__ (self, cls):
        for attr in dir(cls):
            attrobj = getattr(cls,attr)
            if callable(attrobj) and attr.find('__')!=0:
                setattr(cls,attr,self.wrap(attrobj))

    def wrap (self,f):
        def _(*args, **kwargs):
            self.wrapper(*args,**kwargs)
            return f(*args,**kwargs)
        return _

    def wrapper (self, *args, **kwargs):
        print args,kwargs

class PausableWrapper (MethodWrapper):

    def __init__ (self,sleep_for=1):
        self.sleep_for = sleep_for

    def __call__ (self, cls):
        MethodWrapper.__call__(self, cls)
        cls.paused = False
        cls.terminated = False
        cls.pause = lambda *args: self.pause(cls)
        cls.resume = lambda *args: self.resume(cls)
        cls.terminate = lambda *args: self.terminate(cls)
        cls.stop = lambda *args: self.terminate(cls)
        self.init_wrap(cls.__init__)
        

    def init_wrap (self, f):
        def _(cls, *args, **kwargs):
            cls.paused = False
            cls.terminated = False
            return f(cls,*args,**kwargs)
        return _

    def pause (self, cls):
        cls.paused = True

    def resume (self, cls):
        cls.paused = False

    def terminate (self, cls):
        cls.terminated = True

    def unterminate (self, cls):
        cls.terminated = False

    def wrapper (self, cls, *args, **kwargs):
        if cls.terminated: raise "Terminated!"
        while cls.paused:
            if cls.terminated: raise "Terminated!"
            time.sleep(self.sleep_for)
    
            
make_pausable = PausableWrapper()
