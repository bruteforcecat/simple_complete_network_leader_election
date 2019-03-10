# start your application tree manually
# Application.ensure_all_started(:scnle)
ScnleTest.Cluster.spawn("my-cluster", 2)
# run all tests!
ExUnit.start()
