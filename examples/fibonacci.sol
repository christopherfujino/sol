function fibonacci(n Number) -> Number {
  if (n <= 1) {
    return n;
  }
  return fibonacci(n - 1) + fibonacci(n - 2);
}

function main() {
  variable fib20 = fibonacci(20);
  print(String(fib20)); # 6765
}
