# Copyright 2020-2022 Efabless Corporation
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

source $::env(SCRIPTS_DIR)/openroad/common/set_global_connections.tcl
set_global_connections

define_pdn_grid \
    -name stdcell_grid \
    -starts_with POWER \
    -voltage_domain CORE \
    -pins met3

#add_pdn_stripe \
#    -grid stdcell_grid \
#    -layer met2 \
#    -width $::env(PDN_VWIDTH) \
#    -pitch 40 \
#    -offset 20 \
#    -starts_with POWER

#add_pdn_stripe \
#    -grid stdcell_grid \
#    -layer met3 \
#    -width $::env(PDN_RAIL_WIDTH) \
#    -followpins \
#    -starts_with POWER

    add_pdn_ring \
	-grid stdcell_grid \
	-layers {met2 met3} \
	-widths {1 1} \
	-spacings {0.3 0.3} \
	-core_offsets {-2 -1} 
		

# Adds the standard cell rails if enabled.
    add_pdn_stripe \
        -grid stdcell_grid \
        -layer met1 \
        -width $::env(PDN_RAIL_WIDTH) \
        -followpins \
        -starts_with POWER

    add_pdn_connect \
        -grid stdcell_grid \
        -layers {met1 met2}
    add_pdn_connect \
        -grid stdcell_grid \
        -layers {met2 met3}
    add_pdn_connect \
        -grid stdcell_grid \
        -layers {met1 met3}
