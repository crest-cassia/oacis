from rb_call import RubySession

#print('RubySession imported')
rb = RubySession()
rb.require_relative('../config/environment')
#print('Rails environment is imported')
rb.require_relative('../rb_call/patch/mongoid_patch')
#print('patch is loaded')

Simulator = rb.const('Simulator')
ParameterSet = rb.const('ParameterSet')
Run = rb.const('Run')
Analyzer = rb.const('Analyzer')
Analysis = rb.const('Analysis')
Host = rb.const('Host')
