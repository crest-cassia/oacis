import sys
import os

rb_call_path = os.path.abspath(os.path.join(os.path.dirname(__file__), '../rb_call') )
sys.path.append( rb_call_path )

os.putenv('BUNDLE_GEMFILE', os.path.abspath(os.path.join(os.path.dirname(__file__),'../Gemfile')) )
from rb_call import RubySession

Rb = RubySession()
Rb.require_relative('../config/environment')
Rb.require_relative('../rb_call/patch/mongoid_patch')

# Defining classes of OACIS
Simulator = Rb.const('Simulator')
ParameterSet = Rb.const('ParameterSet')
Run = Rb.const('Run')
Analyzer = Rb.const('Analyzer')
Analysis = Rb.const('Analysis')
Host = Rb.const('Host')
HostGroup = Rb.const('HostGroup')

from .oacis_watcher import OacisWatcher

