require "../spec_helper"
require "../support/nodes.cr"

# Check that parsing the given source succeeds. If given, additionally check
# that the result of parsing the source matches the given nodes.
private def it_parses(source, *expected, file=__FILE__, line=__LINE__, end_line=__END_LINE__)
  it %Q(parses `#{source}`), file, line, end_line do
    result = parse_program(source)
    unless expected.empty?
      result.should eq(Expressions.new(*expected))
    end
  end
end

# Expect the given source to raise an error when parsed. If `message` is given,
# the raised error will be expected to contain at least that content.
private def it_does_not_parse(source, message=nil, file=__FILE__, line=__LINE__, end_line=__END_LINE__)
  it %Q(does not parse `#{source}`), file, line, end_line do
    exception = expect_raises(ParseError) do
      result = parse_program(source)
    end

    if message
      (exception.message || "").downcase.should match(message)
    end
  end
end


private def test_calls_with_receiver(receiver_source, receiver_node)
  it_parses %Q(#{receiver_source}call),             Call.new(receiver_node, "call")
  it_parses %Q(#{receiver_source}call?),            Call.new(receiver_node, "call?")
  it_parses %Q(#{receiver_source}call!),            Call.new(receiver_node, "call!")
  it_parses %Q(#{receiver_source}call()),           Call.new(receiver_node, "call")
  it_parses %Q(#{receiver_source}call?()),          Call.new(receiver_node, "call?")
  it_parses %Q(#{receiver_source}call!()),          Call.new(receiver_node, "call!")
  it_parses %Q(#{receiver_source}call(1)),          Call.new(receiver_node, "call", [l(1)])
  it_parses %Q(#{receiver_source}call(1, 2 + 3)),   Call.new(receiver_node, "call", [l(1), Call.new(l(2), "+", [l(3)], infix: true)])
  it_parses %Q(#{receiver_source}call (1)),         Call.new(receiver_node, "call", [l(1)])
  it_parses %Q(
    #{receiver_source}call(
      1,
      2
    )
  ),                            Call.new(receiver_node, "call", [l(1), l(2)])
  it_parses %Q(
    #{receiver_source}call(
    )
  ),                            Call.new(receiver_node, "call")
  # Calls with parameters _must_ wrap them in parentheses.
  it_does_not_parse %Q(#{receiver_source}call a, b)

  # Blocks can be given to a Call as either brace blocks (`{}`) or `do...end` constructs.
  it_parses %Q(#{receiver_source}call{ }),     Call.new(receiver_node, "call", block: Block.new)
  it_parses %Q(#{receiver_source}call   { }),  Call.new(receiver_node, "call", block: Block.new)
  it_parses %Q(
    #{receiver_source}call do
    end
  ),                              Call.new(receiver_node, "call", block: Block.new)
  it_parses %Q(
    #{receiver_source}call    do
    end
  ),                              Call.new(receiver_node, "call", block: Block.new)

  # The `do...end` syntax can also have a delimiter after the `do` and parameters.
  it_parses %Q(#{receiver_source}call do; end),       Call.new(receiver_node, "call",   block: Block.new)
  it_parses %Q(#{receiver_source}call? do; end),      Call.new(receiver_node, "call?",  block: Block.new)
  it_parses %Q(#{receiver_source}call! do; end),      Call.new(receiver_node, "call!",  block: Block.new)
  it_parses %Q(#{receiver_source}call   do; end),     Call.new(receiver_node, "call",   block: Block.new)
  it_parses %Q(#{receiver_source}call do |a|; end),   Call.new(receiver_node, "call",   block: Block.new([p("a")]))

  # Brace blocks accept arguments after the opening brace.
  it_parses %Q(#{receiver_source}call{ |a,b| }),                  Call.new(receiver_node, "call",   block: Block.new([p("a"), p("b")]))
  it_parses %Q(#{receiver_source}call?{ |a,b| }),                 Call.new(receiver_node, "call?",  block: Block.new([p("a"), p("b")]))
  it_parses %Q(#{receiver_source}call!{ |a,b| }),                 Call.new(receiver_node, "call!",  block: Block.new([p("a"), p("b")]))
  # Block parameters are exactly like normal Def parameters, with the same syntax support.
  it_parses %Q(#{receiver_source}call{ | | }),                    Call.new(receiver_node, "call", block: Block.new())
  it_parses %Q(#{receiver_source}call{ |a,*b| }),                 Call.new(receiver_node, "call", block: Block.new([p("a"), p("b", splat: true)]))
  it_parses %Q(#{receiver_source}call{ |1,nil=:thing| }),         Call.new(receiver_node, "call", block: Block.new([p(nil, l(1)), p("thing", l(nil))]))
  it_parses %Q(#{receiver_source}call{ |a : Integer, b : Nil| }), Call.new(receiver_node, "call", block: Block.new([p("a", restriction: c("Integer")), p("b", restriction: c("Nil"))]))
  it_parses %Q(#{receiver_source}call{ |1 =: a : Integer| }),     Call.new(receiver_node, "call", block: Block.new([p("a", l(1), restriction: c("Integer"))]))
  # Union restrictions in block parameters require parentheses to disambiguate the union from the end of the parameter list
  it_parses %Q(#{receiver_source}call{ |1 =: a : (Foo | Nil)| }), Call.new(receiver_node, "call", block: Block.new([p("a", l(1), restriction: c("Integer"))]))
  it_parses %Q(#{receiver_source}call{ |<other>| }),              Call.new(receiver_node, "call", block: Block.new([p(nil, i(Call.new(nil, "other")))]))
  it_parses %Q(#{receiver_source}call{ |<a.b>| }),                Call.new(receiver_node, "call", block: Block.new([p(nil, i(Call.new(Call.new(nil, "a"), "b")))]))
  it_parses %Q(#{receiver_source}call{ |<a[0]>| }),               Call.new(receiver_node, "call", block: Block.new([p(nil, i(Call.new(Call.new(nil, "a"), "[]", [l(0)])))]))
  it_parses %Q(#{receiver_source}call{ |*a,b| }),                 Call.new(receiver_node, "call", block: Block.new([p("a", splat: true), p("b")]))
  it_parses %Q(#{receiver_source}call{ |a,*b,c| }),               Call.new(receiver_node, "call", block: Block.new([p("a"), p("b", splat: true), p("c")]))
  it_parses %Q(#{receiver_source}call{ |a,&block| }),             Call.new(receiver_node, "call", block: Block.new([p("a")], block_param: p("block", block: true)))
  it_parses %Q(#{receiver_source}call{ |a,&b| }),                 Call.new(receiver_node, "call", block: Block.new([p("a")], block_param: p("b", block: true)))
  it_parses %Q(#{receiver_source}call{ |a,
                                              &b| }),                 Call.new(receiver_node, "call", block: Block.new([p("a")], block_param: p("b", block: true)))

  it_does_not_parse %Q(#{receiver_source}call{ |&b,a| }),     /block parameter/
  it_does_not_parse %Q(#{receiver_source}call{ |*a,*b| }),    /multiple splat/

  # `do...end` blocks accept arguments
  it_parses %Q(
    #{receiver_source}call do | |
    end
  ),                Call.new(receiver_node, "call", block: Block.new())
  it_parses %Q(
    #{receiver_source}call do |a,*b|
    end
  ),                Call.new(receiver_node, "call", block: Block.new([p("a"), p("b", splat: true)]))
  it_parses %Q(
    #{receiver_source}call do |*a,b|
    end
  ),                Call.new(receiver_node, "call", block: Block.new([p("a", splat: true), p("b")]))
  it_parses %Q(
    #{receiver_source}call do |a,*b,c|
    end
  ),                Call.new(receiver_node, "call", block: Block.new([p("a"), p("b", splat: true), p("c")]))
  it_parses %Q(
    #{receiver_source}call do |a,&block|
    end
  ),                Call.new(receiver_node, "call", block: Block.new([p("a")], block_param: p("block", block: true)))
  it_parses %Q(
    #{receiver_source}call do |a,&b|
    end
  ),                Call.new(receiver_node, "call", block: Block.new([p("a")], block_param: p("b", block: true)))
  it_parses %Q(
    #{receiver_source}call do |a,
              &b|
    end
  ),                Call.new(receiver_node, "call", block: Block.new([p("a")], block_param: p("b", block: true)))

  it_does_not_parse %Q(
    #{receiver_source}call do |&b,a|
    end
  ),                      /block parameter/
  it_does_not_parse %Q(
    #{receiver_source}call do |*a,*b|
    end
  ),                      /multiple splat/

  it_does_not_parse %Q(
    #{receiver_source}call{
      |arg|
    }
  )
  it_does_not_parse %Q(
    #{receiver_source}call do
      |arg|
    end
  )

  # Calls with arguments _and_ blocks provide the block after the closing parenthesis.
  it_parses %Q(#{receiver_source}call(1, 2){ }),  Call.new(receiver_node, "call", [l(1), l(2)], block: Block.new)
  it_parses %Q(
    #{receiver_source}call(1, 2) do
    end
  ),                            Call.new(receiver_node, "call", [l(1), l(2)], block: Block.new)

  # Calls with blocks that are within other calls can also accept blocks.
  it_parses %Q(call(#{receiver_source}inner(1){ })),  Call.new(nil, "call", [Call.new(receiver_node, "inner", [l(1)], block: Block.new).as(Node)])
  it_parses %Q(
    call(#{receiver_source}inner(1) do
    end)
  ),                                Call.new(nil, "call", [Call.new(receiver_node, "inner", [l(1)], block: Block.new).as(Node)])
  it_parses %Q(call(1, #{receiver_source}inner(1){ }, 2)),  Call.new(nil, "call", [l(1), Call.new(receiver_node, "inner", [l(1)], block: Block.new), l(2)])
  it_parses %Q(
    call(1, #{receiver_source}inner(1) do
    end, 2)
  ),                                      Call.new(nil, "call", [l(1), Call.new(receiver_node, "inner", [l(1)], block: Block.new), l(2)])

  # Blocks are exactly like normal defs, they can contain any valid Expressions node as a body.
  it_parses %Q(#{receiver_source}call{ a = 1; a }), Call.new(receiver_node, "call", block: Block.new(body: e(SimpleAssign.new(v("a"), l(1)), v("a"))))
  it_parses %Q(#{receiver_source}call{
      a = 1
      a
    }
  ), Call.new(receiver_node, "call", block: Block.new(body: e(SimpleAssign.new(v("a"), l(1)), v("a"))))
  it_parses %Q(#{receiver_source}call do
      a = 1
      a
    end
  ), Call.new(receiver_node, "call", block: Block.new(body: e(SimpleAssign.new(v("a"), l(1)), v("a"))))
end



describe "Parser" do
  # Empty program
  # An empty program should not contain any nodes under the root Expressions.
  it_parses %q()


  # Literals

  it_parses %q(nil),    l(nil)
  it_parses %q(true),   l(true)
  it_parses %q(false),  l(false)

  it_parses %q(1),          l(1)
  it_parses %q(1_000),      l(1000)
  it_parses %q(1234567890), l(1234567890)

  it_parses %q(1.0),          l(1.0)
  it_parses %q(123.456),      l(123.456)
  it_parses %q(1_234.567_89), l(1234.56789)

  it_parses %q("hello"),        l("hello")
  it_parses %q("hello\nworld"), l("hello\nworld")
  it_parses %q(""),             l("")
  it_parses %q("  \t  "),       l("  \t  ")

  it_parses %q(:name),          l(:name)
  it_parses %q(:"hello world"), l(:"hello world")


  # Identifiers not previously defined as locals are considered Calls.
  it_parses %q(what),             Call.new(nil, "what")
  it_parses %q(long_identifier),  Call.new(nil, "long_identifier")
  it_parses %q(ident_with_1234),  Call.new(nil, "ident_with_1234")

  it_parses %q(_),              u("_")
  it_parses %q(_named),         u("_named")
  it_parses %q(_named_longer),  u("_named_longer")
  it_parses %q(_1234),          u("_1234")

  it_parses %q(Thing),          c("Thing")
  it_parses %q(A),              c("A")
  it_parses %q(ANOTHER),        c("ANOTHER")
  it_parses %q(UNDER_SCORES),   c("UNDER_SCORES")

  it_parses %q([]),             ListLiteral.new
  it_parses %q([call]),         l([Call.new(nil, "call")])
  it_parses %q([1, 2, 3]),      l([1, 2, 3])
  it_parses %q([1 , 2, 3]),     l([1, 2, 3])
  it_parses %q([  1, 3    ]),   l([1, 3])
  it_parses %q(
    [
      100,
      2.42,
      "hello"
    ]
  ),                            l([100, 2.42, "hello"])
  it_parses %q([1, *a, 3]),     l([1, Splat.new(Call.new(nil, "a")), 3])
  it_parses %q([*a, *b]),       l([Splat.new(Call.new(nil, "a")), Splat.new(Call.new(nil, "b"))])

  it_parses %q({}),             MapLiteral.new
  it_parses %q({a: 1, b: 2}),   l({ :a => 1, :b => 2 })
  it_parses %q({  a: call   }), l({ :a => Call.new(nil, "call") })
  it_parses %q(
    {
      something: "hello",
      other: 5.4
    }
  ),                            l({ :something => "hello", :other => 5.4 })

  it_parses %q(__FILE__),       MagicConst.new(:"__FILE__")
  it_parses %q(__LINE__),       MagicConst.new(:"__LINE__")
  it_parses %q(__DIR__),        MagicConst.new(:"__DIR__")

  # Value interpolations

  # Any literal value is valid in an interpolation.
  it_parses %q(<nil>),          i(nil)
  it_parses %q(<true>),         i(true)
  it_parses %q(<false>),        i(false)
  it_parses %q(<1>),            i(1)
  it_parses %q(<1.5>),          i(1.5)
  it_parses %q(<"hi">),         i("hi")
  it_parses %q(<:hello>),       i(:hello)
  it_parses %q(<:"hi there">),  i(:"hi there")
  it_parses %q(<[1, 2]>),       i([1, 2])
  it_parses %q(<[a, *b]>),      i(l([Call.new(nil, "a"), Splat.new(Call.new(nil, "b"))]))
  it_parses %q(<{a: 1}>),       i({:a => 1})
  # Interpolations are valid as receivers for Calls
  test_calls_with_receiver("<a>.",  i(Call.new(nil, "a")))
  # Calls, Vars, Consts, Underscores are also valid.
  it_parses %q(<a>),            i(Call.new(nil, "a"))
  it_parses %q(<a?>),           i(Call.new(nil, "a?"))
  it_parses %q(<a!>),           i(Call.new(nil, "a!"))
  it_parses %q(<a(1, 2)>),      i(Call.new(nil, "a", [l(1), l(2)]))
  it_parses %q(<a.b(1)>),       i(Call.new(Call.new(nil, "a"), "b", [l(1)]))
  it_parses %q(<a.b.c>),        i(Call.new(Call.new(Call.new(nil, "a"), "b"), "c"))
  it_parses %q(<a{ }>),         i(Call.new(nil, "a", block: Block.new))
  it_parses %q(<a do; end>),    i(Call.new(nil, "a", block: Block.new))
  it_parses %q(<Thing>),        i(c("Thing"))
  it_parses %q(<Thing.Other>),  i(Call.new(c("Thing"), "Other"))
  it_parses %q(<A.B.C>),        i(Call.new(Call.new(c("A"), "B"), "C"))
  it_parses %q(<_>),            i(u("_"))
  it_parses %q(<a[0]>),         i(Call.new(Call.new(nil, "a"), "[]", [l(0)]))
  it_parses %q(<a.b[0]>),       i(Call.new(Call.new(Call.new(nil, "a"), "b"), "[]", [l(0)]))
  it_parses %q(<[1, 2][0]>),    i(Call.new(l([1, 2]), "[]", [l(0)]))
  it_parses %q(<{a: 1}[:a]>),   i(Call.new(l({ :a => 1 }), "[]", [l(:a)]))
  it_parses %q(<a(1, 2)[0]>),   i(Call.new(Call.new(nil, "a", [l(1), l(2)]), "[]", [l(0)]))
  # Complex expressions must be wrapped in parentheses.
  it_parses %q(<(a)>),          i(Call.new(nil, "a"))
  it_parses %q(<(1 + 2)>),      i(Call.new(l(1), "+", [l(2)], infix: true))
  it_does_not_parse %q(<1 + 2>)
  it_does_not_parse %q(<a + b>)
  it_does_not_parse %q(< a + b >)
  # Spacing within the braces is not important
  it_parses %q(< a >),          i(Call.new(nil, "a"))
  it_parses %q(< a[0]   >),     i(Call.new(Call.new(nil, "a"), "[]", [l(0)]))
  # Interpolations can span multiple lines if necessary.
  it_parses %q(<
    a
  >),                           i(Call.new(nil, "a"))
  it_parses %q(<
    (1 + 2)
  >),                           i(Call.new(l(1), "+", [l(2)], infix: true))
  # Interpolations can also be used as Map keys.
  it_parses %q(
    {
      <1>: "int",
      <nil>: :nil
    }
  ),                            l({ i(1) => "int", i(nil) => :nil })
  # Interpolations can be used as a replacement for any primary expression.
  it_parses %q([1, <2>, 3]),    l([1, i(2), 3])
  it_parses %q([1, <a.b>, 3]),  l([1, i(Call.new(Call.new(nil, "a"), "b")), 3])
  it_parses %q(<a[0]> + 4),     Call.new(i(Call.new(Call.new(nil, "a"), "[]", [l(0)])), "+", [l(4)], infix: true)



  # String Interpolations

  # Strings with interpolations are lexed as single String tokens. The parser
  # splits the string into components around `<(...)>` constructs, then parses
  # the contents of those constructs and joins them together to form a list of
  # String components consisting of StringLiterals and arbitrary Nodes.

  # Empty interpolations and string pieces should be removed, and the
  # surrounding string pieces should be merged. If the string is otherwise
  # empty, a blank string literal is used. If the remainder is a single
  # StringLiteral, it is not wrapped in an InterpolatedStringLiteral.
  it_parses %q("<()>"),                       l("")
  it_parses %q("hello<()>"),                  l("hello")
  it_parses %q("<()>, world"),                l(", world")
  it_parses %q("hello<()>, world"),           istr(l("hello"), l(", world"))
  it_parses %q("<()>hello<()>, world<()>!"),  istr(l("hello"), l(", world"), l("!"))
  # Simple expressions
  it_parses %q("<(a)>"),                      istr(Call.new(nil, "a"))
  it_parses %q("<(nil)>"),                    istr(l(nil))
  it_parses %q("<(true)>"),                   istr(l(true))
  it_parses %q("<(false)>"),                  istr(l(false))
  it_parses %q("<(1)>"),                      istr(l(1))
  it_parses %q("<(1.0)>"),                    istr(l(1.0))
  it_parses %q("<("hi")>"),                   istr(l("hi"))
  it_parses %q("<("")>"),                     istr(l(""))
  it_parses %q("<(:hi)>"),                    istr(l(:hi))
  it_parses %q("<([])>"),                     istr(ListLiteral.new)
  it_parses %q("<({})>"),                     istr(MapLiteral.new)

  # Unterminated string literals and unclosed interpolations are caught and
  # handled by the lexer. For example, the code `"<("` will raise a SyntaxError
  # before being lexed.

  # Spacing within the interpolation is not important
  it_parses %q("<(  {}  )>"),               istr(MapLiteral.new)
  it_parses %q("<(
    {}  )>"),                               istr(MapLiteral.new)
  it_parses %q("<(
    )>"),                                   l("")
  # Arbitrary newlines are also allowed, and are not included in the resulting
  # string contents.
  it_parses %q("hello<(
    ""
  )>, world"),                              istr(l("hello"), l(""), l(", world"))

  # Local variables are preserved inside the interpolation
  it_parses %q(a = 1; "<(a)>"),             SimpleAssign.new(v("a"), l(1)), istr(v("a"))

  # Complex expressions
  it_parses %q("2 is <(1 + 1)>"),           istr(l("2 is "), Call.new(l(1), "+", [l(1)], infix: true))

  # Nested interpolations
  it_parses %q("<( "<(b)>" )>"),            istr(istr(Call.new(nil, "b")))

  # Maps, brace blocks, and calls with arguments in interpolations are all
  # potentially ambiguous.
  it_parses %q("<(a.b{ |e| e*2 })>"),     istr(Call.new(Call.new(nil, "a"), "b", block: Block.new([p("e")], Call.new(v("e"), "*", [l(2)], infix: true))))
  it_parses %q("<(a.b{ |e| "<(e)>" })>"), istr(Call.new(Call.new(nil, "a"), "b", block: Block.new([p("e")], istr(v("e")))))
  it_parses %q("<({a: "<(2)>"})>"),       istr(l({:a => istr(l(2))}))
  it_parses %q("<(a.join(","))>"),        istr(Call.new(Call.new(nil, "a"), "join", [l(",")]))

  # Multiple interpolations
  it_parses %q("hello, <(first_name)> <(last_name)>"),  istr(l("hello, "), Call.new(nil, "first_name"), l(" "), Call.new(nil, "last_name"))
  it_parses %q("<(first_name)><(last_name)>"),          istr(Call.new(nil, "first_name"), Call.new(nil, "last_name"))
  it_parses %q("hello, <(first_name)>, or <(other)>"),  istr(l("hello, "), Call.new(nil, "first_name"), l(", or "), Call.new(nil, "other"))



  # Infix expressions

  it_parses %q(1 || 2),         Or.new(l(1), l(2))
  it_parses %q(1 || 2 || 3),    Or.new(l(1), Or.new(l(2), l(3)))
  it_parses %q(1 && 2),         And.new(l(1), l(2))
  it_parses %q(1 && 2 && 3),    And.new(l(1), And.new(l(2), l(3)))

  it_parses %q(1 == 2),         Call.new(l(1), "==",  [l(2)], infix: true)
  it_parses %q(1 != 2),         Call.new(l(1), "!=",  [l(2)], infix: true)
  it_parses %q(1  < 2),         Call.new(l(1), "<",   [l(2)], infix: true)
  it_parses %q(1 <= 2),         Call.new(l(1), "<=",  [l(2)], infix: true)
  it_parses %q(1 >= 2),         Call.new(l(1), ">=",  [l(2)], infix: true)
  it_parses %q(1  > 2),         Call.new(l(1), ">",   [l(2)], infix: true)


  it_parses %q(1 + 2),          Call.new(l(1), "+",   [l(2)], infix: true)
  it_parses %q(1 - 2),          Call.new(l(1), "-",   [l(2)], infix: true)
  it_parses %q(1 * 2),          Call.new(l(1), "*",   [l(2)], infix: true)
  it_parses %q(1 / 2),          Call.new(l(1), "/",   [l(2)], infix: true)
  it_parses %q(1 % 2),          Call.new(l(1), "%",   [l(2)], infix: true)
  it_parses %q("hello" * 2),    Call.new(l("hello"), "*", [l(2)], infix: true)
  it_parses %q([1] - [2]),      Call.new(l([1]), "-", [l([2])], infix: true)

  # Infix expressions allow top-level expressions on the right hand side.
  it_parses %q(1 || raise :foo),  Or.new(l(1), Raise.new(l(:foo)))
  it_parses %q(1 || break),       Or.new(l(1), Break.new)
  it_parses %q(1 || break :foo),  Or.new(l(1), Break.new(l(:foo)))
  it_parses %q(1 || next),        Or.new(l(1), Next.new)
  it_parses %q(1 || next :foo),   Or.new(l(1), Next.new(l(:foo)))
  it_parses %q(1 || return),      Or.new(l(1), Return.new)
  it_parses %q(1 || return :foo), Or.new(l(1), Return.new(l(:foo)))
  it_parses %q(1 && raise :foo),  And.new(l(1), Raise.new(l(:foo)))
  it_parses %q(1 && break),       And.new(l(1), Break.new)
  it_parses %q(1 && break :foo),  And.new(l(1), Break.new(l(:foo)))
  it_parses %q(1 && next),        And.new(l(1), Next.new)
  it_parses %q(1 && next :foo),   And.new(l(1), Next.new(l(:foo)))
  it_parses %q(1 && return),      And.new(l(1), Return.new)
  it_parses %q(1 && return :foo), And.new(l(1), Return.new(l(:foo)))
  # These expressions take control of the expression, similar to infix assignments.
  it_parses %q(1 || raise :foo || :bar),  Or.new(l(1), Raise.new(Or.new(l(:foo), l(:bar))))
  it_parses %q(1 || break :foo || :bar),  Or.new(l(1), Break.new(Or.new(l(:foo), l(:bar))))
  it_parses %q(1 || next :foo || :bar),   Or.new(l(1), Next.new(Or.new(l(:foo), l(:bar))))
  it_parses %q(1 || return :foo || :bar), Or.new(l(1), Return.new(Or.new(l(:foo), l(:bar))))
  it_parses %q(1 || raise :foo && :bar),  Or.new(l(1), Raise.new(And.new(l(:foo), l(:bar))))
  it_parses %q(1 || break :foo && :bar),  Or.new(l(1), Break.new(And.new(l(:foo), l(:bar))))
  it_parses %q(1 || next :foo && :bar),   Or.new(l(1), Next.new(And.new(l(:foo), l(:bar))))
  it_parses %q(1 || return :foo && :bar), Or.new(l(1), Return.new(And.new(l(:foo), l(:bar))))
  it_parses %q(1 && raise :foo || :bar),  And.new(l(1), Raise.new(Or.new(l(:foo), l(:bar))))
  it_parses %q(1 && break :foo || :bar),  And.new(l(1), Break.new(Or.new(l(:foo), l(:bar))))
  it_parses %q(1 && next :foo || :bar),   And.new(l(1), Next.new(Or.new(l(:foo), l(:bar))))
  it_parses %q(1 && return :foo || :bar), And.new(l(1), Return.new(Or.new(l(:foo), l(:bar))))
  it_parses %q(1 && raise :foo && :bar),  And.new(l(1), Raise.new(And.new(l(:foo), l(:bar))))
  it_parses %q(1 && break :foo && :bar),  And.new(l(1), Break.new(And.new(l(:foo), l(:bar))))
  it_parses %q(1 && next :foo && :bar),   And.new(l(1), Next.new(And.new(l(:foo), l(:bar))))
  it_parses %q(1 && return :foo && :bar), And.new(l(1), Return.new(And.new(l(:foo), l(:bar))))


  # Precedence
  it_parses %q(1 && 2 || 3),    Or.new(And.new(l(1), l(2)), l(3))
  it_parses %q(1 || 2 && 3),    Or.new(l(1), And.new(l(2), l(3)))
  it_parses %q(1 == 2 && 3),    And.new(Call.new(l(1), "==", [l(2)], infix: true).as(Node), l(3))
  it_parses %q(1 && 2 == 3),    And.new(l(1), Call.new(l(2), "==", [l(3)], infix: true))
  it_parses %q(1  < 2 == 3),    Call.new(Call.new(l(1), "<",  [l(2)], infix: true).as(Node), "==", [l(3)], infix: true)
  it_parses %q(1 == 2  < 3),    Call.new(l(1), "==", [Call.new(l(2), "<",  [l(3)], infix: true).as(Node)], infix: true)
  it_parses %q(1  + 2  < 3),    Call.new(Call.new(l(1), "+",  [l(2)], infix: true).as(Node), "<",  [l(3)], infix: true)
  it_parses %q(1  < 2  + 3),    Call.new(l(1), "<",  [Call.new(l(2), "+",  [l(3)], infix: true).as(Node)], infix: true)
  it_parses %q(1  * 2  + 3),    Call.new(Call.new(l(1), "*",  [l(2)], infix: true).as(Node), "+",  [l(3)], infix: true)
  it_parses %q(1  + 2  * 3),    Call.new(l(1), "+",  [Call.new(l(2), "*",  [l(3)], infix: true).as(Node)], infix: true)

  # Left-associativity for arithmetic expressions
  it_parses %q(1 - 1 - 1),      Call.new(Call.new(l(1), "-", [l(1)], infix: true), "-", [l(1)], infix: true)
  it_parses %q(1 + 1 - 1),      Call.new(Call.new(l(1), "+", [l(1)], infix: true), "-", [l(1)], infix: true)
  it_parses %q(1 - 1 + 1),      Call.new(Call.new(l(1), "-", [l(1)], infix: true), "+", [l(1)], infix: true)
  it_parses %q(1 / 1 / 1),      Call.new(Call.new(l(1), "/", [l(1)], infix: true), "/", [l(1)], infix: true)
  it_parses %q(1 * 1 / 1),      Call.new(Call.new(l(1), "*", [l(1)], infix: true), "/", [l(1)], infix: true)
  it_parses %q(1 / 1 * 1),      Call.new(Call.new(l(1), "/", [l(1)], infix: true), "*", [l(1)], infix: true)
  it_parses %q(1 / 1 % 1),      Call.new(Call.new(l(1), "/", [l(1)], infix: true), "%", [l(1)], infix: true)
  it_parses %q(1 % 1 / 1),      Call.new(Call.new(l(1), "%", [l(1)], infix: true), "/", [l(1)], infix: true)
  it_parses %q(1 % 1 % 1),      Call.new(Call.new(l(1), "%", [l(1)], infix: true), "%", [l(1)], infix: true)

  it_parses %q(1 * (2 || 3)),   Call.new(l(1), "*", [Or.new(l(2), l(3)).as(Node)], infix: true)

  # Ensure Calls can be used as operands to infix expressions
  it_parses %q(call + other * last), Call.new(Call.new(nil, "call"), "+", [Call.new(Call.new(nil, "other"), "*", [Call.new(nil, "last").as(Node)], infix: true).as(Node)], infix: true)



  # Unary expressions.

  # Note: these examples represent valid _syntax_. They may appear semantically
  # invalid, but should be accepted by the parser none-the-less.

  {% for op in [[:!, Not], [:-, Negation], [:*, Splat]] %}
    # Unary expressions are an operator followed by any valid postfix expression.
    it_parses %q({{op[0].id}}  nil),      {{op[1]}}.new(l(nil))
    it_parses %q({{op[0].id}}false),      {{op[1]}}.new(l(false))
    it_parses %q({{op[0].id}}"hello"),    {{op[1]}}.new(l("hello"))
    it_parses %q({{op[0].id}}[1, 2]),     {{op[1]}}.new(l([1, 2]))
    it_parses %q({{op[0].id}}{a: 2}),     {{op[1]}}.new(l({ :a => 2 }))
    it_parses %q({{op[0].id}}:hi),        {{op[1]}}.new(l(:hi))
    it_parses %q({{op[0].id}}<1.5>),      {{op[1]}}.new(i(1.5))
    it_parses %q({{op[0].id}}<other>),    {{op[1]}}.new(i(Call.new(nil, "other")))
    it_parses %q({{op[0].id}}a),          {{op[1]}}.new(Call.new(nil, "a"))
    it_parses %q({{op[0].id}}(1 + 2)),    {{op[1]}}.new(Call.new(l(1), "+", [l(2)], infix: true))
    it_parses %q({{op[0].id}}a.b),        {{op[1]}}.new(Call.new(Call.new(nil, "a"), "b"))
    it_parses %q({{op[0].id}}Thing.b),    {{op[1]}}.new(Call.new(c("Thing"), "b"))
    it_parses %q(
      {{op[0].id}}(
        1 + 2
      )
    ),                {{op[1]}}.new(Call.new(l(1), "+", [l(2)], infix: true))

    # Unary operators can be chained any number of times.
    it_parses %q({{op[0].id}}{{op[0].id}}a),              {{op[1]}}.new({{op[1]}}.new(Call.new(nil, "a")))
    it_parses %q({{op[0].id}}{{op[0].id}}{{op[0].id}}a),  {{op[1]}}.new({{op[1]}}.new({{op[1]}}.new(Call.new(nil, "a"))))

    # Unary operators are not valid without an argument.
    it_does_not_parse %q({{op[0].id}})
    # The operand must start on the same line as the operator.
    it_does_not_parse %q(
      {{op[0].id}}
      a
    )

    # Unary operations are more precedent than binary operations
    it_parses %q({{op[0].id}}1 + 2),    Call.new({{op[1]}}.new(l(1)), "+", [l(2)], infix: true)
    it_parses %q(1 + {{op[0].id}}2),    Call.new(l(1), "+", [{{op[1]}}.new(l(2)).as(Node)], infix: true)

    # Unary operations can be used anywherea primary expression is expected.
    it_parses %q([1, {{op[0].id}}a]),   l([1, {{op[1]}}.new(Call.new(nil, "a"))])
  {% end %}

  # Unary operators can also be mixed when chaining.
  it_parses %q(!*-a),     Not.new(Splat.new(Negation.new(Call.new(nil, "a"))))
  it_parses %q(-*!100),   Negation.new(Splat.new(Not.new(l(100))))
  it_parses %q(-!*[1,2]), Negation.new(Not.new(Splat.new(l([1, 2]))))

  # Unary operators have a higher precedence than any binary operation.
  it_parses %q(-1 +  -2),   Call.new(Negation.new(l(1)), "+", [Negation.new(l(2)).as(Node)], infix: true)
  it_parses %q(!1 || !2),   Or.new(Not.new(l(1)), Not.new(l(2)).as(Node))
  it_parses %q(-1 == -2),   Call.new(Negation.new(l(1)), "==", [Negation.new(l(2)).as(Node)], infix: true)
  it_parses %q( a =  -1),   SimpleAssign.new(v("a"), Negation.new(l(1)))



  # Simple Assignments

  it_parses %q(a = b),      SimpleAssign.new(v("a"), Call.new(nil, "b"))
  it_parses %q(a = b = c),  SimpleAssign.new(v("a"), SimpleAssign.new(v("b"), Call.new(nil, "c")))
  # Precedence with logical operations is odd.
  # An assignment with a logical operation as an argument considers the logical as higher priority.
  it_parses %q(a = 1 && 2),  SimpleAssign.new(v("a"), And.new(l(1), l(2)))
  it_parses %q(a = 1 || 2),  SimpleAssign.new(v("a"), Or.new(l(1), l(2)))
  # A logical operation with an assignment as an argument considers the assignment as higher priority.
  it_parses %q(1 && b = 2),  And.new(l(1), SimpleAssign.new(v("b"), l(2)))
  it_parses %q(1 || b = 2),  Or.new(l(1), SimpleAssign.new(v("b"), l(2)))
  # Assignments take over the remainder of the expression when appearing in a logical operation.
  it_parses %q(1 || b = 2 && 3), Or.new(l(1), SimpleAssign.new(v("b"), And.new(l(2), l(3))))
  it_parses %q(1 || b = 2 + c = 3 || 4), Or.new(l(1), SimpleAssign.new(v("b"), Call.new(l(2), "+", [SimpleAssign.new(v("c"), Or.new(l(3), l(4))).as(Node)], infix: true)))
  # Assignments within parentheses are contained by them.
  it_parses %q(1 || (b = 2) && 3), Or.new(l(1), And.new(SimpleAssign.new(v("b"), l(2)), l(3)))
  # Once a variable has been assigned, future references to it should be a Var, not a Call.
  it_parses %q(
    a
    a = 2
    a
  ),              Call.new(nil, "a"), SimpleAssign.new(v("a"), l(2)), v("a")
  # Consts and Underscores can also be the target of an assignment, and they
  # should be declared in the current scope.
  it_parses %q(THING = 4),  SimpleAssign.new(c("THING"), l(4))
  it_parses %q(_ = 2),      SimpleAssign.new(u("_"), l(2))
  # The left hand side may also be a Call expression as long as the Call has a receiver.
  it_parses %q(a.b = 1),          Call.new(Call.new(nil, "a"), "b=", [l(1)])
  it_parses %q(a.b.c = 1),        Call.new(Call.new(Call.new(nil, "a"), "b"), "c=", [l(1)])
  it_parses %q(a[0] = 1),         Call.new(Call.new(nil, "a"), "[]=", [l(0), l(1)])
  it_parses %q(a.b = c.d = 1),    Call.new(Call.new(nil, "a"), "b=", [Call.new(Call.new(nil, "c"), "d=", [l(1)]).as(Node)])
  it_parses %q(a[0] = b[0] = 1),  Call.new(Call.new(nil, "a"), "[]=", [l(0), Call.new(Call.new(nil, "b"), "[]=", [l(0), l(1)]).as(Node)])
  # Assignments are not allowed to methods with modifiers
  it_does_not_parse %q(a.b? = 1)
  it_does_not_parse %q(a.b! = 1)
  # Assigned Anonymous Functions called should be coerced to a Call
  it_parses %q(
    foo = fn
            ->() { }
          end
    foo()
  ), SimpleAssign.new(v("foo"), AnonymousFunction.new([Block.new])), Call.new(nil, "foo")
  it_parses %q(
    foo = fn
            ->() { }
          end
    bar = foo
    bar()
  ), SimpleAssign.new(v("foo"), AnonymousFunction.new([Block.new])), SimpleAssign.new(v("bar"), v("foo")), Call.new(nil, "bar")

  # Assignments can not be made to literal values.
  it_does_not_parse %q(2 = 4),          /cannot assign to literal value/i
  it_does_not_parse %q(2.56 = 4),       /cannot assign to literal value/i
  it_does_not_parse %q("hi" = 4),       /cannot assign to literal value/i
  it_does_not_parse %q(nil = 4),        /cannot assign to literal value/i
  it_does_not_parse %q(false = true),   /cannot assign to literal value/i
  it_does_not_parse %q([1, 2, 3] = 4),  /cannot assign to literal value/i



  # Match Assignments

  # Match assignments allow literal values on either side
  it_parses %q(1 =: 1),             MatchAssign.new(l(1), l(1))
  it_parses %q(:hi =: "hi"),        MatchAssign.new(l(:hi), l("hi"))
  it_parses %q(true =: false),      MatchAssign.new(l(true), l(false))
  it_parses %q([1, 2] =: [1, 2]),   MatchAssign.new(l([1, 2]), l([1, 2]))
  it_parses %q({a: 2} =: {a: 2}),   MatchAssign.new(l({:a => 2}), l({:a => 2}))
  # Splats in list literals act as Splat collectors (as in Params).
  it_parses %q([1, *_, 3] =: list), MatchAssign.new(l([1, Splat.new(u("_")), 3]), Call.new(nil, "list"))
  it_parses %q([1, *a, 3] =: list), MatchAssign.new(l([1, Splat.new(v("a")), 3]), Call.new(nil, "list"))
  # Only one Splat is allowed in a List pattern.
  it_does_not_parse %q([*a, *b]       =: [1, 2])
  it_does_not_parse %q([1, *a, 2, *b] =: [1, 2])
  # Multiple Splats can be used if they are in different List patterns.
  it_parses %q([[*a, 2], [3, *d]] =: list), MatchAssign.new(l([[Splat.new(v("a")), 2], [3, Splat.new(v("d"))]]), Call.new(nil, "list"))
  # Vars, Consts, and Underscores can also be used on either side.
  it_parses %q(a =: 5),             MatchAssign.new(v("a"), l(5))
  it_parses %q(Thing =: 10),        MatchAssign.new(c("Thing"), l(10))
  it_parses %q(_ =: 15),            MatchAssign.new(u("_"), l(15))
  # Value Interpolations are also allowed on either side for complex patterns/values.
  it_parses %q(<a> =: <b>),         MatchAssign.new(i(Call.new(nil, "a")), i(Call.new(nil, "b")))
  it_parses %q(<a.b> =: <c.d>),     MatchAssign.new(i(Call.new(Call.new(nil, "a"), "b")), i(Call.new(Call.new(nil, "c"), "d")))
  it_parses %q(<a[0]> =: <b[0]>),   MatchAssign.new(i(Call.new(Call.new(nil, "a"), "[]", [l(0)])), i(Call.new(Call.new(nil, "b"), "[]", [l(0)])))
  # Bare multiple assignment is not allowed. Use a List pattern instead.
  it_does_not_parse %q(a, b =: [1, 2])
  # The value of a match assignment may appear on a new line.
  it_parses %q(
    a =:
      4
  ),            MatchAssign.new(v("a"), l(4))
  # Patterns can be arbitrarily nested.
  it_parses %q(
    [1, {
      a: a,
      b: b
    }, 4] =:
      thing
  ),            MatchAssign.new(l([1, { :a => v("a"), :b => v("b") }, 4]), Call.new(nil, "thing"))

  # Matches can be chained with other matches, as well as simple assignments.
  it_parses %q(
    a = 3 =: b
  ),            SimpleAssign.new(v("a"), MatchAssign.new(l(3), Call.new(nil, "b")))
  it_parses %q(
    3 =: a = b
  ),            MatchAssign.new(l(3), SimpleAssign.new(v("a"), Call.new(nil, "b")))
  it_parses %q(
    3 =: a =: 3
  ),            MatchAssign.new(l(3), MatchAssign.new(v("a"), l(3)))



  # Operational Assignments

  # Most binary operations can be concatenated with an assignment to form an
  # Operational Assignment. These are a syntactic shorthand for and operation
  # and assignment on the same variable, i.e., `a op= b` is equivalent to
  # writing  `a = a op b`.
  {% for op in ["+=", "-=", "*=", "/=", "%=", "||=", "&&="] %}
    # When the left-hand-side is an identifier, treat it as a Var.
    it_parses %q(a {{op.id}} 1),              OpAssign.new(v("a"), {{op}}, l(1))
    it_parses %q(a {{op.id}} a {{op.id}} 1),  OpAssign.new(v("a"), {{op}}, OpAssign.new(v("a"), {{op}}, l(1)))
    it_parses %q(a {{op.id}} 1 + 2),          OpAssign.new(v("a"), {{op}}, Call.new(l(1), "+", [l(2)], infix: true))
    it_parses %q(a {{op.id}} Thing.member),   OpAssign.new(v("a"), {{op}}, Call.new(c("Thing"), "member"))

    # The left-hand-side can also be any simple Call
    it_parses %q(a.b {{op.id}} 1),                OpAssign.new(Call.new(Call.new(nil, "a"), "b"), {{op}}, l(1))
    it_parses %q(a.b {{op.id}} a.b {{op.id}} 1),  OpAssign.new(Call.new(Call.new(nil, "a"), "b"), {{op}}, OpAssign.new(Call.new(Call.new(nil, "a"), "b"), {{op}}, l(1)))
    it_parses %q(a.b {{op.id}} 1 + 2),            OpAssign.new(Call.new(Call.new(nil, "a"), "b"), {{op}}, Call.new(l(1), "+", [l(2)], infix: true))
    it_parses %q(a.b {{op.id}} Thing.member),     OpAssign.new(Call.new(Call.new(nil, "a"), "b"), {{op}}, Call.new(c("Thing"), "member"))
    it_parses %q(a[0] {{op.id}} 1),                 OpAssign.new(Call.new(Call.new(nil, "a"), "[]", [l(0)]), {{op}}, l(1))
    it_parses %q(a[0] {{op.id}} a[0] {{op.id}} 1),  OpAssign.new(Call.new(Call.new(nil, "a"), "[]", [l(0)]), {{op}}, OpAssign.new(Call.new(Call.new(nil, "a"), "[]", [l(0)]), {{op}}, l(1)))
    it_parses %q(a[0] {{op.id}} 1 + 2),             OpAssign.new(Call.new(Call.new(nil, "a"), "[]", [l(0)]), {{op}}, Call.new(l(1), "+", [l(2)], infix: true))
    it_parses %q(a[0] {{op.id}} Thing.member),      OpAssign.new(Call.new(Call.new(nil, "a"), "[]", [l(0)]), {{op}}, Call.new(c("Thing"), "member"))

    # As an infix expression, the value can appear on a new line
    it_parses %q(
      a.b {{op.id}}
        1 + 2
    ),              OpAssign.new(Call.new(Call.new(nil, "a"), "b"), {{op}}, Call.new(l(1), "+", [l(2)], infix: true))
    it_parses %q(
      a.b {{op.id}} (1 +
        2
      )
    ),              OpAssign.new(Call.new(Call.new(nil, "a"), "b"), {{op}}, Call.new(l(1), "+", [l(2)], infix: true))

    # The left-hand-side must be an assignable value (i.e., not a literal)
    it_does_not_parse %q(1 {{op.id}} 2)
    it_does_not_parse %q(nil {{op.id}} 2)
    it_does_not_parse %q([1, 2] {{op.id}} 2)
    # No left-hand-side is also invalid
    it_does_not_parse %q({{op.id}} 2)
  {% end %}


  # Element access

  # The List notation `[...]` is used on any object to access specific
  # elements within it.
  it_parses %q(list[1]),      Call.new(Call.new(nil, "list"), "[]", [l(1)])
  it_parses %q(list[a]),      Call.new(Call.new(nil, "list"), "[]", [Call.new(nil, "a").as(Node)])
  it_parses %q(list[Thing]),  Call.new(Call.new(nil, "list"), "[]", [c("Thing").as(Node)])
  it_parses %q(list[1 + 2]),  Call.new(Call.new(nil, "list"), "[]", [Call.new(l(1), "+", [l(2)], infix: true).as(Node)])
  it_parses %q(list[a = 1]),  Call.new(Call.new(nil, "list"), "[]", [SimpleAssign.new(v("a"), l(1)).as(Node)])
  it_parses %q(list[a = 1]),  Call.new(Call.new(nil, "list"), "[]", [SimpleAssign.new(v("a"), l(1)).as(Node)])
  it_parses %q(list["hi"]),   Call.new(Call.new(nil, "list"), "[]", [l("hi")])
  it_parses %q(list[:hello]), Call.new(Call.new(nil, "list"), "[]", [l(:hello)])
  # Accesses can accept any number of arguments, of any type.
  it_parses %q(list[1, 2]),         Call.new(Call.new(nil, "list"), "[]", [l(1), l(2)])
  it_parses %q(list[nil, false]),   Call.new(Call.new(nil, "list"), "[]", [l(nil), l(false)])
  # The receiver can be any expression.
  it_parses %q((1 + 2)[0]),   Call.new(Call.new(l(1), "+", [l(2)], infix: true), "[]", [l(0)])
  it_parses %q((a = 1)[0]),   Call.new(SimpleAssign.new(v("a"), l(1)), "[]", [l(0)])
  it_parses %q(false[0]),     Call.new(l(false), "[]", [l(0)])
  it_parses %q("hello"[0]),   Call.new(l("hello"), "[]", [l(0)])
  it_parses %q([1, 2][0]),    Call.new(l([1, 2]), "[]", [l(0)])
  it_parses %q({a: 1}[0]),    Call.new(l({ :a => 1 }), "[]", [l(0)])
  it_parses %q(a.b[0]),       Call.new(Call.new(Call.new(nil, "a"), "b"), "[]", [l(0)])
  it_parses %q(Thing.a[0]),   Call.new(Call.new(c("Thing"), "a"), "[]", [l(0)])
  it_parses %q(a(1, 2)[0]),   Call.new(Call.new(nil, "a", [l(1), l(2)]), "[]", [l(0)])
  it_parses %q(
    map{ }[0]
  ),            Call.new(Call.new(nil, "map", block: Block.new), "[]", [l(0)])
  it_parses %q(
    map do
    end[0]
  ),            Call.new(Call.new(nil, "map", block: Block.new), "[]", [l(0)])
  # Accesses must start on the same line, but can span multiple after the opening brace.
  it_parses %q(
    list[
      1,
      2
    ]
  ),            Call.new(Call.new(nil, "list"), "[]", [l(1), l(2)])
  it_parses %q(
    list[
      1 + 2
    ]
  ),            Call.new(Call.new(nil, "list"), "[]", [Call.new(l(1), "+", [l(2)], infix: true).as(Node)])
  it_parses %q(
    list
    [1, 2]
  ),            Call.new(nil, "list"), l([1, 2])
  it_parses %q(
    [1, 2]
    [0]
  ),            l([1, 2]), l([0])
  # Accesses can also be chained together
  it_parses %q(list[1][2]),  Call.new(Call.new(Call.new(nil, "list"), "[]", [l(1)]), "[]", [l(2)])

  # The List notation must have at least one argument to be valid
  it_does_not_parse %q(list[])




  # Expression delimiters

  # Newlines can be used to delimit complete expressions
  it_parses %q(
    a = 1
    a + 2
  ),              SimpleAssign.new(v("a"), l(1)), Call.new(v("a"), "+", [l(2)], infix: true)
  it_parses %q(
    nil
    [4, 5]
  ),              l(nil), l([4, 5])
  # Semicolons can also be used to place multiple expressions on a single line
  it_parses %q(
    a = 1; a + 2;
    b = 2;
  ),              SimpleAssign.new(v("a"), l(1)), Call.new(v("a"), "+", [l(2)], infix: true), SimpleAssign.new(v("b"), l(2))
  # Without the semicolon, a syntax error should occur
  it_does_not_parse %q(a = 1 b = 2)
  # Expression with operators must include the operator on the first line, but
  # the rest of the expression may flow to multiple lines.
  it_parses %q(
    a =
      [
        1,
        2
      ]
  ),              SimpleAssign.new(v("a"), l([1, 2]))
  it_parses %q(
    var1 +
    var2
  ),              Call.new(Call.new(nil, "var1"), "+", [Call.new(nil, "var2").as(Node)], infix: true)
  it_does_not_parse %q(
    var1
    + var2
  )



  # Method definitions

  it_parses %q(
    def foo
    end
  ),                          Def.new("foo") # `@body` will be a Nop
  # Semicolons can be used as delimiters to compact the definition.
  it_parses %q(def foo; end), Def.new("foo")

  # Any identifier is valid as a definition name
  it_parses %q(def foo_;  end), Def.new("foo_")
  it_parses %q(def _foo;  end), Def.new("_foo")
  it_parses %q(def foo?;  end), Def.new("foo?")
  it_parses %q(def foo!;  end), Def.new("foo!")
  it_parses %q(def foo_!; end), Def.new("foo_!")
  it_parses %q(def foo_?; end), Def.new("foo_?")

  # Identifiers that already exist as local variables cannot be used as function names.
  it_does_not_parse %q(foo = 1; def foo; end), /collides/
  # Variables outside of the current scope do not count as collisions
  it_parses %q(
    foo = 1
    defmodule Bar
      def foo; end
    end
  )

  # `=` can also be appended to any non-modified identifier.
  it_parses %q(def foo=;    end), Def.new("foo=")
  it_parses %q(def foo_=(); end), Def.new("foo_=")
  it_parses %q(def _foo=(); end), Def.new("_foo=")
  # Multiple modifiers are not allowed
  it_does_not_parse %q(def foo?=; end)
  it_does_not_parse %q(def foo!=; end)


  it_parses %q(
    def foo(a, b)
    end
  )

  it_parses %q(def foo(); end),           Def.new("foo")
  it_parses %q(def foo(a); end),          Def.new("foo", [p("a")])
  it_parses %q(def foo(a, b); end),       Def.new("foo", [p("a"), p("b")])
  it_parses %q(def foo(_, _second); end), Def.new("foo", [p("_"), p("_second")])

  it_parses %q(
    def foo
      1 + 2
    end
  ),            Def.new("foo", body: e(Call.new(l(1), "+", [l(2)], infix: true)))

  it_parses %q(
    def foo
      a = 1
      a * 4
    end
  ),            Def.new("foo", body: e(SimpleAssign.new(v("a"), l(1)), Call.new(v("a"), "*", [l(4)], infix: true)))

  # A Splat collector can appear anywhere in the param list
  it_parses %q(def foo(*a); end),       Def.new("foo", [p("a", splat: true)], splat_index: 0)
  it_parses %q(def foo(*a, b); end),    Def.new("foo", [p("a", splat: true), p("b")], splat_index: 0)
  it_parses %q(def foo(a, *b); end),    Def.new("foo", [p("a"), p("b", splat: true)], splat_index: 1)
  it_parses %q(def foo(a, *b, c); end), Def.new("foo", [p("a"), p("b", splat: true), p("c")], splat_index: 1)

  # Multiple splat collectors are not allowed in the param list
  it_does_not_parse %q(def foo(*a, *b); end), /multiple splat parameters/

  # A Block parameter must be the last parameter in the param list
  it_parses %q(def foo(&block); end), Def.new("foo", block_param: p("block", block: true))
  it_parses %q(def foo(a, &block); end), Def.new("foo", [p("a")], block_param: p("block", block: true))
  it_parses %q(def foo(a, *b, &block); end), Def.new("foo", [p("a"), p("b", splat: true)], block_param: p("block", block: true), splat_index: 1)
  # The block parameter may also be given any name
  it_parses %q(def foo(a, &b); end), Def.new("foo", [p("a")], block_param: p("b", block: true))
  it_parses %q(def foo(a, &_); end), Def.new("foo", [p("a")], block_param: p("_", block: true))

  it_does_not_parse %q(def foo(&block, a); end),        /block parameter/
  it_does_not_parse %q(def foo(&block1, &block2); end), /block parameter/
  it_does_not_parse %q(def foo(a, &block, c); end),     /block parameter/

  it_parses %q(
    def foo; end
    def foo; end
  ),                Def.new("foo"), Def.new("foo")

  # References to variables defined as parameters should be considered Vars,
  # not Calls. This also applies to the block parameter.
  it_parses %q(def foo(a); a; end),             Def.new("foo", [p("a")], e(v("a")))
  it_parses %q(def foo(&block); block; end),    Def.new("foo", block_param: p("block", block: true), body: e(v("block")))
  # The block can be forced into a Call with parentheses, like any other local variable.
  it_parses %q(def foo(&block); block(); end),  Def.new("foo", block_param: p("block", block: true), body: e(Call.new(nil, "block")))

  # The Vars defined within the Def should be removed after the Def finishes.
  it_parses %q(def foo(a); end; a), Def.new("foo", [p("a")]), Call.new(nil, "a")

  # Defs allow patterns as parameters
  it_parses %q(def foo(nil); end),          Def.new("foo", [p(nil, l(nil))])
  it_parses %q(def foo(1, 2); end),         Def.new("foo", [p(nil, l(1)), p(nil, l(2))])
  it_parses %q(def foo([1, a]); end),       Def.new("foo", [p(nil, l([1, v("a")]))])
  it_parses %q(def foo({a: 1, b: b}); end), Def.new("foo", [p(nil, l({ :a => 1, :b => v("b") }))])
  # Patterns can also be followed by a name to capture the entire argument.
  it_parses %q(def foo([1, a] =: b); end),  Def.new("foo", [p("b", l([1, v("a")]))])
  it_parses %q(def foo([1, _] =: _); end),  Def.new("foo", [p("_", l([1, u("_")]))])
  it_parses %q(def foo(<other> =: _); end), Def.new("foo", [p("_", i(Call.new(nil, "other")))])
  it_parses %q(def foo(<a.b> =: _); end),   Def.new("foo", [p("_", i(Call.new(Call.new(nil, "a"), "b")))])
  it_parses %q(def foo(<a[0]> =: _); end),  Def.new("foo", [p("_", i(Call.new(Call.new(nil, "a"), "[]", [l(0)])))])
  # Splats within patterns are allowed.
  it_parses %q(def foo([1, *_, 3]); end),   Def.new("foo", [p(nil, l([1, Splat.new(u("_")), 3]))])

  # Type restrictions can be appended to any parameter to restrict the parameter
  # to an exact type. The type must be a valid type path.
  # Simple names
  it_parses %q(def foo(a : Integer); end),          Def.new("foo", [p("a", restriction: c("Integer"))])
  it_parses %q(def foo(a : Nil); end),              Def.new("foo", [p("a", restriction: c("Nil"))])
  it_parses %q(def foo(a : A.Foo); end),            Def.new("foo", [p("a", restriction: Call.new(c("A"), "Foo"))])
  it_parses %q(def foo(a : A | B); end),            Def.new("foo", [p("a", restriction: tu(c("A"), c("B")))])
  it_does_not_parse %q(def foo(a : 123); end)
  it_does_not_parse %q(def foo(a : nil); end)
  it_does_not_parse %q(def foo(a : [1, 2]); end)
  it_does_not_parse %q(def foo(a : b); end)
  it_does_not_parse %q(def foo(a : 1 + 2); end)
  it_does_not_parse %q(def foo(a : <thing>); end)
  it_does_not_parse %q(def foo(a : (A + B)); end)
  # Simple patterns
  it_parses %q(def foo(1 : Integer); end),        Def.new("foo", [p(nil, l(1), restriction: c("Integer"))])
  it_parses %q(def foo(1 : Nil); end),            Def.new("foo", [p(nil, l(1), restriction: c("Nil"))])
  it_parses %q(def foo(1 : A.Foo); end),          Def.new("foo", [p(nil, l(1), restriction: Call.new(c("A"), "Foo"))])
  it_parses %q(def foo(1 : A | B); end),          Def.new("foo", [p(nil, l(1), restriction: tu(c("A"), c("B")))])
  it_parses %q(def foo(nil : Integer); end),      Def.new("foo", [p(nil, l(nil), restriction: c("Integer"))])
  it_parses %q(def foo(nil : Nil); end),          Def.new("foo", [p(nil, l(nil), restriction: c("Nil"))])
  it_parses %q(def foo(nil : A.Foo); end),        Def.new("foo", [p(nil, l(nil), restriction: Call.new(c("A"), "Foo"))])
  it_parses %q(def foo(nil : A | B); end),        Def.new("foo", [p(nil, l(nil), restriction: tu(c("A"), c("B")))])
  it_parses %q(def foo(<call> : Integer); end),   Def.new("foo", [p(nil, i(Call.new(nil, "call")), restriction: c("Integer"))])
  it_parses %q(def foo(<call> : Nil); end),       Def.new("foo", [p(nil, i(Call.new(nil, "call")), restriction: c("Nil"))])
  it_parses %q(def foo(<call> : A.Foo); end),     Def.new("foo", [p(nil, i(Call.new(nil, "call")), restriction: Call.new(c("A"), "Foo"))])
  it_parses %q(def foo(<call> : A | B); end),     Def.new("foo", [p(nil, i(Call.new(nil, "call")), restriction: tu(c("A"), c("B")))])
  it_parses %q(def foo(<a.b> : Integer); end),    Def.new("foo", [p(nil, i(Call.new(Call.new(nil, "a"), "b")), restriction: c("Integer"))])
  it_parses %q(def foo(<a.b> : Nil); end),        Def.new("foo", [p(nil, i(Call.new(Call.new(nil, "a"), "b")), restriction: c("Nil"))])
  it_parses %q(def foo(<a.b> : A.Foo); end),      Def.new("foo", [p(nil, i(Call.new(Call.new(nil, "a"), "b")), restriction: Call.new(c("A"), "Foo"))])
  it_parses %q(def foo(<a.b> : A | B); end),      Def.new("foo", [p(nil, i(Call.new(Call.new(nil, "a"), "b")), restriction: tu(c("A"), c("B")))])
  it_parses %q(def foo(<a[0]> : Integer); end),   Def.new("foo", [p(nil, i(Call.new(Call.new(nil, "a"), "[]", [l(0)])), restriction: c("Integer"))])
  it_parses %q(def foo(<a[0]> : Nil); end),       Def.new("foo", [p(nil, i(Call.new(Call.new(nil, "a"), "[]", [l(0)])), restriction: c("Nil"))])
  it_parses %q(def foo(<a[0]> : A.Foo); end),     Def.new("foo", [p(nil, i(Call.new(Call.new(nil, "a"), "[]", [l(0)])), restriction: Call.new(c("A"), "Foo"))])
  it_parses %q(def foo(<a[0]> : A | B); end),     Def.new("foo", [p(nil, i(Call.new(Call.new(nil, "a"), "[]", [l(0)])), restriction: tu(c("A"), c("B")))])
  it_parses %q(def foo([1, 2] : Integer); end),   Def.new("foo", [p(nil, l([1, 2]), restriction: c("Integer"))])
  it_parses %q(def foo([1, 2] : Nil); end),       Def.new("foo", [p(nil, l([1, 2]), restriction: c("Nil"))])
  it_parses %q(def foo([1, 2] : A.Foo); end),     Def.new("foo", [p(nil, l([1, 2]), restriction: Call.new(c("A"), "Foo"))])
  it_parses %q(def foo([1, 2] : A | B); end),     Def.new("foo", [p(nil, l([1, 2]), restriction: tu(c("A"), c("B")))])
  # Patterns and names
  it_parses %q(def foo(1 =: a : Integer); end),       Def.new("foo", [p("a", l(1), restriction: c("Integer"))])
  it_parses %q(def foo(1 =: a : Nil); end),           Def.new("foo", [p("a", l(1), restriction: c("Nil"))])
  it_parses %q(def foo(1 =: a : A.Foo); end),         Def.new("foo", [p("a", l(1), restriction: Call.new(c("A"), "Foo"))])
  it_parses %q(def foo(1 =: a : A | B); end),         Def.new("foo", [p("a", l(1), restriction: tu(c("A"), c("B")))])
  it_parses %q(def foo(nil =: a : Integer); end),     Def.new("foo", [p("a", l(nil), restriction: c("Integer"))])
  it_parses %q(def foo(nil =: a : Nil); end),         Def.new("foo", [p("a", l(nil), restriction: c("Nil"))])
  it_parses %q(def foo(nil =: a : A.Foo); end),       Def.new("foo", [p("a", l(nil), restriction: Call.new(c("A"), "Foo"))])
  it_parses %q(def foo(nil =: a : A | B); end),       Def.new("foo", [p("a", l(nil), restriction: tu(c("A"), c("B")))])
  it_parses %q(def foo(<call> =: a : Integer); end),  Def.new("foo", [p("a", i(Call.new(nil, "call")), restriction: c("Integer"))])
  it_parses %q(def foo(<call> =: a : Nil); end),      Def.new("foo", [p("a", i(Call.new(nil, "call")), restriction: c("Nil"))])
  it_parses %q(def foo(<call> =: a : A.Foo); end),    Def.new("foo", [p("a", i(Call.new(nil, "call")), restriction: Call.new(c("A"), "Foo"))])
  it_parses %q(def foo(<call> =: a : A | B); end),    Def.new("foo", [p("a", i(Call.new(nil, "call")), restriction: tu(c("A"), c("B")))])
  it_parses %q(def foo(<a.b> : Integer); end),        Def.new("foo", [p(nil, i(Call.new(Call.new(nil, "a"), "b")), restriction: c("Integer"))])
  it_parses %q(def foo(<a.b> : Nil); end),            Def.new("foo", [p(nil, i(Call.new(Call.new(nil, "a"), "b")), restriction: c("Nil"))])
  it_parses %q(def foo(<a.b> : A.Foo); end),          Def.new("foo", [p(nil, i(Call.new(Call.new(nil, "a"), "b")), restriction: Call.new(c("A"), "Foo"))])
  it_parses %q(def foo(<a.b> : A | B); end),          Def.new("foo", [p(nil, i(Call.new(Call.new(nil, "a"), "b")), restriction: tu(c("A"), c("B")))])
  it_parses %q(def foo(<a[0]> : Integer); end),       Def.new("foo", [p(nil, i(Call.new(Call.new(nil, "a"), "[]", [l(0)])), restriction: c("Integer"))])
  it_parses %q(def foo(<a[0]> : Nil); end),           Def.new("foo", [p(nil, i(Call.new(Call.new(nil, "a"), "[]", [l(0)])), restriction: c("Nil"))])
  it_parses %q(def foo(<a[0]> : A.Foo); end),         Def.new("foo", [p(nil, i(Call.new(Call.new(nil, "a"), "[]", [l(0)])), restriction: Call.new(c("A"), "Foo"))])
  it_parses %q(def foo(<a[0]> : A | B); end),         Def.new("foo", [p(nil, i(Call.new(Call.new(nil, "a"), "[]", [l(0)])), restriction: tu(c("A"), c("B")))])
  it_parses %q(def foo([1, 2] =: a : Integer); end),  Def.new("foo", [p("a", l([1, 2]), restriction: c("Integer"))])
  it_parses %q(def foo([1, 2] =: a : Nil); end),      Def.new("foo", [p("a", l([1, 2]), restriction: c("Nil"))])
  it_parses %q(def foo([1, 2] =: a : A.Foo); end),    Def.new("foo", [p("a", l([1, 2]), restriction: Call.new(c("A"), "Foo"))])
  it_parses %q(def foo([1, 2] =: a : A | B); end),    Def.new("foo", [p("a", l([1, 2]), restriction: tu(c("A"), c("B")))])
  # Only the top level parameters may have retrictions.
  it_does_not_parse %q(def foo([1, a : List]); end)
  it_does_not_parse %q(def foo([1, _ : List]); end)
  it_does_not_parse %q(def foo([1, [a, b] : List]); end)
  it_does_not_parse %q(def foo([1, a : List] =: c); end)
  it_does_not_parse %q(def foo([1, _ : List] =: c); end)
  it_does_not_parse %q(def foo([1, [a, b] : List] =: c); end)
  # Block and Splat parameters may not have restrictions
  it_does_not_parse %q(def foo(*a : List); end)
  it_does_not_parse %q(def foo(&block : Block); end)
  # All components of a parameter must appear inline with the previous component
  it_does_not_parse %q(
    def foo(a :
                List)
  )
  it_does_not_parse %q(
    def foo(a
              : List)
  )
  it_does_not_parse %q(
    def foo(<(1+2)> =:
                        a)
  )
  it_does_not_parse %q(
    def foo(<(1+2)>
                    =: a)
  )
  # Individual components of a parameter _may_ span multiple lines, but should
  # avoid it where possible.
  it_parses %q(
    def foo(<(1 +
                  2)> =: a : Integer); end
  ),                                    Def.new("foo", [p("a", i(Call.new(l(1), "+", [l(2)], infix: true)), restriction: c("Integer"))])
  # Parameters may each appear on their own line for clarity
  it_parses %q(
    def foo(
        [1, _] =: list : List,
        nil,
        b : Integer
      )
    end
  ),                            Def.new("foo", [p("list", l([1, u("_")]), restriction: c("List")), p(nil, l(nil)), p("b", restriction: c("Integer"))])
  it_parses %q(
    def foo(a : A |
                B)
    end
  ),                            Def.new("foo", [p("a", restriction: tu(c("A"), c("B")))])
  it_does_not_parse %q(
    def foo(a : A
              | B)
    end
  )

  # Some operators are also allowed as method names for overloading.
  [
    "+", "-", "*", "/", "%", "[]", "[]=",
    "<", "<=", "!=", "==", ">=", ">"
  ].each do |op|
    it_parses %Q(def #{op}; end),         Def.new(op)
    it_parses %Q(def #{op}(); end),       Def.new(op)
    it_parses %Q(def #{op}(other); end),  Def.new(op, [p("other")])
    it_parses %Q(def #{op}(a, b); end),   Def.new(op, [p("a"), p("b")])
  end

  # Methods can also specify a return type with a restriction placed after the parameters
  it_parses %q(def foo : Integer; end),   Def.new("foo", return_type: c("Integer"))
  it_parses %q(
    def foo : Integer
    end
  ),                Def.new("foo", return_type: c("Integer"))
  it_parses %q(def foo : Foo; end),         Def.new("foo", return_type: c("Foo"))
  it_parses %q(def foo() : Foo; end),       Def.new("foo", return_type: c("Foo"))
  # The return type can be any valid type path or union
  it_parses %q(def foo : Thing.Other; end), Def.new("foo", return_type: Call.new(c("Thing"), "Other"))
  it_parses %q(def foo() : A.B.C; end), Def.new("foo", return_type: Call.new(Call.new(c("A"), "B"), "C"))
  it_parses %q(def foo() : A | Nil; end), Def.new("foo", return_type: tu(c("A"), c("Nil")))
  it_parses %q(def foo() : Foo.Bar | Nil; end), Def.new("foo", return_type: tu(Call.new(c("Foo"), "Bar"), c("Nil")))
  # The return type must appear on the same line as the parenthesis that closes the parameter list
  it_parses %q(
    def foo(
            ) : Foo
    end
  ),                Def.new("foo", return_type: c("Foo"))
  it_does_not_parse %q(
    def foo()
      : Foo
    end
  )
  it_does_not_parse %q(
    def foo
      : Foo
    end
  )
  # The return type must be a type expression
  it_does_not_parse %q(def foo : 1; end)
  it_does_not_parse %q(def foo : nil; end)
  it_does_not_parse %q(def foo : a + b; end)
  it_does_not_parse %q(def foo : a.b; end)
  it_does_not_parse %q(def foo : Foo.a; end)
  it_does_not_parse %q(def foo : a; end)
  it_does_not_parse %q(def foo : _nothing; end)
  it_does_not_parse %q(def foo : false; end)
  # And the expression must not be empty
  it_does_not_parse %q(def foo : ; end)

  # Types for parameters and a return type can all be given for one definition
  it_parses %q(def foo(a : Foo, b) : Foo; end), Def.new("foo", [p("a", restriction: c("Foo")), p("b")], return_type: c("Foo"))



  # Module definitions

  it_parses %q(
    defmodule Foo
    end
  ),                                  ModuleDef.new("Foo")
  it_parses %q(defmodule Foo; end),   ModuleDef.new("Foo")
  # Modules must specify a Constant as their name
  it_does_not_parse %q(defmodule foo; end)
  it_does_not_parse %q(defmodule _nope; end)
  it_parses %q(
    defmodule Foo
      def foo; end
    end
  ),                ModuleDef.new("Foo", e(Def.new("foo")))
  # Modules allow immediate code evaluation on their scope.
  it_parses %q(
    defmodule Foo
      1 + 2
      a = 3
    end
  ),                ModuleDef.new("Foo", e(Call.new(l(1), "+", [l(2)], infix: true), SimpleAssign.new(v("a"), l(3))))
  # Modules can also be nested
  it_parses %q(
    defmodule Foo
      defmodule Bar
      end
    end
  ),                ModuleDef.new("Foo", e(ModuleDef.new("Bar")))



  # Type definitions

  # A type definition can contain 0 or more properties
  it_parses %q(
    deftype Thing
    end
  ),                                  TypeDef.new("Thing")
  it_parses %q(deftype Thing; end),   TypeDef.new("Thing")
  # Types must specify a Constant as their name
  it_does_not_parse %q(deftype foo; end)
  it_does_not_parse %q(deftype _nope; end)

  # Types allow immediate code evaluation on their scope.
  it_parses %q(
    deftype Thing
      1 + 2
      a = 3
    end
  ),                TypeDef.new("Thing", body: e(Call.new(l(1), "+", [l(2)], infix: true), SimpleAssign.new(v("a"), l(3))))

  # Types can also be nested
  it_parses %q(
    deftype Thing
      deftype Part
      end
    end
  ),                TypeDef.new("Thing", body: e(TypeDef.new("Part")))


  # Type Union

  # Type Unions are written as a joining of two or more types separated by a
  # pipe character.
  # Type Unions are not currently allowed outside of type restrictions for
  # method parameters and return types.
  it_parses %q(def foo : A | B; end), Def.new("foo", return_type: tu(c("A"), c("B")))
  # Any number of types can be added to the union
  it_parses %q(def foo : A | B | C; end), Def.new("foo", return_type: tu(c("A"), c("B"), c("C")))
  it_parses %q(def foo : Foo | Bar | Baz | Boo | Car; end), Def.new("foo", return_type: tu(c("Foo"), c("Bar"), c("Baz"), c("Boo"), c("Car")))
  # Entries in the union may also be paths to types
  it_parses %q(def foo : Foo.Bar | A.B.C; end), Def.new("foo", return_type: tu(Call.new(c("Foo"), "Bar"), Call.new(Call.new(c("A"), "B"), "C")))

  # A union must have at least two types
  it_does_not_parse %q(def foo; A | ; end)
  it_does_not_parse %q(def foo; A | B |; end)



  # Inheritance

  # Types can inherit from other types using a syntax similar to type restrictions
  it_parses %q(deftype Foo : Bar; end),             TypeDef.new("Foo", supertype: c("Bar"))
  # The supertype can be a namespaced name
  it_parses %q(deftype Foo : Bar.Baz; end),         TypeDef.new("Foo", supertype: Call.new(c("Bar"), "Baz"))
  it_parses %q(deftype Foo : Bar.Baz.Foo; end),     TypeDef.new("Foo", supertype: Call.new(Call.new(c("Bar"), "Baz"), "Foo"))
  # Type supertype can also be interpolated
  it_parses %q(deftype Foo : <get_supertype>; end), TypeDef.new("Foo", supertype: i(Call.new(nil, "get_supertype")))
  # If a colon is given, a type name is required
  it_does_not_parse %q(deftype Foo : ; end)
  it_does_not_parse %q(
    deftype Foo :
    end
  )
  # The separating colon must be padded with a space to avoid confusion with a Symbol.
  it_does_not_parse %q(
    deftype Foo:Bar; end
  )
  # The supertype name must be given on the same line as the type
  it_does_not_parse %q(
    deftype Foo :
      Bar
    end
  )
  it_does_not_parse %q(
    deftype Foo
      : Bar
    end
  )
  # Type paths must be given with no spaces
  it_does_not_parse %q(deftype Foo : Bar . Baz; end)
  # Inheritance is only valid on type definitions
  it_does_not_parse %q(defmodule Foo : Bar; end)
  # The supertype can not be a type union
  it_does_not_parse %q(deftype Foo : A | B; end)



  # Type methods

  it_parses %q(
    deftype Foo
      def foo; end
    end
  ),                TypeDef.new("Foo", body: e(Def.new("foo")))

  it_parses %q(
    deftype Foo
      defstatic foo; end
    end
  ),                TypeDef.new("Foo", body: e(Def.new("foo", static: true)))

  # Types and modules can be arbitrarily nested.
  it_parses %q(
    deftype Foo
      defmodule Bar
        deftype Baz
        end
      end
    end
  ),                    TypeDef.new("Foo", body: e(ModuleDef.new("Bar", e(TypeDef.new("Baz")))))
  it_parses %q(
    defmodule Foo
      deftype Bar
        defmodule Baz
        end
      end
    end
  ),                    ModuleDef.new("Foo", e(TypeDef.new("Bar", body: e(ModuleDef.new("Baz")))))



  # Instance variables

  # Instance variables are marked with an `@` prefix.
  it_parses %q(@a),           iv("a")
  it_parses %q(@variable),    iv("variable")
  # Instance variables can appear as a primary value anywhere they are accepted.
  it_parses %q(<@var>),       i(iv("var"))
  it_parses %q(1 + @var),     Call.new(l(1), "+", [iv("var")] of Node, infix: true)
  it_parses %q(@var.each),    Call.new(iv("var"), "each")
  it_parses %q(
    def foo(<@var>)
    end
  ),                          Def.new("foo", [p(nil, i(iv("var")))])

  # Instance variables can be the target of any assignment.
  it_parses %q(@var = 1),           SimpleAssign.new(iv("var"), l(1))
  it_parses %q([1, @a] =: [1, 2]),  MatchAssign.new(l([1, iv("a")]), l([1, 2]))
  it_parses %q(@var ||= {}),        OpAssign.new(iv("var"), "||=", MapLiteral.new)



  # Type instantiation

  # Instances of types are created with a percent characeter and brace syntax
  # akin to blocks.
  it_parses %q(%Thing{}),           Instantiation.new(c("Thing"))
  it_parses %q(%Thing {}),          Instantiation.new(c("Thing"))
  it_parses %q(%Thing   {   }),     Instantiation.new(c("Thing"))
  it_parses %q(%Thing{ 1 }),        Instantiation.new(c("Thing"), [l(1)])
  it_parses %q(%Thing{ 1, 2, 3 }),  Instantiation.new(c("Thing"), [l(1), l(2), l(3)])
  it_parses %q(%Thing{ [nil, 1] }), Instantiation.new(c("Thing"), [l([nil, 1])])
  it_parses %q(%Thing{1}),          Instantiation.new(c("Thing"), [l(1)])
  it_parses %q(%Thing{1, 2, 3}),    Instantiation.new(c("Thing"), [l(1), l(2), l(3)])
  it_parses %q(%Thing{[nil, 1]}),   Instantiation.new(c("Thing"), [l([nil, 1])])
  it_parses %q(%Thing{
    1
  }),          Instantiation.new(c("Thing"), [l(1)])
  it_parses %q(%Thing{
    1, 2, 3
  }),    Instantiation.new(c("Thing"), [l(1), l(2), l(3)])
  it_parses %q(%Thing{
    [nil, 1]
  }),   Instantiation.new(c("Thing"), [l([nil, 1])])

  # The braces are required for initialization, even when there are no arguments.
  it_does_not_parse %q(%Thing)
  # There must not be spaces between the percent and the type name
  it_does_not_parse %q(%  Thing{   })
  it_does_not_parse %q(%  Thing { })
  # Similarly, the brace must appear inline  with the type.
  it_does_not_parse %q(
    %Thing
    {}
  )

  # The type can be either a Const, a Path or an interpolation. Any interpolation is
  # valid, and may span multiple lines.
  it_parses %q(%<thing>{}),             Instantiation.new(i(Call.new(nil, "thing")))
  it_parses %q(%<@type>{}),             Instantiation.new(i(iv("type")))
  it_parses %q(%<1.type>{}),            Instantiation.new(i(Call.new(l(1), "type")))
  it_parses %q(%<(type || Default)>{}), Instantiation.new(i(Or.new(Call.new(nil, "type"), c("Default"))))
  it_parses %q(
    %<(
      type
    )>{}
  ),                                    Instantiation.new(i(Call.new(nil, "type")))
  it_parses %q(%IO.FileDescriptor{}),   Instantiation.new(Call.new(c("IO"), "FileDescriptor"))
  it_parses %q(%A.B.C.D{}),             Instantiation.new(Call.new(Call.new(Call.new(c("A"), "B"), "C"), "D"))
  # Type paths must only contain constants
  it_does_not_parse %q(%A.b{})
  it_does_not_parse %q(%a.B{})
  it_does_not_parse %q(%A.b.C{})
  it_does_not_parse %q(%A.B.c{})
  it_does_not_parse %q(%a.b{})

  # Any other node is invalid as a type specification.
  it_does_not_parse %q(%nil{})
  it_does_not_parse %q(%false{})
  it_does_not_parse %q(%1{})
  it_does_not_parse %q(%"hello"{})
  it_does_not_parse %q(%some_type{})

  # Initializations are similar to Calls, allowing all the same syntax for the arguments, including blocks.
  it_parses %q(%Thing{ *opts }),        Instantiation.new(c("Thing"), [Splat.new(Call.new(nil, "opts"))] of Node)
  it_parses %q(%Thing{ } do; end),      Instantiation.new(c("Thing"), block: Block.new)
  it_parses %q(%Thing{ } { }),          Instantiation.new(c("Thing"), block: Block.new)
  it_parses %q(
    %Thing{ } do |a,b|
    end
  ),                      Instantiation.new(c("Thing"), block: Block.new([p("a"), p("b")]))
  it_parses %q(
    %Thing{ } { |a,b| }
  ),                      Instantiation.new(c("Thing"), block: Block.new([p("a"), p("b")]))
  # The block parameter can also be specified as a capture
  it_parses %q(%Thing{&block}), Instantiation.new(c("Thing"), block: FunctionCapture.new(Call.new(nil, "block")))
  it_parses %q(%Thing{
    &fn
      ->(){}
    end
  }),                    Instantiation.new(c("Thing"), block: FunctionCapture.new(AnonymousFunction.new([Block.new])))

  # Also as in a Call, trailing commas and the like are invalid
  it_does_not_parse %q(%Thing{ 1, })
  it_does_not_parse %q(%Thing{
    1,
  })



  # Calls

  test_calls_with_receiver("",                  nil)
  test_calls_with_receiver("object.",           Call.new(nil, "object"))
  test_calls_with_receiver("object?.",          Call.new(nil, "object?"))
  test_calls_with_receiver("object!.",          Call.new(nil, "object!"))
  test_calls_with_receiver("nested.object.",    Call.new(Call.new(nil, "nested"), "object"))
  test_calls_with_receiver("Thing.member.",     Call.new(c("Thing"), "member"))
  test_calls_with_receiver("Thing.Other.",      Call.new(c("Thing"), "Other"))
  test_calls_with_receiver("1.",                l(1))
  test_calls_with_receiver("[1, 2, 3].",        l([1, 2, 3]))
  test_calls_with_receiver("list[1].",          Call.new(Call.new(nil, "list"), "[]", [l(1)]))
  test_calls_with_receiver("list[1, 2].",       Call.new(Call.new(nil, "list"), "[]", [l(1), l(2)]))
  test_calls_with_receiver(%q("some string".),  l("some string"))
  test_calls_with_receiver("(1 + 2).",          Call.new(l(1), "+", [l(2)], infix: true))
  test_calls_with_receiver("method{ }.",        Call.new(nil, "method", block: Block.new))
  test_calls_with_receiver("method do; end.",   Call.new(nil, "method", block: Block.new))
  test_calls_with_receiver("@var.",             iv("var"))
  test_calls_with_receiver("%Thing{}.",         Instantiation.new(c("Thing")))

  # Any value can be coerced into a Call by suffixing it with parentheses.
  it_parses %q(a = 1; a()),               SimpleAssign.new(v("a"), l(1)), Call.new(nil, "a")
  it_parses %q(@a()),                     Call.new(nil, iv("a"))
  it_parses %q((1 + 2)(1, 2)),            Call.new(nil, Call.new(l(1), "+", [l(2)], infix: true), [l(1), l(2)])
  it_parses %q((func = &capture)()),      Call.new(nil, SimpleAssign.new(v("func"), FunctionCapture.new(Call.new(nil, "capture"))))
  it_parses %q((get_func || @default)()), Call.new(nil, Or.new(Call.new(nil, "get_func"), iv("default")))
  it_parses %q(func()(1, 2)()),           Call.new(nil, Call.new(nil, Call.new(nil, "func"), [l(1), l(2)]))
  it_parses %q(callbacks[:first]()),      Call.new(nil, Call.new(Call.new(nil, "callbacks"), "[]", [l(:first)]))
  it_parses %q((fn ->() { } end)()),      Call.new(nil, AnonymousFunction.new([Block.new]))
  it_parses %q(<get_func>()),             Call.new(nil, i(Call.new(nil, "get_func")))



  # Self

  # `self` can be used anywhere a primary expression is allowed
  it_parses %q(self),                 Self.new
  it_parses %q(-self),                Negation.new(Self.new)
  it_parses %q(<self>),               i(Self.new)
  it_parses %q(self + self),          Call.new(Self.new, "+", [Self.new.as(Node)], infix: true)
  test_calls_with_receiver("self.",   Self.new)
  it_parses %q(self[0]),              Call.new(Self.new, "[]", [l(0)])
  # `self` can not be used as the name of a Call
  it_does_not_parse %q(object.self)



  # Include

  # Includes accept any node as an argument, and are valid in any context.
  it_parses %q(include Thing),        Include.new(c("Thing"))
  it_parses %q(include Thing.Other),  Include.new(Call.new(c("Thing"), "Other"))
  it_parses %q(include dynamic),      Include.new(Call.new(nil, "dynamic"))
  it_parses %q(include 1 + 2),        Include.new(Call.new(l(1), "+", [l(2)], infix: true))
  it_parses %q(include self),         Include.new(Self.new)
  it_parses %q(include <something>),  Include.new(i(Call.new(nil, "something")))
  it_parses %q(
    defmodule Thing
      include Other
    end
  ),                                  ModuleDef.new("Thing", e(Include.new(c("Other"))))
  it_parses %q(
    def foo
      include Thing
    end
  ),                                  Def.new("foo", body: e(Include.new(c("Thing"))))
  # The argument for an include must be on the same line as the keyword
  it_does_not_parse %q(
    include
    Thing
  ),                      /expected value for include/
  # The argument is still allowed to span multiple lines
  it_parses %q(
    include 1 +
            2
  ),                                  Include.new(Call.new(l(1), "+", [l(2)], infix: true))
  # Only one value is expected. Providing multiple values is invalid.
  it_does_not_parse %q(
    include Thing1, Thing2
  )

  # Extend

  # Extends accept any node as an argument, and are valid in any context.
  it_parses %q(extend Thing),       Extend.new(c("Thing"))
  it_parses %q(extend Thing.Other), Extend.new(Call.new(c("Thing"), "Other"))
  it_parses %q(extend dynamic),     Extend.new(Call.new(nil, "dynamic"))
  it_parses %q(extend 1 + 2),       Extend.new(Call.new(l(1), "+", [l(2)], infix: true))
  it_parses %q(extend self),        Extend.new(Self.new)
  it_parses %q(extend <something>), Extend.new(i(Call.new(nil, "something")))
  it_parses %q(
    deftype Thing
      extend Other
    end
  ),                                TypeDef.new("Thing", e(Extend.new(c("Other"))))
  # The argument for an extend must be on the same line as the keyword.
  it_does_not_parse %q(
    extend
    Thing
  ),                                /expected value for extend/
  # The argument is still allowed to span multiple lines
  it_parses %q(
    extend 1 +
           2
  ),                                Extend.new(Call.new(l(1), "+", [l(2)], infix: true))
  # Only one value is expected. Providing multiple values is invalid.
  it_does_not_parse %q(
    extend Thing1, Thing2
  )

  # Require

  # Requires are syntactically similar to includes, but the expected value is a String.
  it_parses %q(require "some_file"),  Require.new(l("some_file"))
  it_parses %q(require base + path),  Require.new(Call.new(Call.new(nil, "base"), "+", [Call.new(nil, "path").as(Node)], infix: true))
  it_parses %q(require Thing.dep),    Require.new(Call.new(c("Thing"), "dep"))
  it_parses %q(require <something>),  Require.new(i(Call.new(nil, "something")))
  it_parses %q(
    defmodule Thing
      require "other_thing"
    end
  ),                                  ModuleDef.new("Thing", e(Require.new(l("other_thing"))))
  it_parses %q(
    def foo
      require "other_thing"
    end
  ),                                  Def.new("foo", body: e(Require.new(l("other_thing"))))
  it_does_not_parse %q(
    require
    "some_file"
  ),                      /expected value for require/
  it_parses %q(
    require base +
            path
  ),                                  Require.new(Call.new(Call.new(nil, "base"), "+", [Call.new(nil, "path").as(Node)], infix: true))
  # Only one value is expected. Providing multiple values is invalid.
  it_does_not_parse %q(
    require "file1", "file2"
  )



  # Conditionals

  # The primary conditional expression is `when`. It functionally replaces `if`
  # from most other languages.
  it_parses %q(
    when true
    end
  ),                                When.new(l(true))
  it_parses %q(
    when (true)
    end
  ),                                When.new(l(true))
  it_parses %q(when true; end),     When.new(l(true))
  it_parses %q(when a == 1; end),   When.new(Call.new(Call.new(nil, "a"), "==", [l(1)], infix: true))
  # Any expression can be used as a condition
  it_parses %q(
    when a = 1
    end
  ),                                When.new(SimpleAssign.new(v("a"), l(1)))
  it_parses %q(
    when 1 + 2
    end
  ),                                When.new(Call.new(l(1), "+", [l(2)], infix: true))
  it_parses %q(
    when call(1, 2)
    end
  ),                                When.new(Call.new(nil, "call", [l(1), l(2)]))
  it_parses %q(
    when [1,2].map{ |e| }
    end
  ),                                When.new(Call.new(l([1, 2]), "map", block: Block.new([p("e")])))
  # The body of a When is a normal code block.
  it_parses %q(
    when true
      1 + 1
      do_something
    end
  ),                                When.new(l(true), e(Call.new(l(1), "+", [l(1)], infix: true), Call.new(nil, "do_something")))
  # Whens can be chained together for more complex logic. This is most similar
  # to `else if` in other languages.
  it_parses %q(
    when true
      # Do a thing
    when false
      # Do another thing
    end
  ),                                When.new(l(true), alternative: When.new(l(false)))
  # An `else` can be used at the end of a When chain as a catch-all.
  it_parses %q(
    when true
    else
      a = 1
    end
  ),                                When.new(l(true), alternative: e(SimpleAssign.new(v("a"), l(1))))
  it_parses %q(
    when true
    when false
    else
    end
  ),                                When.new(l(true), alternative: When.new(l(false)))
  # Whens are also valid as the value of an assignment
  it_parses %q(
    a = when true
        when false
        end
  ),                                SimpleAssign.new(v("a"), When.new(l(true), alternative: When.new(l(false))))
  it_parses %q(
    long_name =
      when true
      when false
      end
  ),                                SimpleAssign.new(v("long_name"), When.new(l(true), alternative: When.new(l(false))))
  # Only one expression may be given for the condition of a When
  it_does_not_parse %q(
    when a, b
    end
  )


  # Unless is the logical inverse of When.
  it_parses %q(
    unless true
    end
  ),                                Unless.new(l(true))
  it_parses %q(
    unless (true)
    end
  ),                                Unless.new(l(true))
  it_parses %q(unless true; end),   Unless.new(l(true))
  it_parses %q(unless a == 1; end), Unless.new(Call.new(Call.new(nil, "a"), "==", [l(1)], infix: true))
  it_parses %q(
    unless a = 1
    end
  ),                                Unless.new(SimpleAssign.new(v("a"), l(1)))
  it_parses %q(
    unless 1 + 2
    end
  ),                                Unless.new(Call.new(l(1), "+", [l(2)], infix: true))
  it_parses %q(
    unless call(1, 2)
    end
  ),                                Unless.new(Call.new(nil, "call", [l(1), l(2)]))
  it_parses %q(
    unless [1,2].map{ |e| }
    end
  ),                                Unless.new(Call.new(l([1, 2]), "map", block: Block.new([p("e")])))
  it_parses %q(
    unless true
      1 + 1
      do_something
    end
  ),                                Unless.new(l(true), e(Call.new(l(1), "+", [l(1)], infix: true), Call.new(nil, "do_something")))
  it_parses %q(
    unless true
      # Do a thing
    unless false
      # Do another thing
    end
  ),                                Unless.new(l(true), alternative: Unless.new(l(false)))
  it_parses %q(
    unless true
    else
    end
  ),                                Unless.new(l(true))
  it_parses %q(
    unless true
    else
      a = 1
    end
  ),                                Unless.new(l(true), alternative: e(SimpleAssign.new(v("a"), l(1))))
  it_parses %q(
    unless true
    unless false
    else
    end
  ),                                Unless.new(l(true), alternative: Unless.new(l(false)))
  it_parses %q(
    a = unless true
        unless false
        end
  ),                                SimpleAssign.new(v("a"), Unless.new(l(true), alternative: Unless.new(l(false))))
  it_parses %q(
    long_name =
      unless true
      unless false
      end
  ),                                SimpleAssign.new(v("long_name"), Unless.new(l(true), alternative: Unless.new(l(false))))

  # When and Unless can be used in any combination
  it_parses %q(
    when true
    unless false
    end
  ),                                When.new(l(true), alternative: Unless.new(l(false)))
  it_parses %q(
    unless false
    when true
    end
  ),                                Unless.new(l(false), alternative: When.new(l(true)))
  it_parses %q(
    when true
    unless false
    when true
    end
  ),                                When.new(l(true), alternative: Unless.new(l(false), alternative: When.new(l(true))))
  it_parses %q(
    unless false
    when true
    unless false
    end
  ),                                Unless.new(l(false), alternative: When.new(l(true), alternative: Unless.new(l(false))))
  it_parses %q(
    a = when true
        unless false
        end
  ),                                SimpleAssign.new(v("a"), When.new(l(true), alternative: Unless.new(l(false))))
  it_parses %q(
    long_name =
      unless true
      when false
      end
  ),                                SimpleAssign.new(v("long_name"), Unless.new(l(true), alternative: When.new(l(false))))


  # `else` _must_ be the last block of a When chain
  it_does_not_parse %q(
    when true
    else
    when false
    end
  )
  it_does_not_parse %q(
    unless true
    else
    unless false
    end
  )
  # `else` is not valid on it's own
  it_does_not_parse %q(else; end)
  it_does_not_parse %q(
    else
    end
  )

  # Whens cannot be directly nested. These fail because the Whens are
  # considered as a single chain, so the second end is unexpected.
  it_does_not_parse %q(
    when true
      when false
      end
    end
  )
  it_does_not_parse %q(
    unless true
      unless false
      end
    end
  )

  # Whens that are nested within other constructs maintain their scoping
  it_parses %q(
    when true
      call do
        when true
        else
        end
      end
    when false
    end
  )



  # Loops

  # Loops are syntactically similar to Whens, but do not allow for chaining.
  # While and Until are the main looping constructs.
  it_parses %q(
    while true
    end
  ),                                While.new(l(true))
  it_parses %q(while true; end),    While.new(l(true))
  it_parses %q(while a == 1; end),  While.new(Call.new(Call.new(nil, "a"), "==", [l(1)], infix: true))
  it_parses %q(
    while a = 1
    end
  ),                                While.new(SimpleAssign.new(v("a"), l(1)))
  it_parses %q(
    while 1 + 2
    end
  ),                                While.new(Call.new(l(1), "+", [l(2)], infix: true))
  it_parses %q(
    while call(1, 2)
    end
  ),                                While.new(Call.new(nil, "call", [l(1), l(2)]))
  it_parses %q(
    while [1,2].map{ |e| }
    end
  ),                                While.new(Call.new(l([1, 2]), "map", block: Block.new([p("e")])))
  it_parses %q(
    while true
      1 + 1
      do_something
    end
  ),                                While.new(l(true), e(Call.new(l(1), "+", [l(1)], infix: true), Call.new(nil, "do_something")))

  it_parses %q(
    until true
    end
  ),                                Until.new(l(true))
  it_parses %q(until true; end),    Until.new(l(true))
  it_parses %q(until a == 1; end),  Until.new(Call.new(Call.new(nil, "a"), "==", [l(1)], infix: true))
  it_parses %q(
    until a = 1
    end
  ),                                Until.new(SimpleAssign.new(v("a"), l(1)))
  it_parses %q(
    until 1 + 2
    end
  ),                                Until.new(Call.new(l(1), "+", [l(2)], infix: true))
  it_parses %q(
    until call(1, 2)
    end
  ),                                Until.new(Call.new(nil, "call", [l(1), l(2)]))
  it_parses %q(
    until [1,2].map{ |e| }
    end
  ),                                Until.new(Call.new(l([1, 2]), "map", block: Block.new([p("e")])))
  it_parses %q(
    until true
      1 + 1
      do_something
    end
  ),                                Until.new(l(true), e(Call.new(l(1), "+", [l(1)], infix: true), Call.new(nil, "do_something")))

  # Loops can be nested directly
  it_parses %q(
    while true
      until false
      end
    end
  ),                                While.new(l(true), e(Until.new(l(false))))
  it_parses %q(
    until false
      while true
      end
    end
  ),                                Until.new(l(false), e(While.new(l(true))))

  # Loops and conditionals can be intertwined with no issues.
  it_parses %q(
    while true
      when a == b
      end
    end
  ),                                While.new(l(true), e(When.new(Call.new(Call.new(nil, "a"), "==", [Call.new(nil, "b").as(Node)], infix: true))))



  # Flow Control

  # Returns, Breaks, and Nexts all accept an optional value, like other keyword
  # expressions, the value must start on the same line as the keyword.

  {% for keyword, node in { "return".id => Return, "break".id => Break, "next".id => Next } %}
    it_parses %q({{keyword}}),              {{node}}.new
    it_parses %q({{keyword}} nil),          {{node}}.new(l(nil))
    it_parses %q({{keyword}} 1),            {{node}}.new(l(1))
    it_parses %q({{keyword}} "hello"),      {{node}}.new(l("hello"))
    it_parses %q({{keyword}} {a: 1, b: 2}), {{node}}.new(l({ :a => 1, :b => 2 }))
    it_parses %q({{keyword}} [1, 2, 3]),    {{node}}.new(l([1, 2, 3]))
    it_parses %q({{keyword}} %Thing{}),     {{node}}.new(Instantiation.new(c("Thing")))
    it_parses %q({{keyword}} Const),        {{node}}.new(c("Const"))
    it_parses %q({{keyword}} a),            {{node}}.new(Call.new(nil, "a"))
    it_parses %q({{keyword}} 1 + 2),        {{node}}.new(Call.new(l(1), "+", [l(2)], infix: true))
    it_parses %q({{keyword}} *collection),  {{node}}.new(Splat.new(Call.new(nil, "collection")))
    it_parses %q(
      {{keyword}} 1 +
                  2
    ),                                      {{node}}.new(Call.new(l(1), "+", [l(2)], infix: true))
    it_parses %q(
      {{keyword}} (
        1 + 2
      )
    ),                                      {{node}}.new(Call.new(l(1), "+", [l(2)], infix: true))
    it_parses %q(
      {{keyword}}
      1 + 2
    ),                                      {{node}}.new, Call.new(l(1), "+", [l(2)], infix: true)

    # Carrying multiple values implicitly is not supported. To simulate this,
    # use a List instead.
    it_does_not_parse %q(
      {{keyword}} 1, 2
    )

    # Flow control has a lower precedence than assignment, meaning an assignment
    # can be used as the value of a control expression.
    it_parses %q({{keyword}} foo = :bar),   {{node}}.new(SimpleAssign.new(v("foo"), l(:bar)))
  {% end %}



  # Raise

  # A Raise is syntactically valid so long as it is given an argument.
  it_parses %q(raise "hello"),  Raise.new(l("hello"))
  it_parses %q(raise :hi),      Raise.new(l(:hi))
  it_parses %q(raise nil),      Raise.new(l(nil))
  it_parses %q(raise true),     Raise.new(l(true))
  it_parses %q(raise false),    Raise.new(l(false))
  it_parses %q(raise 1),        Raise.new(l(1))
  it_parses %q(raise 1.0),      Raise.new(l(1))
  it_parses %q(raise []),       Raise.new(ListLiteral.new)
  it_parses %q(raise {}),       Raise.new(MapLiteral.new)
  it_parses %q(raise Thing),    Raise.new(c("Thing"))
  it_parses %q(raise a),        Raise.new(Call.new(nil, "a"))
  it_parses %q(raise a.b),      Raise.new(Call.new(Call.new(nil, "a"), "b"))
  it_parses %q(raise 1 + 2),    Raise.new(Call.new(l(1), "+", [l(2)], infix: true))
  it_parses %q(raise %Thing{}), Raise.new(Instantiation.new(c("Thing")))
  it_parses %q(raise <[1, 2]>), Raise.new(i(l([1, 2])))
  it_does_not_parse %q(raise),  /value/

  # The argument to the raise must start on the same line as the keyword
  it_does_not_parse %q(
    raise
      "some error"
  ),                            /value/

  # A Raise is _not_ a normal Call, and thus does not accept multiple parameters or a block.
  it_does_not_parse %q(raise 1, 2)
  it_does_not_parse %q(raise do; end)
  it_does_not_parse %q(raise { |a| })



  # Exception Handling

  # Exceptions can be handled and dealt with by any combination of `rescue` and
  # optionally plus `else` and/or `ensure` clauses.
  # These clauses are only valid when they trail either a Def or Block.
  it_parses %q(
    def foo
    rescue
    end
  ),                Def.new("foo", body: ExceptionHandler.new(Nop.new, [Rescue.new]))
  it_parses %q(def foo; rescue; end), Def.new("foo", body: ExceptionHandler.new(Nop.new, [Rescue.new]))
  # The trailing clauses may contain any valid Expressions node.
  it_parses %q(
    def foo
    rescue
      1 + 2
      a = 1
    end
  ),                Def.new("foo", body: ExceptionHandler.new(Nop.new, [Rescue.new(e(Call.new(l(1), "+", [l(2)], infix: true), SimpleAssign.new(v("a"), l(1))))]))
  it_parses %q(def foo; rescue; a; end), Def.new("foo", body: ExceptionHandler.new(Nop.new, [Rescue.new(e(Call.new(nil, "a")))]))

  # `rescue` can also accept a single Param (with the same syntax as Def) to restrict what Exceptions it can handle.
  it_parses %q(
    def foo
    rescue nil
    end),           Def.new("foo", body: ExceptionHandler.new(Nop.new, [Rescue.new(Nop.new, p(nil, l(nil)))]))
  it_parses %q(
    def foo
    rescue [1, a]
    end
  ),                Def.new("foo", body: ExceptionHandler.new(Nop.new, [Rescue.new(Nop.new, p(nil, l([1, v("a")])))]))
  it_parses %q(
    def foo
    rescue {a: 1, b: b}
    end
  ),                Def.new("foo", body: ExceptionHandler.new(Nop.new, [Rescue.new(Nop.new, p(nil, l({ :a => 1, :b => v("b") })))]))
  # Patterns can also be followed by a name to capture the entire argument.
  it_parses %q(
    def foo
    rescue [1, a] =: b
    end
  ),                Def.new("foo", body: ExceptionHandler.new(Nop.new, [Rescue.new(Nop.new, p("b", l([1, v("a")])))]))
  it_parses %q(
    def foo
    rescue <other> =: _
    end
  ),                Def.new("foo", body: ExceptionHandler.new(Nop.new, [Rescue.new(Nop.new, p("_", i(Call.new(nil, "other"))))]))

  # Splats within patterns are allowed.
  it_parses %q(
    def foo
    rescue [1, *_, 3]
    end
  ),                Def.new("foo", body: ExceptionHandler.new(Nop.new, [Rescue.new(Nop.new, p(nil, l([1, Splat.new(u("_")), 3])))]))

  # Type restrictions can be appended to any parameter to restrict the parameter
  # to an exact type. The type must be a constant.
  it_parses %q(
    def foo
    rescue a : Integer
    end
  ),                Def.new("foo", body: ExceptionHandler.new(Nop.new, [Rescue.new(Nop.new, p("a", restriction: c("Integer")))]))
  it_does_not_parse %q(
    def foo
    rescue a : 123
    end
  )
  it_does_not_parse %q(
    def foo
    rescue a : nil
    end
  )
  it_does_not_parse %q(
    def foo
    rescue a : [1, 2]
    end
  )
  it_does_not_parse %q(
    def foo
    rescue a : b
    end
  )
  it_does_not_parse %q(
    def foo
    rescue a : 1 + 2
    end
  )
  it_does_not_parse %q(
    def foo
    rescue a : <thing>
    end
  )
  it_does_not_parse %q(
    def foo
    rescue a : (A + B)
    end
  )
  # Simple patterns
  it_parses %q(
    def foo
    rescue 1 : Integer
    end
  ),                Def.new("foo", body: ExceptionHandler.new(Nop.new, [Rescue.new(Nop.new, p(nil, l(1), restriction: c("Integer")))]))
  it_parses %q(
    def foo
    rescue nil : Integer
    end
  ),                Def.new("foo", body: ExceptionHandler.new(Nop.new, [Rescue.new(Nop.new, p(nil, l(nil), restriction: c("Integer")))]))
  it_parses %q(
    def foo
    rescue <call> : Integer
    end
  ),                Def.new("foo", body: ExceptionHandler.new(Nop.new, [Rescue.new(Nop.new, p(nil, i(Call.new(nil, "call")), restriction: c("Integer")))]))
  it_parses %q(
    def foo
    rescue <a.b> : Integer
    end
  ),                Def.new("foo", body: ExceptionHandler.new(Nop.new, [Rescue.new(Nop.new, p(nil, i(Call.new(Call.new(nil, "a"), "b")), restriction: c("Integer")))]))
  it_parses %q(
    def foo
    rescue <a[0]> : Integer
    end
  ),                Def.new("foo", body: ExceptionHandler.new(Nop.new, [Rescue.new(Nop.new, p(nil, i(Call.new(Call.new(nil, "a"), "[]", [l(0)])), restriction: c("Integer")))]))
  it_parses %q(
    def foo
    rescue [1, 2] : Integer
    end
  ),                Def.new("foo", body: ExceptionHandler.new(Nop.new, [Rescue.new(Nop.new, p(nil, l([1, 2]), restriction: c("Integer")))]))
  # Patterns and names
  it_parses %q(
    def foo
    rescue 1 =: a : Integer
    end
  ),                Def.new("foo", body: ExceptionHandler.new(Nop.new, [Rescue.new(Nop.new, p("a", l(1), restriction: c("Integer")))]))
  it_parses %q(
    def foo
    rescue 1 =: a : Nil
    end
  ),                Def.new("foo", body: ExceptionHandler.new(Nop.new, [Rescue.new(Nop.new, p("a", l(1), restriction: c("Nil")))]))
  it_parses %q(
    def foo
    rescue 1 =: a : Thing
    end
  ),                Def.new("foo", body: ExceptionHandler.new(Nop.new, [Rescue.new(Nop.new, p("a", l(1), restriction: c("Thing")))]))
  it_parses %q(
    def foo
    rescue nil =: a : Integer
    end
  ),                Def.new("foo", body: ExceptionHandler.new(Nop.new, [Rescue.new(Nop.new, p("a", l(nil), restriction: c("Integer")))]))
  it_parses %q(
    def foo
    rescue nil =: a : Nil
    end
  ),                Def.new("foo", body: ExceptionHandler.new(Nop.new, [Rescue.new(Nop.new, p("a", l(nil), restriction: c("Nil")))]))
  it_parses %q(
    def foo
    rescue nil =: a : Thing
    end
  ),                Def.new("foo", body: ExceptionHandler.new(Nop.new, [Rescue.new(Nop.new, p("a", l(nil), restriction: c("Thing")))]))
  it_parses %q(
    def foo
    rescue <call> =: a : Integer
    end
  ),                Def.new("foo", body: ExceptionHandler.new(Nop.new, [Rescue.new(Nop.new, p("a", i(Call.new(nil, "call")), restriction: c("Integer")))]))
  it_parses %q(
    def foo
    rescue <call> =: a : Nil
    end
  ),                Def.new("foo", body: ExceptionHandler.new(Nop.new, [Rescue.new(Nop.new, p("a", i(Call.new(nil, "call")), restriction: c("Nil")))]))
  it_parses %q(
    def foo
    rescue <call> =: a : Thing
    end
  ),                Def.new("foo", body: ExceptionHandler.new(Nop.new, [Rescue.new(Nop.new, p("a", i(Call.new(nil, "call")), restriction: c("Thing")))]))
  it_parses %q(
    def foo
    rescue <a.b> : Integer
    end
  ),                Def.new("foo", body: ExceptionHandler.new(Nop.new, [Rescue.new(Nop.new, p(nil, i(Call.new(Call.new(nil, "a"), "b")), restriction: c("Integer")))]))
  it_parses %q(
    def foo
    rescue <a.b> : Nil
    end
  ),                Def.new("foo", body: ExceptionHandler.new(Nop.new, [Rescue.new(Nop.new, p(nil, i(Call.new(Call.new(nil, "a"), "b")), restriction: c("Nil")))]))
  it_parses %q(
    def foo
    rescue <a.b> : Thing
    end
  ),                Def.new("foo", body: ExceptionHandler.new(Nop.new, [Rescue.new(Nop.new, p(nil, i(Call.new(Call.new(nil, "a"), "b")), restriction: c("Thing")))]))
  it_parses %q(
    def foo
    rescue <a[0]> : Integer
    end
  ),                Def.new("foo", body: ExceptionHandler.new(Nop.new, [Rescue.new(Nop.new, p(nil, i(Call.new(Call.new(nil, "a"), "[]", [l(0)])), restriction: c("Integer")))]))
  it_parses %q(
    def foo
    rescue <a[0]> : Nil
    end
  ),                Def.new("foo", body: ExceptionHandler.new(Nop.new, [Rescue.new(Nop.new, p(nil, i(Call.new(Call.new(nil, "a"), "[]", [l(0)])), restriction: c("Nil")))]))
  it_parses %q(
    def foo
    rescue <a[0]> : Thing
    end
  ),                Def.new("foo", body: ExceptionHandler.new(Nop.new, [Rescue.new(Nop.new, p(nil, i(Call.new(Call.new(nil, "a"), "[]", [l(0)])), restriction: c("Thing")))]))
  it_parses %q(
    def foo
    rescue [1, 2] =: a : Integer
    end
  ),                Def.new("foo", body: ExceptionHandler.new(Nop.new, [Rescue.new(Nop.new, p("a", l([1, 2]), restriction: c("Integer")))]))
  it_parses %q(
    def foo
    rescue [1, 2] =: a : Nil
    end
  ),                Def.new("foo", body: ExceptionHandler.new(Nop.new, [Rescue.new(Nop.new, p("a", l([1, 2]), restriction: c("Nil")))]))
  it_parses %q(
    def foo
    rescue [1, 2] =: a : Thing
    end
  ),                Def.new("foo", body: ExceptionHandler.new(Nop.new, [Rescue.new(Nop.new, p("a", l([1, 2]), restriction: c("Thing")))]))
  # Only the top level parameters may have retrictions.
  it_does_not_parse %q(
    def foo
    rescue [1, a : List]
    end
  )
  it_does_not_parse %q(
    def foo
    rescue [1, _ : List]
    end
  )
  it_does_not_parse %q(
    def foo
    rescue [1, [a, b] : List]
    end
  )
  it_does_not_parse %q(
    def foo
    rescue [1, a : List] =: c
    end
  )
  it_does_not_parse %q(
    def foo
    rescue [1, _ : List] =: c
    end
  )
  it_does_not_parse %q(
    def foo
    rescue [1, [a, b] : List] =: c
    end
  )
  # Block and Splat parameters may not have restrictions
  it_does_not_parse %q(
    def foo
    rescue *a : List
    end
  )
  it_does_not_parse %q(
    def foo
    rescue &block : Block
    end
  )
  # All components of a parameter must appear inline with the previous component
  it_does_not_parse %q(
    def foo
    rescue a :
                List
    end
  )
  it_does_not_parse %q(
    def foo
    rescue a
              : List
    end
  )
  it_does_not_parse %q(
    def foo
    rescue <(1+2)> =:
                        a
    end
  )
  it_does_not_parse %q(
    def foo
    rescue <(1+2)>
                    =: a
    end
  )
  # Individual components of a parameter _may_ span multiple lines, but should
  # avoid it where possible.
  it_parses %q(
    def foo
    rescue <(1 +
                  2)> =: a : Integer
    end
  ),                                    Def.new("foo", body: ExceptionHandler.new(Nop.new, [Rescue.new(Nop.new, p("a", i(Call.new(l(1), "+", [l(2)], infix: true)), restriction: c("Integer")))]))


  # Multiple `rescue` clauses can be specified.
  it_parses %q(
    def foo
    rescue
    rescue
    end
  ),                Def.new("foo", body: ExceptionHandler.new(Nop.new, [Rescue.new, Rescue.new]))

  it_parses %q(
    def foo
    rescue Error1
    rescue Error2
    end
  ),                Def.new("foo", body: ExceptionHandler.new(Nop.new, [Rescue.new(Nop.new, p(nil, c("Error1"))), Rescue.new(Nop.new, p(nil, c("Error2")))]))

  it_parses %q(
    def foo
    rescue {msg: msg} : Error
    rescue Error2
    rescue
    end
  ),                Def.new("foo", body: ExceptionHandler.new(Nop.new, [Rescue.new(Nop.new, p(nil, l({:msg => v("msg")}), restriction: c("Error"))), Rescue.new(Nop.new, p(nil, c("Error2"))), Rescue.new]))

  # `ensure` can be used on its own or after a `rescue`.
  it_parses %q(
    def foo
    ensure
    end
  ),                Def.new("foo", body: ExceptionHandler.new(Nop.new, ensure: Nop.new))
  it_parses %q(
    def foo
    rescue
    ensure
    end
  ),                Def.new("foo", body: ExceptionHandler.new(Nop.new, [Rescue.new], ensure: Nop.new))

  # `ensure` _must_ be the last clause of an ExceptionHandler.
  it_does_not_parse %q(
    def foo
    ensure
    rescue
    end
  ),                /ensure/
  it_does_not_parse %q(
    def foo
    rescue
    ensure
    rescue
    end
  ),                /ensure/
  # Only 1 `ensure` clause may be given
  it_does_not_parse %q(
    def foo
    ensure
    ensure
    end
  ),                /ensure/

  # `ensure` does not take any arguments
  it_does_not_parse %q(
    def foo
    ensure x
    end
  )
  it_does_not_parse %q(
    def foo
    ensure [1, 2] =: a
    end
  )
  it_does_not_parse %q(
    def foo
    ensure ex : Exception
    end
  )

  # All forms of exception handling are also valid on Blocks defined with the `do...end` syntax.
  it_parses %q(
    each do
    rescue
    end
  ),                Call.new(nil, "each", block: Block.new(body: ExceptionHandler.new(Nop.new, [Rescue.new])))
  it_parses %q(each do; rescue; end), Call.new(nil, "each", block: Block.new(body: ExceptionHandler.new(Nop.new, [Rescue.new])))
  # The trailing clauses may contain any valid Expressions node.
  it_parses %q(
    each do
    rescue
      1 + 2
      a = 1
    end
  ),                Call.new(nil, "each", block: Block.new(body: ExceptionHandler.new(Nop.new, [Rescue.new(e(Call.new(l(1), "+", [l(2)], infix: true), SimpleAssign.new(v("a"), l(1))))])))
  it_parses %q(each do; rescue; a; end), Call.new(nil, "each", block: Block.new(body: ExceptionHandler.new(Nop.new, [Rescue.new(e(Call.new(nil, "a")))])))

  # `rescue` can also accept a single Param (with the same syntax as Def) to restrict what Exceptions it can handle.
  it_parses %q(
    each do
    rescue nil
    end),           Call.new(nil, "each", block: Block.new(body: ExceptionHandler.new(Nop.new, [Rescue.new(Nop.new, p(nil, l(nil)))])))
  it_parses %q(
    each do
    rescue [1, a]
    end
  ),                Call.new(nil, "each", block: Block.new(body: ExceptionHandler.new(Nop.new, [Rescue.new(Nop.new, p(nil, l([1, v("a")])))])))
  it_parses %q(
    each do
    rescue {a: 1, b: b}
    end
  ),                Call.new(nil, "each", block: Block.new(body: ExceptionHandler.new(Nop.new, [Rescue.new(Nop.new, p(nil, l({ :a => 1, :b => v("b") })))])))
  # Patterns can also be followed by a name to capture the entire argument.
  it_parses %q(
    each do
    rescue [1, a] =: b
    end
  ),                Call.new(nil, "each", block: Block.new(body: ExceptionHandler.new(Nop.new, [Rescue.new(Nop.new, p("b", l([1, v("a")])))])))
  it_parses %q(
    each do
    rescue <other> =: _
    end
  ),                Call.new(nil, "each", block: Block.new(body: ExceptionHandler.new(Nop.new, [Rescue.new(Nop.new, p("_", i(Call.new(nil, "other"))))])))

  # Splats within patterns are allowed.
  it_parses %q(
    each do
    rescue [1, *_, 3]
    end
  ),                Call.new(nil, "each", block: Block.new(body: ExceptionHandler.new(Nop.new, [Rescue.new(Nop.new, p(nil, l([1, Splat.new(u("_")), 3])))])))

  # Type restrictions can be appended to any parameter to restrict the parameter
  # to an exact type. The type must be a constant.
  it_parses %q(
    each do
    rescue a : Integer
    end
  ),                Call.new(nil, "each", block: Block.new(body: ExceptionHandler.new(Nop.new, [Rescue.new(Nop.new, p("a", restriction: c("Integer")))])))
  it_does_not_parse %q(
    each do
    rescue a : 123
    end
  )
  it_does_not_parse %q(
    each do
    rescue a : nil
    end
  )
  it_does_not_parse %q(
    each do
    rescue a : [1, 2]
    end
  )
  it_does_not_parse %q(
    each do
    rescue a : b
    end
  )
  it_does_not_parse %q(
    each do
    rescue a : 1 + 2
    end
  )
  it_does_not_parse %q(
    each do
    rescue a : <thing>
    end
  )
  it_does_not_parse %q(
    each do
    rescue a : (A + B)
    end
  )
  # Simple patterns
  it_parses %q(
    each do
    rescue 1 : Integer
    end
  ),                Call.new(nil, "each", block: Block.new(body: ExceptionHandler.new(Nop.new, [Rescue.new(Nop.new, p(nil, l(1), restriction: c("Integer")))])))
  it_parses %q(
    each do
    rescue nil : Integer
    end
  ),                Call.new(nil, "each", block: Block.new(body: ExceptionHandler.new(Nop.new, [Rescue.new(Nop.new, p(nil, l(nil), restriction: c("Integer")))])))
  it_parses %q(
    each do
    rescue <call> : Integer
    end
  ),                Call.new(nil, "each", block: Block.new(body: ExceptionHandler.new(Nop.new, [Rescue.new(Nop.new, p(nil, i(Call.new(nil, "call")), restriction: c("Integer")))])))
  it_parses %q(
    each do
    rescue <a.b> : Integer
    end
  ),                Call.new(nil, "each", block: Block.new(body: ExceptionHandler.new(Nop.new, [Rescue.new(Nop.new, p(nil, i(Call.new(Call.new(nil, "a"), "b")), restriction: c("Integer")))])))
  it_parses %q(
    each do
    rescue <a[0]> : Integer
    end
  ),                Call.new(nil, "each", block: Block.new(body: ExceptionHandler.new(Nop.new, [Rescue.new(Nop.new, p(nil, i(Call.new(Call.new(nil, "a"), "[]", [l(0)])), restriction: c("Integer")))])))
  it_parses %q(
    each do
    rescue [1, 2] : Integer
    end
  ),                Call.new(nil, "each", block: Block.new(body: ExceptionHandler.new(Nop.new, [Rescue.new(Nop.new, p(nil, l([1, 2]), restriction: c("Integer")))])))
  # Patterns and names
  it_parses %q(
    each do
    rescue 1 =: a : Integer
    end
  ),                Call.new(nil, "each", block: Block.new(body: ExceptionHandler.new(Nop.new, [Rescue.new(Nop.new, p("a", l(1), restriction: c("Integer")))])))
  it_parses %q(
    each do
    rescue 1 =: a : Nil
    end
  ),                Call.new(nil, "each", block: Block.new(body: ExceptionHandler.new(Nop.new, [Rescue.new(Nop.new, p("a", l(1), restriction: c("Nil")))])))
  it_parses %q(
    each do
    rescue 1 =: a : Thing
    end
  ),                Call.new(nil, "each", block: Block.new(body: ExceptionHandler.new(Nop.new, [Rescue.new(Nop.new, p("a", l(1), restriction: c("Thing")))])))
  it_parses %q(
    each do
    rescue nil =: a : Integer
    end
  ),                Call.new(nil, "each", block: Block.new(body: ExceptionHandler.new(Nop.new, [Rescue.new(Nop.new, p("a", l(nil), restriction: c("Integer")))])))
  it_parses %q(
    each do
    rescue nil =: a : Nil
    end
  ),                Call.new(nil, "each", block: Block.new(body: ExceptionHandler.new(Nop.new, [Rescue.new(Nop.new, p("a", l(nil), restriction: c("Nil")))])))
  it_parses %q(
    each do
    rescue nil =: a : Thing
    end
  ),                Call.new(nil, "each", block: Block.new(body: ExceptionHandler.new(Nop.new, [Rescue.new(Nop.new, p("a", l(nil), restriction: c("Thing")))])))
  it_parses %q(
    each do
    rescue <call> =: a : Integer
    end
  ),                Call.new(nil, "each", block: Block.new(body: ExceptionHandler.new(Nop.new, [Rescue.new(Nop.new, p("a", i(Call.new(nil, "call")), restriction: c("Integer")))])))
  it_parses %q(
    each do
    rescue <call> =: a : Nil
    end
  ),                Call.new(nil, "each", block: Block.new(body: ExceptionHandler.new(Nop.new, [Rescue.new(Nop.new, p("a", i(Call.new(nil, "call")), restriction: c("Nil")))])))
  it_parses %q(
    each do
    rescue <call> =: a : Thing
    end
  ),                Call.new(nil, "each", block: Block.new(body: ExceptionHandler.new(Nop.new, [Rescue.new(Nop.new, p("a", i(Call.new(nil, "call")), restriction: c("Thing")))])))
  it_parses %q(
    each do
    rescue <a.b> : Integer
    end
  ),                Call.new(nil, "each", block: Block.new(body: ExceptionHandler.new(Nop.new, [Rescue.new(Nop.new, p(nil, i(Call.new(Call.new(nil, "a"), "b")), restriction: c("Integer")))])))
  it_parses %q(
    each do
    rescue <a.b> : Nil
    end
  ),                Call.new(nil, "each", block: Block.new(body: ExceptionHandler.new(Nop.new, [Rescue.new(Nop.new, p(nil, i(Call.new(Call.new(nil, "a"), "b")), restriction: c("Nil")))])))
  it_parses %q(
    each do
    rescue <a.b> : Thing
    end
  ),                Call.new(nil, "each", block: Block.new(body: ExceptionHandler.new(Nop.new, [Rescue.new(Nop.new, p(nil, i(Call.new(Call.new(nil, "a"), "b")), restriction: c("Thing")))])))
  it_parses %q(
    each do
    rescue <a[0]> : Integer
    end
  ),                Call.new(nil, "each", block: Block.new(body: ExceptionHandler.new(Nop.new, [Rescue.new(Nop.new, p(nil, i(Call.new(Call.new(nil, "a"), "[]", [l(0)])), restriction: c("Integer")))])))
  it_parses %q(
    each do
    rescue <a[0]> : Nil
    end
  ),                Call.new(nil, "each", block: Block.new(body: ExceptionHandler.new(Nop.new, [Rescue.new(Nop.new, p(nil, i(Call.new(Call.new(nil, "a"), "[]", [l(0)])), restriction: c("Nil")))])))
  it_parses %q(
    each do
    rescue <a[0]> : Thing
    end
  ),                Call.new(nil, "each", block: Block.new(body: ExceptionHandler.new(Nop.new, [Rescue.new(Nop.new, p(nil, i(Call.new(Call.new(nil, "a"), "[]", [l(0)])), restriction: c("Thing")))])))
  it_parses %q(
    each do
    rescue [1, 2] =: a : Integer
    end
  ),                Call.new(nil, "each", block: Block.new(body: ExceptionHandler.new(Nop.new, [Rescue.new(Nop.new, p("a", l([1, 2]), restriction: c("Integer")))])))
  it_parses %q(
    each do
    rescue [1, 2] =: a : Nil
    end
  ),                Call.new(nil, "each", block: Block.new(body: ExceptionHandler.new(Nop.new, [Rescue.new(Nop.new, p("a", l([1, 2]), restriction: c("Nil")))])))
  it_parses %q(
    each do
    rescue [1, 2] =: a : Thing
    end
  ),                Call.new(nil, "each", block: Block.new(body: ExceptionHandler.new(Nop.new, [Rescue.new(Nop.new, p("a", l([1, 2]), restriction: c("Thing")))])))
  # Only the top level parameters may have retrictions.
  it_does_not_parse %q(
    each do
    rescue [1, a : List]
    end
  )
  it_does_not_parse %q(
    each do
    rescue [1, _ : List]
    end
  )
  it_does_not_parse %q(
    each do
    rescue [1, [a, b] : List]
    end
  )
  it_does_not_parse %q(
    each do
    rescue [1, a : List] =: c
    end
  )
  it_does_not_parse %q(
    each do
    rescue [1, _ : List] =: c
    end
  )
  it_does_not_parse %q(
    each do
    rescue [1, [a, b] : List] =: c
    end
  )
  # Block and Splat parameters may not have restrictions
  it_does_not_parse %q(
    each do
    rescue *a : List
    end
  )
  it_does_not_parse %q(
    each do
    rescue &block : Block
    end
  )
  # All components of a parameter must appear inline with the previous component
  it_does_not_parse %q(
    each do
    rescue a :
                List
    end
  )
  it_does_not_parse %q(
    each do
    rescue a
              : List
    end
  )
  it_does_not_parse %q(
    each do
    rescue <(1+2)> =:
                        a
    end
  )
  it_does_not_parse %q(
    each do
    rescue <(1+2)>
                    =: a
    end
  )
  # Individual components of a parameter _may_ span multiple lines, but should
  # avoid it where possible.
  it_parses %q(
    each do
    rescue <(1 +
                  2)> =: a : Integer
    end
  ),                                    Call.new(nil, "each", block: Block.new(body: ExceptionHandler.new(Nop.new, [Rescue.new(Nop.new, p("a", i(Call.new(l(1), "+", [l(2)], infix: true)), restriction: c("Integer")))])))


  # Multiple `rescue` clauses can be specified.
  it_parses %q(
    each do
    rescue
    rescue
    end
  ),                Call.new(nil, "each", block: Block.new(body: ExceptionHandler.new(Nop.new, [Rescue.new, Rescue.new])))

  it_parses %q(
    each do
    rescue Error1
    rescue Error2
    end
  ),                Call.new(nil, "each", block: Block.new(body: ExceptionHandler.new(Nop.new, [Rescue.new(Nop.new, p(nil, c("Error1"))), Rescue.new(Nop.new, p(nil, c("Error2")))])))

  it_parses %q(
    each do
    rescue {msg: msg} : Error
    rescue Error2
    rescue
    end
  ),                Call.new(nil, "each", block: Block.new(body: ExceptionHandler.new(Nop.new, [Rescue.new(Nop.new, p(nil, l({:msg => v("msg")}), restriction: c("Error"))), Rescue.new(Nop.new, p(nil, c("Error2"))), Rescue.new])))

  # `ensure` can be used on its own or after a `rescue`.
  it_parses %q(
    each do
    ensure
    end
  ),                Call.new(nil, "each", block: Block.new(body: ExceptionHandler.new(Nop.new, ensure: Nop.new)))
  it_parses %q(
    each do
    rescue
    ensure
    end
  ),                Call.new(nil, "each", block: Block.new(body: ExceptionHandler.new(Nop.new, [Rescue.new], ensure: Nop.new)))

  # `ensure` _must_ be the last clause of an ExceptionHandler.
  it_does_not_parse %q(
    each do
    ensure
    rescue
    end
  ),                /ensure/
  it_does_not_parse %q(
    each do
    rescue
    ensure
    rescue
    end
  ),                /ensure/
  # Only 1 `ensure` clause may be given
  it_does_not_parse %q(
    each do
    ensure
    ensure
    end
  ),                /ensure/

  # `ensure` does not take any arguments
  it_does_not_parse %q(
    each do
    ensure x
    end
  )
  it_does_not_parse %q(
    each do
    ensure [1, 2] =: a
    end
  )
  it_does_not_parse %q(
    each do
    ensure ex : Exception
    end
  )

  # Blocks using the brace syntax do _not_ allow for exception handling.
  it_does_not_parse %q(
    each {
    rescue
      # woops
    }
  )

  it_does_not_parse %q(
    each {
    ensure
      # still wrong
    }
  )



  # Anonymous functions

  # Anonymous functions are shorthand wrappers for multi-clause functions with no name. They
  # are created with an `fn ... end` block, where each clause is indicated by a "stab" (`->`),
  # followed by parenthesized parameters (even when no parameters are given), and then a block
  # for the body (either brace-block or do-end-block style).
  it_parses %q(
    fn
      ->() { }
    end
  ),                          AnonymousFunction.new([Block.new])
  it_parses %q(
    fn
      ->() do
      end
    end
  ),                          AnonymousFunction.new([Block.new(style: :doend)])

  it_parses %q(
    fn
      ->(a, b) { a + b }
    end
  ),                          AnonymousFunction.new([Block.new([p("a"), p("b")], e(Call.new(v("a"), "+", [v("b")] of Node)))])
  it_parses %q(
    fn
      ->(a, b) do
        a + b
      end
    end
  ),                          AnonymousFunction.new([Block.new([p("a"), p("b")], e(Call.new(v("a"), "+", [v("b")] of Node)), style: :doend)])

  it_parses %q(
    fn
      ->(1, :hi) { true || false }
    end
  ),                          AnonymousFunction.new([Block.new([p(nil, l(1)), p(nil, l(:hi))], e(Or.new(l(true), l(false))))])

  # Like regular functions, anonymous functions can set type restrictions on their parameters
  it_parses %q(
    fn
      ->(a : Integer) { }
      ->(a : Float) { }
    end
  ),                          AnonymousFunction.new([Block.new([p("a", restriction: c("Integer"))]), Block.new([p("a", restriction: c("Float"))])])

  # They can also specify return types after the parenthesis that closes the parameters.
  it_parses %q(
    fn
      ->(a) : A.B { }
      ->(a) : Foo { }
    end
  ),                          AnonymousFunction.new([Block.new([p("a")], return_type: Call.new(c("A"), "B")), Block.new([p("a")], return_type: c("Foo"))])
it_parses %q(
    fn
      ->(a) : Foo | Nil { }
    end
  ),                          AnonymousFunction.new([Block.new([p("a")], return_type: tu(c("Foo"), c("Nil")))])



  # Exception handling is not allowed with {... } syntax, only with do... end
  it_does_not_parse %q(
    fn
      ->() {
        raise :error
      rescue
          :rescued
      }
    end
  )

  # Expection handling in anonymous functions with do... end syntax is allowed
  it_parses %q(
    fn
      ->() do
        raise :error
      rescue
        :rescue
      end

      ->(n : Integer) do
        :success
      end

      ->(3) { :got_3 }
    end
  ), AnonymousFunction.new([
       Block.new(body: ExceptionHandler.new(Raise.new(l(:error)), [Rescue.new(l(:rescue))])),
       Block.new([p("n", restriction: c("Integer"))], l(:success)),
       Block.new([p(nil, l(3))], l(:got_3))
     ])

  # The bodies of each clause may contain multiple expressions
  it_parses %q(
    fn
      ->(1, :hi) { 1 + 1; 2 + 2; }
    end
  ),                        AnonymousFunction.new([Block.new([p(nil, l(1)), p(nil, l(:hi))], e(Call.new(l(1), "+", [l(1)]), Call.new(l(2), "+", [l(2)])))])
  it_parses %q(
    fn
      ->(1, :hi) do
        1 + 1
        2 + 2
      end
    end
  ),                        AnonymousFunction.new([Block.new([p(nil, l(1)), p(nil, l(:hi))], e(Call.new(l(1), "+", [l(1)]), Call.new(l(2), "+", [l(2)])), style: :doend)])

  # Multiple clauses can be given in a row.
  it_parses %q(
    fn
      ->(a) { }
      ->(b) { }
    end
  ),                        AnonymousFunction.new([Block.new([p("a")]), Block.new([p("b")])])

  # Blank lines between clauses are also allowed
  it_parses %q(
    fn
      ->(a) { }


      ->(b) { }
    end
  ),                        AnonymousFunction.new([Block.new([p("a")]), Block.new([p("b")])])

  # Bracing styles can be mixed in the same definition.
  it_parses %q(
    fn
      ->() { }
      ->() do
      end
    end
  ),                        AnonymousFunction.new([Block.new, Block.new(style: :doend)])

  # The parameter syntax is just like normal functions. Pattern matching and all.
  it_parses %q(
    fn
      ->([a, *_, b] =: p, &block) { }
    end
  ),                       AnonymousFunction.new([Block.new([p("p", l([v("a"), Splat.new(u("_")), v("b")])), p("block", block: true)])])

  # Anonymous functions can be compacted to a single line if desired. This syntax
  # is generally unnecessary, since the normal block syntax is clearner and
  # shorter for single clauses anyway.
  it_parses %q(fn ->()  {}    end), AnonymousFunction.new([Block.new])
  it_parses %q(fn ->(a) { 1 } end), AnonymousFunction.new([Block.new([p("a")], e(l(1)))])

  # It is invalid for an anonymous function to contain less than 1 clause.
  it_does_not_parse %q(fn end),   /no clause/
  it_does_not_parse %q(
    fn
    end
  ),                              /no clause/

  # All clauses must include parentheses, even if no parameters are given
  it_does_not_parse %q(
    fn
      -> {}
    end
  )
  it_does_not_parse %q(
    fn
      -> do
      end
    end
  )

  # The parentheses for a clause must start on the same line as the stab, but are
  # allowed to span multiple lines.
  it_does_not_parse %q(
    fn
      ->
        () { }
    end
  )

  it_parses %q(
    fn
      ->(
        a,
        c
      ) { }
    end
  ),              AnonymousFunction.new([Block.new([p("a"), p("b")])])

  # Similarly, the start of the block must appear on the same line as the closing
  # parenthesis of the parameter list.
  it_does_not_parse %q(
    fn
      -> ()
        { }
    end
  )
  it_does_not_parse %q(
    fn
      -> ()
        do
      end
    end
  )

  # All clauses must have their bodies wrapped with a bracing construct, even for
  # single-expression bodies.
  it_does_not_parse %q(
    fn
      ->(a) a + 1
    end
  )
  it_does_not_parse %q(
    fn
      ->(1) { 1 }
      ->(a) a + 1
    end
  )

  ##
  # Exception handling on anonymous functions
  #
  it_parses %q(
    fn ->() do
      rescue
      end
    end
  ),                AnonymousFunction.new([Block.new(body: ExceptionHandler.new(Nop.new, [Rescue.new]))])
  # The trailing clauses may contain any valid Expressions node.
  it_parses %q(
    fn ->() do
      rescue
        1 + 2
        a = 1
      end
    end
  ),                AnonymousFunction.new([Block.new(body: ExceptionHandler.new(Nop.new, [Rescue.new(e(Call.new(l(1), "+", [l(2)], infix: true), SimpleAssign.new(v("a"), l(1))))]))])
  it_parses %q(
  fn
    ->() do rescue; a; end
  end
  ),                AnonymousFunction.new([Block.new(body: ExceptionHandler.new(Nop.new, [Rescue.new(e(Call.new(nil, "a")))]))])

  # `rescue` can also accept a single Param (with the same syntax as Def) to restrict what Exceptions it can handle.
  it_parses %q(
    fn ->() do
      rescue nil
      end
    end
  ),                AnonymousFunction.new([Block.new(body: ExceptionHandler.new(Nop.new, [Rescue.new(Nop.new, p(nil, l(nil)))]))])
  it_parses %q(
    fn ->() do
      rescue [1, a]
      end
    end
  ),                AnonymousFunction.new([Block.new(body: ExceptionHandler.new(Nop.new, [Rescue.new(Nop.new, p(nil, l([1, v("a")])))]))])
  it_parses %q(
    fn ->() do
      rescue {a: 1, b: b}
      end
    end
  ),                AnonymousFunction.new([Block.new(body: ExceptionHandler.new(Nop.new, [Rescue.new(Nop.new, p(nil, l({ :a => 1, :b => v("b") })))]))])
  # Patterns can also be followed by a name to capture the entire argument.
  it_parses %q(
    fn ->() do
      rescue [1, a] =: b
      end
    end
  ),                AnonymousFunction.new([Block.new(body: ExceptionHandler.new(Nop.new, [Rescue.new(Nop.new, p("b", l([1, v("a")])))]))])
  it_parses %q(
    fn ->() do
      rescue <other> =: _
      end
    end
  ),                AnonymousFunction.new([Block.new(body: ExceptionHandler.new(Nop.new, [Rescue.new(Nop.new, p("_", i(Call.new(nil, "other"))))]))])

  # Splats within patterns are allowed.
  it_parses %q(
    fn ->() do
      rescue [1, *_, 3]
      end
    end
  ),                AnonymousFunction.new([Block.new(body: ExceptionHandler.new(Nop.new, [Rescue.new(Nop.new, p(nil, l([1, Splat.new(u("_")), 3])))]))])

  # Type restrictions can be appended to any parameter to restrict the parameter
  # to an exact type. The type must be a constant.
  it_parses %q(
    fn ->() do
      rescue a : Integer
      end
    end
  ),                AnonymousFunction.new([Block.new(body: ExceptionHandler.new(Nop.new, [Rescue.new(Nop.new, p("a", restriction: c("Integer")))]))])
  it_does_not_parse %q(
    fn ->() do
      rescue a : 123
      end
    end
  )
  it_does_not_parse %q(
    fn ->() do
      rescue a : nil
      end
    end
  )
  it_does_not_parse %q(
    fn ->() do
      rescue a : [1, 2]
      end
    end
  )
  it_does_not_parse %q(
    fn ->() do
      rescue a : b
      end
    end
  )
  it_does_not_parse %q(
    fn ->() do
      rescue a : 1 + 2
      end
    end
  )
  it_does_not_parse %q(
    fn ->() do
      rescue a : <thing>
      end
    end
  )
  it_does_not_parse %q(
    fn ->() do
      rescue a : (A + B)
      end
    end
  )
  # Simple patterns
  it_parses %q(
    fn ->() do
      rescue 1 : Integer
      end
    end
  ),                AnonymousFunction.new([Block.new(body: ExceptionHandler.new(Nop.new, [Rescue.new(Nop.new, p(nil, l(1), restriction: c("Integer")))]))])
  it_parses %q(
    fn ->() do
      rescue nil : Integer
      end
    end
  ),                AnonymousFunction.new([Block.new(body: ExceptionHandler.new(Nop.new, [Rescue.new(Nop.new, p(nil, l(nil), restriction: c("Integer")))]))])
  it_parses %q(
    fn ->() do
      rescue <call> : Integer
      end
    end
  ),                AnonymousFunction.new([Block.new(body: ExceptionHandler.new(Nop.new, [Rescue.new(Nop.new, p(nil, i(Call.new(nil, "call")), restriction: c("Integer")))]))])
  it_parses %q(
    fn ->() do
      rescue <a.b> : Integer
      end
    end
  ),                AnonymousFunction.new([Block.new(body: ExceptionHandler.new(Nop.new, [Rescue.new(Nop.new, p(nil, i(Call.new(Call.new(nil, "a"), "b")), restriction: c("Integer")))]))])
  it_parses %q(
    fn ->() do
      rescue <a[0]> : Integer
      end
    end
  ),                AnonymousFunction.new([Block.new(body: ExceptionHandler.new(Nop.new, [Rescue.new(Nop.new, p(nil, i(Call.new(Call.new(nil, "a"), "[]", [l(0)])), restriction: c("Integer")))]))])
  it_parses %q(
    fn ->() do
      rescue [1, 2] : Integer
      end
    end
  ),                AnonymousFunction.new([Block.new(body: ExceptionHandler.new(Nop.new, [Rescue.new(Nop.new, p(nil, l([1, 2]), restriction: c("Integer")))]))])
  # Patterns and names
  it_parses %q(
    fn ->() do
      rescue 1 =: a : Integer
      end
    end
  ),                AnonymousFunction.new([Block.new(body: ExceptionHandler.new(Nop.new, [Rescue.new(Nop.new, p("a", l(1), restriction: c("Integer")))]))])
  it_parses %q(
    fn ->() do
      rescue 1 =: a : Nil
      end
    end
  ),                AnonymousFunction.new([Block.new(body: ExceptionHandler.new(Nop.new, [Rescue.new(Nop.new, p("a", l(1), restriction: c("Nil")))]))])
  it_parses %q(
    fn ->() do
      rescue 1 =: a : Thing
      end
    end
  ),                AnonymousFunction.new([Block.new(body: ExceptionHandler.new(Nop.new, [Rescue.new(Nop.new, p("a", l(1), restriction: c("Thing")))]))])
  it_parses %q(
    fn ->() do
      rescue nil =: a : Integer
      end
    end
  ),                AnonymousFunction.new([Block.new(body: ExceptionHandler.new(Nop.new, [Rescue.new(Nop.new, p("a", l(nil), restriction: c("Integer")))]))])
  it_parses %q(
    fn ->() do
      rescue nil =: a : Nil
      end
    end
  ),                AnonymousFunction.new([Block.new(body: ExceptionHandler.new(Nop.new, [Rescue.new(Nop.new, p("a", l(nil), restriction: c("Nil")))]))])
  it_parses %q(
    fn ->() do
      rescue nil =: a : Thing
      end
    end
  ),                AnonymousFunction.new([Block.new(body: ExceptionHandler.new(Nop.new, [Rescue.new(Nop.new, p("a", l(nil), restriction: c("Thing")))]))])
  it_parses %q(
    fn ->() do
      rescue <call> =: a : Integer
      end
    end
  ),                AnonymousFunction.new([Block.new(body: ExceptionHandler.new(Nop.new, [Rescue.new(Nop.new, p("a", i(Call.new(nil, "call")), restriction: c("Integer")))]))])
  it_parses %q(
    fn ->() do
      rescue <call> =: a : Nil
      end
    end
  ),                AnonymousFunction.new([Block.new(body: ExceptionHandler.new(Nop.new, [Rescue.new(Nop.new, p("a", i(Call.new(nil, "call")), restriction: c("Nil")))]))])
  it_parses %q(
    fn ->() do
      rescue <call> =: a : Thing
      end
    end
  ),                AnonymousFunction.new([Block.new(body: ExceptionHandler.new(Nop.new, [Rescue.new(Nop.new, p("a", i(Call.new(nil, "call")), restriction: c("Thing")))]))])
  it_parses %q(
    fn ->() do
      rescue <a.b> : Integer
      end
    end
  ),                AnonymousFunction.new([Block.new(body: ExceptionHandler.new(Nop.new, [Rescue.new(Nop.new, p(nil, i(Call.new(Call.new(nil, "a"), "b")), restriction: c("Integer")))]))])
  it_parses %q(
    fn ->() do
      rescue <a.b> : Nil
      end
    end
  ),                AnonymousFunction.new([Block.new(body: ExceptionHandler.new(Nop.new, [Rescue.new(Nop.new, p(nil, i(Call.new(Call.new(nil, "a"), "b")), restriction: c("Nil")))]))])
  it_parses %q(
    fn ->() do
      rescue <a.b> : Thing
      end
    end
  ),                AnonymousFunction.new([Block.new(body: ExceptionHandler.new(Nop.new, [Rescue.new(Nop.new, p(nil, i(Call.new(Call.new(nil, "a"), "b")), restriction: c("Thing")))]))])
  it_parses %q(
    fn ->() do
      rescue <a[0]> : Integer
      end
    end
  ),                AnonymousFunction.new([Block.new(body: ExceptionHandler.new(Nop.new, [Rescue.new(Nop.new, p(nil, i(Call.new(Call.new(nil, "a"), "[]", [l(0)])), restriction: c("Integer")))]))])
  it_parses %q(
    fn ->() do
      rescue <a[0]> : Nil
      end
    end
  ),                AnonymousFunction.new([Block.new(body: ExceptionHandler.new(Nop.new, [Rescue.new(Nop.new, p(nil, i(Call.new(Call.new(nil, "a"), "[]", [l(0)])), restriction: c("Nil")))]))])
  it_parses %q(
    fn ->() do
      rescue <a[0]> : Thing
      end
    end
  ),                AnonymousFunction.new([Block.new(body: ExceptionHandler.new(Nop.new, [Rescue.new(Nop.new, p(nil, i(Call.new(Call.new(nil, "a"), "[]", [l(0)])), restriction: c("Thing")))]))])
  it_parses %q(
    fn ->() do
      rescue [1, 2] =: a : Integer
      end
    end
  ),                AnonymousFunction.new([Block.new(body: ExceptionHandler.new(Nop.new, [Rescue.new(Nop.new, p("a", l([1, 2]), restriction: c("Integer")))]))])
  it_parses %q(
    fn ->() do
      rescue [1, 2] =: a : Nil
      end
    end
  ),                AnonymousFunction.new([Block.new(body: ExceptionHandler.new(Nop.new, [Rescue.new(Nop.new, p("a", l([1, 2]), restriction: c("Nil")))]))])
  it_parses %q(
    fn ->() do
      rescue [1, 2] =: a : Thing
      end
    end
  ),                AnonymousFunction.new([Block.new(body: ExceptionHandler.new(Nop.new, [Rescue.new(Nop.new, p("a", l([1, 2]), restriction: c("Thing")))]))])
  # Only the top level parameters may have retrictions.
  it_does_not_parse %q(
    fn ->() do
      rescue [1, a : List]
      end
    end
  )
  it_does_not_parse %q(
    fn ->() do
      rescue [1, _ : List]
      end
    end
  )
  it_does_not_parse %q(
    fn ->() do
      rescue [1, [a, b] : List]
      end
    end
  )
  it_does_not_parse %q(
    fn ->() do
      rescue [1, a : List] =: c
      end
    end
  )
  it_does_not_parse %q(
    fn ->() do
      rescue [1, _ : List] =: c
      end
    end
  )
  it_does_not_parse %q(
    fn ->() do
      rescue [1, [a, b] : List] =: c
      end
    end
  )
  # Block and Splat parameters may not have restrictions
  it_does_not_parse %q(
    fn ->() do
      rescue *a : List
      end
    end
  )
  it_does_not_parse %q(
    fn ->() do
      rescue &block : Block
      end
    end
  )
  # All components of a parameter must appear inline with the previous component
  it_does_not_parse %q(
    fn ->() do
      rescue a :
                List
      end
    end
  )
  it_does_not_parse %q(
    fn ->() do
      rescue a
              : List
      end
    end
  )
  it_does_not_parse %q(
    fn ->() do
      rescue <(1+2)> =:
                        a
      end
    end
  )
  it_does_not_parse %q(
    fn ->() do
      rescue <(1+2)>
                    =: a
      end
    end
  )
  # Individual components of a parameter _may_ span multiple lines, but should
  # avoid it where possible.
  it_parses %q(
    fn ->() do
      rescue <(1 +
                  2)> =: a : Integer
      end
    end
  ),                AnonymousFunction.new([Block.new(body: ExceptionHandler.new(Nop.new, [Rescue.new(Nop.new, p("a", i(Call.new(l(1), "+", [l(2)], infix: true)), restriction: c("Integer")))]))])


  # Multiple `rescue` clauses can be specified.
  it_parses %q(
    fn ->() do
      rescue
      rescue
      end
    end
  ),                AnonymousFunction.new([Block.new(body: ExceptionHandler.new(Nop.new, [Rescue.new, Rescue.new]))])

  it_parses %q(
    fn ->() do
      rescue Error1
      rescue Error2
      end
    end
  ),                AnonymousFunction.new([Block.new(body: ExceptionHandler.new(Nop.new, [Rescue.new(Nop.new, p(nil, c("Error1"))), Rescue.new(Nop.new, p(nil, c("Error2")))]))])

  it_parses %q(
    fn ->() do
      rescue {msg: msg} : Error
      rescue Error2
      rescue
      end
    end
  ),                AnonymousFunction.new([Block.new(body: ExceptionHandler.new(Nop.new, [Rescue.new(Nop.new, p(nil, l({:msg => v("msg")}), restriction: c("Error"))), Rescue.new(Nop.new, p(nil, c("Error2"))), Rescue.new]))])

  # `ensure` can be used on its own or after a `rescue`.
  it_parses %q(
    fn ->() do
      ensure
      end
    end
  ),                AnonymousFunction.new([Block.new(body: ExceptionHandler.new(Nop.new, ensure: Nop.new))])
  it_parses %q(
    fn ->() do
      rescue
      ensure
      end
    end
  ),                AnonymousFunction.new([Block.new(body: ExceptionHandler.new(Nop.new, [Rescue.new], ensure: Nop.new))])

  # `ensure` _must_ be the last clause of an ExceptionHandler.
  it_does_not_parse %q(
    fn ->() do
      ensure
      rescue
      end
    end
  ),                /ensure/
  it_does_not_parse %q(
    fn ->() do
      rescue
      ensure
      rescue
      end
    end
  ),                /ensure/
  # Only 1 `ensure` clause may be given
  it_does_not_parse %q(
    fn ->() do
      ensure
      ensure
      end
    end
  ),                /ensure/

  # `ensure` does not take any arguments
  it_does_not_parse %q(
    fn ->() do
      ensure x
      end
    end
  )
  it_does_not_parse %q(
    fn ->() do
      ensure [1, 2] =: a
      end
    end
  )
  it_does_not_parse %q(
    fn ->() do
      ensure ex : Exception
      end
    end
  )



  # Function capturing

  # Functions can be captured using an `&` prefix.
  it_parses %q(&foo),               FunctionCapture.new(Call.new(nil, "foo"))
  # The value of a capture can be any primary expression
  it_parses %q(&self.foo),          FunctionCapture.new(Call.new(Self.new, "foo"))
  it_parses %q(&(a || b)),          FunctionCapture.new(Or.new(Call.new(nil, "a"), Call.new(nil, "b")))
  it_parses %q(&callbacks[:start]), FunctionCapture.new(Call.new(Call.new(nil, "callbacks"), "[]", [l(:start)]))
  it_parses %q(&a.b.c),             FunctionCapture.new(Call.new(Call.new(Call.new(nil, "a"), "b"), "c"))

  # Spacing between the ampersand and the expression is allowed, but not newlines.
  it_parses %q(& foo),              FunctionCapture.new(Call.new(nil, "foo"))
  it_does_not_parse %q(
    &
    foo
  )

  # An anonymous function can be the value of a function capture. Other literals
  # are parseable in captures, but will fail in the interpreter.
  it_parses %q(
    &fn
      ->() { }
    end
  ),                                FunctionCapture.new(AnonymousFunction.new([Block.new]))


  # A function capture given as the last argument to a function call will be considered
  # the block argument for the function.
  it_parses %q(foo(1, 2, &bar)),    Call.new(nil, "foo", [l(1), l(2)], block: FunctionCapture.new(Call.new(nil, "bar")))
  it_parses %q(foo(&bar)),          Call.new(nil, "foo", block: FunctionCapture.new(Call.new(nil, "bar")))

  # A function capture given as anything other than the last argument is invalid.
  it_does_not_parse %q(foo(1, &bar, 2))

  # Passing functions as arguments can be achieved by capturing the function in a
  # separate expression
  it_parses %q(
    bar = &baz
    foo(1, bar, 2)
  ),                                SimpleAssign.new(v("bar"), FunctionCapture.new(Call.new(nil, "baz"))), Call.new(nil, "foo", [l(1), v("bar"), l(2)])

  # The most common use case of function capturing is to define multi-clause anonymous
  # functions as the block argument for a Call
  it_parses %q(
    foo(1, 2, &fn
      ->(1) { true }
      ->(2) { false }
    end)
  ),                                Call.new(nil, "foo", [l(1), l(2)], block: FunctionCapture.new(AnonymousFunction.new([Block.new([p(nil, l(1))], body: e(l(true))), Block.new([p(nil, l(2))], body: e(l(false)))])))

  # If a function capture is given as a block argument, an inline block is not allowed.
  it_does_not_parse %q(
    foo(&bar) { }
  ),                /captured function/
  it_does_not_parse %q(
    foo(&bar) do
    end
  ),                /captured function/



  # Match

  # Match expressions are a syntax sugar around creating and invoking an
  # anonymous function immediately. As such, the body of a `match` can be any
  # valid anonymous function body, and the arguments can be any series of
  # inline expressions.
  it_parses %q(
    match 1
      ->() { }
    end
  ),                          Match.new([l(1)], [Block.new])
  it_parses %q(
    match 1
      ->() do
      end
    end
  ),                          Match.new([l(1)], [Block.new(style: :doend)])

  it_parses %q(
    match 1
      ->(a, b) { a + b }
    end
  ),                          Match.new([l(1)], [Block.new([p("a"), p("b")], e(Call.new(v("a"), "+", [v("b")] of Node)))])
  it_parses %q(
    match 1
      ->(a, b) do
        a + b
      end
    end
  ),                          Match.new([l(1)], [Block.new([p("a"), p("b")], e(Call.new(v("a"), "+", [v("b")] of Node)), style: :doend)])

  it_parses %q(
    match 1
      ->(1, :hi) { true || false }
    end
  ),                          Match.new([l(1)], [Block.new([p(nil, l(1)), p(nil, l(:hi))], e(Or.new(l(true), l(false))))])

  # Spacing around the arguments is negligible
  it_parses %q(
    match       1
      ->() { }
    end
  ),                          Match.new([l(1)], [Block.new])

  # Expection handling on matches can be done with the do...end block syntax
  it_parses %q(
    match 1
      ->() do
        raise :error
      rescue
        :rescue
      end

      ->(n : Integer) do
        :success
      end

      ->(3) { :got_3 }
    end
  ), Match.new([l(1)], [
       Block.new(body: ExceptionHandler.new(Raise.new(l(:error)), [Rescue.new(l(:rescue))])),
       Block.new([p("n", restriction: c("Integer"))], l(:success)),
       Block.new([p(nil, l(3))], l(:got_3))
     ])

  # Exception handling is not allowed with {... } syntax
  it_does_not_parse %q(
    match 1
      ->() {
        raise :error
      rescue
          :rescued
      }
    end
  )

  # The bodies of each clause may contain multiple expressions
  it_parses %q(
    match 1
      ->(1, :hi) { 1 + 1; 2 + 2; }
    end
  ),                        Match.new([l(1)], [Block.new([p(nil, l(1)), p(nil, l(:hi))], e(Call.new(l(1), "+", [l(1)]), Call.new(l(2), "+", [l(2)])))])
  it_parses %q(
    match 1
      ->(1, :hi) do
        1 + 1
        2 + 2
      end
    end
  ),                        Match.new([l(1)], [Block.new([p(nil, l(1)), p(nil, l(:hi))], e(Call.new(l(1), "+", [l(1)]), Call.new(l(2), "+", [l(2)])), style: :doend)])

  # Multiple clauses can be given in a row.
  it_parses %q(
    match 1
      ->(a) { }
      ->(b) { }
    end
  ),                        Match.new([l(1)], [Block.new([p("a")]), Block.new([p("b")])])

  # Blank lines between clauses are also allowed
  it_parses %q(
    match 1
      ->(a) { }


      ->(b) { }
    end
  ),                        Match.new([l(1)], [Block.new([p("a")]), Block.new([p("b")])])

  # Bracing styles can be mixed in the same definition.
  it_parses %q(
    match 1
      ->() { }
      ->() do
      end
    end
  ),                        Match.new([l(1)], [Block.new, Block.new(style: :doend)])

  # The parameter syntax is just like normal functions. Pattern matching and all.
  it_parses %q(
    match 1
      ->([a, *_, b] =: p, &block) { }
    end
  ),                       Match.new([l(1)], [Block.new([p("p", l([v("a"), Splat.new(u("_")), v("b")])), p("block", block: true)])])

  # Matches can not be compressed to one line
  it_does_not_parse %q(match 1 ->()  {}    end)
  it_does_not_parse %q(match 1 ->(a) { 1 } end)

  # It is invalid for a match expression to contain less than 1 clause.
  it_does_not_parse %q(
    match 1
    end
  ),                              /no clause/

  # All clauses must include parentheses, even if no parameters are given
  it_does_not_parse %q(
    match 1
      -> {}
    end
  )
  it_does_not_parse %q(
    match 1
      -> do
      end
    end
  )

  # The parentheses for a clause must start on the same line as the stab, but are
  # allowed to span multiple lines.
  it_does_not_parse %q(
    match 1
      ->
        () { }
    end
  )

  it_parses %q(
    match 1
      ->(
        a,
        c
      ) { }
    end
  ),              Match.new([l(1)], [Block.new([p("a"), p("b")])])

  # Similarly, the start of the block must appear on the same line as the closing
  # parenthesis of the parameter list.
  it_does_not_parse %q(
    match 1
      ->()
        { }
    end
  )
  it_does_not_parse %q(
    match 1
      ->()
        do
      end
    end
  )

  # All clauses must have their bodies wrapped with a bracing construct, even for
  # single-expression bodies.
  it_does_not_parse %q(
    match 1
      ->(a) a + 1
    end
  )
  it_does_not_parse %q(
    match 1
      ->(1) { 1 }
      ->(a) a + 1
    end
  )

  # Match arguments can be any valid expression
  it_parses %q(
    match foo(1, 2)
      ->() { }
    end
  ),                Match.new([Call.new(nil, "foo", [l(1), l(2)] of Node)] of Node, [Block.new])
  it_parses %q(
    match 1 + 2
      ->() { }
    end
  ),                Match.new([Call.new(l(1), "+", [l(2)] of Node, infix: true)] of Node, [Block.new])
  it_parses %q(
    match a || b
      ->() { }
    end
  ),                Match.new([Or.new(Call.new(nil, "a"), Call.new(nil, "b"))] of Node, [Block.new])
  it_parses %q(
    match Foo
      ->() { }
    end
  ),                Match.new([c("Foo")] of Node, [Block.new])
  it_parses %q(
    match <:why>
      ->() { }
    end
  ),                Match.new([i(l(:why))] of Node, [Block.new])


  # Matches can be given multiple arguments to match against as a comma-separated list
  it_parses %q(
    match 1, 2, 3
      ->() { }
    end
  ),                Match.new([l(1), l(2), l(3)] of Node, [Block.new([p("a"), p("b"), p("c")], body: e(l(:respect)))])
  it_parses %q(
    match 1 + 2, 2 || 3
      ->() { }
    end
  ),                Match.new([Call.new(l(1), "+", [l(2)] of Node, infix: true), Or.new(l(2), l(3))] of Node, [Block.new])
  # Match arguments can also be splatted into multiple arguments
  it_parses %q(
    match *args
      ->() { }
    end
  ),                Match.new([Splat.new(Call.new(nil, "args"))] of Node, [Block.new])
  it_parses %q(
    match 1, *args, 3
      ->() { }
    end
  ),                Match.new([l(1), Splat.new(Call.new(nil, "args")), l(3)] of Node, [Block.new])


  ##
  # Exception handling on matches
  #
  it_parses %q(
    match 1
      ->() do
      rescue
      end
    end
  ),                Match.new([l(1)] of Node, [Block.new(body: ExceptionHandler.new(Nop.new, [Rescue.new]))])
  # The trailing clauses may contain any valid Expressions node.
  it_parses %q(
    match 1
      ->() do
      rescue
        1 + 2
        a = 1
      end
    end
  ),                Match.new([l(1)] of Node, [Block.new(body: ExceptionHandler.new(Nop.new, [Rescue.new(e(Call.new(l(1), "+", [l(2)], infix: true), SimpleAssign.new(v("a"), l(1))))]))])
  it_parses %q(
    match 1
      ->() do rescue; a; end
    end
  ),                Match.new([l(1)] of Node, [Block.new(body: ExceptionHandler.new(Nop.new, [Rescue.new(e(Call.new(nil, "a")))]))])

  # `rescue` can also accept a single Param (with the same syntax as Def) to restrict what Exceptions it can handle.
  it_parses %q(
    match 1
      ->() do
      rescue nil
      end
    end
  ),                Match.new([l(1)] of Node, [Block.new(body: ExceptionHandler.new(Nop.new, [Rescue.new(Nop.new, p(nil, l(nil)))]))])
  it_parses %q(
    match 1
      ->() do
      rescue [1, a]
      end
    end
  ),                Match.new([l(1)] of Node, [Block.new(body: ExceptionHandler.new(Nop.new, [Rescue.new(Nop.new, p(nil, l([1, v("a")])))]))])
  it_parses %q(
    match 1
      ->() do
      rescue {a: 1, b: b}
      end
    end
  ),                Match.new([l(1)] of Node, [Block.new(body: ExceptionHandler.new(Nop.new, [Rescue.new(Nop.new, p(nil, l({ :a => 1, :b => v("b") })))]))])
  # Patterns can also be followed by a name to capture the entire argument.
  it_parses %q(
    match 1
      ->() do
      rescue [1, a] =: b
      end
    end
  ),                Match.new([l(1)] of Node, [Block.new(body: ExceptionHandler.new(Nop.new, [Rescue.new(Nop.new, p("b", l([1, v("a")])))]))])
  it_parses %q(
    match 1
      ->() do
      rescue <other> =: _
      end
    end
  ),                Match.new([l(1)] of Node, [Block.new(body: ExceptionHandler.new(Nop.new, [Rescue.new(Nop.new, p("_", i(Call.new(nil, "other"))))]))])

  # Splats within patterns are allowed.
  it_parses %q(
    match 1
      ->() do
      rescue [1, *_, 3]
      end
    end
  ),                Match.new([l(1)] of Node, [Block.new(body: ExceptionHandler.new(Nop.new, [Rescue.new(Nop.new, p(nil, l([1, Splat.new(u("_")), 3])))]))])

  # Type restrictions can be appended to any parameter to restrict the parameter
  # to an exact type. The type must be a constant.
  it_parses %q(
    match 1
      ->() do
      rescue a : Integer
      end
    end
  ),                Match.new([l(1)] of Node, [Block.new(body: ExceptionHandler.new(Nop.new, [Rescue.new(Nop.new, p("a", restriction: c("Integer")))]))])
  it_does_not_parse %q(
    match 1
      ->() do
      rescue a : 123
      end
    end
  )
  it_does_not_parse %q(
    match 1
      ->() do
      rescue a : nil
      end
    end
  )
  it_does_not_parse %q(
    match 1
      ->() do
      rescue a : [1, 2]
      end
    end
  )
  it_does_not_parse %q(
    match 1
      ->() do
      rescue a : b
      end
    end
  )
  it_does_not_parse %q(
    match 1
      ->() do
      rescue a : 1 + 2
      end
    end
  )
  it_does_not_parse %q(
    match 1
      ->() do
      rescue a : <thing>
      end
    end
  )
  it_does_not_parse %q(
    match 1
      ->() do
      rescue a : (A + B)
      end
    end
  )
  # Simple patterns
  it_parses %q(
    match 1
      ->() do
      rescue 1 : Integer
      end
    end
  ),                Match.new([l(1)] of Node, [Block.new(body: ExceptionHandler.new(Nop.new, [Rescue.new(Nop.new, p(nil, l(1), restriction: c("Integer")))]))])
  it_parses %q(
    match 1
      ->() do
      rescue nil : Integer
      end
    end
  ),                Match.new([l(1)] of Node, [Block.new(body: ExceptionHandler.new(Nop.new, [Rescue.new(Nop.new, p(nil, l(nil), restriction: c("Integer")))]))])
  it_parses %q(
    match 1
      ->() do
      rescue <call> : Integer
      end
    end
  ),                Match.new([l(1)] of Node, [Block.new(body: ExceptionHandler.new(Nop.new, [Rescue.new(Nop.new, p(nil, i(Call.new(nil, "call")), restriction: c("Integer")))]))])
  it_parses %q(
    match 1
      ->() do
      rescue <a.b> : Integer
      end
    end
  ),                Match.new([l(1)] of Node, [Block.new(body: ExceptionHandler.new(Nop.new, [Rescue.new(Nop.new, p(nil, i(Call.new(Call.new(nil, "a"), "b")), restriction: c("Integer")))]))])
  it_parses %q(
    match 1
      ->() do
      rescue <a[0]> : Integer
      end
    end
  ),                Match.new([l(1)] of Node, [Block.new(body: ExceptionHandler.new(Nop.new, [Rescue.new(Nop.new, p(nil, i(Call.new(Call.new(nil, "a"), "[]", [l(0)])), restriction: c("Integer")))]))])
  it_parses %q(
    match 1
      ->() do
      rescue [1, 2] : Integer
      end
    end
  ),                Match.new([l(1)] of Node, [Block.new(body: ExceptionHandler.new(Nop.new, [Rescue.new(Nop.new, p(nil, l([1, 2]), restriction: c("Integer")))]))])
  # Patterns and names
  it_parses %q(
    match 1
      ->() do
      rescue 1 =: a : Integer
      end
    end
  ),                Match.new([l(1)] of Node, [Block.new(body: ExceptionHandler.new(Nop.new, [Rescue.new(Nop.new, p("a", l(1), restriction: c("Integer")))]))])
  it_parses %q(
    match 1
      ->() do
      rescue 1 =: a : Nil
      end
    end
  ),                Match.new([l(1)] of Node, [Block.new(body: ExceptionHandler.new(Nop.new, [Rescue.new(Nop.new, p("a", l(1), restriction: c("Nil")))]))])
  it_parses %q(
    match 1
      ->() do
      rescue 1 =: a : Thing
      end
    end
  ),                Match.new([l(1)] of Node, [Block.new(body: ExceptionHandler.new(Nop.new, [Rescue.new(Nop.new, p("a", l(1), restriction: c("Thing")))]))])
  it_parses %q(
    match 1
      ->() do
      rescue nil =: a : Integer
      end
    end
  ),                Match.new([l(1)] of Node, [Block.new(body: ExceptionHandler.new(Nop.new, [Rescue.new(Nop.new, p("a", l(nil), restriction: c("Integer")))]))])
  it_parses %q(
    match 1
      ->() do
      rescue nil =: a : Nil
      end
    end
  ),                Match.new([l(1)] of Node, [Block.new(body: ExceptionHandler.new(Nop.new, [Rescue.new(Nop.new, p("a", l(nil), restriction: c("Nil")))]))])
  it_parses %q(
    match 1
      ->() do
      rescue nil =: a : Thing
      end
    end
  ),                Match.new([l(1)] of Node, [Block.new(body: ExceptionHandler.new(Nop.new, [Rescue.new(Nop.new, p("a", l(nil), restriction: c("Thing")))]))])
  it_parses %q(
    match 1
      ->() do
      rescue <call> =: a : Integer
      end
    end
  ),                Match.new([l(1)] of Node, [Block.new(body: ExceptionHandler.new(Nop.new, [Rescue.new(Nop.new, p("a", i(Call.new(nil, "call")), restriction: c("Integer")))]))])
  it_parses %q(
    match 1
      ->() do
      rescue <call> =: a : Nil
      end
    end
  ),                Match.new([l(1)] of Node, [Block.new(body: ExceptionHandler.new(Nop.new, [Rescue.new(Nop.new, p("a", i(Call.new(nil, "call")), restriction: c("Nil")))]))])
  it_parses %q(
    match 1
      ->() do
      rescue <call> =: a : Thing
      end
    end
  ),                Match.new([l(1)] of Node, [Block.new(body: ExceptionHandler.new(Nop.new, [Rescue.new(Nop.new, p("a", i(Call.new(nil, "call")), restriction: c("Thing")))]))])
  it_parses %q(
    match 1
      ->() do
      rescue <a.b> : Integer
      end
    end
  ),                Match.new([l(1)] of Node, [Block.new(body: ExceptionHandler.new(Nop.new, [Rescue.new(Nop.new, p(nil, i(Call.new(Call.new(nil, "a"), "b")), restriction: c("Integer")))]))])
  it_parses %q(
    match 1
      ->() do
      rescue <a.b> : Nil
      end
    end
  ),                Match.new([l(1)] of Node, [Block.new(body: ExceptionHandler.new(Nop.new, [Rescue.new(Nop.new, p(nil, i(Call.new(Call.new(nil, "a"), "b")), restriction: c("Nil")))]))])
  it_parses %q(
    match 1
      ->() do
      rescue <a.b> : Thing
      end
    end
  ),                Match.new([l(1)] of Node, [Block.new(body: ExceptionHandler.new(Nop.new, [Rescue.new(Nop.new, p(nil, i(Call.new(Call.new(nil, "a"), "b")), restriction: c("Thing")))]))])
  it_parses %q(
    match 1
      ->() do
      rescue <a[0]> : Integer
      end
    end
  ),                Match.new([l(1)] of Node, [Block.new(body: ExceptionHandler.new(Nop.new, [Rescue.new(Nop.new, p(nil, i(Call.new(Call.new(nil, "a"), "[]", [l(0)])), restriction: c("Integer")))]))])
  it_parses %q(
    match 1
      ->() do
      rescue <a[0]> : Nil
      end
    end
  ),                Match.new([l(1)] of Node, [Block.new(body: ExceptionHandler.new(Nop.new, [Rescue.new(Nop.new, p(nil, i(Call.new(Call.new(nil, "a"), "[]", [l(0)])), restriction: c("Nil")))]))])
  it_parses %q(
    match 1
      ->() do
      rescue <a[0]> : Thing
      end
    end
  ),                Match.new([l(1)] of Node, [Block.new(body: ExceptionHandler.new(Nop.new, [Rescue.new(Nop.new, p(nil, i(Call.new(Call.new(nil, "a"), "[]", [l(0)])), restriction: c("Thing")))]))])
  it_parses %q(
    match 1
      ->() do
      rescue [1, 2] =: a : Integer
      end
    end
  ),                Match.new([l(1)] of Node, [Block.new(body: ExceptionHandler.new(Nop.new, [Rescue.new(Nop.new, p("a", l([1, 2]), restriction: c("Integer")))]))])
  it_parses %q(
    match 1
      ->() do
      rescue [1, 2] =: a : Nil
      end
    end
  ),                Match.new([l(1)] of Node, [Block.new(body: ExceptionHandler.new(Nop.new, [Rescue.new(Nop.new, p("a", l([1, 2]), restriction: c("Nil")))]))])
  it_parses %q(
    match 1
      ->() do
      rescue [1, 2] =: a : Thing
      end
    end
  ),                Match.new([l(1)] of Node, [Block.new(body: ExceptionHandler.new(Nop.new, [Rescue.new(Nop.new, p("a", l([1, 2]), restriction: c("Thing")))]))])
  # Only the top level parameters may have retrictions.
  it_does_not_parse %q(
    match 1
      ->() do
      rescue [1, a : List]
      end
    end
  )
  it_does_not_parse %q(
    match 1
      ->() do
      rescue [1, _ : List]
      end
    end
  )
  it_does_not_parse %q(
    match 1
      ->() do
      rescue [1, [a, b] : List]
      end
    end
  )
  it_does_not_parse %q(
    match 1
      ->() do
      rescue [1, a : List] =: c
      end
    end
  )
  it_does_not_parse %q(
    match 1
      ->() do
      rescue [1, _ : List] =: c
      end
    end
  )
  it_does_not_parse %q(
    match 1
      ->() do
      rescue [1, [a, b] : List] =: c
      end
    end
  )
  # Block and Splat parameters may not have restrictions
  it_does_not_parse %q(
    match 1
      ->() do
      rescue *a : List
      end
    end
  )
  it_does_not_parse %q(
    match 1
      ->() do
      rescue &block : Block
      end
    end
  )
  # All components of a parameter must appear inline with the previous component
  it_does_not_parse %q(
    match 1
      ->() do
      rescue a :
                List
      end
    end
  )
  it_does_not_parse %q(
    match 1
      ->() do
      rescue a
              : List
      end
    end
  )
  it_does_not_parse %q(
    match 1
      ->() do
      rescue <(1+2)> =:
                        a
      end
    end
  )
  it_does_not_parse %q(
    match 1
      ->() do
      rescue <(1+2)>
                    =: a
      end
    end
  )
  # Individual components of a parameter _may_ span multiple lines, but should
  # avoid it where possible.
  it_parses %q(
    match 1
      ->() do
      rescue <(1 +
                  2)> =: a : Integer
      end
    end
  ),                Match.new([l(1)] of Node, [Block.new(body: ExceptionHandler.new(Nop.new, [Rescue.new(Nop.new, p("a", i(Call.new(l(1), "+", [l(2)], infix: true)), restriction: c("Integer")))]))])


  # Multiple `rescue` clauses can be specified.
  it_parses %q(
    match 1
      ->() do
      rescue
      rescue
      end
    end
  ),                Match.new([l(1)] of Node, [Block.new(body: ExceptionHandler.new(Nop.new, [Rescue.new, Rescue.new]))])

  it_parses %q(
    match 1
      ->() do
      rescue Error1
      rescue Error2
      end
    end
  ),                Match.new([l(1)] of Node, [Block.new(body: ExceptionHandler.new(Nop.new, [Rescue.new(Nop.new, p(nil, c("Error1"))), Rescue.new(Nop.new, p(nil, c("Error2")))]))])

  it_parses %q(
    match 1
      ->() do
      rescue {msg: msg} : Error
      rescue Error2
      rescue
      end
    end
  ),                Match.new([l(1)] of Node, [Block.new(body: ExceptionHandler.new(Nop.new, [Rescue.new(Nop.new, p(nil, l({:msg => v("msg")}), restriction: c("Error"))), Rescue.new(Nop.new, p(nil, c("Error2"))), Rescue.new]))])

  # `ensure` can be used on its own or after a `rescue`.
  it_parses %q(
    match 1
      ->() do
      ensure
      end
    end
  ),                Match.new([l(1)] of Node, [Block.new(body: ExceptionHandler.new(Nop.new, ensure: Nop.new))])
  it_parses %q(
    match 1
      ->() do
      rescue
      ensure
      end
    end
  ),                Match.new([l(1)] of Node, [Block.new(body: ExceptionHandler.new(Nop.new, [Rescue.new], ensure: Nop.new))])

  # `ensure` _must_ be the last clause of an ExceptionHandler.
  it_does_not_parse %q(
    match 1
      ->() do
      ensure
      rescue
      end
    end
  ),                /ensure/
  it_does_not_parse %q(
    match 1
      ->() do
      rescue
      ensure
      rescue
      end
    end
  ),                /ensure/
  # Only 1 `ensure` clause may be given
  it_does_not_parse %q(
    match 1
      ->() do
      ensure
      ensure
      end
    end
  ),                /ensure/

  # `ensure` does not take any arguments
  it_does_not_parse %q(
    match 1
      ->() do
      ensure x
      end
    end
  )
  it_does_not_parse %q(
    match 1
      ->() do
      ensure [1, 2] =: a
      end
    end
  )
  it_does_not_parse %q(
    match 1
      ->() do
      ensure ex : Exception
      end
    end
  )



  # Doc Comments

  # Nodes can be documented with "doc comments" - comments which appear on the
  # lines immediately preceding the node.
  it_parses %q(
    #doc foo
    #| This is a doc comment.
    nil
  ),                            doc("foo", "This is a doc comment.")
  # The header of a doc comment is optional.
  it_parses %q(
    #doc
    #| some documentation
    nil
  ),                            doc("", "some documentation")
  # The content is also optional.
  it_parses %q(
    #doc
    nil
  ),                            doc("")
  # Doc comments with hard newlines will have the newlines replaced with spaces.
  it_parses %q(
    #doc foo
    #| This is a multi-
    #| line doc comment.
    nil
  ),                            doc("foo", "This is a multi- line doc comment.")
  # Two consecutive newlines are chomped down to a single newline.
  it_parses %q(
    #doc foo
    #| This doc has two parts.
    #|
    #| This is the second part.
    nil
  ),                            doc("foo", "This doc has two parts.\nThis is the second part.")
  # Non-doc comments within a doc comment are ignored.
  it_parses %q(
    #doc foo
    #| This doc has a normal
    # ignore me
    #| comment inside it.
    nil
  ),                            doc("foo", "This doc has a normal comment inside it.")
  # Leading blank lines are stripped from the content
  it_parses %q(
    #doc foo
    #|
    #|
    #| The first two lines of this doc are stripped.
    nil
  ),                            doc("foo", "The first two lines of this doc are stripped.")

  # Doc comment content is simply parsed as raw text. There is no required format.
  it_parses %q(
    #doc foo
    #|
    #| Letters, 12345, ^!#$(*&!#)%(^*)\n\t
    #| %.###131
    nil
  ),                           doc("foo", %q(Letters, 12345, ^!#$(*&!#)%(^*)\n\t %.###131))

  # Doc comments are only valid if followed by an expression
  it_does_not_parse %q(
    #doc foo
  )
  it_does_not_parse %q(
    #doc foo
    #| some documentation.
  )

  # Whitespace between a doc comment and its target is ignored
  it_parses %q(
    #doc foo

    nil
  ),                          doc("foo")

  # Docs can be attached to any kind of node, but generally only apply to modules, types, methods, and constants.
  it_parses %q(
    #doc foo
    defmodule Foo; end
  ),                          doc("foo", target: ModuleDef.new("Foo"))
  it_parses %q(
    #doc foo
    deftype Foo; end
  ),                          doc("foo", target: TypeDef.new("Foo"))
  it_parses %q(
    #doc foo
    def foo; end
  ),                          doc("foo", target: Def.new("foo"))
  it_parses %q(
    #doc foo
    FOO = nil
  ),                          doc("foo", target: SimpleAssign.new(c("FOO"), l(nil)))

  # Doc comments do not affect parsing outside of their content. A doc comment placed
  # immediately above or below another expression should not affect that expression.
  it_parses %q(
    #doc foo
    def foo; end
  ),                          doc("foo", target: Def.new("foo"))
  it_parses %q(
    #doc Foo
    deftype Foo; end
  ),                          doc("Foo", target: TypeDef.new("Foo"))
  it_parses %q(
    #doc Foo
    defmodule Foo; end
  ),                          doc("Foo", target: ModuleDef.new("Foo"))
  it_parses %q(
    #doc addition
    1 + 1
  ),                          doc("addition", target: Call.new(l(1), "+", [l(1)], infix: true))
end
