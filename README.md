SP_XBAR Downlink + UVM Verification

Layout
- rtl/: RTL sources and interfaces
- uvm/: UVM package with env, agents, monitors, scoreboard
- tb/: tb_top

Build/Run
- Use your preferred simulator. Edit Makefile target `run` to compile `SRCS`.
- Minimal order (for most simulators): packages -> interfaces -> libs -> RTL -> UVM -> tb_top.

Parameters
- IN_NUM=8, OT_NUM=8, DATA_WIDTH=256, VOQ_DEPTH configurable in `SP_XBAR_downlink`.

UVM
- `xbar_pkg` defines items, driver, sequencer, agent, monitors, scoreboard, base test.
- Test currently fires randomized bursts on each input agent.

