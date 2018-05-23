FROM ubuntu:18.04
RUN apt-get update

RUN apt-get install -y tshark
RUN tshark --version

ADD cqltrace /work/cqltrace
ADD src/ /work/src
ADD tests /work/tests

USER nobody

WORKDIR /work
