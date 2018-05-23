# Testing

To run the tests on your particular version of tshark/wireshark, run the
following from the tests directory:

```bash
./run_all_tests.sh
```

If you just want to try one test you can run the command manually from the
top level directory of this project

```
~cqltrace$ ls
cqlcap  cqltrace  LICENSE  README.md  src  tests

~cqltrace$ ./tests/test_cases/simple_v3.sh ./tests/test_cases/simple_v3.in
# A bunch of output

~cqltrace$ diff <(./tests/test_cases/simple_v3.sh
./tests/test_cases/simple_v3.in) <(cat
./tests/test_cases/simple_v3.out)
# Shows any differences, should be no difference
```
