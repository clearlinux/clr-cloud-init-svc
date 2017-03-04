import os
APP_ROOT = os.path.dirname(os.path.abspath(__file__))   
APP_STATIC = os.path.join(APP_ROOT, 'static')
SUBDIR = os.path.join('/', os.path.basename(APP_ROOT))
