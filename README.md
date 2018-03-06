# cqltrace
A dynamic tracer for viewing CQL traffic in real time or offline later.

# Using it
This provides two tools:
1. `cqltracer`. A tool which understands any standard pcap file containing CQL traffic
2. `cqlcap`. A helper script for helping you get a pcap file containing CQL traffic.

## `cqltracr`
This tool takes as input a pcap file containing CQL traffic (or stdin via
`-`) and decodes it for you.

```
$ ./cqltrace -h
Trace CQL traffic from a pcap file

usage: cqltrace [-hkd] input
  -b              Show bound variables in prepared statements [expensive
  -k              Show just the bound partition keys (requires -b)
  -d              Decode prepared statements if possible
  -r              Parse queries only, no latency. Use this with
                  the -r option in cqlcap for maximum performance
  input           The input file to read from, use - for stdout
```

The output is always four fields separated by the `|` character. For normal
statements you will see:

```
<query_id>|<consistency level>|BINDS=<bind1:bind2...>|<query time>
```

If running with `-d` the `QUERY_ID` will be replaced if possible with the
actual query, If the tracer is not running when a statement is prepared it
can't know the query and just puts the prepared statement id (which is the
md5 hash of the statement). Also the program will output the following
whenever it finds a prepared statement:

```
<query_id>|<statement being prepared>|PREPARE|<query time>
```

## `cqlcap`
This tool outputs a pcap file (or stdout via `-`) containing CQL traffic.
It's just a wrapper around tcpdump that has some nice filters for lower
overhead captures (`-r`).

```
Capture live CQL traffic and output to a file

usage: cqlcap [-h] [-i interface] [-p cql_port] [-v cql_version] output
  -i interface    Choose the interface (e.g. lo, eth0) to capture from
  -p cql_port     The tcp port CQL traffic is coming into (9042)
  -v cql_version  The CQL version to sniff for (v4)
  -h              Show this help message.
  -r              Captures just the requests. Much lower overhead,
                  but can only show the queries, no responses
  output          Save output to this file, - for stdout
```

### Examples

Live tracing of a CQL workload:

```
$ sudo ./cqlcap - | ./cqltrace -b -k -
tcpdump: listening on lo, link-type EN10MB (Ethernet), capture size 262144 bytes
Loading CQL Latency Tracer
SELECT * FROM system.peers|ONE|BINDS=NA|0.000675000
SELECT * FROM system.local WHERE key='local'|ONE|BINDS=NA|0.001267000
SELECT * FROM system.schema_keyspaces|ONE|BINDS=NA|0.000459000
SELECT * FROM system.schema_columnfamilies|ONE|BINDS=NA|0.001243000
SELECT * FROM system.schema_columnfamilies|ONE|BINDS=NA|0.002199000
USE "test"|ONE|BINDS=NA|0.000128000
USE "test"|ONE|BINDS=NA|0.000145000
USE "test"|ONE|BINDS=NA|0.000113000
BDF92D1F7B155EB188447FC1DA11AE96|LOCAL_ONE|BINDS=30|0.000999000
BDF92D1F7B155EB188447FC1DA11AE96|LOCAL_ONE|BINDS=31|0.000965000
BDF92D1F7B155EB188447FC1DA11AE96|LOCAL_ONE|BINDS=32|0.000387000
BDF92D1F7B155EB188447FC1DA11AE96|LOCAL_ONE|BINDS=33|0.000648000
```

Offline tracing of v3 Cassandra traffic (just requests):

```
$ sudo ./cqlcap -v 3 -r test_v3
tcpdump: listening on lo, link-type EN10MB (Ethernet), capture size 262144 bytes
36 packets captured
72 packets received by filter
0 packets dropped by kernel
^C

$ ./cqltrace -r -b -k test_v3
Loading CQL Latency Tracer
SELECT * FROM system.peers|ONE|NA|3
SELECT * FROM system.local WHERE key='local'|ONE|NA|4
SELECT * FROM system.schema_keyspaces|ONE|NA|5
SELECT * FROM system.schema_columnfamilies|ONE|NA|6
USE "test"|ONE|NA|9
USE "test"|ONE|NA|10
11|NA|NA|0.000157000
13|NA|NA|0.000151000
BDF92D1F7B155EB188447FC1DA11AE96|LOCAL_ONE|BINDS=30|15
USE "test"|ONE|NA|17
BDF92D1F7B155EB188447FC1DA11AE96|LOCAL_ONE|BINDS=31|18
BDF92D1F7B155EB188447FC1DA11AE96|LOCAL_ONE|BINDS=32|19
BDF92D1F7B155EB188447FC1DA11AE96|LOCAL_ONE|BINDS=33|20
BDF92D1F7B155EB188447FC1DA11AE96|LOCAL_ONE|BINDS=34|21

$ ./cqltrace -r -d -b -k test_v3
Loading CQL Latency Tracer
SELECT * FROM system.peers|ONE|NA|3
SELECT * FROM system.local WHERE key='local'|ONE|NA|4
SELECT * FROM system.schema_keyspaces|ONE|NA|5
SELECT * FROM system.schema_columnfamilies|ONE|NA|6
USE "test"|ONE|NA|9
USE "test"|ONE|NA|10
BDF92D1F7B155EB188447FC1DA11AE96|SELECT value FROM test.test WHERE key = ?|PREPARE|0.000157000
BDF92D1F7B155EB188447FC1DA11AE96|SELECT value FROM test.test WHERE key = ?|PREPARE|0.000151000
SELECT value FROM test.test WHERE key = ?|LOCAL_ONE|BINDS=30|15
USE "test"|ONE|NA|17
SELECT value FROM test.test WHERE key = ?|LOCAL_ONE|BINDS=31|18
SELECT value FROM test.test WHERE key = ?|LOCAL_ONE|BINDS=32|19
SELECT value FROM test.test WHERE key = ?|LOCAL_ONE|BINDS=33|20
SELECT value FROM test.test WHERE key = ?|LOCAL_ONE|BINDS=34|21
```

# Licensing
As per the Wireshark website, plugins that link to wireshark bindings must
be released under GPL. So this plugin is released under GPL. The one exception
to this is the `lru.lua` implementation included under src, which is
the work of Boris Nagaev and is Licensed under the MIT License (text included
in the file itself).
