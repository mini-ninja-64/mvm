arg -> Identifier | Number | Address
arg_list -> BracketOpen arg BracketClose

invocation -> Identifier arg_list
pragma -> Dot invocation
statement -> (invocation | pragma) Semicolon

block -> Identifier Colon BlockOpen statement* BlockClose
