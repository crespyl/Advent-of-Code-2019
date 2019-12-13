#!/usr/bin/env crystal
require "readline"
require "colorize"
require "../lib/vm2.cr"
require "../lib/disasm.cr"

class Debugger
  property vm : VM2::VM

  property watchlist : Hash(String, Int32)
  property breakpoints : Hash(Int32, String)

  property output_log : Array(Int64)

  def initialize()
    @vm = VM2::VM.new([0_i64])
    @watchlist = {} of String => Int32
    @breakpoints = {} of Int32 => String
    @output_log = [] of Int64
  end

  def print_vm_summary
    puts "%s:%s] PC: %s  BASE: %s" % [@vm.name, @vm.status, format_addr_val(@vm.pc), format_addr_val(@vm.rel_base)]
    puts "IN: #{@vm.input}" if @vm.input.size > 0
    print_watches
    print_disasm(@vm.pc, @vm.pc+25) if @vm.mem.size > 1
  end

  def print_watches
    puts @watchlist.map { |name, a| "%s (%05i) = %05i" % {name, a, @vm.read_mem(a)} }.join(", ")
  end

  def print_breaks
    puts "BREAKPOINTS:"
    puts @breakpoints.join("\n")
  end

  def print_disasm(start,stop)
    segment = @vm.mem[start..stop]
    log "showing #{start}..#{stop}"

    dis = Disasm.intcode_to_str(segment, start)
    log "\n%s\n" % dis
  end

  def prompt
    if @vm.mem.size > 1
      "%s:%s] " % [@vm.name, @vm.status, format_addr_val(@vm.pc), format_addr_val(@vm.rel_base)]
    else
      "> "
    end
  end

  def format_addr_val(addr)
    "%05i (%05i)" % [addr, @vm.read_mem(addr)]
  end

  def log(msg)
    puts msg
  end

  def run_vm
    log "running..."
    start = @vm.cycles
    while @vm.status == :ok && ! @breakpoints[@vm.pc]?
      @vm.exec
    end
    log "stopped after %s cycles" % [@vm.cycles - start]
    log " BREAKPOINT: %s" % @breakpoints[@vm.pc] if @breakpoints[@vm.pc]?
  end

  def load_program(filename)
    @vm = VM2.from_file(filename)
    @vm.output_fn = ->(x: Int64) { @output_log << x; log "VM OUTPUT: %i" % x }
    log "loaded VM (%i)" % @vm.mem.size
  end

  def step(n,verbose=false)
    c = @vm.cycles
    while n > 0 && @vm.status == :ok
      n -= 1
      @vm.exec
      print_vm_summary if verbose
    end
    log "stopped after #{@vm.cycles - c} cycles"
    print_vm_summary
  end

  def add_breakpoint(name, address)
    @breakpoints[address] = name
  end

  def rm_breakpoint(name)
    @breakpoints.each do |k,v|
      if v == name
        @breakpoints[k] = nil
      end
    end
  end

  def add_watch(name, address)
    @watchlist[name] = address
  end

  def rm_watch(name)
    @watchlist[name] = nil
  end

  def run

    log "Intcode Debugger Ready"
    while input = Readline.readline(prompt,true)
      line = input.strip

      if line == "" && @vm.mem.size > 1
        @vm.exec
        print_vm_summary
      end

      next unless line.match(/.+/)

      args = line.split(' ')
      command = args.shift

      case command

      when "load" # load program
        next if args.size < 1
        load_program(args[0])
        print_vm_summary

      when "run" # run the machine until it stops, or the pc hits a breakpoint
        run_vm

      when "step" # step foward n steps, ignoring breakpoints
        n = (args[0]? || "1").to_i
        puts "running #{n} steps"
        step(n)

      when "stepv" # step forward n steps, ignoring breakpoints, print state on each step
        n = (args[0]? || "1").to_i
        puts "running #{n} steps"
        step(n, true)

      when "breakpoint"
        if args.size > 0
          addrs = args.in_groups_of(2,"0").map { |a| {a[0], a[1].to_i} }
          addrs.each do |n,a|
            add_breakpoint(n,a)
          end
          log "added #{addrs.size} breakpoints"
        else
          print_breaks
        end

      when "watch" # add an address to the watchlist
        if args.size > 1
          addrs = args.in_groups_of(2,"0").map { |a| {a[0], a[1].to_i} }
          addrs.each do |n,a|
            add_watch(n,a)
          end
          log "added #{addrs.size} addresses to the watchlist"
        else
          print_watches
        end

      when "show" # show the state and watchlist, show n...: show a list of addresses
        if args.size > 0
          args.each do |a|
            puts "(%s) %05i" % [a, @vm.read_mem(a.to_i)]
          end
        else
          print_vm_summary
        end

      when "set"
        next if args.size < 2

        if args[0].match /\d+/
          a = args[0].to_i64
          v = args[1].to_i64
          @vm.write_mem(a,v)
        else case args[0].downcase
             when "pc"
               @vm.pc = args[1].to_i64
             when "base"
               @vm.rel_base = args[1].to_i64
             when "status"
               case args[1]
               when "ok"
                 @vm.status = :ok
               when "halted"
                 @vm.status = :halted
               when "needs_input"
                 @vm.status = :needs_input
               else "invalid status"
               end
             else log "can't set that"
             end
        end

      when "disasm"
        start = args[0]? ? args[0].to_i : @vm.pc
        stop = args[1]? ? args[1].to_i : start+10

        print_disasm(start,stop)

      when "dump"
        File.write(args[0]? || "dump.txt", vm.mem.map{ |v| v.to_s }.join(","))

      when "input" # feed input to the machine
        next unless args.size > 0
        args.each do |a|
          vm.send_input(a.to_i64)
        end

      when "output" # show the machine's output
        log @output_log

      when "otext"
        log @output_log.map{ |v| v.unsafe_chr }.join

      when "exit"
        log "goodbye"
        break
      end

    end

  end

end

Debugger.new.run
