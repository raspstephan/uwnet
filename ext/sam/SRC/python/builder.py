# file plugin_build.py
import cffi
ffibuilder = cffi.FFI()

header = """
extern void sam_hook(double *, int*, int*, int*);
extern int save_state(void);
extern int set_state_py(char *, double *, int*, int*, int*);
extern int set_state_char(char *, char *);
extern int get_state(char *, double *, int*);
extern int set_state_1d(char *, double *, int*);
extern int set_state_scalar(char *, double *);
extern int compute_next_state(void);
"""

module = """
from my_plugin import ffi
import module

@ffi.def_extern()
def sam_hook(*args):
    module.hook(ffi, args)

@ffi.def_extern(error=1)
def set_state_1d(*args):
    module.set_state_1d(args, ffi=ffi)
    return 0

@ffi.def_extern(error=1)
def set_state_scalar(*args):
    module.set_state_scalar(args, ffi=ffi)
    return 0

@ffi.def_extern(error=1)
def set_state_py(*args):
    module.set_state(args, ffi=ffi)
    return 0

@ffi.def_extern(error=1)
def set_state_char(*args):
    module.set_state_char(args, ffi=ffi)
    return 0

@ffi.def_extern(error=1)
def get_state(*args):
    module.get_state(args, ffi=ffi)
    return 0

@ffi.def_extern(error=1)
def save_state():
    module.save_state()
    return 0

@ffi.def_extern(error=1)
def compute_next_state():
    module.compute_next_state()
    return 0
"""

with open("plugin.h", "w") as f:
    f.write(header)

ffibuilder.embedding_api(header)

ffibuilder.set_source("my_plugin", r'''
    #include "plugin.h"
''')

ffibuilder.embedding_init_code(module)

ffibuilder.compile(target="libplugin.so", verbose=True)
