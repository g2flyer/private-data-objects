# Copyright 2018 Intel Corporation
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

SRCDIR?=$(dir $(abspath $(lastword $(MAKEFILE_LIST))))
ROOTDIR := $(abspath $(SRCDIR)/../..)
EXTENSIONPATH := $(ROOTDIR)/common/build
COMP_REPORT_GEN=cdi/build/gen-cdi-report

TARGETS := all clean debug install test

ifeq ($(PDO_INTERPRETER),gipsy)
    CONTRACTS := auction exchange integer-key test-contracts
else
ifeq ($(PDO_INTERPRETER),wawaka)
    CONTRACTS := wawaka
else
ifeq ($(PDO_INTERPRETER),wawaka-opt)
    CONTRACTS := wawaka
else
ifeq ($(PDO_INTERPRETER),wawaka-aot)
    CONTRACTS := wawaka
else
$(error Incomplete configuration, PDO_INTERPRETER is not defined)
endif
endif
endif
endif

$(TARGETS): $(COMP_REPORT_GEN) $(CONTRACTS)

$(CONTRACTS):
	$(MAKE) -C $@ $(MAKECMDGOALS)

$(COMP_REPORT_GEN) :
	@echo build CDI tools
	@$(MAKE) -C cdi $(MAKECMDGOALS)

.PHONY: $(TARGETS) $(CONTRACTS)
