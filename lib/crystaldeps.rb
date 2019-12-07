#!/usr/bin/env ruby
# quick util script to recursively get the dependencies of a crystal file

def getdeps(filename)
  deps = File
    .readlines(filename)
    .map { |l| l.match('require.+"(.+\.cr)"') }
    .reject { |l| l.nil? }
    .map { |match| match[1] }

  to_redo = []
  deps.each do |path|
    Dir.chdir(File.dirname(filename)) do
      if File.exists? path
        to_redo << File.expand_path(path)
      end
    end
  end

  return to_redo
end

deps = []
files = [ARGV[0]]
checked = []
while !files.empty?
  file = files.pop
  checked << file

  for dep in getdeps(file)
    deps |= [dep]
    if !checked.any? dep
      files << dep
    end
  end
end

puts deps
