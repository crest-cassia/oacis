import unittest
from unittest.mock import MagicMock
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
        assert oacis.Simulator.count() == 0

    def tearDown(self):
        self.DatabaseCleaner.clean()
        assert oacis.Simulator.count() == 0
        root_dir = oacis.Rb.const('ResultDirectory').root().to_s()  #=> public/Result_test
        import shutil
        shutil.rmtree( root_dir )

    def build_simulator(self):
        ParameterDefinition = oacis.Rb.const('ParameterDefinition')
        pd1 = ParameterDefinition( {'key':"p1", 'type':"Integer", 'default': 0} )
        pd2 = ParameterDefinition( {'key':"p2", 'type':"Float", 'default': 1.0} )
        sim = oacis.Simulator.send('create!', {'name': 'my_test_simulator', 'command': 'echo', 'parameter_definitions': [pd1,pd2]} )
        #print( repr(sim), sim.parameter_definitions() )
        assert oacis.Simulator.count() == 1
        host = oacis.Host.send('create!', {"name":"localhost"} )
        sim.executable_on().push(host)
        return sim

    def build_ps(self, sim, num_ps):
        for i in range(num_ps):
            v = {"p1": i, "p2": 0.0}
            sim.find_or_create_parameter_set(v)

    def build_run(self, ps, num_created_runs, num_finished_runs):
        host = ps.simulator().executable_on().first()
        assert host is not None
        for i in range(num_created_runs):
            ps.runs().send( 'create!', submitted_to=host )
        for i in range(num_finished_runs):
            ps.runs().send( 'create!', submitted_to=host, status='finished' )

    def test_watch_ps(self):
        sim = self.build_simulator()
        self.build_ps(sim, 1)
        ps = sim.parameter_sets().first()
        w = oacis.OacisWatcher()
        self.assertEqual( len(w._observed_parameter_sets), 0 )
        w.watch_ps( ps, lambda x: None )
        self.assertEqual( len(w._observed_parameter_sets), 1 )

        w.watch_ps( ps, lambda x: None )
        self.assertEqual( len(w._observed_parameter_sets[ps.id().to_s()]), 2 )

    def test_watch_all_ps(self):
        sim = self.build_simulator()
        self.build_ps(sim, 2)
        ps = sim.parameter_sets().first()
        w = oacis.OacisWatcher()

        self.assertEqual( len(w._observed_parameter_sets_all), 0 )
        w.watch_all_ps( sim.parameter_sets(), lambda pss: None )
        self.assertEqual( len(w._observed_parameter_sets_all), 1 )
        w.watch_all_ps( sim.parameter_sets(), lambda pss: None )
        psids = tuple( sorted([ps.id().to_s() for ps in sim.parameter_sets()]) )
        self.assertEqual( len(w._observed_parameter_sets_all[psids]), 2 )

    def test_completed(self):
        sim = self.build_simulator()
        self.build_ps(sim, 1)
        ps = sim.parameter_sets().first()
        self.build_run(ps, 1, 2)
        assert ps.runs().count() == 3
        assert ps.runs().where( status='created' ).count() == 1
        assert ps.runs().where( status='finished' ).count() == 2
        w = oacis.OacisWatcher()
        self.assertFalse( w._completed(ps) )

        ps.runs().where(status='created').first().update_attribute('status','finished')
        self.assertTrue( w._completed(ps) )

    def test_completed_ps_ids(self):
        sim = self.build_simulator()
        self.build_ps(sim, 2)
        ps1 = sim.parameter_sets().asc('id').first()
        ps2 = sim.parameter_sets().asc('id').last()
        self.build_run(ps1, 0, 2)
        self.build_run(ps2, 1, 1)
        w = oacis.OacisWatcher()
        psids = [ps1.id().to_s(), ps2.id().to_s() ]
        finished = w._completed_ps_ids( psids )
        self.assertEqual( finished, [ps1.id().to_s()] )

    def test_check_completed_ps__callback(self):
        sim = self.build_simulator()
        self.build_ps(sim, 2)
        ps1 = sim.parameter_sets().asc('id').first()
        ps2 = sim.parameter_sets().asc('id').last()
        self.build_run(ps1, 0, 2)
        self.build_run(ps2, 1, 1)

        mock1 = MagicMock()
        mock2 = MagicMock()

        w = oacis.OacisWatcher()
        w.watch_ps(ps1, mock1); w.watch_ps(ps2, mock2)
        w._check_completed_ps()
        mock1.assert_called_with(ps1)
        mock2.assert_not_called()

    def test_check_completed_ps__stop_calling(self):
        sim = self.build_simulator()
        self.build_ps(sim, 1)
        ps = sim.parameter_sets().first()
        self.build_run(ps, 0, 1)

        mock1 = MagicMock()
        mock2 = MagicMock()
        def callback1(ps):
            mock1();
            h = ps.simulator().executable_on().first()
            ps.runs().create( submitted_to=h )

        w = oacis.OacisWatcher()
        w.watch_ps(ps, callback1 ); w.watch_ps(ps, mock2)
        ret = w._check_completed_ps()
        mock1.assert_called_with()
        mock2.assert_not_called()
        self.assertTrue( ret )

    def test_check_completed_ps__return_false_when_no_callback_executed(self):
        sim = self.build_simulator()
        self.build_ps(sim, 1)
        ps = sim.parameter_sets().first()
        self.build_run(ps, 1, 0)

        w = oacis.OacisWatcher()
        w.watch_ps(ps, lambda x: None )
        ret = w._check_completed_ps()
        self.assertFalse( ret )

    def test_check_completed_ps_all__callback(self):
        sim = self.build_simulator()
        self.build_ps(sim, 2)
        for ps in sim.parameter_sets():
            self.build_run(ps, 0, 2)

        mock1 = MagicMock()
        w = oacis.OacisWatcher()
        w.watch_all_ps( sim.parameter_sets(), mock1 )
        ret = w._check_completed_ps_all()
        mock1.assert_called_with( sim.parameter_sets().asc('id') )
        self.assertTrue( ret )

    def test_check_completed_ps_all__not_called(self):
        sim = self.build_simulator()
        self.build_ps(sim, 2)
        ps1 = sim.parameter_sets().asc('id').first()
        self.build_run( ps1, 0, 2 )
        ps2 = sim.parameter_sets().asc('id').last()
        self.build_run( ps2, 1, 1 )

        mock1 = MagicMock()
        w = oacis.OacisWatcher()
        w.watch_all_ps( [ps1,ps2], mock1 )
        ret = w._check_completed_ps_all()
        mock1.assert_not_called()
        self.assertFalse( ret )

    def test_check_completed_ps__recursive_call(self):
        sim = self.build_simulator()
        self.build_ps(sim, 2)
        ps1 = sim.parameter_sets().asc('id').first()
        self.build_run( ps1, 0, 1 )
        ps2 = sim.parameter_sets().asc('id').last()
        self.build_run( ps2, 0, 1 )

        mock1 = MagicMock()
        w = oacis.OacisWatcher()
        def callback(ps_list):
            w.watch_all_ps( [ps2], mock1 )
        w.watch_all_ps( [ps1], callback )
        ret = w._check_completed_ps_all()
        self.assertTrue( ret )
        mock1.assert_not_called()

        ret = w._check_completed_ps_all()
        self.assertTrue( ret )
        mock1.assert_called()

if __name__ == '__main__':
    setupSuite()
    unittest.main()

