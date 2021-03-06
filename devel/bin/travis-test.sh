#!/bin/bash

# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Exit if any command returns non-zero.
set -e

# Print all commands before executing.
set -x

test_c() {
    cd compiler/c
    ./configure
    make -j test
    cd ../../runtime/c
    ./configure
    if [ -z "$TARGET_CC" ]; then
        make -j test
    else
        make -j
    fi
}

test_perl() {
    # Test::Harness defaults to PERL_USE_UNSAFE_INC=1
    export PERL_USE_UNSAFE_INC=0

    source ~/perl5/perlbrew/etc/bashrc
    perlbrew list
    perlbrew switch $PERL_VERSION ||
        perlbrew install --switch --notest --noman --thread $PERL_VERSION
    cd compiler/perl
    cpanm --quiet --installdeps --notest .
    perl Build.PL
    ./Build test
    cd ../../runtime/perl
    perl Build.PL
    ./Build test
}

test_go() {
    mkdir -p gotest/src/git-wip-us.apache.org/repos/asf
    ln -s `pwd` \
        gotest/src/git-wip-us.apache.org/repos/asf/lucy-clownfish.git
    export GOPATH="$(pwd)/gotest"
    cd compiler/go
    go run build.go test
    go run build.go install
    cd ../../runtime/go
    go run build.go test
}

test_python() {
    cd compiler/python
    python3 setup.py test
    cd ../../runtime/python
    python3 setup.py test
}

case $CLOWNFISH_HOST in
    perl)
        test_perl
        ;;
    c)
        test_c
        ;;
    go)
        test_go
        ;;
    python)
        test_python
        ;;
    *)
        echo "unknown CLOWNFISH_HOST: $CLOWNFISH_HOST"
        exit 1
esac

