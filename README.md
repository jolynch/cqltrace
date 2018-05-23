# cqltrace
A dynamic tracer for viewing CQL traffic in real time or offline later.

This works using
[`tshark`](https://www.wireshark.org/docs/man-pages/tshark.html)
[lua plugins](https://wiki.wireshark.org/Lua), so you need `tshark` for this
to work naturally. I've tested with 2.2.6+ and it seems to work.

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

usage: cqltrace [-bkd] input
  -b              Show bound variables in prepared statements [expensive]
  -k              Show just the bound partition keys (requires -b)
  -d              Decode prepared statements if possible
  -r              Parse queries only, with no latency measurements. Use this
                  with the -r option in cqlcap for maximum performance
  -H              Show headers at the top
  input           The input file to read from, use - for stdout
```

The output is always five fields separated by the `|` character. For normal
statements you will see:

```
<source_ip:source_port>|<query_id>|<consistency level>|BINDS=<bind1:bind2...>|<query time>
```

If running with `-d` the `QUERY_ID` will be replaced if possible with the
actual query, If the tracer is not running when a statement is prepared it
can't know the query and just puts the prepared statement id (which is the
md5 hash of the statement). Also the program will output the following
whenever it finds a prepared statement:

```
<source_ip:source_port>|<query_id>|<statement being prepared>|PREPARE|<query time>
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
$ sudo ./cqlcap - | ./cqltrace -H -b -k - 
tcpdump: listening on lo, link-type EN10MB (Ethernet), capture size 262144 bytes
Loading CQL Latency Tracer
SOURCE IP|STATEMENT ID|CONSISTENCY LEVEL|BOUND VARIABLES|LATENCY127.0.0.1:41494|SELECT * FROM system.peers|ONE|BINDS=NA|0.001761000
127.0.0.1:41494|SELECT * FROM system.local WHERE key='local'|ONE|BINDS=NA|0.001526000
127.0.0.1:41494|SELECT * FROM system_schema.keyspaces|ONE|BINDS=NA|0.001266000
127.0.0.1:41494|SELECT * FROM system_schema.tables|ONE|BINDS=NA|0.001056000
127.0.0.1:41494|SELECT * FROM system_schema.tables|ONE|BINDS=NA|0.001271000
127.0.0.1:41494|SELECT * FROM system_schema.tables|ONE|BINDS=NA|0.001579000
127.0.0.1:41494|SELECT * FROM system_schema.tables|ONE|BINDS=NA|0.002255000
127.0.0.1:41494|SELECT * FROM system_schema.tables|ONE|BINDS=NA|0.003498000
127.0.0.1:41494|SELECT * FROM system_schema.tables|ONE|BINDS=NA|0.003514000
127.0.0.1:41498|USE "test"|ONE|BINDS=NA|0.000317000
127.0.0.1:60910|USE "test"|ONE|BINDS=NA|0.000395000
127.0.0.1:56074|USE "test"|ONE|BINDS=NA|0.000265000
127.0.0.1:41498|654772B3D4CFA251A111B33F9F6F9338|LOCAL_ONE|BINDS=30|0.000911000
127.0.0.1:56074|654772B3D4CFA251A111B33F9F6F9338|LOCAL_ONE|BINDS=31|0.000607000
127.0.0.1:56074|654772B3D4CFA251A111B33F9F6F9338|LOCAL_ONE|BINDS=32|0.000660000
```

note: if you dont see anything then you may just not have enough data to flush the buffer

Offline tracing of v3 Cassandra traffic (just requests):

```
$ sudo ./cqlcap -v 3 -r test_v3
tcpdump: listening on lo, link-type EN10MB (Ethernet), capture size 262144 bytes
36 packets captured
72 packets received by filter
0 packets dropped by kernel
^C

$ ./cqltrace -r -b -k test_v3
127.0.0.1:40988|SELECT * FROM system.peers|ONE|NA|3
127.0.0.1:40988|SELECT * FROM system.local WHERE key='local'|ONE|NA|4
127.0.0.1:40988|SELECT * FROM system.schema_keyspaces|ONE|NA|5
127.0.0.1:40988|SELECT * FROM system.schema_columnfamilies|ONE|NA|6
127.0.0.1:40988|USE "test"|ONE|NA|9
127.0.0.1:40992|USE "test"|ONE|NA|10
127.0.0.1:40992|11|NA|NA|0.000157000
127.0.0.1:40992|13|NA|NA|0.000151000
127.0.0.1:40992|BDF92D1F7B155EB188447FC1DA11AE96|LOCAL_ONE|BINDS=30|15
127.0.0.1:40992|USE "test"|ONE|NA|17
127.0.0.1:40992|BDF92D1F7B155EB188447FC1DA11AE96|LOCAL_ONE|BINDS=31|18
127.0.0.1:40992|BDF92D1F7B155EB188447FC1DA11AE96|LOCAL_ONE|BINDS=32|19
127.0.0.1:40992|BDF92D1F7B155EB188447FC1DA11AE96|LOCAL_ONE|BINDS=33|20
127.0.0.1:40992|BDF92D1F7B155EB188447FC1DA11AE96|LOCAL_ONE|BINDS=34|21

$ ./cqltrace -r -d -b -k test_v3
127.0.0.1:40992|SELECT * FROM system.peers|ONE|NA|3
127.0.0.1:40992|SELECT * FROM system.local WHERE key='local'|ONE|NA|4
127.0.0.1:40992|SELECT * FROM system.schema_keyspaces|ONE|NA|5
127.0.0.1:40992|SELECT * FROM system.schema_columnfamilies|ONE|NA|6
127.0.0.1:40994|USE "test"|ONE|NA|9
127.0.0.1:40995|USE "test"|ONE|NA|10
127.0.0.1:40994|BDF92D1F7B155EB188447FC1DA11AE96|SELECT value FROM test.test WHERE key = ?|PREPARE|0.000157000
127.0.0.1:40994|BDF92D1F7B155EB188447FC1DA11AE96|SELECT value FROM test.test WHERE key = ?|PREPARE|0.000151000
127.0.0.1:40994|SELECT value FROM test.test WHERE key = ?|LOCAL_ONE|BINDS=30|15
127.0.0.1:40998|USE "test"|ONE|NA|17
127.0.0.1:40994|SELECT value FROM test.test WHERE key = ?|LOCAL_ONE|BINDS=31|18
127.0.0.1:40995|SELECT value FROM test.test WHERE key = ?|LOCAL_ONE|BINDS=32|19
127.0.0.1:40994|SELECT value FROM test.test WHERE key = ?|LOCAL_ONE|BINDS=33|20
127.0.0.1:40995|SELECT value FROM test.test WHERE key = ?|LOCAL_ONE|BINDS=34|21
```

## Advanced Maneuvers
Since the data comes out in a well defined format, you can do some advanced shell magic
to get things like latency distributions and such.

### Latency Distribution
Using [histogram.py](https://github.com/bitly/data_hacks/blob/master/data_hacks/histogram.py)
we can construct pretty latency distributions:

```
# Play around with some network delay
$ sudo tc qdisc add dev lo root handle 1:0 netem delay 10ms 5ms distribution paretonormal
# Capture some data
$ sudo ./cqlcap netem_test.pcap 

# Decode the data once for playing around with
$ ./cqltrace -b netem_test.pcap > netem_data.txt
# Make pretty graphs
$ netem_data.txt | cut -f 5 -d '|' | histogram.py

# NumSamples = 10402; Min = 0.00; Max = 0.04
# Mean = 0.010384; Variance = 0.000017; SD = 0.004136; Median 0.009328
# each ∎ represents a count of 73
    0.0031 -     0.0069 [  1331]: ∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎
    0.0069 -     0.0107 [  5491]: ∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎
    0.0107 -     0.0144 [  2289]: ∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎
    0.0144 -     0.0182 [   751]: ∎∎∎∎∎∎∎∎∎∎
    0.0182 -     0.0220 [   272]: ∎∎∎
    0.0220 -     0.0258 [   118]: ∎
    0.0258 -     0.0296 [   134]: ∎
    0.0296 -     0.0334 [    11]: 
    0.0334 -     0.0372 [     3]: 
    0.0372 -     0.0410 [     2]: 
```

### Worst offenders

You can easily find the slowest queries using ``sort``:

```
$ sort netem_data.txt -k 5 -t '|' -n | tail
127.0.0.1:59882|654772B3D4CFA251A111B33F9F6F9338|LOCAL_ONE|BINDS=36313939:36313939|0.029998000
127.0.0.1:59882|654772B3D4CFA251A111B33F9F6F9338|LOCAL_ONE|BINDS=36333431:36333431|0.030182000
127.0.0.1:45306|654772B3D4CFA251A111B33F9F6F9338|LOCAL_ONE|BINDS=39343537:39343537|0.030315000
127.0.0.1:45306|654772B3D4CFA251A111B33F9F6F9338|LOCAL_ONE|BINDS=34363132:34363132|0.030735000
127.0.0.1:59882|654772B3D4CFA251A111B33F9F6F9338|LOCAL_ONE|BINDS=38313531:38313531|0.032628000
127.0.0.1:36486|654772B3D4CFA251A111B33F9F6F9338|LOCAL_ONE|BINDS=31303636:31303636|0.033790000
127.0.0.1:36486|654772B3D4CFA251A111B33F9F6F9338|LOCAL_ONE|BINDS=33373135:33373135|0.035173000
127.0.0.1:45306|654772B3D4CFA251A111B33F9F6F9338|LOCAL_ONE|BINDS=31393738:31393738|0.036525000
127.0.0.1:45306|654772B3D4CFA251A111B33F9F6F9338|LOCAL_ONE|BINDS=37363337:37363337|0.039215000
127.0.0.1:45302|SELECT * FROM system_schema.tables|ONE|BINDS=NA|0.041001000
```

You can debug all kinds of interesting questions now with a bit of ``grep``, ``sort``, ``cut``,
etc. For example you can answer questions like:

1. Which ips are sending me all the traffic
2. Which queries are slow?
3. What consistency level are clients really querying at
4. Which partition keys are slow

# Licensing
As per the Wireshark website, plugins that link to wireshark bindings must
be released under GPL. So this plugin is released under GPL. The one exception
to this is the `lru.lua` implementation included under src, which is
the work of Boris Nagaev and is Licensed under the MIT License (text included
in the file itself).

# Running with Docker

If you're having trouble getting this to work with your various version of
tshark and have docker installed you can just use that:

```bash
$ docker build -t cqltrace .
# Copy a packet capture wherever, mount it into your container, and run
# cqltrace on it
# In this case I assume the data is at /tmp/test.pcap
$ docker run -it -v /tmp/test.pcap:/work/data.pcap cqltrace ./cqltrace -H /work/data.pcap
```
