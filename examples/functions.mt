def func(a, b)
  a + b
end

x = 1
y = 2
func(x, y)
func(4, func(x, y) + func(y, x))