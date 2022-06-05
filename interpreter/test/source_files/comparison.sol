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
  #if num > 5 {
  #  print("unreachable 1");
  #}
  #if num < 5 {
  #  print("reachable 4");
  #}
  #if num < 1 {
  #  print("unreachable 2");
  #}
}
