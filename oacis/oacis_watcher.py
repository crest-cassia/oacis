import time

class OacisWatcher():

    def __init__(self, polling = 5):
        self.polling = polling
        self._observed_parameter_sets = {}
        self._observed_parameter_sets_all = {}

    def watch_ps(self, ps, callback):
        psid = ps.id().to_s()
        if psid in self._observed_parameter_sets:
            self._observed_parameter_sets[psid].append( callback )
        else:
            self._observed_parameter_sets[psid] = [ callback ]

    def watch_all_ps(self, ps_array, callback):
        sorted_ps_ids = tuple( sorted( [ ps.id().to_s() for ps in ps_array ] ) )
        if sorted_ps_ids in self._observed_parameter_sets_all:
            self._observed_parameter_sets_all[sorted_ps_ids].append( callback )
        else:
            self._observed_parameter_sets_all[sorted_ps_ids] = [ callback ]

    def loop(self):
        print("start polling")
        while True:
            executed = True
            while executed:
                executed = (self._check_completed_ps() or self._check_completed_ps_all())
            if len(self._observed_parameter_sets) == 0 and len(self._observed_parameter_sets_all) == 0:
                break
            print("waiting for %d sec" % self.polling)
            time.sleep( self.polling )
        print("stop polling")

    def _check_completed_ps(self):
        from . import ParameterSet
        executed = False
        watched_ps_ids = list( self._observed_parameter_sets.keys() )
        psids = self._completed_ps_ids( watched_ps_ids )
        
        for psid in psids:
            ps = ParameterSet.find(psid)
            if len(ps.runs()) == 0:
                print("%s has no run" % ps.id().to_s() )
            else:
                print("calling callback for %s" % ps.id().to_s() )
                executed = True
                queue = self._observed_parameter_sets[psid]
                while len(queue) > 0:
                    callback = queue.pop(0)
                    callback( ps )
                    if self._completed( ps.reload() ) == False:
                        break

        empty_psids = [ psid for psid,callbacks in self._observed_parameter_sets.items() if len(callbacks)==0 ]
        for empty_psid in empty_psids:
            self._observed_parameter_sets.pop(empty_psid)

        return executed

    def _check_completed_ps_all(self):
        from . import ParameterSet
        from functools import reduce
        executed = False
        flattened = reduce(lambda x,y: list(x)+list(y), self._observed_parameter_sets_all.keys(), [])
        watched_ps_ids = list( set(flattened) )
        completed = self._completed_ps_ids( watched_ps_ids )

        for psids,callbacks in self._observed_parameter_sets_all.items():
            if all( (psid in completed) for psid in psids ):
                print("calling callback for %s" % repr(psids) )
                executed = True
                watched_pss = [ ParameterSet.find(psid) for psid in psids ]
                while len(callbacks) > 0:
                    callback = callbacks.pop(0)
                    callback(watched_pss)
                    if any( self._completed(ps.reload()) for ps in watched_pss ):
                        break

        empty_keys = [ key for key,callbacks in self._observed_parameter_sets_all.items() if len(callbacks)==0 ]
        for key in empty_keys:
            self._observed_parameter_sets_all.pop(key)
        return executed

    def _completed_ps_ids(self, watched_ps_ids ):
        from . import Run
        query = Run.send('in',parameter_set_id = watched_ps_ids).send('in',status=['created','submitted','running']).selector()
        incomplete_ps_ids = [ psid.to_s() for psid in Run.collection().distinct( "parameter_set_id", query ) ]
        completed = list( set(watched_ps_ids) - set(incomplete_ps_ids) )
        return completed

    def _completed(self, ps):
        return ps.runs().send('in', status=['created','submitted','running']).count() == 0

