# OACIS uses multi-document transactions (ParameterSet creation runs inside
# a transaction to stay consistent with concurrent parameter-definition
# changes). MongoDB provides transactions only on replica sets; a
# single-node replica set is sufficient and adds no operational burden.
#
# Without this check, the first ParameterSet creation on a standalone
# mongod fails with a misleading driver error, so fail fast with
# instructions instead.
Rails.application.config.after_initialize do
  next if ENV['OACIS_SKIP_REPLICA_SET_CHECK']
  begin
    hello = Mongoid.default_client.command(hello: 1).documents.first
    unless hello['setName']
      abort <<~MSG
        ============================================================================
        OACIS requires MongoDB to run as a replica set (a single node is fine),
        because ParameterSet creation uses multi-document transactions.

        To convert an existing standalone mongod (existing data is preserved):

          1. add the following to mongod.conf:
               replication:
                 replSetName: rs0
          2. restart mongod
          3. run once in mongosh:
               rs.initiate({_id: "rs0", members: [{_id: 0, host: "localhost:27017"}]})

        Set OACIS_SKIP_REPLICA_SET_CHECK=1 to bypass this check (not recommended;
        creating parameter sets will fail on a standalone mongod).
        ============================================================================
      MSG
    end
  rescue Mongo::Error::NoServerAvailable, Mongo::Error::SocketError, Mongo::Error::SocketTimeoutError
    # MongoDB is not reachable at boot (e.g. during asset precompilation);
    # any real DB access will fail later with its own error
  end
end
