#!/usr/bin/env crystal

require "colorize"
require "../lib/intcode.cr"
require "../lib/utils.cr"

INPUT = Utils.get_input_file(Utils.cli_param_or_default(0, "day9/input.txt"))

Intcode.set_debug(Utils.enable_debug_output?)
vm = Intcode::VM.from_string(INPUT)

vm.run()
