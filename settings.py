import os

# __file__ refers to the file settings.py 
# APP_ROOT = application_top
APP_ROOT = os.path.dirname(os.path.abspath(__file__))   
APP_STATIC = os.path.join(APP_ROOT, 'static')
