import unittest
import os

os.environ['RAILS_ENV'] = 'test'
import oacis

def setupSuite():
    print("setting up")
    Mongoid = oacis.Rb.const("Mongoid")
    assert Mongoid.default_client().options()['database'] == 'oacis_test'
    oacis.Rb.require('database_cleaner')

class TestOacisWatcher(unittest.TestCase):

    def setUp(self):
        self.DatabaseCleaner = oacis.Rb.const('DatabaseCleaner')
        self.DatabaseCleaner.start()
        print( oacis.Simulator.count() )

    def tearDown(self):
        print("being cleaned up")
        self.DatabaseCleaner.clean()
        print( oacis.Simulator.count() )
        root_dir = oacis.Rb.const('ResultDirectory').root().to_s()  #=> public/Result_test
        import shutil
        shutil.rmtree( root_dir )

    def build_simulator(self):
        ParameterDefinition = oacis.Rb.const('ParameterDefinition')
        pd1 = ParameterDefinition( {'key':"p1", 'type':"Integer", 'default': 0} )
        pd2 = ParameterDefinition( {'key':"p2", 'type':"Float", 'default': 1.0} )
        sim = oacis.Simulator.create( {'name': 'my_test_simulator', 'command': 'echo', 'parameter_definitions': [pd1,pd2]} )
        #print( repr(sim) )
        #print( sim.parameter_definitions() )
        #print( oacis.Simulator.count() )
        return sim

    def build_ps(self, sim, num_ps):
        for i in range(num_ps):
            v = {"p1": i, "p2": 0.0}
            sim.find_or_create_parameter_set(v)

    def test_watch_ps(self):
        sim = self.build_simulator()
        self.build_ps(sim, 1)
        w = oacis.OacisWatcher()
        self.assertEqual( len(w.observed_parameter_sets), 0 )
        def on_ps_finished(ps): pass
        w.watch_ps( sim.parameter_sets().first(), on_ps_finished )
        self.assertEqual( len(w.observed_parameter_sets), 1 )

if __name__ == '__main__':
    setupSuite()
    unittest.main()

