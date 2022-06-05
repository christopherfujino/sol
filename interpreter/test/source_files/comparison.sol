# depends on ./control_flow.sol

function main() {
  variable foo = false;

  if foo == false {
    print("reachable 1");
  }

  if foo != true {
    print("reachable 2");
  }

  variable num = 3;

  if num > 2 {
    print("reachable 3");
  }
  if num > 5 {
    print("unreachable 1");
  }
  if num < 5 {
    print("reachable 4");
  }
  if num < 1 {
    print("unreachable 2");
  }

  if num >= 2 {
    print("reachable 5");
  }
  if num >= 3 {
    print("reachable 6");
  }
  if num >= 4 {
    print("unreachable 3");
  }

  if num <= 4 {
    print("reachable 7");
  }
  if num <= 3 {
    print("reachable 8");
  }
  if num <= 2 {
    print("unreachable 4");
  }
}
