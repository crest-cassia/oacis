import time

class OacisWatcher():

    def __init__(self, polling = 5):
        self.polling = polling
        self.observed_parameter_sets = {}
        self.observed_parameter_sets_all = {}

    def watch_ps(self, ps, callback):
        psid = ps.id().to_s()
        if psid in self.observed_parameter_sets:
            self.observed_parameter_sets[psid].append( callback )
        else:
            self.observed_parameter_sets[psid] = [ callback ]

    def loop(self):
        print("start polling")
        while True:
            executed = True
            while executed:
                executed = self.check_completed_ps()
            if len(self.observed_parameter_sets) == 0:
                break
            print("waiting for %d sec" % self.polling)
            time.sleep( self.polling )
        print("stop polling")

    def check_completed_ps(self):
        from . import ParameterSet
        executed = False
        watched_ps_ids = list( self.observed_parameter_sets.keys() )
        psids = self.completed_ps_ids( watched_ps_ids )
        
        for psid in psids:
            ps = ParameterSet.find(psid)
            if len(ps.runs()) == 0:
                print("%s has no run" % ps.id().to_s() )
            else:
                print("calling callback for %s" % ps.id().to_s() )
                executed = True
                queue = self.observed_parameter_sets[psid]
                while len(queue) > 0:
                    callback = queue.pop(0)
                    callback( ps )
                    if self.completed( ps.reload() ) == False:
                        break

        empty_psids = [ psid for psid,callbacks in self.observed_parameter_sets.items() if len(callbacks)==0 ]
        for empty_psid in empty_psids:
            self.observed_parameter_sets.pop(empty_psid)

        return executed

    def completed_ps_ids(self, watched_ps_ids ):
        from . import Run
        query = Run.send('in',parameter_set_id = watched_ps_ids).send('in',status=['created','submitted','running']).selector()
        incomplete_ps_ids = [ psid.to_s() for psid in Run.collection().distinct( "parameter_set_id", query ) ]
        completed = list( set(watched_ps_ids) - set(incomplete_ps_ids) )
        print( completed )
        return completed

    def completed(self, ps):
        return ps.runs().send('in', status=['created','submitted','running']).count() == 0

