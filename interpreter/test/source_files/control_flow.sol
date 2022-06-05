function main() {
  if false {
    print("unreachable 1");
  }

  if true {
    print("reachable 1");
  } else {
    print("unreachable 2");
  }

  if false {
    print("unreachable 3");
  } else if false {
    print("unreachable 4");
  } else if true {
    print("reachable 2");
  } else {
    print("unreachable 5");
  }

  if false {
    print("unreachable 6");
  } else if false {
    print("unreachable 7");
  } else {
    print("reachable 3");
  }
}
