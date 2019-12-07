# build the docs for the intcode library

#deps=$(./lib/crystaldeps.rb lib/intcode.cr)

crystal docs -o docs lib/intcode.cr
