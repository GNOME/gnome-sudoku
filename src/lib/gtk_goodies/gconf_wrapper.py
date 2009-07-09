# -*- coding: utf-8 -*-
# GConf wrapper1
# COPIED VERBATIM FROM http://www.daa.com.au/pipermail/pygtk/2002-August/003220.html
# by Johan Dahlin

import gconf
from gconf import VALUE_BOOL, VALUE_INT, VALUE_STRING, VALUE_FLOAT
from types import StringType, IntType, FloatType, BooleanType

verbose = False

class GConfError (Exception):
    pass


class GConf:
    def __init__ (self, appname, allowed={}):
        self._domain = '/apps/%s/' % appname
        self._allowed = allowed
        self._gconf_client = gconf.client_get_default ()

    def __getitem__ (self, attr):
        return self.get_value (attr)

    def __setitem__ (self, key, val):
        allowed = self._allowed
        if allowed.has_key (key):
            if not key in allowed[key]:
                good = ', '.join (allowed[key])
            raise GConfError, '%s must be one of: (%s)' % (key, good)
        self.set_value (key, val)

    def _get_type (self, key):
        KeyType = type (key)
        if KeyType == StringType:
            return 'string'
        elif KeyType == IntType:
            return 'int'
        elif KeyType == FloatType:
            return 'float'
        elif KeyType == BooleanType:
            return 'bool'
        else:
            raise GConfError, 'unsupported type: %s' % str (KeyType)

    # Public functions

    def set_allowed (self, allowed):
        self._allowed = allowed

    def set_domain (self, domain):
        self._domain = domain

    def get_domain (self):
        return self._domain
   
    def get_gconf_client (self):
        return self._gconf_client

    def get_value (self, key):
        '''returns the value of key `key' ''' #'
        if '/' in key:
            raise GConfError, 'key must not contain /'

        value = self._gconf_client.get (self._domain + key)
        ValueType = value.type
        if ValueType == VALUE_BOOL:
            return value.get_bool ()
        elif ValueType == VALUE_INT:
            return value.get_int ()
        elif ValueType == VALUE_STRING:
            return value.get_string ()
        elif ValueType == VALUE_FLOAT:
            return value.get_float ()
   
    def set_value (self, key, value):
        '''sets the value of key `key' to `value' '''
        value_type = self._get_type (value)

        if '/' in key:
            raise GConfError, 'key must not contain /'

        func = getattr (self._gconf_client, 'set_' + value_type)
        apply (func, (self._domain + key, value))

    def get_string (self, key):
        if '/' in key:
            raise GConfError, 'key must not contain /'

        return self._gconf_client.get_string (self._domain + key)
   
    def set_string (self, key, value):
        if type (value) != StringType:
            raise GConfError, 'value must be a string'
        if '/' in key:
            raise GConfError, 'key must not contain /'

        self._gconf_client.set_string (self._domain + key, value)

    def get_bool (self, key):
        if '/' in key:
            raise GConfError, 'key must not contain /'

        return self._gconf_client.get_bool (self._domain + key)
   
    def set_bool (self, key, value):
        if type (value) != IntType and \
           (key != 0 or key != 1):
            raise GConfError, 'value must be a boolean'
        if '/' in key:
            raise GConfError, 'key must not contain /'

        self._gconf_client.set_bool (self._domain + key, value)

    def get_int (self, key):
        if '/' in key:
            raise GConfError, 'key must not contain /'

        return self._gconf_client.get_int (self._domain + key)
   
    def set_int (self, key, value):
        if type (value) != IntType:
            raise GConfError, 'value must be an int'
        if '/' in key:
            raise GConfError, 'key must not contain /'

        self._gconf_client.set_int (self._domain + key, value)

    def get_float (self, key):
        if '/' in key:
            raise GConfError, 'key must not contain /'

        return self._gconf_client.get_float (self._domain + key)
   
    def set_float (self, key, value):
        if type (value) != FloatType:
            raise GConfError, 'value must be an float'

        if '/' in key:
            raise GConfError, 'key must not contain /'

        self._gconf_client.set_float (self._domain + key, value)

class GConfWrapper:
    """Provide some general purpose convenience functions for keeping
    GConf keys and GUI in sync.
    """

    # These can be defined by subclasses as they see fit
    initial_prefs = {}

    def __init__ (self, gconf):
        """gconf is an instance of our GConf convenience class."""
        self.gconf = gconf

    def gconf_wrap (self, key_name, widget,
                    get_method=lambda w: w.get_value(),
                    set_method=lambda w,v: w.set_value(v),
                    signal='changed'):
        if verbose:
            print 'Wrapping ',key_name,widget,get_method,set_method,signal
        try:
            if verbose: print 'setting ',key_name,self.gconf[key_name]
            set_method(widget,self.gconf[key_name])
        except:
            if self.initial_prefs.has_key(key_name):
                if verbose: print 'Falling back to value from initial_prefs',self.initial_prefs[key_name]
                val = self.initial_prefs[key_name]
                self.gconf[key_name]=val
                set_method(widget,val)
            else:
                if verbose: print 'Falling back to value already in widget',
                val = get_method(widget)
                if verbose: print val
                self.gconf[key_name]= val
                set_method(widget,val)
        widget.connect(signal,self.gconf_set_key,key_name,get_method)

    def gconf_wrap_toggle (self, key_name, action):
        self.gconf_wrap(key_name,action,
                        get_method=lambda w: w.get_active(),
                        set_method=lambda w,v: w.set_active(v),
                        signal='toggled')

    def gconf_wrap_adjustment (self, key_name, adj):
        self.gconf_wrap(key_name,adj,signal='value-changed')

    def gconf_set_key (self, action, key_name, get_method):
        # gconf takes integers rather than booleans...
        if verbose: print 'Setting ',key_name,'->',get_method(action)
        self.gconf[key_name]= get_method(action)

    

def test():
    c = GConf ('test-gconf')
    c['foo'] = '1'
    c['bar'] = 2
    c['baz'] = 3.0
    print c['foo'], c['bar'], c['baz']
   
if __name__ == '__main__':
    test()

