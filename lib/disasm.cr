require "../lib/intcode.cr"

module Disasm
  def self.intcode_to_str(intcode : Array(Int64), offset=0)

    vm = Intcode::VM.new(intcode)
    address = 0_i64

    String.build do |str|
      while address < vm.mem.size
        begin
          opcode, params = Intcode::Opcode.get_opcode_and_params(vm, address)
          str << "%5s : %05s : %s\n" % [address+offset, vm.mem[address], opcode.debug(vm, params)]
          address += opcode.size
        rescue
          str << "%5s : %05s : ??\n" % [address+offset, vm.mem[address]]
          address += 1
        end
      end
    end
  end
end
