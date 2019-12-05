require "../lib/intcode.cr"

module Disasm
  def self.intcode_to_str(intcode : Array(Int32))

    vm = Intcode::VM.new(intcode)
    address = 0

    result = String.build do |str|
      while address < vm.mem.size
        begin
          opcode, params = Intcode::Opcode.get_opcode_and_params(vm, address)
          str << "%5s : %05s : %s\n" % [address+1, vm.mem[address], opcode.debug(vm, params)]
          address += opcode.size
        rescue
          str << "%5s : %05s : ??\n" % [address+1, vm.mem[address]]
          address += 1
        end
      end
    end

    return result
  end
end
