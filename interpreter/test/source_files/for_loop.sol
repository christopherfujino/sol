function maxNumber(numbers Number[]) -> Number {
  variable max = 0;
  for index, number in numbers {
    if index == 0 {
      max = number;
      continue;
    }
    if number > max {
      max = number;
    }
  }
  return max;
}

function main() {
  variable allNumbers = Number[1, 7, 3];
  variable bigNumber = maxNumber(allNumbers);
  print("The biggest number is " + String(bigNumber));
}
